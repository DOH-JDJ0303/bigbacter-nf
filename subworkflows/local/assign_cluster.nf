//
// Assign PopPUNK clusters for each isolate
//

// Modules
include { ASSIGN_PP_CLUSTER } from '../../modules/local/assign-pp-cluster'
include { POPPUNK_VISUAL    } from '../../modules/local/poppunk-visualize'

// Function for determining the most recent PopPUNK database
def get_ppdb ( s ) {
    s_path = file(params.db).resolve(s)
    // get most recent PopPunk database
    pp_db = s_path.resolve("pp_db")
    pp_db = pp_db.resolve(pp_db.list().sort().last())
        
    return pp_db
}

// Function for determining if a cluster is new or old
def get_status ( taxa, cluster ) {
    c_path = file(params.db).resolve(taxa).resolve("clusters").resolve(cluster)
    status = c_path.exists() ? "old" : "new"
    return status        
}

workflow CLUSTER {
    take:
    manifest   // channel: [ val(sample), val(taxa), file(assembly), file(fastq_1), file(fastq_2) ]
    timestamp  // channel: val(timestamp)

    main:
    ch_versions = Channel.empty()
    // Determine the most recent PopPUNK database for each species and then group by species
    manifest
        .map { sample, taxa, assembly, fastq_1, fastq_2 -> [taxa, sample, assembly] }
        .groupTuple()
        .map {taxa, sample, assembly -> [taxa, sample, assembly, get_ppdb(taxa)]}
        .set { pp_grouped }

    // MODULE: Assign PopPUNK clusters
    ASSIGN_PP_CLUSTER(
        pp_grouped,
        timestamp
    )
    ch_versions = ch_versions.mix(ASSIGN_PP_CLUSTER.out.versions)

    // MODULE: Create visuals for new PopPUNK database
    POPPUNK_VISUAL(
        ASSIGN_PP_CLUSTER.out.new_pp_db,
        timestamp
    )
    ch_versions = ch_versions.mix(POPPUNK_VISUAL.out.versions)

    // Assign clusters as new and old   
    ASSIGN_PP_CLUSTER
        .out
        .cluster_results
        .splitCsv(header: true)
        .map { tuple(it.sample, it.taxa, it.cluster) }
        .map{ sample, taxa, cluster -> [sample, cluster, get_status(taxa, cluster)]}
        .set { sample_cluster_status }
    
    emit:
    sample_cluster_status = sample_cluster_status           // channel: [ val(sample), val(cluster), val(status) ]
    new_pp_db             = ASSIGN_PP_CLUSTER.out.new_pp_db // channel: [ val(taxa), path(new_pp_db)]
    versions              = ch_versions                     // channel: [ versions.yml ]
}
