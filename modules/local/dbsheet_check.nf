process DBSHEET_CHECK {
    tag "$dbsheet"
    label 'process_single'

    conda "conda-forge::python=3.8.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    path dbsheet

    output:
    path '*.csv', emit: csv

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/bigbacter/bin/
    """
    cp ${dbsheet} dbsheet.valid.csv
    """
}
