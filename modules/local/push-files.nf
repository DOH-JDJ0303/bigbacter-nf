process PUSH_CLUSTER_FILES {
    tag "${taxa}_${cluster}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), path(ref, stageAs: "ref.fa.gz"), path(new_snippy), path(assembly)

    output:
    tuple path(new_snippy), path(assembly), path('ref.fa.gz'), emit: cluster_files
    
    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # clean up the reference assembly
    ref=!{ref}
    ## compress (if necessary)
    if [[ !{ref} != *.gz ]]
    then
        gzip !{ref}
        ref="${ref}.gz"
    fi
    ## rename (if necessary)
    if [[ !{ref} != ref.fa.gz ]]
    then
        mv ${ref} ref.fa.gz
    fi
    '''
}

process PUSH_TAXA_FILES {
    tag "${taxa}"
    label 'process_low'

    input:
    tuple val(taxa), path(new_pp_db)

    output:
    path new_pp_db, emit: taxa_files

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}
