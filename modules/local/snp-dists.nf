process SNP_DISTS {
    input:
    tuple val(taxa), val(cluster), path(aln)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("${prefix}.*", includeInputs: true), emit: result

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    prefix       = "${timestamp}-${taxa}-${cluster}-core"
    '''
    # run snp-dists
    snp-dists !{args} !{aln} > !{prefix}.dist
    '''
}
