//
// Push files back to the BigBacter database
//

include { PUSH_PP_DB } from '../../modules/local/push-files'
include { PUSH_BB_DB_NEW } from '../../modules/local/push-files'
include { PUSH_SNIPPY_OLD } from '../../modules/local/push-files'
include { PUSH_MASH_OLD } from '../../modules/local/push-files'
include { PUSH_MASH_ALL } from '../../modules/local/push-files'

workflow PUSH_FILES {
    take:
    pp_files // channel:
    bb_files // channel: [val(taxa_cluster), val(cluster), val(taxa), path(cluster_dir), path(snippy_new), path(core), val(status), path(mash_sketch), path(mash_cache), path(ava_cluster)]
    mash_all // channel: [val(taxa), path(mash_sketch), path(mash_cache), path(ava_all)]    

    main:
    PUSH_PP_DB(pp_files)
    
    // Split samples into new and old
    // New clusters
    bb_files
        .filter { taxa_cluster, cluster, taxa, bb_db, snippy_new, core, status, mash_sketch, mash_cache, ava_cluster -> status == "new" }
        .set { new_clusters }
    // Old clusters
    bb_files
        .filter { taxa_cluster, cluster, taxa, bb_db, snippy_new, core, status, mash_sketch, mash_cache, ava_cluster -> status == "old" }
        .set { old_clusters }
    
    PUSH_BB_DB_NEW(new_clusters)
    PUSH_SNIPPY_OLD(old_clusters)
    PUSH_MASH_OLD(old_clusters)
    PUSH_MASH_ALL(mash_all)

    emit:
    status = "done"
}
