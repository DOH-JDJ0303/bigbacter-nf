process IQTREE {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path(core), val(status)

    output:
    tuple val(taxa_cluster), path("*.treefile")

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


   mash_cluster = mash_cluster // channel: [val(taxa_cluster), new_mash, mash_cache, ava_cluster]
    mash_all = MASH_DIST_ALL.out.mash_results // channel: [val(taxa), new_mash, mash_cache, ava_all]

process MASH_TREES {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa_cluster), val(new_mash_cluster), val(mash_cache_cluster), path(ava_cluster)
    tuple val(taxa), val(new_mash_all), val(mash_cache_all), path(ava_all)

    output:
    tuple val(taxa_cluster), path("*.treefile")

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    
    '''
}
