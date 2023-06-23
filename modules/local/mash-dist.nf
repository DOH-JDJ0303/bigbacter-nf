process MASH_DIST_CLUSTER_NEW {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa_cluster), val(sample), val(taxa), path(assembly), val(cluster), val(status), val(mash_sketch)

    output:
    tuple val(taxa_cluster), path('0.msh'), path('CACHE'), path('mash-ava-cluster.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # create sketch and cache for all assemblies
    mash sketch -o 0 !{assembly}
    echo '0' > CACHE
    # perform all-vs-all mash comparion
    mash dist 0.msh 0.msh > mash-ava-cluster.tsv
    '''
}

process MASH_DIST_CLUSTER_OLD {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa_cluster), val(sample), val(taxa), path(assembly), val(cluster), val(status), val(mash_sketch)
    val new_sketch

    output:
    tuple val(taxa_cluster), path("${new_sketch}.msh"), path('CACHE'), path('mash-ava-cluster.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # create sketch for all assemblies
    mash sketch -o new !{assembly}
    # add new sketch to the existing sketch and create cache
    mash paste "!{new_sketch}" !{mash_sketch} new.msh
    echo "!{new_sketch}" > CACHE
    # perform all-vs-all mash comparion
    mash dist !{new_sketch}.msh !{new_sketch}.msh > mash-ava-cluster.tsv
    '''
}

process MASH_DIST_ALL {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa), path(assembly), val(mash_sketch)
    val new_sketch

    output:
    tuple val(taxa), path("${new_sketch}.msh"), path('CACHE'), path('mash-ava-all.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # create sketch for all assemblies
    mash sketch -o new !{assembly}
    # add new sketch to the existing sketch and create cache
    mash paste "!{new_sketch}" !{mash_sketch} new.msh
    echo "!{new_sketch}" > CACHE
    # perform all-vs-all mash comparion
    mash dist !{new_sketch}.msh !{new_sketch}.msh > mash-ava-all.tsv
    '''
}
