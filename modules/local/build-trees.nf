process IQTREE {
    input:
    tuple val(taxa), val(cluster), path(core)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("${prefix}.*", includeInputs: true), emit: results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    taxa_name    = taxa[0]
    cluster_name = cluster[0]
    prefix       = "${timestamp}-${taxa_name}-${cluster_name}-core"
    '''
    # run IQTREE2
    iqtree2 -s !{prefix}.aln !{args} || true
    # check for output
    if [[ ! -f "*.treefile" ]]
    then
        touch !{prefix}.treefile.fail
    fi
    '''
}

process MASH_TREE_CLUSTER {

    input:
    tuple val(taxa), val(cluster), val(new_sketch), path(ava_cluster)
    val timestamp

    output:
    tuple val(taxa), val(cluster), val(new_sketch), path("mash-ava-cluster.treefile*"), emit: results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    taxa_name    = taxa[0]
    cluster_name = cluster[0]
    '''
    build-mash-tree.R !{ava_cluster} || true
    if [[ ! -f "mash-ava-cluster.treefile" ]]
    then
        touch mash-ava-cluster.treefile.fail
    fi
    '''
}