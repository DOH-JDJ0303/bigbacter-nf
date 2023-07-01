//
// Perform all-vs-all Mash comparisons
//

include { GET_MASH_SKETCH_CLUSTER } from '../../modules/local/get-cache-files'
include { GET_MASH_SKETCH_ALL     } from '../../modules/local/get-cache-files'

include { MASH_DIST_CLUSTER_NEW   } from '../../modules/local/mash-dist'
include { MASH_DIST_CLUSTER_OLD   } from '../../modules/local/mash-dist'
include { MASH_DIST_ALL           } from '../../modules/local/mash-dist'

include { MASH_TREE_CLUSTER       } from '../../modules/local/build-trees'
include { MASH_TREE_ALL           } from '../../modules/local/build-trees'

workflow MASH_SKETCH {
    take:
    manifest   // channel: [ val(taxa_cluster), val(sample), val(taxa), path(assembly), val(fastq_1), val(fastq_2), val(cluster), val(status) ]
    timestamp  // channel: val(timestamp)

    main:
    // Group by 'taxa_cluster', simplify, and add cluster cache path
    manifest
        .map { taxa_cluster, sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa_cluster, sample, taxa, assembly, cluster, status ] }
        .groupTuple(by: 0)
        .map { taxa_cluster, sample, taxa, assembly, cluster, status -> [taxa_cluster, sample, taxa, assembly, cluster, status[0], params.db+taxa.get(0)+"/clusters/"+cluster.get(0)+"/mash/CACHE"] }
        .set { manifest_simple }

    // Split samples into new and old
    // New clusters
    manifest_simple
        .filter { taxa_cluster, sample, taxa, assembly, cluster, status, cluster_cache -> status == "new" }
        .set { new_clusters }
    // Old clusters
    manifest_simple
        .filter { taxa_cluster, sample, taxa, assembly, cluster, status, cluster_cache -> status == "old" }
        .set { old_clusters }
    // Prepare manifest for all sample comparison 
    manifest_simple
        .map {taxa_cluster, sample, taxa, assembly, cluster, status, cluster_cache -> [sample, taxa, assembly, params.db+taxa.get(0)+"/mash/CACHE"] }
        .set { all_with_cache }

    // Determine which sketch files to use
    // Per cluster - old samples only
    GET_MASH_SKETCH_CLUSTER(
        old_clusters,
        timestamp
    )
    // All samples
    GET_MASH_SKETCH_ALL(
        all_with_cache,
        timestamp
    )

    // Run mash & build trees
    // Per cluster
    MASH_DIST_CLUSTER_NEW(
        new_clusters,
        timestamp
    )
    MASH_DIST_CLUSTER_OLD(
        GET_MASH_SKETCH_CLUSTER.out.mash_cluster, 
        timestamp
    )

    MASH_DIST_CLUSTER_NEW
        .out
        .mash_results
        .concat(MASH_DIST_CLUSTER_OLD.out.mash_results)
        .set { mash_cluster }

    MASH_TREE_CLUSTER(
        mash_cluster,
        timestamp
    )

    // All samples
    MASH_DIST_ALL(
        GET_MASH_SKETCH_ALL.out.mash_all,
        timestamp
    )
    MASH_TREE_ALL(
        MASH_DIST_ALL.out.mash_results,
        timestamp
        
    )

    emit:
    mash_cluster = MASH_TREE_CLUSTER.out.mash_results // channel: [val(taxa_cluster), new_mash, mash_cache, ava_cluster]
    mash_all = MASH_TREE_ALL.out.mash_results         // channel: [val(taxa), new_mash, mash_cache, ava_all]
}
