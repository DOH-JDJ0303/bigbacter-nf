process PREPARE_DB_MOD {

    input:
    tuple val(taxa), path(pp_db)

    output:
    path "0000000000.tar.gz"
    
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # prepare the PopPUNK database
    prepare-pp-db.sh ${pp_db} 0000000000
    """
}

