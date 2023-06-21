process CREATE_CLUSTER_DIR {
    publishDir "${db_path}/${taxa}/clusters/${cluster}/"

    input:
    tuple val(sample), val(cluster), val(taxa), path(assembly)
    val db_path

    output:
    path 'snippy/'
    path 'mash/'
    path 'ref/'

    when:
    task.ext.when == null || task.ext.when

    shell:
    """
    mkdir snippy
    mkdir mash
    mkdir ref

    mv !{assembly} ref/ref.fa
    """
}
