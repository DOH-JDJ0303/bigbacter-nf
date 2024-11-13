#!/bin/bash


datasets download genome taxon "$@"
unzip ncbi_dataset*
if [[ "$@" == *"--reference"* ]]; then
  directory="reference_genomes"
else
  directory="assemblies"
fi
mkdir $directory
find ncbi_dataset*/data/* -name '*.*' -type f | xargs mv --target-directory=$directory
rm -r ncbi_dataset* README.md
