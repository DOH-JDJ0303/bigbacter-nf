process PUSH_PP_DBS {
    publishDir "${db_path}/${taxa}/pp_db/"

    input:
    tuple path(new_db), path(cache), val(taxa), val(references) 
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

process PUSH_PP_REFS {
    publishDir "${db_path}/${taxa}/refs/"

    input:
    tuple val(new_db), val(CACHE), val(taxa), path(references)
    val db_path

    output:
    path '*.fa', optional: true, includeInputs: true

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    rm placeholder.tmp.fa
    """
}
