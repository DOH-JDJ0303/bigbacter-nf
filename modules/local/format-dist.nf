process FORMAT_DIST {
    tag "${taxa}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), path(dist), path(tree)
    val cols

    output:
    tuple val(taxa), val(cluster ), path("dist.formatted.txt"), path(tree), emit: dist

    when:
    task.ext.when == null || task.ext.when

    shell:
    args   = task.ext.args ?: ''
    '''
    # filter dist file to contain only samples in the core SNP tree.
    # doing this with shell is much faster than R or Python
    format-dist.sh "!{dist}" "!{tree}" "!{cols}"
    '''
}