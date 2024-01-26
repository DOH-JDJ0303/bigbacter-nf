
process RESOLVE_MERGED_CLUSTERS {
    tag "${sample}"
    label 'process_low'
    stageInMode 'copy'

    input:
    tuple val(taxa), val(merged_cluster), path(db_info), path(dist), val(sample)

    output:
    path "best_cluster.csv", emit: best_cluster

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    resolve-merged.sh !{sample} !{taxa} !{dist} !{db_info}
    '''
}