process SNIPPY_SINGLE {
    input:
    tuple val(sample), val(taxa), val(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status), path(ref)
    val timestamp

    output:
    tuple val(sample), path('*.tar.gz'), emit: results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args = task.ext.args ?: ''
    '''
    # run Snippy
    snippy \
        --reference !{ref} \
        --R1 !{fastq_1} \
        --R2 !{fastq_2} \
        --outdir ./!{sample} \
        !{args}

    # compress output
    tar -czvf !{sample}.tar.gz !{sample}/
    '''
}

process SNIPPY_CORE {
    input:
    tuple val(taxa), val(cluster), path(reference), path(new_snippy), path(old_snippy)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path('core/*'), emit: results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    new_files    = new_snippy.name
    old_files    = old_snippy.name == "main.nf" ? '' : old_snippy.name
    taxa_name    = taxa[0]
    cluster_name = cluster[0]
    prefix       = "${timestamp}-${taxa_name}-${cluster_name}-core"
    '''
    # Extract files
    mkdir snippy_files
    new_files=$(echo !{new_files} | tr -d '[] ' | tr ',' '\n' | grep "tar.gz")
    if [ -d !{old_files} ]
    then
        old_files=$(ls !{old_files} | grep "tar.gz")
    else
        old_files=""
    fi
    all_files="${new_files} ${old_files}"
    for f in ${all_files}
    do
        echo "Extracting ${f}"
        tar -xzvhf ${f} -C snippy_files/
    done

    # run Snippy-core
    mkdir core
    cd core
    snippy-core --prefix !{prefix} --ref ../!{reference} !{args} ../snippy_files/* || true
    cd ../

    # gather core stats and re-run snippy-core if any samples failed QC
    ## gather stats
    echo -e "$(head -n 1 core/!{prefix}.txt)\tPER_GENFRAC\tPER_LOWCOV\tPER_HET\tQUAL" > !{prefix}.stats
    cat core/!{prefix}.txt | tail -n +2 | awk '{genfrac = 100*($3-$8)/($2-$7); plow = 100*$8/($2-$7); phet = 100*$6/($2-$7); print $0, genfrac, plow, phet}' | awk -v g="!{params.min_genfrac}" -v h="!{params.max_het}" -v l="!{params.max_lowcov}" '{if($9 < g || $10 > l || $11 > h) print $0, "FAIL"; else print $0, "PASS"}' | tr ' ' '\t' >> !{prefix}.stats
    n_fail=$(cat !{prefix}.stats | awk '$12 == "FAIL" {print $0}' | wc -l)
    n_pass=$(cat !{prefix}.stats | awk '$12 == "PASS" {print $0}' | wc -l)
    if [[ ${n_fail} > 0 ]]
    then
        ## remove current core SNP results
        rm core/!{prefix}*
        ## check if all samples failed QC
        if [[ ${n_pass} > 0 ]]
        then
            pass=$(cat !{prefix}.stats | awk '$12 == "PASS" && $1 != "Reference" {print "../snippy_files/"$1}')
            cd core/
            snippy-core --ref ../!{reference} !{args} ${pass} || true
            cd ../
        else
            echo "All samples failed QC" > core/!{prefix}.fail
        fi
    fi
    ## include !{prefix}.stats in output
    mv !{prefix}.stats core/
    '''
}
