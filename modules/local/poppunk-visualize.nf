process POPPUNK_VISUAL {
    tag "${taxa}"
    label 'process_medium'

    input:
    tuple val(taxa), path(db)
    val timestamp

    output:
    path "results/*",    emit: results
    path 'versions.yml', emit: versions


    when:
    task.ext.when == null || task.ext.when

    shell:
    args           = task.ext.args ?: ''
    prefix         = "${timestamp}-${taxa}"
    db_name        = db.name
    '''
    # decompress database
    db_comp="!{db_name}"
    db=${db_comp%.tar.gz}
    tar -xzvf !{db} -C ./

    # create visuals
    poppunk_visualise --ref-db ${db} --output !{prefix}-poppunk !{args} 
    
    # move files to simplify output
    mkdir results && mv !{prefix}-poppunk/* results/

    # version info
    echo "!{task.process}:\n    poppunk: $(poppunk_assign --version | cut -f 2 -d ' ' | tr -d '\n\r\t ')" > versions.yml
    '''
}
