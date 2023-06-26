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
    # rename 'core.dist' to 'core.dist.fail' if empty
    if [[ ! -s "core.dist" ]]
    then
        mv core.dist core.fail.dist
    fi
    '''
}
