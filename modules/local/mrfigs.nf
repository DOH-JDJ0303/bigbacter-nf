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
    # create the microreact figures
    mrfigs.R ${template} ${metadata} ${summary} ${snp_tree} ${snp_mat} ${acc_mat} ${prefix}
    """
}

