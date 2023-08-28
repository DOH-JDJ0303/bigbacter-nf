process IQTREE {
    tag "${taxa}_${cluster}"
    label 'process_high'
    
    input:
    tuple val(taxa), val(cluster), path(aln)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.treefile"), emit: result, optional: true
    path 'versions.yml',                               emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    prefix       = "${timestamp}-${taxa}-${cluster}"
    '''
    # run IQTREE2
    iqtree2 -s !{aln} !{args} || true

    #### VERSION INFO ####
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        iqtree2: $(iqtree2 --version | head -n 1 | cut -f 4  -d ' ')
    END_VERSIONS
    '''
}