process IQTREE {
    input:
    tuple val(taxa_cluster), val(taxa), val(cluster), path(core)
    val timestamp

    output:
    tuple val(taxa_cluster), val(taxa), val(cluster), path("${prefix}.*", includeInputs: true), emit: results

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
        touch !{prefix}.fail.treefile
    fi
    '''
}


process MASH_TREE_CLUSTER {

    input:
    tuple val(taxa_cluster), val(taxa), val(cluster), val(new_mash), val(mash_cache), path(ava_cluster)
    val timestamp

    output:
    tuple val(taxa_cluster), val(new_mash), val(mash_cache), path("*.treefile", includeInputs: true), emit: mash_results

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
        touch mash-ava-cluster.fail.treefile
    fi
    '''
}

process MASH_TREE_ALL {

    input:
    tuple val(taxa), val(new_mash), val(mash_cache), path(ava_all)
    val timestamp

    output:
    tuple val(taxa), val(new_mash), val(mash_cache), path("*.treefile", includeInputs: true), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args      = task.ext.args ?: ''
    taxa_name    = taxa[0]
    '''
    build-mash-tree.R !{ava_all} || true
    if [[ ! -f "mash-ava-all.treefile" ]]
    then
        touch mash-ava-all.fail.treefile
    fi
    '''
}
