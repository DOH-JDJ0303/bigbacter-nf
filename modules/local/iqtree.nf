process IQTREE {
    tag "${taxa}_${cluster}"
    label 'process_high'
    
    input:
    tuple val(taxa), val(cluster), path(aln), path(const_sites), val(count)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.contree"),  emit: result, optional: true
    path 'versions.yml',                               emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    prefix       = "${timestamp}-${taxa}-${cluster}"
    '''
    # perform bootstrapping if there are more than 4 samples
    if [[ !{count} > 4 ]]
    then
        bs="-B 1000"
    else
        bs=""
    fi

    # run IQTREE2
    iqtree2 \
        -s !{aln} \
        -fconst $(cat !{const_sites}) \
        -T !{task.cpus} \
        !{args} \
        ${bs} || true
    
    # rename file for consistency
    if [[ !{count}  < 5 ]]
    then
        mv *.treefile core-tree.contree
    fi

    #### VERSION INFO ####
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        iqtree2: $(iqtree2 --version | head -n 1 | cut -f 4  -d ' ')
    END_VERSIONS
    '''
}