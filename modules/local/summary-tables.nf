process SUMMARY_TABLE {
    container 'johnjare/spree:1.0'

    input:
    tuple val(taxa_cluster), val(cluster), val(taxa), val(bb_db), val(snippy_new), path(core), val(status), val(mash_sketch_cluster), val(mash_cache_cluster), path(ava_cluster)
    val timestamp

    output:
    path '*-report.tsv', emit: cluster_report

    when:
    task.ext.when == null || task.ext.when

    shell:
    core_files = core.name
    mash_files = ava_cluster.name
    '''
    # create path variables
    ## output directory
    outdir=!{params.outdir}
    outdir=${outdir%/}
    ## nested directory paths
    run_path="${outdir}/!{timestamp}"
    taxa_path="${run_path}/!{taxa}"
    clust_path="${taxa_path}/!{cluster}"
    core_path="${clust_path}/core_snps"
    mash_clust_path="${clust_path}/mash"
    mash_all_path="${taxa_path}/mash"
    # get list of files & append paths
    ## cluster-specific files
    echo !{core_files} | tr -d '[] ' | tr ',' '\n' | awk -v p=${core_path} '{print p"/"$1}' > core_f
    echo !{mash_files} | tr -d '[] ' | tr ',' '\n' | awk -v p=${mash_clust_path} '{print p"/"$1}' > mash_f
    ## add taxa-specific files to cluster-specific files - these should always be created
    echo -e "${mash_all_path}/mash-ava-all.tsv\n${mash_all_path}/mash-ava-all.treefile\n${mash_all_path}/mash-ava-all.treefile.jpg" >> mash_f
    # get list of new samples
    echo !{snippy_new} | tr -d '[] ' | tr ',' '\n' > new_samples
    # create summary table
    summary-report.R "!{timestamp}" "!{taxa}" "!{cluster}" "!{params.strong_link_cutoff}" "!{params.inter_link_cutoff}"     
    '''
}
