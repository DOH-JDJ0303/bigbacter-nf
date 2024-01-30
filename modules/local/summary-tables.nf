process SUMMARY_TABLE {
    tag "${taxa}_${cluster}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), path(dists), path(stats)
    path manifest
    val timestamp

    output:
    tuple val(taxa), val(cluster), path('*-summary.tsv'), emit: summary

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # create summary table
    summary-report.R \
        "!{timestamp}" \
        "!{taxa}" \
        "!{cluster}" \
        "!{params.strong_link_cutoff}" \
        "!{params.inter_link_cutoff}" \
        *.snippy.stats \
        *.snippy.dist \
        *.gubbins.stats \
        *.gubbins.dist \
        !{manifest}
    '''
}
