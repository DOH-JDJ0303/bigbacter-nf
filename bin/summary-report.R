#!/usr/bin/env Rscript

# load packages
library(tidyverse)

# load arguments
args <- commandArgs(trailingOnly = TRUE)
run_id <- args[1]
taxa <- args[2]
cluster <- args[3]
strong_linkage_cutoff <- args[4]
intermediate_linkage_cutoff <- args[5]
core_s_file <- args[6]
core_d_file <- args[7]

# load new samples
new_samples <- read_tsv("new_samples", col_names = F)
  
### CORE SNPS ###
# load core SNP stats
core_s <- read_tsv(core_s_file)
# determine number of samples in cluster (must pass all QC)
n_iso <- core_s %>%
  subset(QUAL == "PASS" & ID != "Reference") %>%
  nrow()

# Load distance matrix - if the file exists
if(file.exists(core_d_file)){
  core_d <- read_tsv(core_d_file) %>%
    rename(ID = ...1) %>%
    pivot_longer(names_to = "ID2", values_to = "snps", cols = 2:ncol(.))

  # summarize SNP distances
  core_d_summary <- core_d %>% 
    subset(ID != ID2) %>%
    group_by(ID) %>%
    summarise(MEAN_SNP_DIST = round(mean(snps), digits = 0), MIN_SNP_DIST = min(snps), MAX_SNP_DIST = max(snps))
  
  # determine strong and intermediate
  get_linkages <- function(id, strong, intermediate){
    strong_link <- core_d %>%
      subset(ID == id) %>%
      subset(ID != ID2) %>%
      subset(snps <= strong)
      if(nrow(strong_link > 0)){
        strong_result <- paste(strong_link$ID2, collapse = ", ")
        }else(strong_result <- "none")
    int_link <- core_d %>%
      subset(ID == id) %>%
      subset(ID != ID2) %>%
      subset(snps > strong & snps <= intermediate)
     if(nrow(int_link > 0)){
        int_result <- paste(int_link$ID2, collapse = ", ")
        }else(int_result <- "none")
    result <- data.frame("ID" = id, "STRONG_LINKAGE" = strong_result, "INTER_LINKAGE" = int_result)
    return(result)
  }
  
  core_linkages <- do.call(rbind, lapply(unique(core_d$ID), FUN=get_linkages, strong=strong_linkage_cutoff, intermediate=intermediate_linkage_cutoff))

}else{
  # make tables with error messages
  core_d_summary <- core_s %>%
    mutate(MEAN_SNP_DIST = "cannot calculate - core.dist missing",
           MIN_SNP_DIST = "cannot calculate - core.dist missing",
           MAX_SNP_DIST = "cannot calculate - core.dist missing") %>%
    select(ID, MEAN_SNP_DIST, MIN_SNP_DIST, MAX_SNP_DIST)
  
  core_linkages <- core_s %>%
    mutate(STRONG_LINKAGE = "cannot calculate - core.dist missing",
           INTER_LINKAGE = "cannot calculate - core.dist missing") %>%
    select(ID, STRONG_LINKAGE, INTER_LINKAGE)
}

# combine all together and save
## combine all
summary <- core_s %>%
  merge(core_d_summary, by = "ID", all.x = T) %>%
  merge(core_linkages, by = "ID", all.x = T) %>%
  mutate(RUN_ID = run_id,
         TAXA = taxa,
         CLUSTER = cluster,
         ISO_IN_CLUSTER = n_iso,
         ) %>%
  select(ID, QUAL, RUN_ID, TAXA, CLUSTER, ISO_IN_CLUSTER, MEAN_SNP_DIST, MIN_SNP_DIST, MAX_SNP_DIST, STRONG_LINKAGE, INTER_LINKAGE, LENGTH, ALIGNED, UNALIGNED, VARIANT, HET, MASKED, LOWCOV, PER_GENFRAC, PER_LOWCOV, PER_HET) %>%
  .[.$ID %in% new_samples,]
## make file name
filename <- paste0(run_id,"-",taxa,"-",cluster,"-summary.tsv")
## write table
write.table(x = summary, file=filename, quote = F, sep = "\t", row.names = F)
