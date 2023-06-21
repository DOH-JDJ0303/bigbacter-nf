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
        .map { tuple(db_path+it.taxa+"/pp_db/CACHE", it.sample, it.taxa, it.assembly, db_path+it.taxa+"/pp_db/") }
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

    // Combine cluster results, new reference status, and the original manifest into single channel
     ASSIGN_PP_CLUSTER
        .out
        .cluster_status
        .splitCsv(header: true)
        .map { tuple(it.taxa_cluster, it.status) }
        .set { cluster_status }

    ASSIGN_PP_CLUSTER
        .out
        .cluster_results
        .splitCsv(header: true)
        .collect()
        .flatten()
        .map { tuple(it.sample, it.cluster, it.taxa_cluster) }
        .set { all_cluster_results }

     manifest
        .map { tuple(it.sample, it.taxa, it.assembly, it.fastq_1, it.fastq_2) }
        .join(all_cluster_results)
        .groupTuple(by: 6)
        .map { tuple(it.get(6), it.get(0), it.get(1), it.get(2), it.get(3), it.get(4), it.get(5))}
        .join(cluster_status)
        .set { manifest_grouped }    

    emit:
    manifest_grouped = manifest_grouped // channel: [ val(taxa_cluster), val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster) ]
    new_pp_db = ASSIGN_PP_CLUSTER.out.new_pp_db // channel: [ path(new_db), path(CACHE), val(taxa) ]
    versions = GET_PP_DB.out.versions // channel: [ versions.yml ]
}
