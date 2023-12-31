process TREE_FIGURE {
    tag "${taxa}_${cluster}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), path(tree)
    path manifest
    val timestamp

    output:
    path "*.jpg*"
    path "corrected.nwk", optional: true

    when:
    task.ext.when == null || task.ext.when

    shell:
    prefix = "${timestamp}-${taxa}-${cluster}"
    '''
    tree-figures.R !{tree} !{manifest}
    '''
}
