process GET_PP_DB {

    input:
    tuple path(cache), val(sample), val(taxa), val(assembly)

    output:
    tuple stdout, val(sample), val(taxa), val(assembly), emit: pp_list
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    cdb=$(cat !{cache})
    echo "!{params.db}/!{taxa}/pp_db/${cdb}/" | tr -d '\t\n\r '
    
    echo "hello" > versions.yml
    '''
}

process GET_MASH_SKETCH_CLUSTER {

    input:
    tuple val(taxa_cluster), val(sample), val(taxa), val(assembly), val(cluster), val(status), path(cluster_cache) 

    output:
    tuple val(taxa_cluster), val(sample), val(taxa), val(assembly), val(cluster), val(status), stdout, emit: mash_cluster
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    taxa_name = taxa[0]
    cluster_name = cluster[0]
    '''
    cmsh=$(cat !{cluster_cache})
    echo "!{params.db}/!{taxa_name}/clusters/!{cluster_name}/mash/${cmsh}.msh" | tr -d '\t\n\r '

    echo "hello" > versions.yml
    '''
}

process GET_MASH_SKETCH_ALL {

    input:
    tuple val(sample), val(taxa), val(assembly), path(all_cache)

    output:
    tuple val(sample), val(taxa), val(assembly), stdout, emit: mash_all
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    taxa_name = taxa[0]
    '''
    cmsh=$(cat !{all_cache})
    echo "!{params.db}/!{taxa_name}/mash/${cmsh}.msh" | tr -d '\t\n\r '

    echo "hello" > versions.yml
    '''
}
