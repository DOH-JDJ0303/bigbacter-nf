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
    ext=$2
    new_db=$3
    optional=$4

    file=$(ls ${old_db}/*${ext} | head -n 1)
    # check if the file is empty, otherwise copy
    if [[ -z ${file} ]]
    then
        if [[ "${optional}" == "false" ]]
        then
            echo "Error: No file with extension ${ext} found in the current database" && exit 1
        else
            echo "Optional file with extension ${ext} not found."
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
rename_file ${db} '_clusters.csv' ${new_name} "false"

## Reference files
if [ -f ${db}/*.refs.h5 ]
then
    rename_file ${db} 'refs.h5' ${new_name} "false"
    rename_file ${db} 'refs.dists.pkl' ${new_name} "false"
    rename_file ${db} 'refs.dists.npy' ${new_name} "false"
    rename_file ${db} 'refs' ${new_name} "false"
    rename_file ${db} 'refs_graph.gt' ${new_name} "false"
fi

## Full dataset
if [ -f ${db}/*.h5 ]
then
    rename_file ${db} '.h5' ${new_name} "false"
    rename_file ${db} '.dists.pkl' ${new_name} "false"
    rename_file ${db} '.dists.npy' ${new_name} "false"
    rename_file ${db} '_fit.pkl' ${new_name} "false"
    rename_file ${db} '_fit.npz' ${new_name} "false"
    rename_file ${db} '_graph.gt' ${new_name} "false"
fi

# compress the new directory
echo -e "\nCompressing the new database:"
tar -czvf ${out}.tar.gz ${out}/
