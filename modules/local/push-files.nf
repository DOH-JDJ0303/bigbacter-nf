process PUSH_CLUSTER_FILES {

    input:
    tuple val(taxa_cluster), val(taxa), val(cluster), path(reference), path(new_snippy), path(new_cluster_sketch), path(new_cluster_cache), val(summary)

    output:
    tuple path(reference), path(new_snippy), path(new_cluster_sketch), path(new_cluster_cache)
    
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}

process PUSH_TAXA_FILES {

    input:
    tuple val(taxa), path(new_pp_db), path(new_pp_cache), path(new_taxa_sketch), val(summary)

    output:
    tuple path(new_pp_db), path(new_pp_cache), path(new_taxa_sketch)

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}
