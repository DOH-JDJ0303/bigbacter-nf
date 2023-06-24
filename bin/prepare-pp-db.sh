#!/bin/bash

db=${1%/}
name=${db##*/}

mkdir 0000000000

files=$(ls ${db})
for f in ${files}
do
    cp ${db}/${f} 0000000000/0000000000${f:${#name}}
done

