
process MASH_DIST_CLUSTER {

    input:
    tuple val(taxa), val(cluster), val(status), path(assembly), val(sample), path(sketch)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.msh"), path('mash-ava-cluster.tsv'), emit: results

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
    # check if this is the first sketch
    if [[ !{status} == "new" ]]
    then 
        # rename sketch file to current
        mv new.msh 0000000000.msh
    else
        # add new sketch to the existing sketch
        mash paste "!{timestamp}" !{mash_sketch} new.msh
        rm !{mash_sketch} new.msh
    fi
    # perform all-vs-all mash comparion
    mash dist *.msh *.msh > mash-ava-cluster.tsv
    '''
}