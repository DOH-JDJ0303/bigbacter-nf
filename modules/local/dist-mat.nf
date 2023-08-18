process DIST_MAT {

    input:
    tuple val(taxa), val(cluster), path(dist), path(tree)
    val timestamp

    output:
    path "*.jpg"

    when:
    task.ext.when == null || task.ext.when

    shell:
    args   = task.ext.args ?: ''
    prefix = "${timestamp}-${taxa}-${cluster}-snp-matrix"
    '''
    # make figure
    dist-mat.R !{dist} !{tree}
    # rename figure
    mv snp-matrix.jpg !{prefix}.jpg
    '''
}