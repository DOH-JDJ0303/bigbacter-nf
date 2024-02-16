#!/bin/bash

db=${1%/}

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
    alt=$3
    new_db=$4
    optional=$5

    # check full and ref version file paths
    echo -e "\nSearching for file with pattern '${pattern}':"
    main_file=$(ls ${old_db}/*${pattern} | grep -v "${alt}" 2> /dev/null)
    alt_file=$(ls ${old_db}/*${pattern} | grep "${alt}" 2> /dev/null)
    
    # Check if either the full version or ref version of the file exists and preferentially use the full version
    if [[ ! -z ${main_file} ]]
    then
        echo "File found!"
        file=${main_file}
        status="ok"
    elif [[ ! -z ${alt_file} ]]
    then
        echo "Alt file found!"
        file=${alt_file}
        status="ok"
    else
        if [ "${optional}" == "true" ]
        then
            echo "File not found but thats ok because it is optional."
            status="fail"
        else
            echo "\nError: No file with pattern ${pattern} found in the current database. See https://poppunk.readthedocs.io/en/latest/model_distribution.html for a list of required files." && exit 1
        fi
    fi

    # copy file if it was found and is not optional
    if [ ${status} == "ok" ]
    then
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
rename_file ${db} '.refs' ' ' ${new_name} "true"

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
tar -czvf ${new_name}.tar.gz ${new_name}/
