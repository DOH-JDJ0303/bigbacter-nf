process PUSH_PP_DB {
    publishDir "${db_path}/${taxa}/pp_db/"

    input:
    tuple path(new_db), path(cache), val(taxa)
    val db_path

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
    publishDir "${db_path}/${taxa}/clusters/"

    input:
    tuple val(cluster), val(taxa), path(bb_db), path(snippy_new), val(core), val(status)
    val db_path

    output:
    path '${cluster_dir}/'

    when:
    task.ext.when == null || task.ext.when

    shell:
    cluster_dir = bb_db.name
    """
    mv !{snippy_new}/*/ !{bb_db}/snippy/ || true
    """
}

process PUSH_BB_DB_OLD {
    publishDir "${db_path}/${taxa}/clusters/${cluster}/snippy/"

    input:
    tuple val(cluster), val(taxa), val(bb_db), path(snippy_new), val(core), val(status)
    val db_path

    output:
    path 'snippy_new/*'

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    """
}
