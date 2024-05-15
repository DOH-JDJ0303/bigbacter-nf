process MRFIGS {
    tag "${prefix}"

    input:
    tuple val(taxa), val(cluster), val(source), path(metadata), path(snp_mat), path(snp_tree), path(acc_mat)
    path template
    val timestamp

    output:
    path "*.microreact"
    
    when:
    task.ext.when == null || task.ext.when

    prefix = "${timestamp}-${taxa}-${cluster}.${source}"
    script:
    """
    mrfigs.sh ${template} ${prefix} ${metadata} ${snp_mat} ${snp_tree} ${acc_mat}
    """
}

