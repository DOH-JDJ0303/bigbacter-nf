process TREE_FIGURE {

    input:
    tuple val(taxa), val(cluster), path(tree)
    val timestamp

    output:
    path "*.jpg*"

    when:
    task.ext.when == null || task.ext.when

    shell:
    prefix = "${timestamp}-${taxa}-${cluster}-core"
    '''
    tree-figures.R *.treefile
    '''
}
