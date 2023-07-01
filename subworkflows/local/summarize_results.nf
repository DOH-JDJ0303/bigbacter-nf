//
// Push files back to the BigBacter database
//

include { TREE_FIGURE_CLUSTER } from '../../modules/local/tree-figures'
include { TREE_FIGURE_ALL     } from '../../modules/local/tree-figures'
include { SUMMARY_TABLE       } from '../../modules/local/summary-tables'

workflow SUMMARIZE_RESULTS {
    take:
    all_cluster_results // channel: [val(taxa_cluster), val(taxa), va(cluster), path(core), path(ava_cluster)]
    mash_all            // channel: [val(taxa), path(ava_taxa)]
    new_samples         // channel: [val(sample)]
    timestamp           // channel: val timestamp

    main:
    // Make tree figures
    // Cluster-level trees (Core & Mash)
    TREE_FIGURE_CLUSTER(
        all_cluster_results,
        timestamp
        )
    // Taxa-level tree (Mash only)
    TREE_FIGURE_ALL(
        mash_all,
        timestamp
    )

    // Make summary table
    SUMMARY_TABLE(
        all_cluster_results, 
        new_samples,
        timestamp
    )

    emit:
    summary = SUMMARY_TABLE.out.summary // channel: [ val(taxa_cluster), val(taxa), path(summary) ]
}
