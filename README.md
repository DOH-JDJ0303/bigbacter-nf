# BigBacter
## Overview 
BigBacter is a pipeline aimed at simplifying bacterial genomic surveillance.

**Main features**
1) Saves your samples to a personal database (can be stored locally or on the cloud)
2)  Includes database samples when they are closely related to new samples
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
|Column Name|Description|
|-|-|
|sample|sample name|
|taxa|sample taxonomy (species or lower)|
|assembly|assembly file|
|fastq_1|foward read|
|fastq_2|reverse read|

BigBacter also requires a taxon-specific PopPUNK database (pre-made databases can be found [here](https://www.bacpop.org/poppunk/)).
(https://www.bacpop.org/poppunk/))
> [!TIP]
> BigBacter is designed to run after general bacterial analysis (e.g, [PHoeNIx](https://github.com/CDCgov/phoenix), [Bactopia](https://github.com/bactopia/bactopia), [TheiaProk](https://github.com/theiagen/public_health_bioinformatics).)

## How to use BigBacter:
1) [Quick Start](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki/1.-Quick-Start)
2) [Full Instructions](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki/2.-Full-Instructions)

### Checkout the [wiki](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki) to learn more!

> BigBacter was originally created by Jared Johnson for the Washington State Department of Health. See a full list of contributors [here]().
