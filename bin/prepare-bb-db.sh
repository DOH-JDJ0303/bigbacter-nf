#!/bin/bash

species=$(echo $1 | tr ' ' '_')
pp_db=${2%/}
outdir=${3%/}

# make directory structure
bb_db="${outdir}/${species}"
mkdir -p \
    ${bb_db}/pp_db/ \
    ${bb_db}/mash \
    ${bb_db}/clusters

# create initial taxa-level mash cache file
echo 0000000000 > ${bb_db}/mash/CACHE
touch ${bb_db}/mash/0000000000.msh

# prepare the PopPunk database
pp_db_name=${pp_db##*/}
files=$(ls ${pp_db})
for f in ${files}
do
    cp ${pp_db}/${f} 0000000000/0000000000${f:${#pp_db_name}}
done
tar -czvf 0000000000.tar.gz 0000000000/

mv 0000000000.tar.gz ${bb_db}/pp_db/

echo 0000000000 > ${bb_db}/pp_db/CACHE

# set up cluster structure
clusters=$(cat 0000000000/0000000000_clusters.csv | tr ',' '\t' | cut -f 2 | sort | uniq | grep -v "Cluster")
for c in ${clusters}
do
        clus=$(printf "%05d" ${c})
        mkdir -p \
            "${bb_db}/clusters/${clus}/snippy" \
            "${bb_db}/clusters/${clus}/mash" \
            "${bb_db}/clusters/${clus}/ref"
    
    # create initial cluster-level mash cache file and dummy sketch file
    echo 0000000000 > ${bb_db}/clusters/${clus}/mash/CACHE
    touch ${bb_db}/clusters/${clus}/mash/0000000000.msh
done


