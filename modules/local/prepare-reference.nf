process PREPARE_REFERENCE {
    input:
    tuple val(taxa_cluster), val(samples), val(taxa), path(assemblies), val(fastq_1), val(fastq_2), val(cluster), val(status)
    val timestamp

    output:
    tuple val(taxa_cluster), path('ref/*.fa'), emit: reference
    tuple val(taxa_cluster), val("$workflow.scriptFile"), emit: dummy_var_files

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assemblies.name
    taxa_name      = taxa[0]
    cluster_name   = cluster[0]
    '''
    # select first assembly as reference - this has a lot of room for improvement
    ref=$(echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' | head -n 1)
    # rename the assembly
    mkdir ref
    mv ${ref} ref/!{taxa_name}-!{cluster_name}-ref.fa
    '''
}
