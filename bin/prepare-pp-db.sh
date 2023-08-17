#!/bin/bash

db=${1%/}
out=${2%/}

# extract files if needed
if [[ ${db} == *.tar.bz2 ]]
then
    echo "Supplied database is bzip2 compressed:"
    tar xjvf ${db}
    db=${db%.tar.bz2}
elif [[ ${db} == *.tar.gz ]]
then
    echo "Supplied database is gzip compressed:"
    tar xzvf ${db}
    db=${db%.tar.gz}
else
    echo "Supplied database is not compressed"
fi

# prepare the PopPunk database
echo -e "\nPreparing the new database:"
mkdir ${out}
name=${db##*/}
for f in $(ls ${db})
do
    cur="${db}/${f}"
    new="${out}/${out}${f:${#name}}"
    echo "Renaming ${cur} to ${new}"
    cp ${cur} ${new}
done

# check for common file missing from PopPUNK database and fix
if [[ ! -f ${out}/${out}_graph.gt ]]
then
    if [[ -f ${out}/${out}.refs_graph.gt ]]
    then
        cp ${out}/${out}.refs_graph.gt ${out}/${out}_graph.gt
    else
        echo "PopPUNK database is missing required file: '${name}_graph.gt'"
    fi
fi

# compress the new directory
echo -e "\nCompressing the new database:"
tar -czvf ${out}.tar.gz ${out}/
