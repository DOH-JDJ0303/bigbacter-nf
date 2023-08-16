process IQTREE {
    input:
    tuple val(taxa), val(cluster), path(core)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.treefile"), emit: result, optional: true

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    prefix       = "${timestamp}-${taxa}-${cluster}-core"
    '''
    # run IQTREE2
    iqtree2 -s !{prefix}.aln !{args} || true
    '''
}