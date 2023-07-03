//
// Assign PopPUNK clusters for each isolate
//

include { GET_PP_DB         } from '../../modules/local/get-cache-files'
include { ASSIGN_PP_CLUSTER } from '../../modules/local/assign-pp-cluster'

workflow ASSIGN_CLUSTER {
    take:
    manifest   // channel: [ val(sample), val(taxa), file(assembly), file(fastq_1), file(fastq_2) ]
    timestamp  // channel: val(timestamp)

    main:
    // build input for GET_PP_DB
    manifest
        .map { tuple(params.db+it.taxa+"/pp_db/CACHE", it.sample, it.taxa, it.assembly) }
        .set { pp_manifest }  

    // Get the most current PopPUNK database for each species based on the cache in the BigBacter database
    GET_PP_DB(
        pp_manifest,
        timestamp
    )
    GET_PP_DB
        .out
        .pp_list
        .groupTuple()
        .set { pp_grouped }

    // Assign clusters using the selected database
    ASSIGN_PP_CLUSTER(
        pp_grouped, 
        timestamp
    )

    // Combine cluster results, status, and the original manifest into single channel
     ASSIGN_PP_CLUSTER
        .out
        .sample_status
        .splitCsv(header: true)
        .map { tuple(it.sample, it.status) }
        .set { sample_status }
    
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
        .join(sample_status)
        .map { sample, taxa, assembly, fastq_1, fastq_2, cluster, taxa_cluster, status -> [taxa_cluster, sample, taxa, assembly, fastq_1, fastq_2, cluster, status]}
        .set { manifest }

    emit:
    manifest = manifest                                   // channel: [ val(taxa_cluster), val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status) ]
    new_pp_db = ASSIGN_PP_CLUSTER.out.new_pp_db           // channel: [ val(taxa), path(new_pp_db), path(CACHE) ]
    cluster_status = ASSIGN_PP_CLUSTER.out.cluster_status // channel: [ val(taxa_cluster), val(status) ]
    versions = GET_PP_DB.out.versions                     // channel: [ versions.yml ]
}
