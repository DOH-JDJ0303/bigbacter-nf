# BigBacter
## Overview 
BigBacter is a pipeline aimed at simplifying bacterial genomic surveillance.

**Main features**
1) Maintains personal database of samples that can be stored locally or on the cloud
2)  Automatically included samples from the database when they are closely related to new samples
3) Optimized to reduce core genome shrinkage
4) Optimized for speed and resource usage
5) Multiple species/subtypes can be included in a single run
6) Generates report-ready figures

**Main analyses:**
1) Recombination-aware core SNP analysis (Snippy and Gubbins)
2) Accessory distance analysis (PopPUNK)
3) Phylogenetic analysis (IQTREE2 or Rapidnj)

**Main outputs:**
1) Phylogenetic trees (Core SNPs)
2) Distance matrices (Accessory distance and Core SNPs)
3) Tabulated summary (QC metrics, linkage summaries, and more!)
4) Outputs are summarized in Microreact files 🙌

**Required Inputs**
1) Sample name
2) Sample species
3) Sample assembly
4) Sample reads (only Illumina paired-end, for now)
5) Species-specific PopPUNK database (pre-made databases can be found [here](https://www.bacpop.org/poppunk/))
> [!TIP]
> BigBacter is designed to run after general bacterial analysis. We recommend one of the following (in no specific order): [PHoeNIx](https://github.com/CDCgov/phoenix), [Bactopia](https://github.com/bactopia/bactopia), or [TheiaProk](https://github.com/theiagen/public_health_bioinformatics).

## How to use BigBacter:
1) [Quick Start](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki/1.-Quick-Start)
2) [Full Instructions](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki/2.-Full-Instructions)

### Checkout the [wiki](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki) to learn more!
