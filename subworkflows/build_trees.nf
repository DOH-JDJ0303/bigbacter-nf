//
// Create tree files
//

include { IQTREE } from '../../modules/local/build-trees'
include { MASH_TREE_CLUSTER } from '../../modules/local/build-trees'
include { MASH_TREE_ALL } from '../../modules/local/build-trees'

workflow BUILD_TREES {
    take:
    
    mash_cluster // channel: [val(taxa_cluster), val(new_mash_cluster), val(mash_cache_cluster), path(ava_cluster)]
    mash_all // channel: [val(taxa), val(new_mash_all), val(mash_cache_all), path(ava_all)]

    main:
    // Split samples into new and old
    // New clusters
    manifest
        .filter { taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status -> status == "new" }
        .set { new_clusters }
    // Old clusters
    manifest
        .filter { taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status -> status == "old" }
        .map { taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status -> [taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status, params.db+taxas.get(0)+"/clusters/"+clusters.get(0)] }
        .set { old_clusters }

    CALL_VARIANTS_NEW(new_clusters)
    CALL_VARIANTS_OLD(old_clusters)

    CALL_VARIANTS_NEW
        .out
        .snippy_results
        .concat(CALL_VARIANTS_OLD.out.snippy_results)
        .set {new_bb_db}

    emit:
    new_bb_db = new_bb_db // channel: [taxa_cluster, cluster, taxa, bb_db, snippy_new, core, status]
}
