#!/bin/bash

# mrfigs.sh v1.0
# Author: Jared Johnson, jared.johnson@doh.wa.gov

set -o pipefail

# check that jq is installed
if ! command -v jq &> /dev/null
then
    echo "This script requires 'jq'. Please make sure it is installed."
    exit 1
fi

# help message
if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "-help" ]] || [[ "$1" == "--help" ]]
then
    echo "mrfigs.sh [microreact template] [metadata file] [core SNP matrix] [core SNP tree] [accessory matrix]"
fi

# Inputs
TEMPLATE=$1
PREFIX=$2
META=$3
SNP_MAT=$4
SNP_TREE=$5
ACC_MAT=$6

#----- PREPAE FILES -----#
# Metadata
META_FILE=${META##./}

META_DATA=$(cat $META | tr '\t' ',' | awk -v ORS='\\n' '{print $0}')

# Core SNP Matrix
SNP_MAT_FILE=${SNP_MAT##./}
SNP_MAT_DATA=$(cat $SNP_MAT | tr '\t' ',' | awk -v ORS='\\n' '{print $0}')

# Core SNP Tree
SNP_TREE_FILE=${SNP_TREE##./}
SNP_TREE_DATA=$(cat $SNP_TREE | awk -v ORS='\\n' '{print $0}')

# Accessory Distance Matrix
ACC_MAT_FILE=${ACC_MAT##./}
ACC_MAT_DATA=$(cat $ACC_MAT | tr '\t' ',' | awk -v ORS='\\n' '{print $0}')

#----- UPDATE MICROREACT TEMPLATE -----#
cat $TEMPLATE | \
    jq --arg prefix $PREFIX '.meta.name = $prefix' | \
    jq --arg meta_data $META_DATA '.files.metadata.blob = $meta_data' | \
    jq --arg meta_file $META_FILE '.files.metadata.name = $meta_file' | \
    jq --arg snp_mat_data $SNP_MAT_DATA '.files.snp_mat.blob = $snp_mat_data' | \
    jq --arg snp_mat_file $SNP_MAT_FILE '.files.snp_mat.name = $snp_mat_file' | \
    jq --arg snp_tree_data $SNP_TREE_DATA '.files.snp_tree.blob = $snp_tree_data' | \
    jq --arg snp_tree_file $SNP_TREE_FILE '.files.snp_tree.name = $snp_tree_file' | \
    jq --arg acc_mat_data $ACC_MAT_DATA '.files.acc_mat.blob = $acc_mat_data' | \
    jq --arg acc_mat_file $ACC_MAT_FILE '.files.acc_mat.name = $acc_mat_file' | \
    sed 's/\\\\/\\/g' \
    > ${PREFIX}.microreact