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
    exclude=$3
    new_db=$4
    optional=$5

    file=$(ls ${old_db}/*${pattern} | grep -v "${exclude}")

    # check if the file is empty, otherwise copy
    if [[ -z ${file} ]]
    then
        if [[ "${optional}" == "false" ]]
        then
            echo "Error: No file with pattern ${pattern} found in the current database. See https://poppunk.readthedocs.io/en/latest/model_distribution.html for a list of required files." && exit 1
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
        new_file=${new_db}/${new_db}${pattern}
        echo "Renaming ${file} to ${new_file}"
        mv ${file} ${new_file}
    fi

}

# reformat database for BigBacter
new_name='0000000000'

# move and format files - https://poppunk.readthedocs.io/en/latest/model_distribution.html
# Optional files
rename_file ${db} '.refs' '' ${new_name} "true"

## Required files
rename_file ${db} '_clusters.csv' 'unword' ${new_name} "false"
rename_file ${db} '.h5' '\.refs\.' ${new_name} "false"
rename_file ${db} '_fit.npz' ' ' ${new_name} "false"
rename_file ${db} '_fit.pkl' ' ' ${new_name} "false"
rename_file ${db} '.dists.npy' '\.refs\.' ${new_name} "false"
rename_file ${db} '.dists.pkl' '\.refs\.' ${new_name} "false"
rename_file ${db} '_graph.gt' '\.refs\.' ${new_name} "false"

# compress the new directory
echo -e "\nCompressing the new database:"
tar -czvf ${out}.tar.gz ${out}/
