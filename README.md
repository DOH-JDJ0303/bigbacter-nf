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
### 1. Configure all pre-made PopPUNK databases (Performed once):
> :warning: This downloads PopPUNK databases for 23 bacterial species (~21 GB total; ~2 hours using AWS Batch). See the wiki page for how to prepare individual PopPUNK databases. 
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
> Note: Nextflow requires the use of absolute file paths in samplesheets.
```csv
sample,taxa,assembly,fastq_1,fastq_2
sample1,Acinetobacter_baumannii,sample1.fasta,sample1_R1.fastq.gz,sample1_R2.fastq.gz
sample2,Escherichia_coli,sample2.fasta,sample2_R1.fastq.gz,sample2_R2.fastq.gz
sample3,Staphylococcus_aureus,sample3.fasta,sample3_R1.fastq.gz,sample3_R2.fastq.gz
```
### 3. Running BigBacter (Performed each time):
> Note: Nextflow versions ≥ 23.10 require that you run `export NXF_SINGULARITY_HOME_MOUNT=true` when running with `-profile singularity` or Gubbins will fail ([issue 7](https://github.com/DOH-JDJ0303/bigbacter-nf/issues/7)).
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
> Note: This is the same command as in step 3 but with `-resume` and `--push true`. This will resume the run from step 3 and push the existing files to the BigBacter database. This allows you to check your results before pushing files to your database.
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
