//
// Perform all-vs-all Mash comparisons
//

include { MASH_DIST } from '../../modules/local/mash-dist'
include { MASH_TREE } from '../../modules/local/mash-tree'

workflow MASH {
    take:
    manifest   // channel: [ val(sample), val(taxa), path(assembly), val(fastq_1), val(fastq_2), val(cluster), val(status) ]
    timestamp  // channel: val(timestamp)

    main:
    // Group samples by cluster
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, status, sample, assembly] }
        .groupTuple(by: [0,1,2])
        .set{ clust_grps }
    
    // Build paths for existing sketch files
    // New samples - no files exist
    clust_grps.filter{ taxa, cluster, status, sample, assembly -> status == "new" }.map{ taxa, cluster, status, sample, assembly -> [taxa, cluster, status, sample, assembly, []] }.set{ clust_grp_new }
    // Old samples
    clust_grps
        .filter{ taxa, cluster, status, sample, assembly -> status == "old" }
        .map{ taxa, cluster, status, sample, assembly -> [taxa, cluster, status, sample, assembly, file(params.db).resolve(taxa).resolve("clusters").resolve(cluster).resolve("mash") ] }
        .concat(clust_grp_new)
        .set{mash_files}

    // Run mash & build tree
    MASH_DIST(
        mash_files,
        timestamp
    )
    
    MASH_TREE(
        MASH_DIST.out.results,
        timestamp
    )

    emit:
    mash_files = MASH_DIST.out.results // channel: [val(taxa), val(cluster), new_sketch, ava]
    mash_tree = MASH_TREE.out.results  // channel: [val(taxa), val(cluster), path(tree)]
}
