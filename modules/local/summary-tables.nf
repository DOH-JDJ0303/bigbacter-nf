process SUMMARY_TABLE {

    input:
    tuple val(taxa), val(cluster), path(dist), path(stats)
    val timestamp
    output:
    tuple val(taxa), val(cluster), path('*-summary.tsv'), emit: summary

    when:
    task.ext.when == null || task.ext.when

    shell:
    prefix       = "${timestamp}-${taxa}-${cluster}-core"
    '''
    # create summary table
    summary-report.R \
        "!{timestamp}" \
        "!{taxa}" \
        "!{cluster}" \
        "!{params.strong_link_cutoff}" \
        "!{params.inter_link_cutoff}" \
        !{stats} \
        !{dist}
    '''
}
