process IQTREE {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path(core), val(status)

    output:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path('core.*', includeInputs: true), val(status), emit: snp_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # run IQTREE2
    iqtree -s core.aln || true
    # check for output
    if [[ ! -f "*.treefile" ]]
    then
        touch core.fail.treefile
    fi
    '''
}


process MASH_TREE_CLUSTER {
    container 'johnjare/spree:1.0'

    input:
    tuple val(taxa_cluster), val(new_mash), val(mash_cache), path(ava_cluster)

    output:
    tuple val(taxa_cluster), val(new_mash), val(mash_cache), path("mash-ava-cluster.*", includeInputs: true), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    build-mash-tree.R !{ava_cluster} || true
    if [[ ! -f "mash-ava-cluster.treefile" ]]
    then
        touch mash-ava-cluster.fail.tree
    fi
    '''
}

process MASH_TREE_ALL {
    container 'johnjare/spree:1.0'

    input:
    tuple val(taxa), val(new_mash), val(mash_cache), path(ava_all)

    output:
    tuple val(taxa), val(new_mash), val(mash_cache), path("mash-ava-all.*", includeInputs: true), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    build-mash-tree.R !{ava_all} || true
    if [[ ! -f "mash-ava-all.treefile" ]]
    then
        touch mash-ava-all.fail.tree
    fi
    '''
}
