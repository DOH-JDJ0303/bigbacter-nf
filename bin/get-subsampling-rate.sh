# this is only necessary because Nextflow doesn't like '\n'
# inputs
reads=$1
assembly=$2
max_depth=$3
## total bases in fastq files
read_b=$(zcat ${reads} | paste - - - - | cut -f 2 | wc -c | awk '{print $1*2}')
## total bases in reference genome
ref_b=$(cat ${assembly} | grep -v '>' | tr -d '\n\r\t ' | wc -c)
## subsampling rate
echo "${max_depth},${read_b},${ref_b}" | awk '{print $1 / ($2 / $3)}' > subsampling_rate