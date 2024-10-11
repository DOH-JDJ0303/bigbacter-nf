# BigBacter
## Overview 
BigBacter is a pipeline aimed at simplifying bacterial genomic surveillance.

**Main features**
1) Samples are maintained in a personalized database that can be stored locally or on the cloud
2) Samples in the database are automatically included in the analysis when they are closely related to new samples
3) Optimized to avoid core genome shrinkage
4) Very efficient (fast and low resource usage)
5) Multiple species/subtypes can be included in a single run
6) Generates report-ready figures

**Main analyses:**
1) Recombination-aware core SNP analysis (Snippy and Gubbins)
2) Accessory distance analysis (PopPUNK)
3) Phylogenetic analysis (IQTREE2 or Rapidnj)

**Main outputs:**
1) Phylogenetic trees (Core SNPs)
2) Distance matrices (Accessory distance and core SNPs)
3) Tabulated summary (QC metrics and more)

\* Outputs are summarized in Microreact files 🙌

**Required Inputs**
1) Sample name
2) Sample taxonomy (species or closer)
3) Sample assembly
4) Sample reads (Illumina paired-end)
5) Species-specific PopPUNK database (list of pre-made databases can be found [here](https://www.bacpop.org/poppunk/))
> [!TIP]
> BigBacter is designed to be run following general bacterial analysis. We recommend one of the following (in no specific order): [PHoeNIx](https://github.com/CDCgov/phoenix), [Bactopia](https://github.com/bactopia/bactopia), or [TheiaProk](https://github.com/theiagen/public_health_bioinformatics).
### Checkout the [wiki](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki) to learn more!

## Quick Start
> [!IMPORTANT]
> BigBacter requires that you have [Nextflow](https://www.nextflow.io/docs/latest/install.html) installed and at least one of the following container engines: [Docker](https://docs.docker.com/engine/install/), [Podman](https://podman.io/docs/installation), [Apptainer](https://apptainer.org/docs/admin/main/installation.html), [Singularity](https://docs.sylabs.io/guides/3.0/user-guide/installation.html).

### 1. Configure your PopPUNK database (Performed once per species):
> [!NOTE]
> This example shows how you would configure an *E. coli* database. You can find a list of available PopPUNK databases [here](https://github.com/DOH-JDJ0303/bigbacter-nf/blob/main/docs/db_profiles.md). You can also find instructions for how to add your own databases [here]().
```
nextflow run DOH-JDJ0303/bigbacter-nf \
    -r main \
    -profile docker,Escherichia_coli_db \
    -entry PREPARE_DB \
    --db $PWD/db
```
### 2. Prepare your samplesheet (Performed each time):
> [!NOTE] 
> Nextflow requires the use of absolute file paths in samplesheets.

`samplesheet.csv`:
```csv
sample,taxa,assembly,fastq_1,fastq_2
sample1,Acinetobacter_baumannii,sample1.fasta,sample1_R1.fastq.gz,sample1_R2.fastq.gz
sample2,Escherichia_coli,sample2.fasta,sample2_R1.fastq.gz,sample2_R2.fastq.gz
sample3,Staphylococcus_aureus,sample3.fasta,sample3_R1.fastq.gz,sample3_R2.fastq.gz
```
### 3. Running BigBacter (Performed each time):
> [!NOTE]
> Nextflow versions ≥ 23.10 require that you run `export NXF_SINGULARITY_HOME_MOUNT=true` when running with `-profile singularity` or Gubbins will fail ([issue 7](https://github.com/DOH-JDJ0303/bigbacter-nf/issues/7)).
```
nextflow run DOH-JDJ0303/bigbacter-nf \
    -r main \
    -profile docker \
    --input $PWD/samplesheet.csv
    --db $PWD/db \
    --outdir $PWD/results \
    --max_cpus 4 \
    --max_memory 8.GB
```
### 4. Add the new samples to your database (Performed each time):
> [!NOTE] 
> This is the same command as in step 3 but with `-resume` and `--push true`. This will resume the run from step 3 and push the existing files to the BigBacter database. This allows you to check your results before pushing files to your database.
```
nextflow run DOH-JDJ0303/bigbacter-nf \
    -r main \
    -profile docker \
    --input $PWD/samplesheet.csv
    --db $PWD/db \
    --outdir $PWD/results \
    --max_cpus 4 \
    --max_memory 8.GB \
    --push true \
    -resume
```
