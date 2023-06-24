#!/bin/bash 

pp_db_path=${1%/}
pp_db=${pp_db_path##*/}
species=$2

# get a list of unique clusters
clusters=$(cat ${pp_db_path}/${pp_db}_clusters.csv | tr ',' '\t' | cut -f 2 | sort | uniq | grep -v "Cluster")
# make initial cluster directory
mkdir clusters
# for every cluster, pick a reference, download it from NCBI, and create a new directory structure
for c in ${clusters}
do
    # select a reference
    row=$(cat ${pp_db_path}/${pp_db}_clusters.csv | tr ',' '\t' | awk -v c=${c} '$2 == c {print $0}' | head -n 1 )
    ref=$(echo ${row} | cut -d ' ' -f 1)
    clus=$(printf "%05d" ${c})
    # make directory structure
    mkdir -p clusters/${clus}/ref/ clusters/${clus}/snippy/ clusters/${clus}/mash
    # download the genome and clean up
    datasets download genome accession ${ref}
    unzip ncbi_dataset.zip
    mv ncbi_dataset/data/*/*.fna clusters/${clus}/ref/${species}-${clus}-ref.fa
    rm -r ncbi_dataset* README.md
    # create the initial Mash sketch file - per clusters
    mash sketch -o clusters/${clus}/mash/0 clusters/${clus}/ref/*.fa
    echo '0000000000' >  clusters/${clus}/mash/CACHE
done

# make mash sketch file for species
mkdir mash
echo "0000000000" > mash/CACHE
mash sketch -o mash/0000000000 clusters/*/ref/*
