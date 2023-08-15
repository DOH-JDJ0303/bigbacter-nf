//
// Call variants per cluster
//

include { SNIPPY_SINGLE } from '../../modules/local/snippy'
include { SNIPPY_CORE   } from '../../modules/local/snippy'
include { SNP_DISTS     } from '../../modules/local/snp-dists'
include { IQTREE        } from '../../modules/local/build-trees'

workflow CALL_VARIANTS {
    take:
    manifest      // channel: [ val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status), path(ref) ]
    timestamp     // channel: val(timestamp)

    main:
    // Perform initial variant calling for each sample using Snippy
    SNIPPY_SINGLE(
        manifest,
        timestamp
    )

    // Add previous SNP files to old clusters
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status, ref -> [sample, taxa, cluster, status, ref] }
        .join(SNIPPY_SINGLE.out.results)
        .groupTuple(by: [1,2])
        .map {sample, taxa, cluster, status, ref, new_snps -> [taxa, cluster, status.get(0), ref.get(0), new_snps]}
        .set {clust_grps}

    clust_grps.filter{ taxa, cluster, status, ref, new_snps -> status == "new" }.map{ taxa, cluster, status, ref, new_snps -> [taxa, cluster, ref, new_snps, []] }.set{ clust_grp_new }
    clust_grps.filter{ taxa, cluster, status, ref, new_snps -> status == "old" }.map{ taxa, cluster, status, ref, new_snps -> [taxa, cluster, ref, new_snps, params.db.resolve("clusters").resolve(cluster).resolve("snippy/")] }.set{ clust_grp_old }

    clust_grp_new.concat(clust_grp_old).set { snp_files }
    
    // Run Snippy-core
    SNIPPY_CORE(
        snp_files,
        timestamp
    )

    // Create SNP distance matrix
    SNP_DISTS(
        SNIPPY_CORE.out.results,
        timestamp
    )

    // Create SNP tree
    IQTREE(
        SNP_DISTS.out.results,
        timestamp
    )

    emit:
    sample_results = SNIPPY_SINGLE.out.results // channel: [taxa, cluster, reference, new_snippy]
    core_results = IQTREE.out.results          // channel: [taxa, cluster, core]
}
