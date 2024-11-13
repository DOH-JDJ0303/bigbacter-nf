Generating input for PopPUNK DB build - example for _C. auris_ in a mamba environment called “smash” (`smash.yaml` file):
1. Determine NCBI Taxonomy ID for target species at [Datasets - NCBI - NLM](https://www.ncbi.nlm.nih.gov/datasets/).
2. Download relevant assemblies into “assembly” directory using tax_ID and get_taxon_genomes.sh. Example:

               bash get-taxon-genomes.sh 498019
3. Download potential reference genomes in to “reference_assembly” directory. Example:

               bash get-taxon-genomes.sh 498019 --reference
4. Generate MASH sketch of between assembly dataset and references(sketch size 10000 to match POPPunk default) – default threads=2 (8 in example). Example:

               bash calc_mash_ani.sh 8
4. Compare assemblies one or more reference and select a set of sequences based upon ANI threshold as a percent(default ANI >=0.95, or rather 95% when compared to a reference genome) to be used in the PopPUNK db.  This step also recommends reference to use based upon ANI to downloaded assembly files. Example:

               python mash_to_poppunk.py  –-ani 99

Output of this last step is the `<recommended_refseq>_pp-input.tsv` which is the `--r-files` input for pp DB builds. 
