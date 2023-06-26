process TREE_FIGURE_CLUSTER {
    container 'johnjare/spree:1.0'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path(core), val(status), val(mash_sketch_cluster), val(mash_cache_cluster), path(ava_cluster)

    output:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path('core.*', includeInputs: true), val(status), val(mash_sketch_cluster), val(mash_cache_cluster), path("mash-ava-cluster.*", includeInputs: true), emit: all_cluster_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # core SNP tree
    if [[ -f 'core.aln.treefile' ]]
    then
        tree-figures.R 'core.aln.treefile'
    else
        touch 'core.aln.treefile.fail.jpg'
    fi
    # Mash tree
    if [[ -f 'mash-ava-cluster.treefile' ]]
    then
        tree-figures.R 'mash-ava-cluster.treefile'
    else
        touch 'mash-ava-cluster.treefile.fail.jpg'
    fi
    '''
}

process TREE_FIGURE_ALL {
    container 'johnjare/spree:1.0'

    input:
    tuple val(taxa), val(mash_sketch_all), val(mash_cache_all), path(ava_all)

    output:
    tuple val(taxa), val(mash_sketch_all), val(mash_cache_all), path('mash-ava-all.*', includeInputs: true), emit: mash_all

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # Mash tree
    if [[ -f 'mash-ava-all.treefile' ]]
    then
        tree-figures.R 'mash-ava-all.treefile'
    else
        touch 'mash-ava-all.treefile.fail.jpg'
    fi
    '''
}
