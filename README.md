# BigBacter
BigBacter is a pipeline aimed at simplifying bacterial genomic surviellance.
This is accomplished by:
1) pre-clustering isolates into closely related subtypes prior to phylogenetic analysis
2) automatically selecting and archiving cluster-specific reference genomes for SNP analysis
3) identifying and excluding low quality samples
4) archiving samples and automatically including them when samples from the same cluster are identified
5) re-using archived alignment files, thus greatly increasing the speed of SNP analysis
6) automatically generating figures needed for phylogenetic analysis (i.e., trees and SNP matrices)

Please see the [wiki](https://github.com/DOH-JDJ0303/bigbacter-nf/wiki) for more information.

BigBacter was originally written by Jared Johnson for the Washington State Department of Health.

## Quick Start
### 1. Configure pre-made PopPUNK databases (Performed once):
> :warning: This downloads several large files (~20 GB total) and takes ~90 minutes to complete (tested on Seqera Cloud). See the wiki page for how to prepare individual PopPUNK databases. 
```
nextflow run DOH-JDJ0303/bigbacter-nf \
    -r main \
    -profile singularity,all_dbs \
    -entry PREPARE_DB \
    --db $PWD/db \
    --max_cpus 4 \
    --max_memory 8.GB
```
### 2. Prepare your samplesheet (Performed each time):
```csv
sample,taxa,assembly,fastq_1,fastq_2
sample1,Acinetobacter_baumannii,sample1.fasta,sample1_R1.fastq.gz,sample1_R2.fastq.gz
sample2,Escherichia_coli,sample2.fasta,sample2_R1.fastq.gz,sample2_R2.fastq.gz
sample3,Staphylococcus_aureus,sample3.fasta,sample3_R1.fastq.gz,sample3_R2.fastq.gz
```
### 3. Running BigBacter (Performed each time):
```
nextflow run DOH-JDJ0303/bigbacter-nf \
    -r main \
    -profile singularity \
    --input $PWD/samplesheet.csv
    --db $PWD/db \
    --outdir $PWD/results \
    --max_cpus 4 \
    --max_memory 8.GB
```
### 4. Add the new samples to your database (Performed each time):
```
nextflow run DOH-JDJ0303/bigbacter-nf \
    -r main \
    -profile singularity \
    --input $PWD/samplesheet.csv
    --db $PWD/db \
    --outdir $PWD/results \
    --max_cpus 4 \
    --max_memory 8.GB \
    --push true \
    -resume
```
