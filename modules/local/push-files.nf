process PUSH_PP_DB {
    publishDir "${params.db}/${taxa}/pp_db/", mode: 'copy'

    input:
    tuple path(new_db), path(cache), val(taxa)

    output:
    path(new_db)
    path(cache)
    
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}

process PUSH_BB_DB_NEW {
    publishDir "${params.db}/${taxa}/clusters/", mode: 'copy'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), path(bb_db), path(snippy_new), val(core), val(status), path(mash_sketch), path(mash_cache), val(ava_cluster)

    output:
    path bb_db, includeInputs: true

    when:
    task.ext.when == null || task.ext.when

    shell:
    """
    mv !{snippy_new} !{bb_db}/snippy/
    mkdir !{bb_db}/mash
    mv !{mash_sketch} !{mash_cache} !{bb_db}/mash/
    """
}

process PUSH_SNIPPY_OLD {
    publishDir "${params.db}/${taxa}/clusters/${cluster}/snippy/", mode: 'copy'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), path(snippy_new), val(core), val(status), val(mash_sketch), val(mash_cache), val(ava_cluster)

    output:
    path '*.tar.gz', includeInputs: true

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}

process PUSH_MASH_OLD {
    publishDir "${params.db}/${taxa}/clusters/${cluster}/mash/", mode: 'copy'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), val(core), val(status), path(mash_sketch), path(mash_cache), val(ava_cluster)

    output:
    path '*.msh', includeInputs: true
    path 'CACHE', includeInputs: true

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}

process PUSH_MASH_ALL {
    publishDir "${params.db}/${taxa_name}/mash/", mode: 'copy'

    input:
    tuple val(taxa), path(mash_sketch), path(mash_cache), val(ava_all)

    output:
    path '*.msh', includeInputs: true
    path 'CACHE', includeInputs: true

    when:
    task.ext.when == null || task.ext.when

    script:
    taxa_name = taxa[0]
    """
    """
}
