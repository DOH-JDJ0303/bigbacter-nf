process MRFIGS {
    tag "${prefix}"

    input:
    tuple val(taxa), val(cluster), val(source), path(metadata), path(snp_mat), path(snp_tree), path(acc_mat), path(summary)
    path template
    val timestamp

    output:
    path "*.microreact"
    
    when:
    task.ext.when == null || task.ext.when

    prefix = "${timestamp}-${taxa}-${cluster}.${source}"
    script:
    """
    # combine tree partition data with the run summary
    mrfigs-format.R ${metadata} ${summary} ${summary.simpleName}.csv
    # create the microreact figures
    mrfigs.sh ${template} ${prefix} ${summary.simpleName}.csv ${snp_mat} ${snp_tree} ${acc_mat}
    """
}

