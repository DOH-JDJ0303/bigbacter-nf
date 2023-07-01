process CALL_VARIANTS_NEW {
    input:
    tuple val(taxa_cluster), val(samples), val(taxa), path(assemblies), path(fastq_1), path(fastq_2), val(cluster), val(status)

    output:
    tuple val(taxa_cluster), val(cluster_name), val(taxa_name), path(cluster_name), path("snippy_new/*.tar.gz"), path("core/core.*"), val(status), emit: snippy_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    def args           = task.ext.args ?: ''
    def assembly_names = assemblies.name
    def fwd_reads      = fastq_1.name
    def rev_reads      = fastq_2.name
    def taxa_name      = taxa[0]
    def cluster_name   = cluster[0]
    '''
    # create .tsv of samples and their associated files
    echo !{samples} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
    echo !{fwd_reads} | tr -d '[] ' | tr ',' '\n' > r1_col
    echo !{fwd_reads} | tr -d '[] ' | tr ',' '\n' > r2_col
    paste s_col a_col r1_col r2_col > manifest.tsv

    # make directory structure
    mkdir -p \
        !{cluster_name}/ref \
        !{cluster_name}/snippy

    # select a reference genome
    ref=$(cat manifest.tsv | head -n 1 | cut -f 2)
    cp ${ref} !{cluster_name}/ref/!{taxa_name}-!{cluster_name}-ref.fa

    # run Snippy on each sample individually
    mkdir snippy_new
    echo '#!/bin/bash' > snippy_script.sh
    cat manifest.tsv | awk '{print "snippy --cleanup --cpus 8 --reference !{cluster_name}/ref/*.fa --R1 "$3" --R2 "$4" --outdir snippy_new/"$1 }' >> snippy_script.sh
    bash snippy_script.sh
   
    # run snippy-core
    mkdir core
    cd core
    snippy-core --ref ../!{cluster_name}/ref/*.fa ../snippy_new/* || true
    cd ../

    # gather core stats and re-run snippy-core is any samples failed QC
    ## gather stats
    echo -e "$(cat core/core.txt | head -n 1)\tPER_GENFRAC\tPER_LOWCOV\tPER_HET\tQUAL" > core.stats
    cat core/core.txt | tail -n +2 | awk '{genfrac = 100*($3-$8)/($2-$7); plow = 100*$8/($2-$7); phet = 100*$6/($2-$7); print $0, genfrac, plow, phet}' | awk -v g="!{params.min_genfrac}" -v h="!{params.max_het}" -v l="!{params.max_lowcov}" '{if($9 < g || $10 > l || $11 > h) print $0, "FAIL"; else print $0, "PASS"}' | tr ' ' '\t' >> core.stats
    ## count number of samples that passed and failed QC
    n_fail=$(cat core.stats | awk '$12 == "FAIL" {print $0}' | wc -l)
    n_pass=$(cat core.stats | awk '$12 == "PASS" {print $0}' | wc -l)
    if [[ ${n_fail} > 0 ]]
    then
        ## remove current core SNP results
        rm core/core*
        ## check if all samples failed QC
        if [[ ${n_pass} > 0 ]]
        then
            pass=$(cat core.stats | awk '$12 == "PASS" && $1 != "Reference" {print "../snippy_new/"$1}')
            cd core/
            snippy-core --ref ../!{cluster_name}/ref/*.fa ${pass} || true
            cd ../
        else
            echo "All samples failed QC" > core/core.fail
        fi
    fi
    ## include core.stats in output
    mv core.stats core/
    
    # compress outputs
    cd snippy_new
    dirs=$(ls -d */)
    for d in ${dirs}
    do
        name=${d%/}
        tar -czvf ${name##*/}.tar.gz ${d}
    done
    cd ../
    '''
}


process CALL_VARIANTS_OLD {
    input:
    tuple val(taxa_cluster), val(samples), val(taxa), path(assemblies), path(fastq_1), path(fastq_2), val(cluster), val(status), path(cluster_dir)

    output:
    tuple val(taxa_cluster), val(cluster_name), val(taxa_name), path(cluster_name), path('snippy_new/*.tar.gz'), path("core/core.*"), val(status), emit: snippy_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args           = task.ext.args ?: ''
    assembly_names = assemblies.name
    fwd_reads      = fastq_1.name
    rev_reads      = fastq_2.name
    taxa_name      = taxa[0]
    cluster_name   = cluster[0]
    snippy_new     = "snippy_new"
    '''
    # create .tsv of samples and their associated files
    echo !{samples} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
    echo !{fwd_reads} | tr -d '[] ' | tr ',' '\n' > r1_col
    echo !{fwd_reads} | tr -d '[] ' | tr ',' '\n' > r2_col
    paste s_col a_col r1_col r2_col > manifest.tsv

    # run Snippy on each sample individually
    mkdir snippy_new
    echo '#!/bin/bash' > snippy_script.sh
    cat manifest.tsv | awk '{print "snippy --cleanup --cpus 8 --reference !{cluster_dir}/ref/*.fa --R1 "$3" --R2 "$4" --outdir snippy_new/"$1 }' >> snippy_script.sh
    bash snippy_script.sh

    # run snippy-core
    ## check for previous samples
    mkdir core

    n=$(ls !{cluster_dir}/snippy/ | wc -l)
    if [[ $n > 0 ]]
    then
        mkdir snippy_old
        tars=$(ls !{cluster_dir}/snippy/*.tar.gz)
        for t in ${tars}
        do
            tar -xzvf ${t} -C snippy_old/
        done

       cd core
       snippy-core --ref ../!{cluster_dir}/ref/*.fa ../snippy_old/* ../snippy_new/* || true
    else
       cd core
       snippy-core --ref ../!{cluster_dir}/ref/*.fa ../snippy_new/* || true
    fi
    cd ../

    # gather core stats and re-run snippy-core is any samples failed QC
    ## gather stats
    echo -e "$(cat core/core.txt | head -n 1)\tPER_GENFRAC\tPER_LOWCOV\tPER_HET\tQUAL" > core.stats
    cat core/core.txt | tail -n +2 | awk '{genfrac = 100*($3-$8)/($2-$7); plow = 100*$8/($2-$7); phet = 100*$6/($2-$7); print $0, genfrac, plow, phet}' | awk -v g="!{params.min_genfrac}" -v h="!{params.max_het}" -v l="!{params.max_lowcov}" '{if($9 < g || $10 > l || $11 > h) print $0, "FAIL"; else print $0, "PASS"}' | tr ' ' '\t' >> core.stats
    n_fail=$(cat core.stats | awk '$12 == "FAIL" {print $0}' | wc -l)
    n_pass=$(cat core.stats | awk '$12 == "PASS" {print $0}' | wc -l)
    if [[ ${n_fail} > 0 ]]
    then
        ## remove current core SNP results
        rm core/core*
        ## check if all samples failed QC
        if [[ ${n_pass} > 0 ]]
        then
            pass=$(cat core.stats | awk '$12 == "PASS" && $1 != "Reference" {print "../snippy_*/"$1}')
            cd core/
            snippy-core --ref ../!{cluster_name}/ref/*.fa ${pass} || true
            cd ../
        else
            echo "All samples failed QC" > core/core.fail
        fi
    fi
    ## include core.stats in output
    mv core.stats core/

    # compress outputs
    cd snippy_new
    dirs=$(ls -d */)
    for d in ${dirs}
    do
        name=${d%/}
        tar -czvf ${name##*/}.tar.gz ${d}
    done
    cd ../
    '''
}
