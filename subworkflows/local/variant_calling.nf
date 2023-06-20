//
// Call variants per cluster
//

include { RUN_SNIPPY } from '../../modules/local/run_snippy'

workflow CALL_VARIANTS {
    take:
    cluster_results // channel: [ val(sample), val(cluster), file(assembly), file(fastq_1), file(file2 ]
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
        .map { it.taxa }
        .set { taxa }

    manifest
        .map { db_path+it.taxa+"/pp_db/" }
        .set { db_source }

    manifest
        .map { db_path+it.taxa+"/pp_db/CACHE" }
        .merge(sample)
        .merge(taxa)
        .merge(assembly)
        .merge(db_source)
        .set { pp_manifest }   

    // Get the most current PopPUNK database for each species based on the cache in the BigBacter database
    GET_PP_DB(pp_manifest)
    GET_PP_DB
        .out
        .pp_list
        .groupTuple()
        .set { pp_grouped }

    // Assign clusters using the selected database
    ASSIGN_PP_CLUSTER(pp_grouped, nextflow.timestamp.replaceAll(" ", "_").replaceAll(":", "."))

    // Combine cluster results into single tuple
    ASSIGN_PP_CLUSTER
        .out
        .cluster_results
        .splitCsv(header: true)
        .view { it }

    // Push new database and references
    PUSH_PP_DBS(ASSIGN_PP_CLUSTER.out.new_pp_db, db_path)
    PUSH_PP_REFS(ASSIGN_PP_CLUSTER.out.new_pp_db, db_path)
    

    emit:
    versions = GET_PP_DB.out.versions // channel: [ versions.yml ]
}
