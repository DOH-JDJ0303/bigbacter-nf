#!/bin/bash

#### VARIABLES ####
sample=$1
taxa=$2
dist=$3
db_info=$4

#### DETERMINE THE NEAREST NEIGHBOR ####
zcat ${dist} | awk 'BEGIN { OFS = "\t"} $1 != "Query" {print $1, $2, $5}'  > dist.txt
zcat ${dist} | awk 'BEGIN { OFS = "\t"} $1 != "Query" {print $2, $1, $5}'  >> dist.txt
nn=$(cat dist.txt | awk -v s=${sample} 'BEGIN { OFS = "\t"} $1 == s {print $2,$3}' | sort -rgk 2 | sed -n 1p | cut -f 1)
echo ${nn}

#### GET CLUSTER OF NEAREST NEIGHBOR ####
nn_c=$(cat ${db_info} | awk -v s=${nn} '$3 == s {print $2}')

#### SAVE ####
echo "${sample},${taxa},${nn_c}" > best_cluster.csv