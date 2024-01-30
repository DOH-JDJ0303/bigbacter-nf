process SNIPPY_SINGLE {
    tag "${sample}"
    label "process_high"

    input:
    tuple val(sample), val(taxa), val(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status), path(ref)
    val timestamp

    output:
    tuple val(sample), path('*.tar.gz'), emit: results
    path 'versions.yml',                 emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    args = task.ext.args ?: ''
    '''
    # check if the reference is compressed
    ref=!{ref}
    if [[ !{ref} == *.gz ]]
    then
        gzip -d !{ref}
        ref=${ref%.gz}
    fi

    # run Snippy
    snippy \
        --reference ${ref} \
        --R1 !{fastq_1} \
        --R2 !{fastq_2} \
        --outdir ./!{sample} \
        --cpus !{task.cpus} \
        !{args}

    # compress output
    tar -czvf !{sample}.tar.gz !{sample}/

    #### VERSION INFO ####
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        snippy: $(snippy --version | cut -f 2 -d ' ')
    END_VERSIONS
    '''
}

process SNIPPY_CORE {
    tag "${taxa}_${cluster}"
    label "process_medium"

    input:
    tuple val(taxa), val(cluster), path(ref), path("new_files/*"), path("old_files")
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("${prefix}.snippy.stats"),                              emit: stats
    tuple val(taxa), val(cluster), path("${prefix}.aln"), path("${prefix}-constant-sites.txt"), emit: aln
    tuple val(taxa), val(cluster), path("${prefix}.full.aln"),                                  emit: full_aln
    path 'versions.yml',                                                                        emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    prefix       = "${timestamp}-${taxa}-${cluster}"
    '''
    # check if the reference is compressed
    ref=!{ref}
    if [[ !{ref} == *.gz ]]
    then
        gzip -d !{ref}
        ref=${ref%.gz}
    fi

    # move files into common directory
    # old files do not replace new files if the name is the same
    mkdir all_files
    mv new_files/*.tar.gz all_files/
    mv -n old_files/*.tar.gz all_files/ || true
    # extract files
    cd all_files/
    for f in $(ls *.tar.gz)
    do
        echo "Extracting ${f}"
        tar -xzvhf ${f} -C ./
    done
    rm *.tar.gz
    cd ../

    # run Snippy-core
    # it is possible that no SNPs are found, so this will always be allowed to succeed
    mkdir core
    cd core
    snippy-core --prefix !{prefix} --ref ../${ref} !{args} ../all_files/* || true
    cd ../

    # gather core stats and re-run snippy-core if any samples failed QC
    ## gather stats
    echo -e "$(head -n 1 core/!{prefix}.txt)\tPER_GENFRAC\tPER_LOWCOV\tPER_HET\tQUAL" > !{prefix}.snippy.stats
    cat core/!{prefix}.txt | tail -n +2 | awk '{genfrac = 100*$3/$2; plow = 100*$8/$2; phet = 100*$6/$2; print $0, genfrac, plow, phet}' | awk -v g="!{params.min_genfrac}" -v h="!{params.max_het}" -v l="!{params.max_lowcov}" '{if($9 < g || $10 > l || $11 > h) print $0, "FAIL"; else print $0, "PASS"}' | tr ' ' '\t' >> !{prefix}.snippy.stats
    n_fail=$(cat !{prefix}.snippy.stats | awk '$12 == "FAIL" {print $0}' | wc -l)
    n_pass=$(cat !{prefix}.snippy.stats | awk '$12 == "PASS" {print $0}' | wc -l)
    if [[ ${n_fail} > 0 ]]
    then
        ## remove current core SNP results
        rm core/!{prefix}*
        ## check if all samples failed QC
        if [[ ${n_pass} > 0 ]]
        then
            pass=$(cat !{prefix}.snippy.stats | awk '$12 == "PASS" && $1 != "Reference" {print "../all_files/"$1}')
            cd core/
            snippy-core --prefix !{prefix} --ref ../${ref} !{args} ${pass} || true
            cd ../
        else
            echo "\nAll samples failed QC\n"
            exit 1
        fi
    fi

    # move alignment files to simplify publish
    mv core/*.aln ./

    # create empty core alignment file if no SNPs were found
    if [ ! -s !{prefix}.aln ]
    then
        touch !{prefix}.aln
    fi

    # get constant sites
    snp-sites -C !{prefix}.full.aln > !{prefix}-constant-sites.txt || true

    #### VERSION INFO #### - normal approach throws error
    echo -e "\\"!{task.process}\\":\n    snippy: $(snippy --version | cut -f 2 -d ' ')" > versions.yml
    '''
}
