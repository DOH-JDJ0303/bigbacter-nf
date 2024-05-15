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
include { INPUT_CHECK      } from '../subworkflows/local/input_check'
include { CLUSTER          } from '../subworkflows/local/cluster'
include { CORE             } from '../subworkflows/local/core'
include { ACCESSORY        } from '../subworkflows/local/accessory'
include { PUSH_FILES       } from '../subworkflows/local/push_files'

include { NCBI_DATASETS    } from '../modules/local/ncbi-datasets'
include { FASTERQDUMP      } from '../modules/local/fasterqdump'
include { FASTP            } from '../modules/local/fastp'
include { SEQTK_SEQ        } from '../modules/local/seqtk_seq'
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
    pp_size = 0
    ref_size = 0
    snippy_size = 0
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
        }
    }
    // Get total and convert to GB
    total_size = pp_size+ref_size+snippy_size
    total_size = MemoryUnit.of(total_size).toGiga()
    pp_size = MemoryUnit.of(pp_size).toGiga()
    ref_size = MemoryUnit.of(ref_size).toGiga()
    snippy_size = MemoryUnit.of(snippy_size).toGiga()
    // Print to Screen
    println "\n===========================\nBigBacter Database Summary:\n===========================\nDatabase Path: "+db_path+"\nPopPUNK Files: "+pp_size+"GB\nReference Files: "+ref_size+"GB\nSNP Files: "+snippy_size+"GB\nTotal: "+total_size+"GB\n"
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
        .set { timestamp }

    // provide custom run ID that replaces the timestamp - set up this way to avoid being a value channel 
    params.run_id ? timestamp.map{ timestamp -> params.run_id }.set{ timestamp } : timestamp

    /*
    =============================================================================================================================
        CHECK SAMPLESHEET
    =============================================================================================================================
    */
    if (params.input != "${projectDir}/assets/samplesheet.csv"){
        // Create input channel 
        ch_input = file(params.input)

        // SUBWORKFLOW: Read in samplesheet, validate and stage input files
        INPUT_CHECK (
            ch_input,
            timestamp
        )
        ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
        // The 'single_end' field is removed because samples must be paired end.
        INPUT_CHECK
            .out
            .manifest
            .map{ tuple(it.sample, it.taxa, it.assembly, it.fastq_1, it.fastq_2) }
            .set{manifest}
    }

    /*
    =============================================================================================================================
        PREPARE INPUTS FROM NCBI
    =============================================================================================================================
    */
    if (params.ncbi){
        // Load NCBI samplesheet
        Channel
            .fromPath(params.ncbi)
            .splitCsv(header: true)
            .map{ tuple(it.sample, it.taxa, it.assembly, it.sra) }
            .set{ ch_ncbi }
        // MODULE: Download genome assemblies from NCBI
        NCBI_DATASETS(
            ch_ncbi
        )
        ch_versions = ch_versions.mix(NCBI_DATASETS.out.versions)

        // MODULE: Download reads assemblies from NCBI
        FASTERQDUMP(
            ch_ncbi
        )
        ch_versions = ch_versions.mix(FASTERQDUMP.out.versions)

        // Added samples to the manifest channel
        ch_ncbi
            .map{ sample, taxa, assembly, sra -> [ sample, taxa ] }
            .join(NCBI_DATASETS.out.assembly, by: 0)
            .join(FASTERQDUMP.out.reads, by: 0)
            .concat(manifest)
            .set{ manifest }
    }

    // set validated manifest path - easier ways to do this but this works with Seqera Cloud
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2 -> sample+","+taxa+","+assembly+","+fastq_1+","+fastq_2 }
        .set{samplesheetlines}
    Channel.of("sample,taxa,assembly,fastq_1,fastq_2")
        .concat(samplesheetlines)
        .collectFile(name: "samplesheet-collected.csv", sort: 'index', newLine: true)
        .set{ manifest_path }

     /*
    =============================================================================================================================
        QUALITY FILTER INPUTS
    =============================================================================================================================
    */

    if(params.assembly_qc){
        // MODULE: Run seqtk seq on assembly
        SEQTK_SEQ(
            manifest.map{ sample, taxa, assembly, fastq_1, fastq_2 -> [ sample, assembly ] },
            timestamp
        )
        ch_versions = ch_versions.mix(SEQTK_SEQ.out.versions)

        // Add quality filter datasets back to manifest
        manifest
            .map{ sample, taxa, assembly, fastq_1, fastq_2 -> [ sample, taxa, fastq_1, fastq_2 ] }
            .join(SEQTK_SEQ.out.assembly, by: 0)
            .map{ sample, taxa, fastq_1, fastq_2, assembly -> [ sample, taxa, assembly, fastq_1, fastq_2 ] }
            .set{ manifest }
    }
    

    // MODULE: Run fastp on reads
    if (params.read_qc){
        FASTP(
            manifest.map{ sample, taxa, assembly, fastq_1, fastq_2 -> [ sample, fastq_1, fastq_2 ] },
            timestamp
        )
        ch_versions = ch_versions.mix(FASTP.out.versions)
        
        // Add quality filter datasets back to manifest
        manifest
            .map{ sample, taxa, assembly, fastq_1, fastq_2 -> [ sample, taxa, assembly ] }
            .join(FASTP.out.reads, by: 0)
            .set{ manifest }
    }

    /*
    =============================================================================================================================
        ASSIGN CLUSTERS
    =============================================================================================================================
    */
    // SUBWORKFLOW: Assign PopPUNK clusters
    CLUSTER(
        manifest,
        timestamp
    )
    ch_versions = ch_versions.mix(CLUSTER.out.versions)

    // Update manifest with cluster and status info
    CLUSTER.out.sample_cluster_status.map { sample, cluster, status -> [sample, cluster, status] }.set { sample_cluster_status }
    manifest.join(sample_cluster_status).set { manifest }

    /*
    =============================================================================================================================
        CORE GENOME ANALYSIS
    =============================================================================================================================
    */
    // SUBWORKFLOW: Core genome analysis
    CORE(
        manifest,
        manifest_path, 
        timestamp
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
        manifest_path,
        timestamp
    )
    ch_versions = ch_versions.mix(ACCESSORY.out.versions)

    /*
    =============================================================================================================================
        SUMMARIZE RESULTS
    =============================================================================================================================
    */
    // Consolidate results for Microreact
    CORE
        .out
        .meta
        .join(CORE.out.dist, by: [0,1,2])
        .join(CORE.out.tree, by: [0,1,2])
        .combine(ACCESSORY.out.dist.map{ taxa, cluster, source, dist -> [ taxa, cluster, dist] }, by: [0,1])
        .set{ ch_microreact }
    // MODULE: Create Microreact figures
    MRFIGS (
        ch_microreact,
        file("$projectDir/assets/microreact.json", checkIfExists: true),
        timestamp        
    )
    
    // Consolidate results for summarylines
    CORE
        .out
        .dist
        .map{ taxa, cluster, source, dist -> [ taxa, cluster, dist ] }
        .groupTuple(by: [0,1])
        .join(CORE.out.stats, by: [0,1])
        .set{core_summary}

    // MODULE: Make individual summary tables
    SUMMARY_TABLE(
        core_summary.combine(manifest_path),
        timestamp
    )

    // MODULE: Combine summary tables
    COMBINED_SUMMARY(
       SUMMARY_TABLE.out.summary.map{taxa, cluster, summary -> [ summary ]}.collect(),
       manifest_path,
       timestamp
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
    CORE
        .out
        .snp_files
        .map{ taxa, cluster, ref, new_snippy, old_snippy -> [ taxa, cluster, ref, new_snippy ] }
        .set{ cluster_files }
    
    // if push is 'true'
    ch_wait = cluster_files.concat(taxa_files).collect().flatten().last()
    if(params.push){
        // SUBWORKFLOW: Push new BigBacter database
        PUSH_FILES(
            cluster_files,
            taxa_files
        )
        PUSH_FILES
            .out
            .push_files
            .last()
            .set{ch_wait}
    }

    // Collect database info - optional
    if (params.db_info){ timestamp.combine(ch_wait).map{ timestamp, wait_file -> db_info(params.db, params.outdir, timestamp, wait_file) } }

    /*
    =============================================================================================================================
        NEXTFLOW DEFAULTS
    =============================================================================================================================
    */
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml'),
        timestamp
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
        timestamp
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
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
