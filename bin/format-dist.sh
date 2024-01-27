#!/bin/bash

# format-dist.sh v1.0.0
# Author: Jared Johnson, jared.johnson@doh.wa.gov

version="v1.0.0"

#----- HELP & VERSION -----#
# help message
if [ $1 == "-h" ] || [ $1 == "--help" ] || [ $1 == "-help" ]
then
    echo -e "$0 [dist_file] [tree_file] [dist_cols]" && exit 0
fi

# version
if [ $1 == "-v" ] || [ $1 == "--version" ] || [ $1 == "-version" ]
then
    echo -e ${version} && exit 0
fi

#---- INPUTS ----#
dist_file=$1
tree_file=$2
dist_cols=$3

#---- EXTRACT TIPS FROM TREE ----#
cat ${tree_file} | tr ',' '\n' | sed 's/:.*//g' | tr -d '(\t ' > tips.txt

#---- SUBSET DIST FILE ----#
# create header
echo -e "id1\tid2\tdist" > dist.formatted.txt
## check if dist file is compressed
if [[ ${dist_file} == *.gz ]]
then
    zcat ${dist_file} | cut -f ${dist_cols} | awk -F'\t' 'NR==FNR{a[$1]; next} ($1 in a) && ($2 in a)' tips.txt - >> dist.formatted.txt
else
    cat ${dist_file} | cut -f ${dist_cols} | awk -F'\t' 'NR==FNR{a[$1]; next} ($1 in a) && ($2 in a)' tips.txt - >> dist.formatted.txt
fi

#---- CLEAN UP ----#
#rm tips.txt

