//
// Assign PopPUNK clusters for each isolate
//

// Modules
include { ASSIGN_PP_CLUSTER       } from '../../modules/local/assign-pp-cluster'
include { POPPUNK_VISUAL          } from '../../modules/local/poppunk-visualize'
include { RESOLVE_MERGED_CLUSTERS } from '../../modules/local/resolve-merged-clusters'


// Function for determining the most recent PopPUNK database
def get_ppdb ( taxa ) {
    // determine path to taxa database
    taxa_path = file(params.db).resolve(taxa)
    // check that a bigbacter database exists for the taxa
    if(!taxa_path.exists()) {
        exit 1, "ERROR: No BigBacter database exists for \n${taxa} at the provided path: ${params.db}"
    }
    // get most recent PopPunk database
    pp_db = taxa_path.resolve("pp_db")
    pp_db = pp_db.resolve(pp_db.list().sort().last())
        
    return pp_db
}

// Function for determining if a cluster is new or old
def get_status ( taxa, cluster ) {
    c_path = file(params.db).resolve(taxa).resolve("clusters").resolve(cluster)
    status = c_path.exists() ? true : false
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

    // Load cluster results  
    ASSIGN_PP_CLUSTER
        .out
        .cluster_results
        .splitCsv(header: true)
        .map { tuple(it.Taxon, it.Cluster) } // 'Taxon' == 'sample' != 'taxa' .
        .join(manifest.map{ sample, taxa, assembly, fastq_1, fastq_2 -> [sample, taxa, assembly] }, by: 0)
        .set {cluster_results}

    // 
    // MODULE: Resolve merged clusters
    //

    if ( params.resolve_merged ) {
        // load merged clusters & determine if the cluster exists in the BigBacter database
        ASSIGN_PP_CLUSTER
            .out
            .merged_clusters
            .splitCsv(header: true)
            .map { tuple(it.taxa, it.merged_cluster, it.cluster, get_status(it.taxa, it.cluster.padLeft(5, "0"))) }
            .set{ merged_clusters }
        
        // make sure that this merge didn't occur on a fresh PopPUNK database
        merged_clusters
            .map { taxa, merged_cluster, cluster, bb_status -> [ taxa, merged_cluster, cluster, bb_status ? 1 : 0 ] }
            .groupTuple(by: [0,1])
            .map { taxa, merged_cluster, clusters, bb_status -> [ taxa, merged_cluster, bb_status.sum() == 0 ] }
            .combine(merged_clusters, by: [0,1])
            .set { merged_clusters }

        // split out any merges that did occur on a fresh PopPUNK database and arbitrarily select a cluster from merged list
        merged_clusters
            .filter { taxa, merged_cluster, pp_status, cluster, bb_status -> pp_status }
            .groupTuple(by: [0,1])
            .map { taxa, merged_cluster, pp_status, clusters, bb_status -> [ taxa, merged_cluster, clusters.get(0) ] }
            .combine(cluster_results.map { sample, cluster, taxa, assembly -> [ taxa, cluster, sample ] }, by: [0,1])
            .map { taxa, merged_cluster, cluster, sample -> [ sample, taxa, cluster ] }
            .set { fresh_merges }
        
        // split out the remaining merges
        merged_clusters
            .filter { taxa, merged_cluster, pp_status, cluster, bb_status -> ! pp_status && bb_status }
            .map { taxa, merged_cluster, pp_status, cluster, bb_status -> [ taxa, merged_cluster, cluster, file(params.db).resolve(taxa).resolve("clusters").resolve(cluster).resolve("mash") ] }
            .groupTuple(by: [0,1])
            .combine(cluster_results.map { sample, cluster, taxa, assembly -> [ taxa, cluster, assembly, sample ] }, by: [0,1] )
            .set { stale_merges }

        RESOLVE_MERGED_CLUSTERS (
            stale_merges
        )

        cluster_results
            .map { sample, cluster, taxa, assembly -> [ sample, taxa, cluster, cluster.contains("_") ] }
            .filter { sample, taxa, cluster, merge_status -> ! merge_status }
            .map { sample, taxa, cluster, merge_status -> [ sample, taxa, cluster ] }
            .concat(RESOLVE_MERGED_CLUSTERS.out.best_cluster.splitCsv(header: false))
            .concat(fresh_merges)
            .set { cluster_results }

    }
    if ( ! params.resolve_merged ) {
        // load merged clusters
        ASSIGN_PP_CLUSTER
            .out
            .merged_clusters
            .splitCsv(header: true)
            .map { tuple(it.taxa, it.merged_cluster) }
            .distinct()
            .map { taxa, merged_cluster -> println( "\nWARNING: You have selected not to resolve " + taxa + " cluster "+ merged_cluster +". \nThis can lead to missed genetic relationships. See https://github.com/DOH-JDJ0303/bigbacter-nf for more information.\n") }
        
        // remove status from 
        cluster_results
            .map { sample, cluster, taxa, assembly ->  [sample, taxa, cluster ] }
            .set { cluster_results }
    }
    
    // Add padding to cluster numbers and determine if they are new or old
    cluster_results
        .map { sample, taxa, cluster -> [sample, cluster.padLeft(5, "0"), get_status(taxa, cluster.padLeft(5, "0"))]}
        .set { sample_cluster_status }

    emit:
    sample_cluster_status = sample_cluster_status           // channel: [ val(sample), val(cluster), val(new_status), val(merge_status) ]
    new_pp_db             = ASSIGN_PP_CLUSTER.out.new_pp_db // channel: [ val(taxa), path(new_pp_db)]
    versions              = ch_versions                     // channel: [ versions.yml ]
}
