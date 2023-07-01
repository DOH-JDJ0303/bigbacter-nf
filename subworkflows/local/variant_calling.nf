//
// Call variants per cluster
//

include { SNIPPY_SINGLE } from '../../modules/local/snippy'
include { SNIPPY_CORE   } from '../../modules/local/snippy'
include { SNP_DISTS     } from '../../modules/local/snp-dists'
include { IQTREE        } from '../../modules/local/build-trees'

workflow CALL_VARIANTS {
    take:
    manifest      // channel: [ val(taxa_cluster), val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status), path(reference) ]
    old_var_files // channel: [ val(taxa_cluster), path(old_var_files) ]
    timestamp     // channel: val(timestamp)

    main:
    // Perform initial variant calling for each sample using Snippy
    SNIPPY_SINGLE(
        manifest,
        timestamp
    )

    // Group by 'taxa_cluster' and append on any old samples files
    old_var_files
        .map { taxa_cluster, old_var_files -> [taxa_cluster, old_var_files]}
        .set { old_var_files }

    SNIPPY_SINGLE
        .out
        .results
        .map { taxa_cluster, taxa, cluster, reference, new_snippy -> [taxa_cluster, taxa, cluster, reference, new_snippy] }
        .groupTuple(by: 0)
        .map { taxa_cluster, taxa, cluster, reference, new_snippy -> [taxa_cluster, taxa, cluster, reference[0], new_snippy] }
        .join(old_var_files)
        .set { all_snippy_files }
    
    // Run Snippy-core
    SNIPPY_CORE(
        all_snippy_files,
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
    sample_results = SNIPPY_SINGLE.out.results // channel: [taxa_cluster, taxa, cluster, reference, new_snippy]
    core_results = IQTREE.out.results          // channel: [taxa_cluster, taxa, cluster, core]
}
