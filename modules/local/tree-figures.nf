process TREE_FIGURE_CLUSTER {

    input:
    tuple val(taxa_cluster), val(taxa), val(cluster), path(core), path(ava_cluster)
    val timestamp

    output:
    path "*.jpg*", emit: tree_figures

    when:
    task.ext.when == null || task.ext.when

    shell:
    taxa_name    = taxa[0]
    cluster_name = cluster[0]
    prefix       = "${timestamp}-${taxa_name}-${cluster_name}-core"
    '''
    # core SNP tree
    if [[ -f '!{prefix}.aln.treefile' ]]
    then
        tree-figures.R '!{prefix}.aln.treefile'
    else
        touch '!{prefix}.fail'
    fi
    # Mash tree
    if [[ -f 'mash-ava-cluster.treefile' ]]
    then
        tree-figures.R 'mash-ava-cluster.treefile'
    else
        touch 'mash-ava-cluster.treefile.jpg.fail'
    fi
    '''
}

process TREE_FIGURE_ALL {

    input:
    tuple val(taxa), path(ava_taxa)
    val timestamp

    output:
    path "*.jpg*", emit: tree_figures

    when:
    task.ext.when == null || task.ext.when

    shell:
    taxa_name = taxa[0]
    '''
    # Mash tree
    if [[ -f 'mash-ava-all.treefile' ]]
    then
        tree-figures.R 'mash-ava-all.treefile'
    else
        touch 'mash-ava-all.treefile.jpg.fail'
    fi
    '''
}
