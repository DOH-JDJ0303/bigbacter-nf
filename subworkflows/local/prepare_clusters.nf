//
// Prepapre clusters for analysis
//

include { PREPARE_REFERENCE } from '../../modules/local/prepare-reference'
include { FETCH_EXISTING_DB } from '../../modules/local/fetch-existing-db'

workflow PREPARE_CLUSTERS {
    take:
    manifest  // channel: [ val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status) ]
    timestamp // channel: val(timestamp)

    main:
    // Split samples into new and old and create version that is grouped by 'taxa_cluster'
    // New clusters
    manifest
        .filter { sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> status == "new" }
        .map { sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> t }
        .set { new_clusters }
    new_clusters
        .groupTuple(by: [0,1])
        .set{ new_clusters_grouped }
    // Old clusters
    manifest
        .filter { samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status -> status == "old" }
        .set { old_clusters }
    old_clusters
        .groupTuple(by: [0,1])
        .map { samples, taxa, assemblies, fastq_1s, fastq_2s, clusters, status -> [samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status, params.db+taxas.get(0)+"/clusters/"+clusters.get(0)] }
        .set { old_clusters_grouped }

    // Select a reference for new clusters
    PREPARE_REFERENCE(
        new_clusters_grouped,
        timestamp
    )

    // Fetch the reference and variant files for previous samples for old clusters
    FETCH_EXISTING_DB(
        old_clusters_grouped,
        timestamp
    )
    
    // Add references to individual samples
    new_clusters
        .combine(PREPARE_REFERENCE.out.reference, by: 0)
        .set { new_clusters }
    old_clusters
        .combine(FETCH_EXISTING_DB.out.reference, by: 0)
        .set { old_clusters }

    // Combine new and old clusters
    new_clusters
        .concat(old_clusters)
        .set {old_new_merged}
    FETCH_EXISTING_DB
        .out
        .old_var_files
        .concat(PREPARE_REFERENCE.out.dummy_var_files)
        .set { old_var_files }

    emit:
    manifest = old_new_merged     // channel: [ val(taxa_cluster), val(sample), val(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status), path(reference) ]
    old_var_files = old_var_files // channel: [ val(taxa_cluster), path(old_var_files) ]
}
