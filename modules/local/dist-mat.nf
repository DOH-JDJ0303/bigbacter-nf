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
    tuple val(taxa), val(cluster), val(input_source), path("*.jpg"),          emit: figure, optional: true
    tuple val(taxa), val(cluster), val(input_source), path("*-metadata.csv"), emit: meta, optional: true
    tuple val(taxa), val(cluster), val(input_source), path("*-wide.csv"),     emit: dist_wide
    tuple val(taxa), val(cluster), val(input_source), path("*-long.csv"),     emit: dist_long

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
        "!{prefix}" \
        "!{params.max_static}" \
        "!{params.partition_threshold}"
    '''
}
