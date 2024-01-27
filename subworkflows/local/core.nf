//
// Perform core genome analysis within each cluster
//

include { SNIPPY_SINGLE } from '../../modules/local/snippy'
include { SNIPPY_CORE   } from '../../modules/local/snippy'
include { SNP_DISTS     } from '../../modules/local/snp-dists'
include { IQTREE        } from '../../modules/local/iqtree'
include { RAPIDNJ       } from '../../modules/nf-core/rapidnj/main'
include { TREE_FIGURE   } from '../../modules/local/tree-figures'
include { DIST_MAT      } from '../../modules/local/dist-mat'



// Function for counting the number of samples in an alignment file
def count_alignments ( aln_file ) {
    count = 0
    total = aln_file.eachLine{ line -> count+= line.count('>')}
    return total
}

workflow CORE {
    take:
    manifest      // channel: [ val(sample), val(taxa), path(assembly), path(fastq_1), path(fastq_2), val(cluster), val(status)]
    manifest_file   // channel: [ val(new_samples) ]
    timestamp     // channel: val(timestamp)

    main:
    ch_versions = Channel.empty()
    // Select reference genomes and update manifest
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status -> [taxa, cluster, assembly, status]}
        .groupTuple(by: [0,1])
        .map{ taxa, cluster, assembly, status -> [taxa, cluster, assembly, status.get(0)] }
        .set { clust_grps }
    
    clust_grps.filter{ taxa, cluster, assembly, status -> ! status }.map{ taxa, cluster, assembly, status -> [taxa, cluster, assembly.first()] }.set{ clust_grp_new }
    clust_grps.filter{ taxa, cluster, assembly, status -> status }.map{ taxa, cluster, assembly, status -> [taxa, cluster, file(params.db) / taxa / "clusters" / cluster / "ref/ref.fa.gz" ] }.set{ clust_grps_old }
    
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
    ch_versions = ch_versions.mix(SNIPPY_SINGLE.out.versions)

    // Add previous SNP files to old clusters
    manifest
        .map{ sample, taxa, assembly, fastq_1, fastq_2, cluster, status, ref -> [sample, taxa, cluster, status, ref] }
        .join(SNIPPY_SINGLE.out.results)
        .groupTuple(by: [1,2])
        .map {sample, taxa, cluster, status, ref, new_snps -> [taxa, cluster, status.get(0), ref.get(0), new_snps]}
        .set {clust_grps}

    clust_grps
        .filter{ taxa, cluster, status, ref, new_snps -> ! status }
        .map{ taxa, cluster, status, ref, new_snps -> [taxa, cluster, ref, new_snps, []] }
        .set{ clust_grp_new }
    clust_grps
        .filter{ taxa, cluster, status, ref, new_snps -> status }
        .map{ taxa, cluster, status, ref, new_snps -> [taxa, cluster, ref, new_snps, file(file(params.db) / taxa / "clusters" / cluster / "snippy", type: 'dir')] }
        .set{ clust_grp_old }

    clust_grp_new.concat(clust_grp_old).set { snp_files }
    
    // Run Snippy-core
    SNIPPY_CORE(
        snp_files,
        timestamp
    )
    ch_versions = ch_versions.mix(SNIPPY_CORE.out.versions)

    // Create SNP distance matrix
    SNP_DISTS(
        SNIPPY_CORE.out.snp_aln,
        timestamp
    )
    ch_versions = ch_versions.mix(SNP_DISTS.out.versions)

    // Create SNP tree
    // count the number of samples in each alignment
    SNIPPY_CORE
        .out
        .snp_aln
        .map{ taxa, cluster, aln, const_sites -> [taxa, cluster, aln, const_sites, count_alignments(aln)] }
        .set{ aln_w_count }

    // MODULE: Run IQTREE - only performed for clusters with fewer than defined 'max_ml'
    IQTREE(
        aln_w_count.filter{taxa, cluster, aln, const_sites, count -> count <= params.max_ml }.map{taxa, cluster, aln, const_sites, count -> [taxa, cluster, aln, const_sites, count]},
        timestamp
    )
    ch_versions = ch_versions.mix(IQTREE.out.versions)
    // MODULE: Run Rapidnj - only performed for clusters with more than the defined 'max_ml'
    RAPIDNJ(
        aln_w_count.filter{taxa, cluster, aln, const_sites, count -> count > params.max_ml }.map{taxa, cluster, aln, const_sites, count -> [taxa, cluster, aln]},
        timestamp
    )
    ch_versions = ch_versions.mix(RAPIDNJ.out.versions)
    
    // Combine the outputs of IQTREE and RAPIDNJ and add core SNP stats
    IQTREE
        .out
        .result
        .map{ taxa, cluster, tree -> [taxa, cluster, tree, "core SNPs", "Maximum Likelihood"] }
        .set{ ml_tree }
    RAPIDNJ
        .out
        .result
        .map{ taxa, cluster, tree -> [taxa, cluster, tree, "core SNPs", "Neighbor Joining"] }
        .set{ nj_tree }
    ml_tree
        .concat(nj_tree)
        .set{ core_tree }

    // MODULE: Make tree figures and distance matrix
    // Tree figure
    TREE_FIGURE (
        core_tree.join(SNIPPY_CORE.out.stats, by: [0,1]),
        manifest_file,
        timestamp
    )
   
   // Distance matrix figure
   SNP_DISTS
       .out
       .result
       .join(core_tree.map{ taxa, cluster, tree, type, method -> [ taxa, cluster, tree  ]}, by: [0,1])       
       .set{ dist_mat_input }

    DIST_MAT (
        dist_mat_input,
        manifest_file,
        "wide",
        "SNP",
        100,
        timestamp
    )

    emit:
    snp_files = snp_files             // channel: [ val(taxa), val(cluster), path(ref), path(new_snippy), path(old_snippy) ]
    tree      = core_tree             // channel: [ val(taxa), val(cluster), path(tree), val(type), val(method),  ]
    dist      = SNP_DISTS.out.result  // channel: [ val(taxa), val(cluster), path(dist) ]
    stats     = SNIPPY_CORE.out.stats // channel: [ val(taxa), val(cluster), path(stats) ]
    versions  = ch_versions           // channel: [ versions.yml ]
}
