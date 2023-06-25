process SNP_DISTS {
    container 'staphb/snp-dists:0.8.2'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path(core), val(status)


    output:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path("core.*", includeInputs: true), val(status), emit: snp_results

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # run snp-dists
    snp-dists -b core.aln > core.dist || true
    # return empty file if snp-dists fails
    if [[ ! -f "core.dist" ]]
    then
        touch core.fail.dist
    fi
    '''
}
