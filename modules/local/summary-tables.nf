process SUMMARY_TABLE {

    input:
    tuple val(taxa), val(cluster), path(dist), path(stats)
    val new_samples
    val timestamp

    output:
    tuple val(taxa), val(cluster), path('*-summary.tsv'), emit: summary

    when:
    task.ext.when == null || task.ext.when

    shell:
    prefix = "${timestamp}-${taxa}-${cluster}-core"
    '''
    # create new sample list
    echo !{new_samples.join(",")} | tr ',' '\n' > new_samples.txt
    # create summary table
    summary-report.R \
        "!{timestamp}" \
        "!{taxa}" \
        "!{cluster}" \
        "!{params.strong_link_cutoff}" \
        "!{params.inter_link_cutoff}" \
        !{stats} \
        !{dist} \
        new_samples.txt
    '''
}
