[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/bigbacter/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Nextflow Tower](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Nextflow%20Tower-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/nf-core/bigbacter)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23bigbacter-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/bigbacter)[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

BigBacter is a pipeline aimed at simplifying bacterial genomic surviellance. 
This is accomplished by:
1) pre-clustering isolates into closely related subtypes prior to phylogenetic analysis
2) automatically selecting subtype-specific reference genomes for SNP analysis
3) identifying and excluding low quality samples
4) archiving samples and automatically including them when samples of the same subtype are identified
5) re-using archived alignment files, thus dramatically increasing the speed of SNP analysis
6) automatically generating figures needed for phylogenetic analysis (i.e., trees and SNP matricies)

It is best practice to run samples through a generic bacterial analysis pipeline, such as [PHoeNIx](https://github.com/CDCgov/phoenix), [Bactopia](https://github.com/bactopia/bactopia), or [TheiaProk](https://github.com/theiagen/public_health_bioinformatics), prior to running BigBacter. This will generate the necessary input files (trimmed reads and an assembly), in addition to providing an initial QC check and species classification. BigBacter also requires a species-specific PopPUNK [database](https://www.bacpop.org/poppunk/). If a PopPUNK database does not exist for the species of interest it can be created following the instructions provided [here](https://poppunk.readthedocs.io/en/latest/index.html). A summary of the required inputs is provided below:
1) Species-level classification.
2) Trimmed/QC filtered reads.
3) A high quality assembly (multiple contigs ok).
4) A PopPUNK database for the species of interest.

## Usage

> **Note**
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how
> to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline)
> with `-profile test` before running the workflow on actual data.

### Step 1 - Download or create the PopPUNK database
> **Note:** Steps 1-3 only need to be run once for each species.

Download your species specific PopPUNK databases from [here](https://www.bacpop.org/poppunk/) or create one followig the PopPUNK [manual](https://poppunk.readthedocs.io/en/latest/index.html).

### Step 2. Prepare a samplesheet containing the database information
PopPUNK databases are added to your BigBacter database using a samplesheet containing the species name and the path to the PopPUNK database (see below). This only has to be peformed once for each species! The database can be supplied as gzip or bzip compressed tar files or as the uncompressed directory. The PopPUNK database will be reformatted and saved to a taxa-specific directory within your BigBacter database (e.g., `$PWD/db/Acinetobacter_baumannii/pp_db/0000000000.tar.gz`). An example of this samplesheet using bzip, gzip, and uncompressed PopPUNK databases is shown below.

`pp_db_list.csv`:
```csv
taxa,pp_db
Acinetobacter_baumannii,abaumannii_db.tar.gz
Escherichia_coli,ecoli_db.tar.bz2
Staphylococcus_aureus,staph_db/
```
### Step 3. Run the BigBacter `PREPARE_DB` workflow to add the PopPUNK database to your BigBacter database:
Run the command below using the the samplesheet created above, changing inputs where appropriate. 
> **Note:** It is recommended that all database files be saved to a common directory (i.e., the BigBacter database). BigBacter will automatically split these files into taxa-specific directories and update them each time the pipeline is run.

```bash
nextflow run https://github.com/DOH-JDJ0303/bigbacter-nf \
   -entry PREPARE_DB \
   --input pp_db_list.csv \
   --db $PWD/db
```

### Step 4. Prepare a samplesheet containing sample information
> **Note:** Steps 4-5 are run each time new samples are available.

`samplesheet.csv`:
```csv
sample,taxa,assembly,fastq_1,fastq_2
sample1,Acinetobacter_baumannii,sample1.fasta,sample1_R1.fastq.gz,sample1_R2.fastq.gz
sample2,Escherichia_coli,sample2.fasta,sample2_R1.fastq.gz,sample2_R2.fastq.gz
sample3,Staphylococcus_aureus,sample3.fasta,sample3_R1.fastq.gz,sample3_R2.fastq.gz
```

### Step 5. Run the main BigBacter workflow:
```bash
nextflow run https://github.com/DOH-JDJ0303/bigbacter-nf \
   --input samplesheet.csv \
   --outdir $PWD/results \
   --db $PWD/db
```

> **Warning:**
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those
> provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

For more details, please refer to the [usage documentation](https://nf-co.re/bigbacter/usage) and the [parameter documentation](https://nf-co.re/bigbacter/parameters).

## Pipeline output

To be updated

## Credits

nf-core/bigbacter was originally written by Jared Johnson.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#bigbacter` channel](https://nfcore.slack.com/channels/bigbacter) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use  nf-core/bigbacter for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
