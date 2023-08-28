def VERSION = '2.3.2' // Version information not provided by tool on CLI

process RAPIDNJ {
    tag "${taxa}_${cluster}"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::rapidnj=2.3.2 conda-forge::biopython=1.78" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-805c6e0f138f952f9c61cdd57c632a1a263ea990:3c52e4c8da6b3e4d69b9ca83fa4d366168898179-0' :
        'quay.io/biocontainers/mulled-v2-805c6e0f138f952f9c61cdd57c632a1a263ea990:3c52e4c8da6b3e4d69b9ca83fa4d366168898179-0' }"

    input:
    tuple val(taxa), val(cluster), path(aln)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.treefile"), emit: result, optional: true
    path 'versions.yml',                               emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = "${timestamp}-${taxa}-${cluster}"
    """
    python \\
        -c 'from Bio import SeqIO; SeqIO.convert("$aln", "fasta", "alignment.sth", "stockholm")'

    rapidnj \\
        alignment.sth \\
        $args \\
        -i sth \\
        -c $task.cpus \\
        -x ${prefix}.treefile

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rapidnj: $VERSION
        biopython: \$(python -c "import Bio; print(Bio.__version__)")
    END_VERSIONS
    """
}