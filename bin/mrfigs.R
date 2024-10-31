#!/usr/bin/env Rscript

version <- "1.0"

# mrfigs.R
# Author: Jared Johnson, jared.johnson@doh.wa.gov

# libraries
library(tidyverse)
library(rjson)

# inputs
args <- commandArgs(trailingOnly=TRUE)
mr_template <- args[1]
meta_file <- args[2]
summary_file <- args[3]
tree_file <- args[4]
snp_file <- args[5]
acc_file <- args[6]
prefix <- args[7]

# account for missing accessory genome matrix
if(!file.exists(acc_file)){acc_file <- 'empty.csv'; write.csv(data.frame(empty = "no data"), acc_file)}


# function for converting comma-separated lists into colon-separated lists for Microreact
comma2colon <- function(str) {
    str <- str %>%
      str_remove_all(pattern = " ") %>%
      str_replace_all(pattern = ",", replacement = ":")

    return(str)
}

## define output file names
meta.file.name <- paste0(prefix,"-summary.csv")
tree.file.name <- basename(tree_file)
snp.file.name <- basename(snp_file)
acc.file.name <- basename(acc_file)

# configure metadata
## load metadata - all we really need are the partitions
df.meta <- read_csv(meta_file) %>% 
  select(-STATUS)
## load cluster summary
df.summary <- read_tsv(summary_file) %>%
  mutate(STRONG_LINKAGE_SNIPPY = comma2colon(STRONG_LINKAGE_SNIPPY),
         STRONG_LINKAGE_GUBBINS = comma2colon(STRONG_LINKAGE_GUBBINS),
         INTER_LINKAGE_SNIPPY = comma2colon(INTER_LINKAGE_SNIPPY),
         INTER_LINKAGE_GUBBINS = comma2colon(INTER_LINKAGE_GUBBINS)) %>%
  merge(df.meta, by = "ID", all = T) %>%
  mutate_all(str_remove_all, pattern = " ")
## updated table
write.table(x=df.summary, quote = F, row.names = F, sep = ",", file = meta.file.name)

# create microreact file
## load template
mr.file <- fromJSON(file = mr_template)
## update project name
mr.file$meta$name <- prefix
## update metadata
mr.file$files$metadata$name <- meta.file.name
mr.file$files$metadata$blob <- readChar(meta.file.name, file.info(meta.file.name)$size)
## update tree file
mr.file$files$snp_tree$name <- tree.file.name
mr.file$files$snp_tree$blob <- readChar(tree_file, file.info(tree_file)$size)
## update SNP matrix
mr.file$files$snp_mat$name <- snp.file.name
mr.file$files$snp_mat$blob <- readChar(snp_file, file.info(snp_file)$size)
## update accessory matrix
mr.file$files$acc_mat$name <- acc.file.name
mr.file$files$acc_mat$blob <- readChar(acc_file, file.info(acc_file)$size)
## export microreact file
write(toJSON(mr.file), paste0(prefix,".microreact"))