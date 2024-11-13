process SEQTK_SEQ {
    tag "${sample}"
    label 'process_low'

    conda "bioconda::seqtk=1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqtk:1.3--h5bf99c6_3' :
        'quay.io/biocontainers/seqtk:1.3--h5bf99c6_3' }"

    input:
    tuple val(sample), path(assembly)
    val timestamp

    output:
    tuple val(sample), path("${prefix}.fa.gz"), emit: assembly
    path "versions.yml",                        emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: sample
    """
    seqtk \\
        seq \\
        -L ${params.min_contig_len} \\
        $args \\
        $assembly | \\
        gzip -c > ${prefix}.fa.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqtk: \$(echo \$(seqtk 2>&1) | sed 's/^.*Version: //; s/ .*\$//')
    END_VERSIONS
    """
}