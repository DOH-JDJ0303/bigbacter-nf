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
    ch_versions = Channel.empty()
    // Group samples by cluster
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, status, sample, assembly] }
        .groupTuple(by: [0,1,2])
        .set{ clust_grps }
    
    // Build paths for existing sketch files
    // New samples - no files exist
    clust_grps.filter{ taxa, cluster, status, sample, assembly -> ! status }.map{ taxa, cluster, status, sample, assembly -> [taxa, cluster, status, sample, assembly, []] }.set{ clust_grp_new }
    // Old samples
    clust_grps
        .filter{ taxa, cluster, status, sample, assembly -> status }
        .map{ taxa, cluster, status, sample, assembly -> [taxa, cluster, status, sample, assembly, file(file(params.db) / taxa / "clusters" / cluster / "mash", type: 'dir') ] }
        .concat(clust_grp_new)
        .set{mash_files}

    // Run mash & build tree
    MASH_DIST(
        mash_files,
        timestamp
    )
    ch_versions = ch_versions.mix(MASH_DIST.out.versions)
    
    MASH_TREE(
        MASH_DIST.out.results,
        timestamp
    )

    MASH_DIST.out.results

    emit:
    mash_files = MASH_DIST.out.results // channel: [val(taxa), val(cluster), new_sketch, ava]
    mash_tree  = MASH_TREE.out.results // channel: [val(taxa), val(cluster), path(tree)]
    versions   = ch_versions           // channel: [ versions.yml ]

}
