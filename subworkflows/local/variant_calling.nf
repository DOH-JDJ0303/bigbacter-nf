//
// Call variants per cluster
//

include { CALL_VARIANTS_NEW } from '../../modules/local/call-variants'
include { CALL_VARIANTS_OLD } from '../../modules/local/call-variants'

workflow CALL_VARIANTS {
    take:
    manifest // channel: [ val(taxa_cluster), val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status) ]
    db_path //  val: path/to/db

    main:
    // Split samples into new and old
    // New clusters
    manifest
        .filter { taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status -> status == "new" }
        .set { new_clusters }
    // Old clusters
    manifest
        .filter { taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status -> status == "old" }
        .map { taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status -> [taxa_cluster, samples, taxas, assemblies, fastq_1s, fastq_2s, clusters, status, db_path+taxas.get(0)+"/clusters/"+clusters.get(0)] }
        .set { old_clusters }

    CALL_VARIANTS_NEW(new_clusters)
    CALL_VARIANTS_OLD(old_clusters)

    CALL_VARIANTS_NEW
        .out
        .snippy_results
        .concat(CALL_VARIANTS_OLD.out.snippy_results)
        .set {new_bb_db}

    new_bb_db.view { it }

    emit:
    new_bb_db = new_bb_db
}
