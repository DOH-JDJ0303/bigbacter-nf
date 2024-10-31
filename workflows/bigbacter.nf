/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowBigbacter.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.db, params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (! (params.input || params.ncbi)) { exit 1, 'Input not specified!' } else{ manifest = Channel.empty()}
if (params.db) { ch_db = file(params.db) } else { exit 1, 'BigBacter database not specified!' }
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PREPARE_INPUT    } from '../subworkflows/local/prepare_inputs'
include { CLUSTER          } from '../subworkflows/local/cluster'
include { CORE             } from '../subworkflows/local/core'
include { ACCESSORY        } from '../subworkflows/local/accessory'
include { PUSH_FILES       } from '../subworkflows/local/push_files'

include { MRFIGS           } from '../modules/local/mrfigs'
include { SUMMARY_TABLE    } from '../modules/local/summary-tables'
include { COMBINED_SUMMARY } from '../modules/local/combined-summary'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { TIMESTAMP                   } from '../modules/local/get-timestamp'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// get list of isolates in each cluster for a taxa
def db_taxa_clusters ( taxa , timestamp ) {
    // determine path to taxa database
    clusters_path = file(params.db).resolve(taxa).resolve("clusters")
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

// Function for gathering BigBacter database info
def db_info ( db_path, outdir_path, timestamp, wait_file ) {
    // Build output file path
    ts_str = timestamp.toString()
    db_info = file(outdir_path).resolve(ts_str).resolve(ts_str+"-db-info.csv")
    if (db_info.exists()) { db_info.delete() }
    // Add header
    db_info.append("Taxon,Cluster,File_Type,File_Name,Size,File_Date,File_Path\n")
    // Create empty variables for total counts
    pp_size       = 0
    ref_size      = 0
    snippy_size   = 0
    assembly_size = 0
    // Iterate through taxa
    for ( taxon in file(db_path).list() ) {
        taxon_path = file(db_path).resolve(taxon)
        // Iterate through PopPUNK files
        for ( pp in file(taxon_path).resolve("pp_db").list() ) {
            // Build file path
            pp_file = file(taxon_path).resolve("pp_db").resolve(pp)
            // Total size
            pp_file_size = pp_file.size()
            pp_size = pp_size + pp_file_size
            // File date
            pp_date = new Date(pp_file.lastModified())
            // Create row & append
            pp_row = taxon+",NA,PopPUNK_Database,"+pp+","+pp_file_size+","+pp_date+","+pp_file.toUriString()+"\n" 
            ! pp_row ?: db_info.append(pp_row)
        }
        // Iterate through cluster files
        for ( cluster in file(taxon_path).resolve("clusters").list() ) {
            cluster_path = file(taxon_path).resolve("clusters").resolve(cluster)
            // Reference files
            for ( ref in file(cluster_path).resolve("ref").list() ) {
                // Build file path
                ref_file = file(cluster_path).resolve("ref").resolve(ref)
                // Total size
                ref_file_size = ref_file.size()
                ref_size = ref_size + ref_file_size
                // File date
                ref_date = new Date(ref_file.lastModified())
                // Create row & append
                ref_row = taxon+","+cluster+",SNP_Reference,"+ref+","+ref_file_size+","+ref_date+","+ref_file.toUriString()+"\n"
                ! ref_row ?: db_info.append(ref_row)
            }
            // Snippy files
            for ( snippy in file(cluster_path).resolve("snippy").list() ) { 
                // Build file path
                snippy_file = file(cluster_path).resolve("snippy").resolve(snippy)
                // Total size
                snippy_file_size = snippy_file.size()
                snippy_size = snippy_size + snippy_file_size
                // File date
                snippy_date = new Date(snippy_file.lastModified())
                // Create row & append
                snippy_row = taxon+","+cluster+",SNP_Files,"+snippy+","+snippy_file_size+","+snippy_date+","+snippy_file.toUriString()+"\n"
                ! snippy_row ?: db_info.append(snippy_row)
            }
            // Assembly files
            for ( assembly in file(cluster_path).resolve("assembly").list() ) { 
                // Build file path
                assembly_file = file(cluster_path).resolve("assembly").resolve(assembly)
                // Total size
                assembly_file_size = assembly_file.size()
                assembly_size = assembly_size + assembly_file_size
                // File date
                assembly_date = new Date(assembly_file.lastModified())
                // Create row & append
                assembly_row = taxon+","+cluster+",Assembly_File,"+assembly+","+assembly_file_size+","+assembly_date+","+assembly_file.toUriString()+"\n"
                ! assembly_row ?: db_info.append(assembly_row)
            }
        }
    }
    // Get total and convert to GB
    total_size = pp_size+ref_size+snippy_size+assembly_size
    total_size = MemoryUnit.of(total_size).toGiga()
    pp_size = MemoryUnit.of(pp_size).toMega()
    ref_size = MemoryUnit.of(ref_size).toMega()
    snippy_size = MemoryUnit.of(snippy_size).toMega()
    assembly_size = MemoryUnit.of(assembly_size).toMega()
    // Print to Screen
    println "\n===========================\nBigBacter Database Summary:\n===========================\nDatabase Path: "+db_path+"\nPopPUNK Files: "+pp_size+"MB\nReference Files: "+ref_size+"MB\nSNP Files: "+snippy_size+"MB\nAssembly Files: "+assembly_size+"MB\nTotal: "+total_size+"GB\n"
    // Return file
    return db_info
}

// Info required for completion email and summary
def multiqc_report = []

workflow BIGBACTER {

    ch_versions = Channel.empty()

    /*
    =============================================================================================================================
        GET EPOCH TIMESTAMP
    =============================================================================================================================
    */
    // MODULE: Get epoch timestamp
    TIMESTAMP()
        .set { ch_timestamp }

    // provide custom run ID that replaces the timestamp - set up this way to avoid being a value channel 
    params.run_id ? timestamp.map{ timestamp -> params.run_id }.set{ ch_timestamp } : ch_timestamp

    /*
    =============================================================================================================================
        PREPARE INPUT
    =============================================================================================================================
    */
    PREPARE_INPUT(
        file(params.input),
        ch_timestamp
    )
    // Create manifest channels
    PREPARE_INPUT.out.manifest.set{ ch_manifest }
    PREPARE_INPUT.out.manifest_path.set{ ch_manifest_path }

    /*
    =============================================================================================================================
        ASSIGN CLUSTERS
        - clusters assigned by PopPUNK when not manually provided in the samplesheet
    =============================================================================================================================
    */
    // SUBWORKFLOW: Assign PopPUNK clusters
    CLUSTER(
        ch_manifest.filter{ it -> ! it.cluster }.map{ it -> [ it.sample, it.taxa, it.assembly ] },
        ch_timestamp
    )
    ch_versions = ch_versions.mix(CLUSTER.out.versions)
    // Add cluster info back and combine with manual clusters
    ch_manifest
        .filter{ it -> it.cluster }
        .map{ it -> [ it.sample, it.cluster ] }
        .concat(CLUSTER.out.sample_clusters)
        .set{ ch_sample_clusters }

    /*
    =============================================================================================================================
        CORE GENOME ANALYSIS
    =============================================================================================================================
    */
    //// SUBWORKFLOW: Core genome analysis
    CORE(
        ch_manifest.map{ it -> [ it.sample, it.taxa, it.assembly, it.fastq_1, it.fastq_2 ] }.join( ch_sample_clusters, by: 0 ),
        ch_manifest_path, 
        ch_timestamp
    )
    ch_versions = ch_versions.mix(CORE.out.versions)

    /*
    =============================================================================================================================
        ACCESSORY GENOME ANALYSIS
    =============================================================================================================================
    */
    // SUBWORKFLOW: Accessory genome analysis
    ACCESSORY(
        CLUSTER.out.core_acc_dist,
        CORE.out.tree,
        ch_manifest_path,
        ch_timestamp
    )
    ch_versions = ch_versions.mix(ACCESSORY.out.versions)

    /*
    =============================================================================================================================
        SUMMARIZE RESULTS
    =============================================================================================================================
    */
    // Consolidate results for summarylines
    CORE
        .out
        .dist
        .map{ taxa, cluster, source, dist -> [ taxa, cluster, dist ] }
        .groupTuple(by: [0,1])
        .join(CORE.out.stats, by: [0,1])
        .set{ch_core_summary}

    // MODULE: Make individual summary tables
    SUMMARY_TABLE(
        ch_core_summary.combine(ch_manifest_path),
        ch_timestamp
    )

    // MODULE: Combine summary tables
    COMBINED_SUMMARY(
       SUMMARY_TABLE.out.summary.map{taxa, cluster, summary -> [ summary ]}.collect(),
       ch_manifest_path,
       ch_timestamp
   )

    // Consolidate results for Microreact
    // Accessory genome
    CORE
        .out
        .meta
        .join( CORE.out.dist, by: [0,1,2] )
        .join( CORE.out.tree, by: [0,1,2] )
        .combine( ACCESSORY.out.dist.map{ taxa, cluster, source, dist -> [ taxa, cluster, dist ] }.concat( ch_manifest.filter{ it -> it.cluster }.map{ it -> [ it.taxa, it.cluster, [] ] } ), by: [0,1] )
        .combine( SUMMARY_TABLE.out.summary, by: [0,1] )
        .set{ ch_microreact }
    // MODULE: Create Microreact figures
    MRFIGS (
        ch_microreact,
        file("$projectDir/assets/microreact.json", checkIfExists: true),
        ch_timestamp
    )

    /*
    =============================================================================================================================
        PUSH FILES TO BIGBACTER DATABASE
    =============================================================================================================================
    */
    // Consolidate taxa-specific files
    CLUSTER
        .out
        .new_pp_db
        .set{ taxa_files }

    // Consolidate cluster-specific files
    ch_manifest
        .map{ it -> [ it.sample, it.taxa, it.assembly ] }
        .combine( ch_sample_clusters, by: 0 )
        .map{ sample, taxa, assembly, cluster -> [ taxa, cluster, assembly ] }
        .groupTuple(by: [0,1])
        .set{ ch_cluster_assemblies }
    CORE
        .out
        .snp_files
        .map{ taxa, cluster, ref, new_snippy, old_snippy -> [ taxa, cluster, ref, new_snippy ] }
        .join(ch_cluster_assemblies, by: [0,1])
        .set{ cluster_files }

    // if push is 'true'
    ch_wait = cluster_files.concat(taxa_files).collect().flatten().last() // force pipeline to wait till after all new database files have been created
    if(params.push){
        // SUBWORKFLOW: Push new BigBacter database
        PUSH_FILES(
            cluster_files,
            taxa_files
        )
        PUSH_FILES.out.push_files.last().set{ch_wait} // update the wait channel
    }

    // Collect database info - optional
    if (params.db_info){ ch_timestamp.combine(ch_wait).map{ ch_timestamp, wait_file -> db_info(params.db, params.outdir, ch_timestamp, wait_file) } }

    /*
    =============================================================================================================================
        NEXTFLOW DEFAULTS
    =============================================================================================================================
    */
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml'),
        ch_timestamp
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowBigbacter.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowBigbacter.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        ch_timestamp
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    // Reminder to push files
    if ( ! params.push & !(workflow.commandLine =~ "PREPARE_DB") ) { println "\033[1;33m\n------------------------------------------------------\n\nNext steps:\n1. Check your results\n2. Run the command below to push this run to your database\n\n\033[0;37m> "+workflow.commandLine.replaceAll(/ -resume/, '')+" --push true -resume\n\n------------------------------------------------------\n\033[0m" }
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
