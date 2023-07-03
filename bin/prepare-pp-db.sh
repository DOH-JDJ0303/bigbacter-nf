#!/bin/bash

species=$(echo $1 | tr ' ' '_')
pp_db=${2%/}
outdir=${1%/}

# make directory structure
bb_db=${outdir}/${species}
mkdir -p \
    ${species}/pp_db/ \
    ${species}/mash

# create initial taxa-level mash cache file
echo 0000000000 > ${species}/mash/CACHE

# prepare the PopPunk database
pp_db_name=${pp_db##*/}
cd ${species}/pp_db/
files=$(ls ${pp_db})
for f in ${files}
do
    cp ${pp_db}/${f} 0000000000/0000000000${f:${#pp_db_name}}
done
tar -czvf 0000000000.tar.gz 0000000000/
cd ../../

# set up cluster structure
clusters=$(cat ${pp_db_path}/${pp_db}_clusters.csv | tr ',' '\t' | cut -f 2 | sort | uniq | grep -v "Cluster")
for c in ${clusters}
do
    # make directories
    mkdir -p /
        ${bb_db}/clusters/${c}/snippy /
        ${bb_db}/clusters/${c}/mash /
        ${bb_db}/clusters/${c}/ref
    
    # create initial cluster-level mash cache file
    echo 0000000000 > ${bb_db}/clusters/${c}/mash/CACHE
done


