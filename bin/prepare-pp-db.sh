#!/bin/bash

db=${1%/}
out=${2%/}

# make directory for current database
mkdir current_db

# extract files if needed
if [[ ${db} == *.tar.bz2 ]]
then
    echo "Supplied database is bzip2 compressed:"
    tar xjvf ${db} -C current_db
elif [[ ${db} == *.tar.gz ]]
then
    echo "Supplied database is gzip compressed:"
    tar xzvf ${db} -C current_db
else
    echo "Supplied database is not compressed"
    mv ${db} current_db/
fi
# set new database path
db="current_db/*"

# function for renaming files
rename_file () {
    old_db=${1%/}
    pattern=$2
    ext=$3
    new_db=$4
    optional=$5

    file=$(ls ${old_db}/${pattern})
    # check if the file is empty, otherwise copy
    if [[ -z ${file} ]]
    then
        if [[ "${optional}" == "false" ]]
        then
            echo "Error: No file with pattern ${pattern} found in the current database" && exit 1
        else
            echo "Optional file with pattern ${pattern} not found."
        fi
    else
        # check if the new database directory 
        if [[ ! -d ${new_db} ]]
        then
            echo -e "\nMaking new database directory: ${new_db}/"
            mkdir ${new_db}
        fi
        new_file=${new_db}/${new_db}${ext}
        echo "Renaming ${file} to ${new_file}"
        mv ${file} ${new_file}
    fi

}

# reformat database for BigBacter
new_name='0000000000'

# move and format files - https://poppunk.readthedocs.io/en/latest/model_distribution.html
## check for reference and full dataset files
if [ ! -f ${db}/*refs.h5 ] && [ ! -f ${db}/*.h5 ]
then
    echo "Error: It appears you are missing required files in your PopPUNK database."
    exit 1
fi

## Always required
rename_file ${db} '*[^_unword]_clusters.csv' '_clusters.csv' ${new_name} "false"

## Reference files
if [ -f ${db}/*refs.h5 ]
then
    echo -e "\nReference dataset detected.\n"
    rename_file ${db} '*refs.h5' '_refs.h5' ${new_name} "false"
    rename_file ${db} '*refs.dists.pkl' '_refs.dists.pkl' ${new_name} "false"
    rename_file ${db} '*refs.dists.npy' '_refs.dists.npy' ${new_name} "false"
    rename_file ${db} '*refs_fit.pkl' '_refs_fit.pkl' ${new_name} "false"
    rename_file ${db} '*refs_fit.npz' '_refs_fit.npz' ${new_name} "false"
    rename_file ${db} '*.refs' '.refs' ${new_name} "false"
    rename_file ${db} '*refs_graph.gt' '.refs_graph.gt' ${new_name} "false"
else
    echo -e "\nReference dataset not detected.\n"
fi

## Full dataset
if [ -f ${db}/*.h5 ]
then
    echo -e "\nFull dataset detected.\n"
    rename_file ${db} '*.h5' '.h5' ${new_name} "false"
    rename_file ${db} '*.dists.pkl' '.dist.pkl' ${new_name} "false"
    rename_file ${db} '*.dists.npy' '.dist.npy' ${new_name} "false"
    rename_file ${db} '*_fit.pkl' '_fit.pkl' ${new_name} "false"
    rename_file ${db} '*_fit.npz' '_fit.npz' ${new_name} "false"
    rename_file ${db} '*_graph.gt' '_graph.gt' ${new_name} "false"
else
    echo -e "\nFull dataset not detected.\n"
fi

# compress the new directory
echo -e "\nCompressing the new database:"
tar -czvf ${out}.tar.gz ${out}/
