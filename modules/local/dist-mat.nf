process DIST_MAT {
    tag "${taxa}_${cluster}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), path(dist), path(tree)
    path manifest
    val timestamp

    output:
    path "*.jpg"

    when:
    task.ext.when == null || task.ext.when

    shell:
    args   = task.ext.args ?: ''
    prefix = "${timestamp}-${taxa}-${cluster}"
    '''
    # make figure
    dist-mat.R !{dist} !{tree} !{manifest}
    # rename figure
    mv snp-matrix.jpg "!{prefix}_core-snps_matrix.jpg"
    '''
}