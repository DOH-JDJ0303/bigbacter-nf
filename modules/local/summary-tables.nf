process SUMMARY_TABLE {
    tag "${taxa}_${cluster}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), path(dist), path(stats)
    val new_samples
    val timestamp

    output:
    tuple val(taxa), val(cluster), path('*-summary.tsv'), emit: summary

    when:
    task.ext.when == null || task.ext.when

    shell:
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
