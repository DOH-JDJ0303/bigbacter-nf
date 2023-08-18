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
include { INPUT_CHECK                     } from '../subworkflows/local/input_check'
include { CLUSTER                         } from '../subworkflows/local/assign_cluster'
include { VARIANTS                        } from '../subworkflows/local/call_variants'
include { MASH                            } from '../subworkflows/local/mash'
include { PUSH_FILES                      } from '../subworkflows/local/push_files'

include { DIST_MAT                        } from '../modules/local/dist-mat'
include { TREE_FIGURE as MASH_TREE_FIGURE } from '../modules/local/tree-figures'
include { TREE_FIGURE as CORE_TREE_FIGURE } from '../modules/local/tree-figures'
include { SUMMARY_TABLE                   } from '../modules/local/summary-tables'
include { COMBINED_SUMMARY                } from '../modules/local/combined-summary'

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
        .map { tuple(it.sample, it.taxa, it.assembly, it.fastq_1, it.fastq_2) }
        .set { manifest }

    // SUBWORKFLOW: Assign PopPUNK clusters
    CLUSTER(
        manifest,
        timestamp
    )

    // Update manifest with cluster and status info
    CLUSTER.out.sample_cluster_status.map { sample, cluster, status -> [sample, cluster, status] }.set { sample_cluster_status }
    manifest.join(sample_cluster_status).set { manifest }
    
    // SUBWORKFLOW: Call variants
    VARIANTS(
        manifest, 
        timestamp
    )

    // SUBWORKFLOW: Mash comparisons
    MASH(
        manifest,
        timestamp
    )

   // MODULE: Make Summary table
   VARIANTS.out.core_stats.map{taxa, cluster, stats -> [taxa, cluster, stats]}.set{ core_stats }
   VARIANTS.out.core_dist.map{taxa, cluster, dist -> [taxa, cluster, dist]}.join(core_stats, by: [0,1]).set{core_summary}
   manifest.map{sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [sample]}.collect().set{new_samples}
   SUMMARY_TABLE(
    core_summary,
    new_samples,
    timestamp
   )
   COMBINED_SUMMARY(
    SUMMARY_TABLE.out.summary.map{taxa, cluster, summary -> [summary]}.collect(),
    timestamp
   )

   // MODULE: Make tree figures and distance matrix
   CORE_TREE_FIGURE(
    VARIANTS.out.core_tree,
    timestamp
   )

   MASH_TREE_FIGURE(
    MASH.out.mash_tree,
    timestamp
   )
   
   VARIANTS.out.core_dist.map{taxa, cluster, dist -> [taxa, cluster, dist]}.join(VARIANTS.out.core_tree.map{ taxa, cluster, tree -> [taxa, cluster, tree]}, by: [0,1]).set{dist_mat_input}
   DIST_MAT(
    dist_mat_input,
    timestamp
   )
   
   // SUBWORKFLOW: Push new BigBacter database
   // Taxa-specific files
   CLUSTER.out.new_pp_db.set{ taxa_files }
   // Cluster-specific files
   MASH.out.mash_files.map{ taxa, cluster, new_sketch, ava -> [taxa, cluster, new_sketch]}.set{ mash_files } 
   VARIANTS.out.snp_files
       .map{ taxa, cluster, ref, new_snippy, old_snippy -> [taxa, cluster, ref, new_snippy] }
       .join(mash_files, by: [0,1])
       .set{ cluster_files }

   if(params.push){
    PUSH_FILES(
        cluster_files,
        taxa_files,
        COMBINED_SUMMARY.out.summary
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
