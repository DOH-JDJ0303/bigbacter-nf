//
// Call variants per cluster
//

include { SNIPPY_SINGLE } from '../../modules/local/snippy'
include { SNIPPY_CORE   } from '../../modules/local/snippy'
include { SNP_DISTS     } from '../../modules/local/snp-dists'
include { IQTREE        } from '../../modules/local/iqtree'

workflow VARIANTS {
    take:
    manifest      // channel: [ val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status)]
    timestamp     // channel: val(timestamp)

    main:
    // Select reference genomes and update manifest
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, assembly, status]}
        .groupTuple(by: [0,1])
        .map{ taxa, cluster, assembly, status -> [taxa, cluster, assembly, status.get(0)] }
        .set { clust_grps }
    
    clust_grps.filter{ taxa, cluster, assembly, status -> status == "new" }.map{ taxa, cluster, assembly, status -> [taxa, cluster, assembly.first()] }.set{ clust_grp_new }
    clust_grps.filter{ taxa, cluster, assembly, status -> status == "old" }.map{ taxa, cluster, assembly, status -> [taxa, cluster, file(params.db).resolve(taxa).resolve("clusters").resolve(cluster).resolve("ref/ref.fa") ] }.set{ clust_grps_old }
    
    clust_grp_new.concat(clust_grps_old).set{ clust_grps_refs }

    manifest
        .map { sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, sample, assembly, fastq_1, fastq_2, status] }
        .combine(clust_grps_refs, by: [0,1])
        .map { taxa, cluster, sample, assembly, fastq_1, fastq_2, status, ref -> [sample, taxa, assembly, fastq_1, fastq_2, cluster, status, ref] }
        .set{ manifest }

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
    clust_grps.filter{ taxa, cluster, status, ref, new_snps -> status == "old" }.map{ taxa, cluster, status, ref, new_snps -> [taxa, cluster, ref, new_snps, file(file(params.db) / taxa / "clusters" / cluster / "snippy", type: 'dir')] }.set{ clust_grp_old }

    clust_grp_new.concat(clust_grp_old).set { snp_files }
    
    // Run Snippy-core
    SNIPPY_CORE(
        snp_files,
        timestamp
    )

    // Create SNP distance matrix
    SNP_DISTS(
        SNIPPY_CORE.out.full_aln,
        timestamp
    )

    // Create SNP tree
    IQTREE(
        SNIPPY_CORE.out.full_aln,
        timestamp
    )

    emit:
    snp_files  = snp_files                // channel: [taxa, cluster, ref, new_snippy, old_snippy]
    core_stats = SNIPPY_CORE.out.stats    // channel: [taxa, cluster, stats]
    core_aln   = SNIPPY_CORE.out.full_aln // channel: [taxa, cluster, aln]
    core_dist  = SNP_DISTS.out.result     // channel: [taxa, cluster, dist]
    core_tree  = IQTREE.out.result        // channel: [taxa, cluster, tree]
}
