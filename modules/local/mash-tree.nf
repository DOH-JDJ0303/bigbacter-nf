process MASH_TREE {

    input:
    tuple val(taxa), val(cluster), val(new_sketch), path(ava_cluster)
    val timestamp

    output:
    tuple val(taxa), val(cluster),  path("*.treefile"), emit: results, optional: true

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    '''
    mash-tree.R !{ava_cluster} || true
    '''
}