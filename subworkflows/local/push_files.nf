//
// Push files back to the BigBacter database
//

include { PUSH_CLUSTER_FILES } from '../../modules/local/push-files'
include { PUSH_TAXA_FILES    } from '../../modules/local/push-files'

workflow PUSH_FILES {
    take:
    new_cluster_files // channel: [taxa, cluster, ref, new_snippy, sketch]
    new_taxa_files    // channel: [taxa, new_pp_db]

    main:
    /*
    =============================================================================================================================
        TAXA FILES
    =============================================================================================================================
    */
    // MODULE: Publish taxa-specific files
    PUSH_TAXA_FILES(
        new_taxa_files
    )

    /*
    =============================================================================================================================
        CLUSTER FILES
    =============================================================================================================================
    */
    // MODULE: Publish cluster-specific files
    PUSH_CLUSTER_FILES(
        new_cluster_files
    )

    emit:
    push_files = PUSH_TAXA_FILES.out.taxa_files.concat(PUSH_CLUSTER_FILES.out.cluster_files).collect().flatten()
    

}
