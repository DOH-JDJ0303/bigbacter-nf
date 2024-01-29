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
def checkPathParamList = [ params.input, params.db, params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }
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

    /*
    =============================================================================================================================
        CHECK SAMPLESHEET
    =============================================================================================================================
    */
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
      .map{ tuple(it.sample, it.taxa, it.assembly, it.fastq_1, it.fastq_2)}
      .set{manifest}

    // set validated manifest path
    INPUT_CHECK
      .out
      .csv
      .set{ manifest_path }

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
    // Consolidate results for summary
    CORE
        .out
        .dist
        .map{ taxa, cluster, dist, source -> [ taxa, cluster, dist ] }
        .groupTuple(by: [0,1])
        .join(CORE.out.stats, by: [0,1])
        .set{core_summary}

    // MODULE: Make individual summary tables
    SUMMARY_TABLE(
        core_summary,
        manifest_path,
        timestamp
    )

    // MODULE: Combine summary tables
    COMBINED_SUMMARY(
       SUMMARY_TABLE.out.summary.map{taxa, cluster, summary -> [ summary ]}.collect(),
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
    if(params.push){
        // SUBWORKFLOW: Push new BigBacter database
        PUSH_FILES(
            cluster_files,
            taxa_files,
            COMBINED_SUMMARY.out.summary
            )
    }

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
