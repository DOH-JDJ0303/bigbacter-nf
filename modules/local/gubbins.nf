process GUBBINS {
    tag "${taxa}-${cluster}"
    label 'process_medium'

    conda "bioconda::gubbins=3.3.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gubbins%3A3.3.1--py39pl5321h3d4b85c_0' :
        'biocontainers/gubbins:3.3.1--py39h5bf99c6_0' }"

    input:
    tuple val(taxa), val(cluster), path(aln), path(tree), val(count)
    val timestamp

    output:
    path "*.fasta"                          , emit: aln
    path "*.gff"                            , emit: gff
    path "*.vcf"                            , emit: vcf
    path "*.csv"                            , emit: stats
    path "*.recombination_predictions.embl" , emit: embl_predicted
    path "*.branch_base_reconstruction.embl", emit: embl_branch
    path "*.gubbins.nwk"                            , emit: tree
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = "${timestamp}-${taxa}-${cluster}"
    """
    # perform bootstrapping if there are more than 4 samples
    if [[ !{count} > 4 ]]
    then
        bs="-B 1000"
    else
        bs=""
    fi

    # Run Gubbins
    run_gubbins.py \\
        --threads $task.cpus \\
        --prefix ${prefix} \\
        --starting-tree ${tree} \\
        \${bs} \\
        ${args} \\
        ${aln}

    # rename tree for emitting
    if [[ !{count} > 4 ]]
    then
        cp *.final_bootstrap_tree.tre ${prefix}.gubbins.nwk
    else
        cp *.final_tree.tre ${prefix}.gubbins.nwk
    fi
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gubbins: \$(run_gubbins.py --version 2>&1)
    END_VERSIONS
    """
}
