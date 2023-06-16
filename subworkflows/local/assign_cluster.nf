//
// Assign PopPUNK clusters for each isolate
//

include { GET_PP_DB } from '../../modules/local/get_pp_db'
include { ASSIGN_PP_CLUSTER } from '../../modules/local/assign_pp_cluster'

workflow ASSIGN_CLUSTER {
    take:
    manifest // channel: [ val(sample), val(taxa), file(assembly), file(fastq_1), file(fastq_2) ]
    db_path //  val: path/to/db

    main:
    // build input for GET_PP_DB
    manifest
        .map { it.sample }
        .set { sample }

    manifest
        .map { it.assembly }
        .set { assembly }

    manifest
        .map { db_path+it.taxa+"/pp_db/" }
        .set { db_source }

    manifest
        .map { db_path+it.taxa+"/pp_db/CACHE" }
        .merge(sample)
        .merge(assembly)
        .merge(db_source)
        .set { pp_manifest }

   pp_manifest
        .view { it }   

    // Get the most current PopPUNK database for each species based on the cache in the BigBacter database
    GET_PP_DB(pp_manifest)
    GET_PP_DB
        .out
        .pp_list
        .groupTuple()
        .set { pp_grouped }

    // Assign clusters using the selected database
    ASSIGN_PP_CLUSTER(pp_grouped)
    ASSIGN_PP_CLUSTER
        .out
        .view {it}

    emit:
    versions = GET_PP_DB.out.versions // channel: [ versions.yml ]
}
