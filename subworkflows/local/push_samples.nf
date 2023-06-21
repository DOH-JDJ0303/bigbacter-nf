//
// Push files back to the BigBacter database
//

include { PUSH_PP_DB } from '../../modules/local/push-files'
include { PUSH_BB_DB_NEW } from '../../modules/local/push-files'
include { PUSH_BB_DB_OLD } from '../../modules/local/push-files'

workflow PUSH_FILES {
    take:
    pp_files // channel:
    bb_files // channel:
    db_path //  val: path/to/db

    main:
    PUSH_PP_DB(pp_files, db_path)
    
    // Split samples into new and old
    // New clusters
    bb_files
        .filter { cluster, taxa, bb_db, snippy_new, core, status -> status == "new" }
        .set { new_clusters }
    // Old clusters
    bb_files
        .filter { cluster, taxa, bb_db, snippy_new, core, status -> status == "new" }
        .set { old_clusters }
    
    PUSH_BB_DB_NEW(new_clusters, db_path)
    PUSH_BB_DB_OLD(old_clusters, db_path)

    emit:
    status = "done"
}
