//
// Perform core genome analysis within each cluster
//

include { SNIPPY_SINGLE } from '../../modules/local/snippy'
include { SNIPPY_CORE   } from '../../modules/local/snippy'
include { GUBBINS       } from '../../modules/local/gubbins'
include { SNP_DISTS     } from '../../modules/local/snp-dists'
include { IQTREE        } from '../../modules/local/iqtree'
include { RAPIDNJ       } from '../../modules/nf-core/rapidnj/main'
include { TREE_FIGURE   } from '../../modules/local/tree-figures'
include { DIST_MAT      } from '../../modules/local/dist-mat'

/*
=============================================================================================================================
    SUBWORKFLOW FUNCTIONS
=============================================================================================================================
*/

// Function for counting the number of samples in an alignment file
def count_alignments ( aln_file ) {
    count = 0
    total = aln_file.eachLine{ line -> count+= line.count('>')}
    return total
}

/*
=============================================================================================================================
    SUBWORKFLOW
=============================================================================================================================
*/
workflow CORE {
    take:
    manifest      // channel: [ val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status)]
    manifest_file // channel: [ val(samplesheet.valid.csv) ]
    timestamp     // channel: val(timestamp)

    main:
    ch_versions = Channel.empty()
    /* 
    =============================================================================================================================
        DETERMINE REFERENCE GENOME
    =============================================================================================================================
    */
    // Group manifets by taxa and cluster
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, assembly, status]}
        .groupTuple(by: [0,1])
        .map{ taxa, cluster, assembly, status -> [taxa, cluster, assembly, status.get(0)] }
        .set { clust_grps }
    // New clusters - select first assembly
    clust_grps
        .filter{ taxa, cluster, assembly, status -> ! status }
        .map{ taxa, cluster, assembly, status -> [taxa, cluster, assembly.first()] }
        .set{ clust_grp_new }
    // Old clusters - resolve path to reference in BigBacter database
    clust_grps
        .filter{ taxa, cluster, assembly, status -> status }
        .map{ taxa, cluster, assembly, status -> [taxa, cluster, file(params.db) / taxa / "clusters" / cluster / "ref/ref.fa.gz" ] }
        .set{ clust_grps_old }
    // Combine new and old clusters into single channel and add back to reference
    manifest
        .map { sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, sample, assembly, fastq_1, fastq_2, status] }
        .combine(clust_grp_new.concat(clust_grps_old), by: [0,1])
        .map { taxa, cluster, sample, assembly, fastq_1, fastq_2, status, ref -> [sample, taxa, assembly, fastq_1, fastq_2, cluster, status, ref] }
        .set{ manifest }

    /* 
    =============================================================================================================================
        INDIVIDUAL SNP CALLING
    =============================================================================================================================
    */
    // Run Snippy on each isolate
    SNIPPY_SINGLE(
        manifest,
        timestamp
    )
    ch_versions = ch_versions.mix(SNIPPY_SINGLE.out.versions)
    // Group samples by taxa and cluster
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status, ref -> [ sample, taxa, cluster, status, ref ] }
        .join(SNIPPY_SINGLE.out.results)
        .groupTuple(by: [1,2])
        .map {sample, taxa, cluster, status, ref, new_snps -> [ taxa, cluster, status.get(0), ref.get(0), new_snps ]}
        .set {clust_grps}
    // New clusters - add empty tuple in place of historic SNP files
    clust_grps
        .filter{ taxa, cluster, status, ref, new_snps -> ! status }
        .map{ taxa, cluster, status, ref, new_snps -> [ taxa, cluster, ref, new_snps, [] ] }
        .set{ clust_grp_new }
    // Old clusters - resolve path to snippy directory in the BigBacter database
    clust_grps
        .filter{ taxa, cluster, status, ref, new_snps -> status }
        .map{ taxa, cluster, status, ref, new_snps -> [ taxa, cluster, ref, new_snps, file(file(params.db) / taxa / "clusters" / cluster / "snippy", type: 'dir') ] }
        .set{ clust_grp_old }
    // Combine new and old cluster channels
    clust_grp_new
        .concat(clust_grp_old)
        .set { snp_files }
    
    /* 
    =============================================================================================================================
        CORE SNP CALLING
    =============================================================================================================================
    */
    // Run Snippy Core
    SNIPPY_CORE(
        snp_files,
        timestamp
    )
    ch_versions = ch_versions.mix(SNIPPY_CORE.out.versions)

    /* 
    =============================================================================================================================
        GATHER METRICS ON CORE ALIGNMENT
    =============================================================================================================================
    */
    // count the number of samples in each alignment & determine if any SNPs could be identified
    SNIPPY_CORE
        .out
        .aln
        .map{ taxa, cluster, aln, const_sites -> [ taxa, cluster, aln, const_sites, count_alignments(aln), file(aln).isEmpty() ] }
        .set{ aln_w_metrics }

    /*
    =============================================================================================================================
        GENERATE NEIGHBOR JOINING TREE
        - only performed for clusters with SNPs, samples > 'max_ml',and samples > 'min_tree'
        - skips recombination analysis
        - this option should only be used if you do not have the computational power needed for a ML tree
    =============================================================================================================================
    */
    // Filter clusters exceeding max_ml and above min_tree
    aln_w_metrics
        .filter{ taxa, cluster, aln, const_sites, count, snp_status -> count > params.max_ml && count > params.min_tree && ! snp_status }
        .map{ taxa, cluster, aln, const_sites, count, snp_status -> [ taxa, cluster, aln ]}
        .set{ nj_samples }
    // MODULE: Run Rapidnj 
    RAPIDNJ(
        nj_samples,
        timestamp
    )
    ch_versions = ch_versions.mix(RAPIDNJ.out.versions)
    /* 
    =============================================================================================================================
        GENERATE MAXIMUM LIKELIHOOD TREE
        - only performed for clusters with SNPs, samples <= 'max_ml', and samples > 'min_tree'
        - this is the preferred method
        - acts as first tree for Gubbins
    =============================================================================================================================
    */
    // Filter clusters at or below max_ml and above min_tree
    aln_w_metrics
        .filter{ taxa, cluster, aln, const_sites, count, snp_status -> count <= params.max_ml && count > params.min_tree && ! snp_status }
        .map{ taxa, cluster, aln, const_sites, count, snp_status -> [ taxa, cluster, aln, const_sites, count ]}
        .set{ ml_samples }
    // MODULE: Run IQTREE2
    IQTREE(
        ml_samples,
        timestamp
    )
    ch_versions = ch_versions.mix(IQTREE.out.versions)
    /*
    =============================================================================================================================
        IDENTIFY RECOMBINANT REGIONS & BUILD TREE
        - only performed on clusters passed through the IQTREE module
    =============================================================================================================================
    */
    // MODULE: Run Gubbins
    GUBBINS(
        SNIPPY_CORE
            .out
            .clean_aln
            .join(IQTREE.out.result, by: [0, 1]), // merging with the IQTREE output ensures only clusters with enough samples/SNPs get through
        timestamp
    )
    ch_versions = ch_versions.mix(GUBBINS.out.versions)

    /* 
    =============================================================================================================================
        CALCULATE PAIRWISE SNP DIFFERENCES
        - performed for all clusters that had SNPs identified
    =============================================================================================================================
    */
    // Combine alignment files
    SNIPPY_CORE
        .out
        .full_aln
        .map{ taxa, cluster, aln -> [ taxa, cluster, aln, "snippy" ] }
        .concat( GUBBINS.out.aln.map{ taxa, cluster, aln -> [ taxa, cluster, aln, "gubbins" ] })
        .set{ all_alns }

    // Create SNP distance matrix
    SNP_DISTS(
        all_alns,
        timestamp
    )
    ch_versions = ch_versions.mix(SNP_DISTS.out.versions)

    // Add 

    /*
    =============================================================================================================================
        CREATE TREE FIGURES
    =============================================================================================================================
    */
    // Trees Channel
    RAPIDNJ
        .out
        .result
        .map{ taxa, cluster, tree -> [taxa, cluster, tree, "Core SNPs", "Neighbor Joining", "snippy", [] ] }
        .set{ nj_tree }
    IQTREE
        .out
        .result
        .map{ taxa, cluster, tree, count -> [taxa, cluster, tree, "Core SNPs", "Maximum Likelihood", "snippy" ] }
        .join(SNIPPY_CORE.out.stats, by: [0,1])
        .set{ ml_tree }
    GUBBINS
        .out
        .tree
        .map{ taxa, cluster, tree -> [taxa, cluster, tree, "Core SNPs", "Maximum Likelihood", "gubbins", [] ] }
        .set{ rc_tree }
    ml_tree
        .concat(nj_tree)
        .concat(rc_tree)
        .set{ all_trees }
    
    // Tree figures
    TREE_FIGURE (
        all_trees.combine(manifest_file),
        timestamp
    )

    /* 
    =============================================================================================================================
        CREATE SNP DISTANCE MATRIX FIGURES
        - boolean indicates if recombination is masked
    =============================================================================================================================
    */
    // Combine distance matrix with tree
    SNP_DISTS
        .out
        .result
        .map{ taxa, cluster, dist, source -> [ taxa, cluster, source, dist ] }
        .join(all_trees.map{ taxa, cluster, tree, type, method, source, stats -> [ taxa, cluster, source, tree ]}, by: [0,1,2], remainder: true)
        .map{ taxa, cluster, source, dist, tree -> [ taxa, cluster, source, dist, tree == null ? [] : tree ] }       
        .set{ all_dists }

    // Create distance matrix figure
    DIST_MAT (
        all_dists.combine(manifest_file),
        "wide",
        "Core SNPs",
        "FALSE",
        100,
        timestamp
    )

    /* 
    =============================================================================================================================
        COMBINE CHANNEL FOR EMITTING
    =============================================================================================================================
    */
    // Combine stats files from core SNP analysis
    SNIPPY_CORE
        .out
        .stats
        .concat(GUBBINS.out.stats)
        .groupTuple(by: [0,1])
        .set{ all_stats }

    emit:
    snp_files = snp_files   // channel: [ val(taxa), val(cluster), path(ref), path(new_snippy), path(old_snippy) ]
    tree      = all_trees   // channel: [ val(taxa), val(cluster), path(tree), val(type), val(method), val(source), path(stats) ]
    dist      = all_dists   // channel: [ val(taxa), val(cluster), path(dist), val(source) ]
    stats     = all_stats   // channel: [ val(taxa), val(cluster), path(stats) ]
    versions  = ch_versions // channel: [ versions.yml ]
}
