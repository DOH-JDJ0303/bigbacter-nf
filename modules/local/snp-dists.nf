process SNP_DISTS {
    tag "${taxa}_${cluster}"
    label 'process_low'
    
    input:
    tuple val(taxa), val(cluster), path(aln), val(const_sites)
    val timestamp

    output:
    tuple val(taxa), val(cluster), path("*.dist"), emit: result
    path 'versions.yml',                           emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    args         = task.ext.args ?: ''
    prefix       = "${timestamp}-${taxa}-${cluster}-core"
    '''
    # Run snp-dists if SNPs were detected, otherwise create empty file
    if [ -s !{aln} ]
    then
        snp-dists !{args} !{aln} > !{prefix}.dist
    else
        touch !{prefix}.dist
    fi
    
    #### VERSION INFO ####
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        snp-dists: $(snp-dists -v | cut -f 2 -d ' ')
    END_VERSIONS
    '''
}
