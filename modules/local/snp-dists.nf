process SNP_DISTS {
    tag "${taxa}_${cluster}_${source}"
    label 'process_low'
    
    input:
    tuple val(taxa), val(cluster), path(aln), val(source)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.dist"), val(source), emit: result
    path 'versions.yml',                                        emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    prefix       = "${timestamp}-${taxa}-${cluster}-core"
    '''
    # Run snp-dists
    snp-dists !{args} !{aln} > !{prefix}.!{source}.dist
    
    #### VERSION INFO ####
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        snp-dists: $(snp-dists -v | cut -f 2 -d ' ')
    END_VERSIONS
    '''
}
