process PUSH_CLUSTER_FILES {

    input:
    tuple val(taxa), val(cluster), path(ref), path(new_snippy), path(sketch)

    output:
    path ref
    path new_snippy
    path sketch
    
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}

process PUSH_TAXA_FILES {

    input:
    tuple val(taxa), path(new_pp_db)

    output:
    path new_pp_db

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}
