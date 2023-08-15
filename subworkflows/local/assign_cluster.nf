//
// Assign PopPUNK clusters for each isolate
//

def get_ppdb ( s ) {
    s_path = params.db.resolve(s)
    // get most recent PopPunk database
    pp_db = s_path.resolve("pp_db")
    pp_db = pp_db.resolve(pp_db.list().sort().last())
        
    return pp_db
}

def get_status ( taxa, cluster ) {
    c_path = file(db_path.resolve(taxa).resolve("clusters").resolve(cluster))
    status = c_path.exists() ? "old" : "new"
    return status        
}

include { ASSIGN_PP_CLUSTER } from '../../modules/local/assign-pp-cluster'

workflow ASSIGN_CLUSTER {
    take:
    manifest   // channel: [ val(sample), val(taxa), file(assembly), file(fastq_1), file(fastq_2) ]
    timestamp  // channel: val(timestamp)

    main:
    // Determine the most recent PopPUNK database for each species and then group by species

    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2 -> [taxa, sample, assembly, get_ppdb(taxa)] }
        .groupTuple()
        .set { pp_grouped }

    // Assign clusters
    ASSIGN_PP_CLUSTER(
        pp_grouped,
        timestamp
    )

    // Assign clusters as new and old   
    ASSIGN_PP_CLUSTER
        .out
        .cluster_results
        .collect()
        .splitCsv(header: true)
        .map { tuple(it.sample, it.taxa, it.cluster) }
        .map{ sample, taxa, cluster -> [sample, cluster, get_status(taxa, cluster)]}
        .set { sample_cluster_status }

    emit:
    sample_cluster_status = sample_cluster_status         // channel: [ val(sample), val(cluster), val(status) ]
    new_pp_db = ASSIGN_PP_CLUSTER.out.new_pp_db           // channel: [ val(taxa), path(new_pp_db)]
}
