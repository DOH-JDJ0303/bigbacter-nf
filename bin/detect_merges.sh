#!/bin/bash

# detect_merges.sh v1.1.0
# Author: Jared Johnson, jared.johnson@doh.wa.gov

version="v1.0.0"

# inputs
old_db=$1
new_db=$2

#----- HELP & VERSION -----#
# help message
if [[ ${old_db} == "-h" ]] || [[ ${old_db} == "--help" ]] || [[ ${old_db} == "-help" ]] || [[ ${old_db} == "" ]]
then
    echo -e "detect_merges.sh [path/to/old/*_cluster.csv] [path/to/new/*_cluster.csv]" && exit 0
fi

# version
if [[ ${old_db} == "-v" ]] || [[ ${old_db} == "--version" ]] || [[ ${old_db} == "-version" ]]
then
    echo -e ${version} && exit 0
fi

# make tmp dir
mkdir tmp

# get list of new samples
cat ${old_db} | cut -f 1 -d ',' | grep '_' | sort > tmp/old_samples.txt
cat ${new_db} | cut -f 1 -d ',' | grep '_' | sort > tmp/new_samples.txt
new_samples=$(comm -13 tmp/old_samples.txt tmp/new_samples.txt | tr '\n' '@' | sed 's/^/@/g')

# get list of newly merged clusters - if any
cat ${old_db} | cut -f 2 -d ',' | grep '_' | sort | uniq > tmp/old_merge.txt
cat ${new_db} | cut -f 2 -d ',' | grep '_' | sort | uniq > tmp/new_merge.txt
new_merge=$(comm -13 tmp/old_merge.txt tmp/new_merge.txt | sort | uniq)

# clean up intermediate files
rm -r tmp

# print results
if [[ ${new_merge} != '' ]]
then
    echo -e "ERROR: Uh oh! One or more samples has caused one or more PopPUNK clusters to merge. \nPlease see https://github.com/DOH-JDJ0303/bigbacter-nf for more information about how to proceed. \nIsolates that may have caused these merges are summarized below."
    for c in ${new_merge}
    do
        echo -e "\nMerged cluster ${c}:"
        for s in $(cat ${new_db} | grep ${c} | cut -f '1' -d ',')
        do
            if [[ ${new_samples} == *"@${s}@"* ]]
            then
                echo ${s}
            fi
        done
    done
    exit 1
else
   echo "No new merged clusters. You are free to proceed! :)"
fi