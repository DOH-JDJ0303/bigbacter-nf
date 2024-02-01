process GUBBINS {
    tag "${taxa}-${cluster}"
    label 'process_medium'

    conda "bioconda::gubbins=3.3.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gubbins%3A3.3.1--py39pl5321h3d4b85c_0' :
        'quay.io/biocontainers/gubbins:3.3.1--py310pl5321h83093d7_0' }"

    input:
    tuple val(taxa), val(cluster), path(aln), path(tree), val(count)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.fasta"),                           emit: aln
    tuple val(taxa), val(cluster), path("*.gff"),                             emit: gff
    tuple val(taxa), val(cluster), path("*.vcf"),                             emit: vcf
    tuple val(taxa), val(cluster), path("*.gubbins.stats"),                   emit: stats
    tuple val(taxa), val(cluster), path("*.recombination_predictions.embl"),  emit: embl_predicted
    tuple val(taxa), val(cluster), path("*.branch_base_reconstruction.embl"), emit: embl_branch
    tuple val(taxa), val(cluster), path("*.gubbins.nwk"),                     emit: tree
    path "versions.yml",                                                      emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = "${timestamp}-${taxa}-${cluster}"
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
        \${bs} \\
        ${args} \\
        ${aln}

    # rename stats for easy summary
    mv *.csv ${prefix}.gubbins.stats

    # rename tree for emitting
    if [[ !{count} > 4 ]]
    then
        cp ${prefix}.final_bootstrap_tree.tre ${prefix}.gubbins.nwk
    else
        cp ${prefix}.final_tree.tre ${prefix}.gubbins.nwk
    fi
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gubbins: \$(run_gubbins.py --version 2>&1)
    END_VERSIONS
    """
}
