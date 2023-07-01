process SUMMARY_TABLE {

    input:
    tuple val(taxa_cluster), val(taxa), val(cluster), path(core), path(ava_cluster)
    val new_samples
    val timestamp

    output:
    tuple val(taxa_cluster), val(taxa), path('*-summary.tsv'), emit: summary

    when:
    task.ext.when == null || task.ext.when

    shell:
    core_files   = core.name
    mash_files   = ava_cluster.name
    taxa_name    = taxa[0]
    cluster_name = cluster[0]
    prefix       = "${timestamp}-${taxa_name}-${cluster_name}-core"
    '''
    # get list of new samples
    echo !{new_samples} | tr -d '[] ' | tr ',' '\n' > new_samples
    # create summary table
    summary-report.R \
        "!{timestamp}" \
        "!{taxa_name}" \
        "!{cluster_name}" \
        "!{params.strong_link_cutoff}" \
        "!{params.inter_link_cutoff}" \
        !{prefix}.stats \
        !{prefix}.dist
    '''
}
