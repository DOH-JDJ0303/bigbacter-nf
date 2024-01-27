//
// Assign PopPUNK clusters for each isolate
//

// Modules
include { POPPUNK_ASSIGN          } from '../../modules/local/poppunk-assign'
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

// get list of isolates in each cluster for a taxa
def db_taxa_clusters ( taxa , timestamp ) {
    // determine path to taxa database
    clusters_path = file(params.db).resolve(taxa).resolve("clusters")
    // check that a bigbacter database exists for the taxa
    if(!clusters_path.exists()) {
        exit 1, "ERROR: No BigBacter database exists for \n${taxa} at the provided path: ${params.db}"
    }
    // get list of isolates associated with each cluster
    taxadir = file(params.outdir).resolve(timestamp.toString()).resolve(taxa)
    taxadir.mkdirs()
    db_info_file = taxadir.resolve(taxa+"-db-info.txt")
    db_info_file.delete()
    clusters = clusters_path.list()
    for ( cluster in clusters ) {
        // list isolates
        isolates = clusters_path.resolve(cluster).resolve("snippy").list()
        // create list
        for ( iso in isolates ) {
            row = taxa+"\t"+cluster+"\t"+iso.replace(".tar.gz", "")+"\n"
            db_info_file.append(row) 
        }
    }
    return db_info_file
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
    POPPUNK_ASSIGN (
        pp_grouped,
        timestamp
    )
    ch_versions = ch_versions.mix(POPPUNK_ASSIGN.out.versions)

    // MODULE: Create visuals for new PopPUNK database
    POPPUNK_VISUAL(
        POPPUNK_ASSIGN.out.new_pp_db,
        timestamp
    )
    ch_versions = ch_versions.mix(POPPUNK_VISUAL.out.versions)

    // Load cluster results  
    POPPUNK_ASSIGN
        .out
        .cluster_results
        .map { taxa, results -> [ results ] }
        .splitCsv(header: true)
        .map { tuple(it.Taxon.get(0), it.Cluster.get(0)) } // 'Taxon' == 'sample' != 'taxa'
        .join(manifest.map { sample, taxa, assembly, fastq_1, fastq_2  -> [ sample, taxa ]}, by: 0)
        .set {cluster_results}

    // 
    // MODULE: Resolve merged clusters
    //

    if ( params.resolve_merged ) {
        // get list of isolates that belong to each cluster in the BiBacter database
        manifest
            .map{ sample, taxa, assembly, fastq_1, fastq_2 -> taxa }
            .combine(timestamp)
            .distinct()
            .map{ taxa, timestamp -> [ taxa, db_taxa_clusters(taxa, timestamp) ] }
            .set{ db_taxa_clusters }
        
        // load merged clusters & determine if each unmerged cluster exists in the BigBacter database
        POPPUNK_ASSIGN
            .out
            .merged_clusters
            .map { taxa, results -> [ results ] }
            .splitCsv(header: true)
            .map { tuple(it.taxa.get(0), it.merged_cluster.get(0), it.cluster.get(0), get_status(it.taxa.get(0), it.cluster.get(0).padLeft(5, "0"))) }
            .set{ merged_clusters }
        
        // make sure that this merge didn't occur on two or more unmerged clusters that have not been observed yet by BigBacter
        merged_clusters
            .map { taxa, merged_cluster, cluster, bb_status -> [ taxa, merged_cluster, cluster, bb_status ? 1 : 0 ] }
            .groupTuple(by: [0,1])
            .map { taxa, merged_cluster, clusters, bb_status -> [ taxa, merged_cluster, bb_status.sum() == 0 ] }
            .combine(merged_clusters, by: [0,1])
            .set { merged_clusters }

        // split out any merges that did occur on clusters that have not been observed and arbitrarily select an unmerged cluster
        merged_clusters
            .filter { taxa, merged_cluster, pp_status, cluster, bb_status -> pp_status }
            .groupTuple(by: [0,1])
            .map { taxa, merged_cluster, pp_status, unmerged_clusters, bb_status -> [ taxa, merged_cluster, unmerged_clusters.get(0) ] }
            .combine(cluster_results.map { sample, cluster, taxa -> [ taxa, cluster, sample ] }, by: [0,1])
            .map { taxa, merged_cluster, unmerged_cluster, sample -> [ sample, taxa, unmerged_cluster ] }
            .set { fresh_merges }

        // split out the remaining merges and join with the BigBacter database info and Jaccard distance for that taxa
        merged_clusters
            .filter { taxa, merged_cluster, pp_status, unmerged_cluster, bb_status -> ! pp_status && bb_status }
            .map { taxa, merged_cluster, pp_status, unmerged_cluster, bb_status -> [ taxa, merged_cluster ] }
            .distinct()
            .combine(db_taxa_clusters, by: 0)
            .combine(POPPUNK_ASSIGN.out.jaccard_dist, by: 0)
            .combine(cluster_results.map { sample, merged_cluster, taxa -> [ taxa, merged_cluster, sample ] }, by: [0, 1])
            .set {stale_merges } // [ taxa, merged_cluster, db_info, dist ]

        RESOLVE_MERGED_CLUSTERS (
            stale_merges
        )

        cluster_results
            .map { sample, cluster, taxa -> [ sample, taxa, cluster, cluster.contains("_") ] }
            .filter { sample, taxa, cluster, merge_status -> ! merge_status }
            .map { sample, taxa, cluster, merge_status -> [ sample, taxa, cluster ] }
            .concat(RESOLVE_MERGED_CLUSTERS.out.best_cluster.splitCsv(header: false))
            .concat(fresh_merges)
            .set { cluster_results }

    }
    if ( ! params.resolve_merged ) {
        // load merged clusters
        POPPUNK_ASSIGN
            .out
            .merged_clusters
            .map {taxa, results -> [ results ]}
            .splitCsv(header: true)
            .map { tuple(it.taxa.get(0), it.merged_cluster.get(0)) }
            .distinct()
            .map { taxa, merged_cluster -> println( "\nWARNING: You have selected not to resolve " + taxa + " cluster "+ merged_cluster +". \nThis can lead to missed genetic relationships. See https://github.com/DOH-JDJ0303/bigbacter-nf for more information.\n") }
        
        // remove status from 
        cluster_results
            .map { sample, cluster, taxa ->  [sample, taxa, cluster ] }
            .set { cluster_results }
    }
    
    // Add padding to cluster numbers and determine if they are new or old
    cluster_results
        .map { sample, taxa, cluster -> [sample, cluster.padLeft(5, "0"), get_status(taxa, cluster.padLeft(5, "0"))]}
        .set { sample_cluster_status }

    emit:
    sample_cluster_status = sample_cluster_status            // channel: [ val(sample), val(cluster), val(new_status), val(merge_status) ]
    new_pp_db             = POPPUNK_ASSIGN.out.new_pp_db     // channel: [ val(taxa), path(new_pp_db)]
    core_acc_dist         = POPPUNK_ASSIGN.out.core_acc_dist // channel: [ val(taxa), path(dist) ]
    versions              = ch_versions                      // channel: [ versions.yml ]
}
