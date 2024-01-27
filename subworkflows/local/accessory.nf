//
// Perform accessory genome analysis within each cluster
//

include { FORMAT_DIST } from '../../modules/local/format-dist'
include { DIST_MAT    } from '../../modules/local/dist-mat'

workflow ACCESSORY {
    take:
    core_acc_dist // channel: [ val(taxa), val(dist) ]
    core_tree     // channel: [ val(taxa), val(cluster), path(tree), val(type), val(method) ]
    manifest_file // channel: [ val(new_samples) ]
    timestamp     // channel: val(timestamp)

    main:
    ch_versions = Channel.empty()

    // MODULE: Format PopPUNK pairwise distances
    core_acc_dist
        .combine(core_tree.map{ taxa, cluster, tree, type, method -> [taxa, cluster, tree] }, by: 0)
        .map{ taxa, dist, cluster, tree -> [ taxa, cluster, dist, tree ] }
        .set { full_dist }
    FORMAT_DIST (
        full_dist,
        "1,2,4"
    )

    // MODULE: Distance matrix figure
    DIST_MAT (
        FORMAT_DIST.out.dist,
        manifest_file,
        "long",
        "Accessory",
        1,
        timestamp
    )

    emit:
    versions  = ch_versions              // channel: [ versions.yml ]
}
