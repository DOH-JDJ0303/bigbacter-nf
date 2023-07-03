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
if (params.db) { ch_input = file(params.db) } else { exit 1, 'BigBacter database not specified!' }
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
include { INPUT_CHECK       } from '../subworkflows/local/input_check'
include { ASSIGN_CLUSTER    } from '../subworkflows/local/assign_cluster'
include { PREPARE_CLUSTERS  } from '../subworkflows/local/prepare_clusters'
include { CALL_VARIANTS     } from '../subworkflows/local/variant_calling'
include { MASH_SKETCH       } from '../subworkflows/local/mash_sketch'
include { SUMMARIZE_RESULTS } from '../subworkflows/local/summarize_results'
include { PUSH_FILES        } from '../subworkflows/local/publish_new_db'
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

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    //INPUT_CHECK (
    //    ch_input
    //)
    //ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)


    // Get timestamp - used to name cache and some new files
    TIMESTAMP()
    TIMESTAMP
        .out
        .set { timestamp }

    // load manifest file
    Channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .set { manifest }

    // SUBWORKFLOW: Assign PopPUNK clusters
    ASSIGN_CLUSTER(
        manifest,
        timestamp
    )

    // SUBWORKFLOW: Prepapre clusters
    PREPARE_CLUSTERS(
        ASSIGN_CLUSTER.out.manifest,
        timestamp
    )
    
    // SUBWORKFLOW: Call variants
    CALL_VARIANTS(
        PREPARE_CLUSTERS.out.manifest, 
        PREPARE_CLUSTERS.out.old_var_files,
        timestamp
    )

    // SUBWORKFLOW: Mash comparisons
    MASH_SKETCH(
        ASSIGN_CLUSTER.out.manifest,
        timestamp
    )

   // SUBWORKFLOW: Summarize results
   // Consolidate results
   // Taxa-specific files
   MASH_SKETCH
        .out
        .mash_all
        .map { taxa, new_taxa_sketch, new_taxa_cache, ava_taxa -> [taxa, ava_taxa]}
        .set { mash_taxa_results }
   // Cluster-specific files
   MASH_SKETCH
       .out
       .mash_cluster
       .map { taxa_cluster, new_cluster_sketch, new_cluster_cache, ava_cluster -> [taxa_cluster, ava_cluster] }
       .set { mash_cluster_results }
   CALL_VARIANTS
        .out
        .core_results
        .map { taxa_cluster, taxa, cluster, core -> [taxa_cluster, taxa, cluster, core] }
        .set { snippy_cluster_results }
    snippy_cluster_results
        .join(mash_cluster_results)
        .set { all_cluster_results }
    SUMMARIZE_RESULTS(
        all_cluster_results, 
        mash_taxa_results,
        timestamp
    )
    
    // SUBWORKFLOW: Push new BigBacter database
    // Consolidate new database files
    // Taxa-specific files
    ASSIGN_CLUSTER
        .out
        .new_pp_db
        .unique()
        .map { taxa, new_pp_db, new_pp_cache -> [taxa, new_pp_db, new_pp_cache] }
        .set { new_pp_db }
    MASH_SKETCH
        .out
        .mash_all
        .unique()
        .map { taxa, new_taxa_sketch, new_taxa_cache, ava_taxa -> [taxa[0], new_taxa_sketch]}
        .set { new_taxa_sketch }
    SUMMARIZE_RESULTS
        .out
        .summary
        .map { taxa_cluster, taxa, summary -> [taxa[0], summary] }
        .set { dummy_taxa_summary }
    new_pp_db
        .join(new_taxa_sketch)
        .join(dummy_taxa_summary)
        .set { new_taxa_files }

    // Cluster-specific files
    CALL_VARIANTS
        .out
        .sample_results
        .map { taxa_cluster, taxa, cluster, reference, new_snippy -> [taxa_cluster, taxa, cluster, reference, new_snippy] }
        .groupTuple()
        .map { taxa_cluster, taxa, cluster, reference, new_snippy -> [taxa_cluster, taxa[0], cluster[0], reference[0], new_snippy] }
        .set { new_variant_files }
    MASH_SKETCH
        .out
        .mash_cluster
        .map { taxa_cluster, new_cluster_sketch, new_cluster_cache, ava_cluster -> [taxa_cluster, new_cluster_sketch, new_cluster_cache] }
        .set { new_cluster_sketch }
    SUMMARIZE_RESULTS
        .out
        .summary
        .map { taxa_cluster, taxa, summary -> [taxa_cluster, summary] }
        .set { dummy_cluster_summary }
    new_variant_files
        .join(new_cluster_sketch)
        .join(dummy_cluster_summary)
        .set { new_cluster_files }
    
    if(params.push){
       PUSH_FILES(
            new_cluster_files,
            new_taxa_files
       )
    }

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowBigbacter.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowBigbacter.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    //ch_multiqc_files = Channel.empty()
    //ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    //ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    //ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    //ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    //MULTIQC (
    //    ch_multiqc_files.collect(),
    //    ch_multiqc_config.toList(),
    //    ch_multiqc_custom_config.toList(),
    //    ch_multiqc_logo.toList()
    //)
    //multiqc_report = MULTIQC.out.report.toList()
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
