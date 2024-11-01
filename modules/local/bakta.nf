process BAKTA_BAKTA {
    tag "${taxa}-${cluster}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bakta:1.9.3--pyhdfd78af_0' :
        'biocontainers/bakta:1.9.3--pyhdfd78af_0' }"

    input:
    tuple val(taxa), val(cluster), path(fasta)
    path db
    //path proteins
    //path prodigal_tf

    output:
    tuple val(taxa), val(cluster), path("${prefix}.embl")             , emit: embl
    tuple val(taxa), val(cluster), path("${prefix}.faa")              , emit: faa
    tuple val(taxa), val(cluster), path("${prefix}.ffn")              , emit: ffn
    tuple val(taxa), val(cluster), path("${prefix}.fna")              , emit: fna
    tuple val(taxa), val(cluster), path("${prefix}.gbff")             , emit: gbff
    tuple val(taxa), val(cluster), path("${prefix}.gff3")             , emit: gff
    tuple val(taxa), val(cluster), path("${prefix}.hypotheticals.tsv"), emit: hypotheticals_tsv
    tuple val(taxa), val(cluster), path("${prefix}.hypotheticals.faa"), emit: hypotheticals_faa
    tuple val(taxa), val(cluster), path("${prefix}.tsv")              , emit: tsv
    tuple val(taxa), val(cluster), path("${prefix}.txt")              , emit: txt
    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args   ?: ''
    prefix   = task.ext.prefix ?: "${taxa}_${cluster}"
    //def proteins_opt = proteins ? "--proteins ${proteins[0]}" : ""
    //def prodigal_tf = prodigal_tf ? "--prodigal-tf ${prodigal_tf[0]}" : ""
    """
    bakta \\
        $fasta \\
        $args \\
        --threads $task.cpus \\
        --prefix $prefix \\
        --db $db

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bakta: \$(echo \$(bakta --version) 2>&1 | cut -f '2' -d ' ')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${taxa}-${cluster}"
    """
    touch ${prefix}.embl
    touch ${prefix}.faa
    touch ${prefix}.ffn
    touch ${prefix}.fna
    touch ${prefix}.gbff
    touch ${prefix}.gff3
    touch ${prefix}.hypotheticals.tsv
    touch ${prefix}.hypotheticals.faa
    touch ${prefix}.tsv
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bakta: \$(echo \$(bakta --version) 2>&1 | cut -f '2' -d ' ')
    END_VERSIONS
    """
}

process BAKTA_BAKTADBDOWNLOAD {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bakta:1.9.3--pyhdfd78af_0' :
        'biocontainers/bakta:1.9.3--pyhdfd78af_0' }"

    input:
    val(bakta_db_set)

    output:
    path "db-light*"              , emit: bakta_db
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    bakta_db \\
     download \\
     --type light

    echo "bakta_db \\
        download \\
        --type light"

    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bakta: \$(echo \$(bakta_db --version) 2>&1 | cut -f '2' -d ' ')
    END_VERSIONS
    """
}
