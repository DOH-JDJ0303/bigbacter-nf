process MASH_DIST_CLUSTER_NEW {
    
    input:
    tuple val(taxa_cluster), val(sample), val(taxa), path(assembly), val(cluster), val(status), val(mash_sketch)
    val timestamp

    output:
    tuple val(taxa_cluster), val(taxa), val(cluster), path("${timestamp}.msh"), path('CACHE'), path('mash-ava-cluster.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    args           = task.ext.args ?: ''
    taxa_name      = taxa[0]
    cluster_name   = cluster[0]
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
    mash sketch -o !{timestamp} *.fa
    echo "!{timestamp}" > CACHE
    # perform all-vs-all mash comparion
    mash dist !{timestamp}.msh !{timestamp}.msh > mash-ava-cluster.tsv
    '''
}

process MASH_DIST_CLUSTER_OLD {

    input:
    tuple val(taxa_cluster), val(sample), val(taxa), path(assembly), val(cluster), val(status), path(mash_sketch)
    val timestamp

    output:
    tuple val(taxa_cluster), val(taxa), val(cluster), path("${timestamp}.msh"), path('CACHE'), path('mash-ava-cluster.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assembly.name
    taxa_name      = taxa[0]
    cluster_name   = cluster[0]
    sketch_name    = mash_sketch.name
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
    # check if this is the first sketch
    if [[ !{sketch_name} == "0000000000.msh" ]]
    then 
        # rename sketch file to current
        mv new.msh !{timestamp}.msh
    else
        # add new sketch to the existing sketch and create cache
        mash paste "!{timestamp}" !{mash_sketch} new.msh
    fi
    echo "!{timestamp}" > CACHE
    # perform all-vs-all mash comparion
    mash dist !{timestamp}.msh !{timestamp}.msh > mash-ava-cluster.tsv
    '''
}

process MASH_DIST_ALL {

    input:
    tuple val(sample), val(taxa), path(assembly), path(mash_sketch)
    val timestamp

    output:
    tuple val(taxa), path("${timestamp}.msh"), path('CACHE'), path('mash-ava-all.tsv'), emit: mash_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assembly.name
    taxa_name      = taxa[0]
    sketch_name    = mash_sketch.name
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
    # check if this is the first sketch
    if [[ !{sketch_name} == "0000000000.msh" ]]
    then 
        # rename sketch file to current
        mv new.msh !{timestamp}.msh
    else
        # add new sketch to the existing sketch and create cache
        mash paste "!{timestamp}" !{mash_sketch} new.msh
    fi
    echo "!{timestamp}" > CACHE
    # perform all-vs-all mash comparion
    mash dist !{timestamp}.msh !{timestamp}.msh > mash-ava-all.tsv
    '''
}
