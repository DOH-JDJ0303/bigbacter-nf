process FORMAT_ASSEMBLY {
    tag "${sample}"
    label 'process_low'

    input:
    tuple val(sample), path(assembly)

    output:
    tuple val(sample), path("${sample}.fa.gz", includeInputs: true), emit: assembly

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # compress assembly file - ignore if already compressed
    gzip !{assembly} || true
    # rename file, if needed
    mv -n * "!{sample}.fa.gz"
    '''
}
