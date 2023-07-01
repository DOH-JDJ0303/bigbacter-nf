process SNP_DISTS {
    input:
    tuple val(taxa_cluster), val(taxa), val(cluster), path(core)
    val timestamp

    output:
    tuple val(taxa_cluster), val(taxa), val(cluster), path("${prefix}.*", includeInputs: true), emit: results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    taxa_name    = taxa[0]
    cluster_name = cluster[0]
    prefix       = "${timestamp}-${taxa_name}-${cluster_name}-core"
    '''
    # run snp-dists
    snp-dists !{args} !{prefix}.aln > !{prefix}.dist || true
    # rename '!{prefix}.dist' to '!{prefix}.dist.fail' if empty
    if [[ ! -s "!{prefix}.dist" ]]
    then
        mv !{prefix}.dist !{prefix}.fail.dist
    fi
    '''
}
