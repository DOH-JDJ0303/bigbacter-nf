process MASH_DIST_CLUSTER_NEW {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa_cluster), val(sample), val(taxa), path(assembly), val(cluster), val(status), val(mash_sketch)

    output:
    tuple val(taxa_cluster), path('00.msh'), path('CACHE'), path('mash-ava-cluster.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assembly.name
    '''
    # rename assemblies for tree
    echo !{sample} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col        
    paste -d "," s_col a_col > manifest.txt
    for row in $(cat manifest.txt)
    do
        n=$(echo $row | tr ',' '\t' | cut -f 1)
        a=$(echo $row | tr ',' '\t' | cut -f 2)

        mv ${a} ${n}.fa
    done
    # create sketch and cache for all assemblies
    mash sketch -o 0000000000 *.fa
    echo '0000000000' > CACHE
    # perform all-vs-all mash comparion
    mash dist 0000000000.msh 0000000000.msh > mash-ava-cluster.tsv
    '''
}

process MASH_DIST_CLUSTER_OLD {
    container 'staphb/mash:2.3'

    input:
    tuple val(taxa_cluster), val(sample), val(taxa), path(assembly), val(cluster), val(status), val(mash_sketch)
    val new_sketch

    output:
    tuple val(taxa_cluster), path("${new_sketch}.msh"), path('CACHE'), path('mash-ava-cluster.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assembly.name
    '''
    # rename assemblies for tree
    echo !{sample} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
    paste -d "," s_col a_col > manifest.txt
    for row in $(cat manifest.txt)
    do
        n=$(echo $row | tr ',' '\t' | cut -f 1)
        a=$(echo $row | tr ',' '\t' | cut -f 2)

        mv ${a} ${n}.fa
    done
    # create sketch for all assemblies
    mash sketch -o new *.fa
    # add new sketch to the existing sketch and create cache
    mash paste "!{new_sketch}" !{mash_sketch} new.msh
    echo "!{new_sketch}" > CACHE
    # perform all-vs-all mash comparion
    mash dist !{new_sketch}.msh !{new_sketch}.msh > mash-ava-cluster.tsv
    '''
}

process MASH_DIST_ALL {
    container 'staphb/mash:2.3'

    input:
    tuple val(sample), val(taxa), path(assembly), val(mash_sketch)
    val new_sketch

    output:
    tuple val(taxa), path("${new_sketch}.msh"), path('CACHE'), path('mash-ava-all.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assembly.name
    '''
    # rename assemblies for tree
    echo !{sample} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
    paste -d "," s_col a_col > manifest.txt
    for row in $(cat manifest.txt)
    do
        n=$(echo $row | tr ',' '\t' | cut -f 1)
        a=$(echo $row | tr ',' '\t' | cut -f 2)

        mv ${a} ${n}.fa
    done
    # create sketch for all assemblies
    mash sketch -o new *.fa
    # add new sketch to the existing sketch and create cache
    mash paste "!{new_sketch}" !{mash_sketch} new.msh
    echo "!{new_sketch}" > CACHE
    # perform all-vs-all mash comparion
    mash dist !{new_sketch}.msh !{new_sketch}.msh > mash-ava-all.tsv
    '''
}
