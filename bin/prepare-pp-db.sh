#!/bin/bash

db=${1%/}
name=${db##*/}

mkdir 00

files=$(ls ${db})
for f in ${files}
do
    cp ${db}/${f} 00/00${f:${#name}}
done

