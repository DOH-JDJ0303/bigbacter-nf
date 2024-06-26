process DIST_MAT {
    tag "${taxa}_${cluster}_${input_source}"
    label 'process_low'
    stageInMode 'copy'
    errorStrategy 'ignore'

    input:
    tuple val(taxa), val(cluster), val(input_source), path(dist), path(tree), path(manifest)
    val input_format
    val input_type
    val threshold
    val percent_bool
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
    dist-figures.R \
        "!{dist}" \
        "!{tree}" \
        "!{manifest}" \
        "!{input_format}" \
        "!{input_type}" \
        "!{input_source}" \
        "!{threshold}" \
        "!{percent_bool}" \
        "!{prefix}"
    '''
}
