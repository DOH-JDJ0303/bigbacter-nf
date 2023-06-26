//
// Push files back to the BigBacter database
//

include { TREE_FIGURE_CLUSTER } from '../../modules/local/tree-figures'
include { TREE_FIGURE_ALL } from '../../modules/local/tree-figures'
include { SUMMARY_TABLE } from '../../modules/local/summary-tables'

workflow SUMMARIZE_RESULTS {
    take:
    all_cluster_results // channel: [val(taxa_cluster), val(cluster), val(taxa), val(cluster_dir), val(snippy_new), path(core), val(status), path(mash_sketch_cluster), path(mash_cache_cluster), path(ava_cluster)]
    mash_all // channel: [val(taxa), val(mash_sketch_all), val(mash_cache_all), path(ava_all)]
    timestamp // channel: val timestamp

    main:
    // Make tree figures (if possible)
    // Cluster-level trees (Core & Mash)
    TREE_FIGURE_CLUSTER(all_cluster_results)
    // Taxa-level tree (Mash only)
    TREE_FIGURE_ALL(mash_all)

    // Make summary table
    SUMMARY_TABLE(TREE_FIGURE_CLUSTER.out.all_cluster_results, timestamp)

    SUMMARY_TABLE.out.cluster_report.view()

    emit:
    results = "done"
}
