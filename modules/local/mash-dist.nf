
process MASH_DIST {
    tag "${taxa}_${cluster}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), val(status), val(sample), path(assembly), path(old_sketch)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.msh"), path('mash-ava-cluster.tsv'), emit: results
    path 'versions.yml',                                                                     emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # create sketches for each assembly
    ## create table of sample names and their assemblies
    echo !{sample.join(',')} | tr ',' '\n' > s_col
    echo !{assembly.join(',')} | tr ',' '\n' > a_col
    paste -d "," s_col a_col > manifest.txt
    for row in $(cat manifest.txt)
    do
        # rename assemblies
        s=$(echo $row | tr ',' '\t' | cut -f 1)
        a=$(echo $row | tr ',' '\t' | cut -f 2)

        mv ${a} ${s}

        # make sketch
        mash sketch -o ${s} ${s}
    done
    # move old sketches into working directory - if they exist - do not replace new sketches
    mv -n !{old_sketch}/*.msh ./ || true
    # combine all sketches into single file & perform all-vs-all comparison
    mash paste all *.msh
    mash dist all.msh all.msh > mash-ava-cluster.tsv
    # remove all.msh for publishing
    rm all.msh

    # version info
    echo "!{task.process}:\n    mash: $(mash --version | tr -d '\t\n\r ')" > versions.yml
    '''
}