//
// Perform all-vs-all Mash comparisons
//

include { MASH_DIST_CLUSTER       } from '../../modules/local/mash-dist'
include { MASH_TREE_CLUSTER       } from '../../modules/local/build-trees'


def get_sketch ( taxa, cluster ) {
    s_path = file(params.db).resolve(taxa).resolve("clusters").resolve(cluster).resolve("mash")
    sketch = s_path.resolve(s_path.list().sort().last())
    return sketch        
}

workflow MASH_SKETCH {
    take:
    manifest   // channel: [ val(sample), val(taxa), path(assembly), val(fastq_1), val(fastq_2), val(cluster), val(status) ]
    timestamp  // channel: val(timestamp)

    main:
    // Group samples by cluster
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, status.get(0), sample, assembly] }
        .groupTuple(by: [0,1])
        .set{ clust_grps }
    
    // Determine which mash sketch file to use
    // New samples - this is easy
    clust_grps.filter{ taxa, cluster, status, sample, assembly -> status == "new" }.map{ taxa, cluster, status, sample, assembly -> [taxa, cluster, sample, status, assembly, []] }.set{ clust_grp_new }
    // Old samples
    clust_grps
        .filter{ taxa, cluster, status, sample, assembly -> status == "old" }
        .map{ taxa, cluster, status, sample, assembly -> [taxa, cluster, sample, status, assembly, get_sketch(taxa, cluster)] }
        .concat(clust_grp_new)
        .set{mash_files}

    // Run mash & build trees
    // Per cluster
    MASH_DIST_CLUSTER(
        mash_files,
        timestamp
    )
    
    MASH_TREE_CLUSTER(
        MASH_DIST_CLUSTER.out.results,
        timestamp
    )

    emit:
    mash_cluster = MASH_TREE_CLUSTER.out.results // channel: [val(taxa), val(cluster), new_sketch, ava_cluster]
}
