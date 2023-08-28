#!/bin/bash

# inputs
id=$1
min_gf=$2
max_ht=$3
max_lc=$4

# stats
length=$(cat ${id}/snps.aligned.fa | grep -v ">" | tr -d '\t\r\n ' | wc -c)
aligned=$(cat ${id}/snps.aligned.fa | grep -Eo 'A|T|C|G' | wc -l)
unaligned=$(cat ${id}/snps.aligned.fa | grep -o '-' | wc -l)
variant=$(cat ${id}/snps.txt | grep "VariantTotal" | cut -f 2)
het=$(cat ${id}/snps.aligned.fa | grep -o "n" | wc -l)
masked=$(cat ${id}/snps.aligned.fa | grep -o "X" | wc -l)
low_cov=$(cat ${id}/snps.aligned.fa | grep -o "N" | wc -l)

# result
echo -e "${id}\t${length}\t${aligned}\t${unaligned}\t${variant}\t${het}\t${masked}\t${low_cov}" | awk '{genfrac = 100*($3)/$2; plow = 100*$8/$2; phet = 100*$6/$2; print $0, genfrac, phet, plow}' | awk -v g=${min_gf} -v l=${max_lc} -v h=${max_ht} '{if($9 < g || $11 > h || $10 > l) print $0, "FAIL"; else print $0, "PASS"}'
