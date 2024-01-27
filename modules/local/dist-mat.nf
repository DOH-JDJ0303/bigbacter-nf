process DIST_MAT {
    tag "${taxa}_${cluster}"
    label 'process_low'
    stageInMode 'copy'

    input:
    tuple val(taxa), val(cluster), path(dist), path(tree)
    path manifest
    val input_format
    val input_type
    val threshold
    val timestamp

    output:
    path "*.jpg"
    path "*.csv"

    when:
    task.ext.when == null || task.ext.when

    shell:
    args   = task.ext.args ?: ''
    prefix = "${timestamp}-${taxa}-${cluster}"
    '''
    # make figure
    dist-figures.R "!{dist}" "!{tree}" "!{manifest}" "!{input_format}" "!{input_type}" "!{threshold}" "!{prefix}"
    '''
}