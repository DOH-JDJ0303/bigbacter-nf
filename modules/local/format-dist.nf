process FORMAT_DIST {
    tag "${taxa}"
    label 'process_low'

    input:
    tuple val(taxa), val(dist)
    val cols

    output:
    tuple val(taxa), path("dist.txt"), emit: dist

    when:
    task.ext.when == null || task.ext.when

    shell:
    args   = task.ext.args ?: ''
    '''
    zcat !{dist} | cut -f !{cols} > dist.txt
    '''
}