import pandas as pd
import os
import argparse
import subprocess
from argparse import ArgumentParser
from typing import List

'''
 This script goes through MASH sketch results, recommends which reference to use for POPPunk db builds
 (if more) than one reference is provided. Input file for POPPunk db is generated including all
 provided assemblies that are within the ANI value (default 95% or 0.95).
 '''

parser = ArgumentParser()
parser.add_argument("--mash_table", dest="table",  default="results.txt", help="/path/to/input/mash/results.txt")
parser.add_argument("--ani", dest="ani",  default=95.0, help="ANI threshold as a percent. Default of 95% means ")

args = parser.parse_args() 
table = args.table
ani = float(args.ani)


def best_ref(df:pd.DataFrame) -> str:
    refs = df.reference.unique()
    best_ref = refs[0]
    best_ani = 0.0
    for ref in refs:
        cp = df.copy()
        cp = cp.loc[cp['reference'] == ref]
        min_ani = float(cp['ani'].min())
        if min_ani > best_ani:
            best_ani = min_ani
            best_ref = ref 
    return best_ref


def bad_ani_seqs(df:pd.DataFrame, ref:str) -> List:
    cp = df.copy()
    print(len(cp.index))
    cp = cp.loc[cp['reference'] == ref]
    cp_total = len(cp.index)
    cp = cp.loc[cp['ani'] >= ani]
    cp_keep = len(cp.index)
    pp_input = cp['sample'].tolist()
    print(f'{cp_keep}/{cp_total} assemblies are withing {ani} ANI of the reference genome')
    return pp_input


def make_pp_input(filelist:List, reference:str):
    ref_name = os.path.basename(reference).split("_genomic")[0]
    print(f'We recommend using{ref_name} as the reference and are preparing {ref_name}_pp-input.tsv as input for POPPunk')
    with open(ref_name + '_pp-input.tsv', mode='wt', encoding='utf-8') as myfile:
        for i in filelist:
            file_base = os.path.basename(i).split("_genomic")[0]
            myfile.write(file_base + '\t' + i + '\n')
        


if __name__ == "__main__":
    summary = pd.read_csv(table, \
                      names = ["reference", "sample", "ani"], sep='\t')
    ref_best = best_ref(summary)
    pp_input = bad_ani_seqs(summary, ref_best)
    make_pp_input(pp_input, ref_best)
