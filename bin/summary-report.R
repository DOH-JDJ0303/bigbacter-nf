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
snippy_stats_file <- args[6]
snippy_dist_file <- args[7]
gubbins_stats_file <- args[8]
gubbins_dist_file <- args[9]
manifest_path <- args[10]
  
#---- SNIPPY STATS ----#
# load list of new samples
new_samples <- read.csv(manifest_path) %>% .$sample
# load core SNP stats and add status (new or old)
snippy_stats <- read_tsv(snippy_stats_file) %>%
  mutate(STATUS = "OLD")
snippy_stats[snippy_stats$ID %in% new_samples,]$STATUS <- "NEW"
# determine number of samples in cluster
n_iso <- snippy_stats %>%
  subset(ID != "Reference") %>%
  nrow()
n_iso_qc <- snippy_stats %>%
  subset(QUAL == "PASS" & ID != "Reference") %>%
  nrow()


#---- SNP DISTANCES ----#
snp_dist_metrics <- function(dist_file, source){
  # Load distance matrix - if the file exists
  if(file.exists(dist_file) & file.size(dist_file) != 0L){
    dist <- read_tsv(dist_file) %>%
      rename(ID = 1) %>%
      pivot_longer(names_to = "ID2", values_to = "snps", cols = 2:ncol(.))

    # summarize SNP distances
    dist_summary <- dist %>% 
      subset(ID != ID2) %>%
      group_by(ID) %>%
      summarise(paste(MEAN_SNP_DIST,source,sep="_") = round(mean(snps), digits = 0), paste(MIN_SNP_DIST,source,sep="_") = min(snps), paste(MAX_SNP_DIST,source,sep="_") = max(snps))
    
    # determine strong and intermediate
    get_linkages <- function(id, strong, intermediate){
      strong_link <- dist %>%
        subset(ID == id) %>%
        subset(ID != ID2) %>%
        subset(snps <= as.numeric(strong))
      if(nrow(strong_link > 0)){
          strong_result <- paste(strong_link$ID2, collapse = ", ")
          }else(strong_result <- "none")
      int_link <- dist %>%
        subset(ID == id) %>%
        subset(ID != ID2) %>%
        subset(snps > as.numeric(strong) & snps <= as.numeric(intermediate))
      if(nrow(int_link > 0)){
          int_result <- paste(int_link$ID2, collapse = ", ")
          }else(int_result <- "none")
      result <- data.frame("ID" = id, paste(STRONG_LINKAGE,source,sep="_") = strong_result, paste(INTER_LINKAGE,source,sep="_") = int_result)
      return(result)
    }
    
    core_linkages <- do.call(rbind, lapply(unique(dist$ID), FUN=get_linkages, strong=strong_linkage_cutoff, intermediate=intermediate_linkage_cutoff))

  }else{
    # make tables with message
    dist_summary <- snippy_stats %>%
      select(ID) %>%
      mutate(paste(MEAN_SNP_DIST,source,sep="_") = "not performed",
            paste(MIN_SNP_DIST,source,sep="_") = "not performed",
            paste(MAX_SNP_DIST,source,sep="_") = "not performed")

    core_linkages <- snippy_stats %>%
      select(ID) %>%
      mutate(paste(STRONG_LINKAGE,source,sep="_") = "not performed",
            paste(INTER_LINKAGE,source,sep="_") = "not performed")
  }

  # combine summary and core linkages
  snp_metrics <- merge(dist_summary, core_linkages, by = "ID")
  return(snp_metrics)
}

snp_metrics.snippy <- snp_dist_metrics(snippy_dist_file, "SNIPPY")
snp_metrics.gubbins <- snp_dist_metrics(gubbins_dist_file, "GUBBINS")

# combine all together and save
## combine all
summary <- snippy_stats %>%
  merge(snp_metrics.snippy, by = "ID", all.x = T) %>%
  merge(snp_metrics.gubbins, by = "ID", all.x = T) %>%
  mutate(RUN_ID = run_id,
         TAXA = taxa,
         CLUSTER = cluster,
         ISO_IN_CLUSTER = n_iso,
         ISO_PASS_QC = n_iso_qc,
         ) %>%
  select(ID, STATUS, QUAL, RUN_ID, TAXA, CLUSTER, ISO_IN_CLUSTER, ISO_PASS_QC, MEAN_SNP_DIST_SNIPPY, MIN_SNP_DIST_SNIPPY, MAX_SNP_DIST_SNIPPY, STRONG_LINKAGE_SNIPPY, INTER_LINKAGE_SNIPPY, MEAN_SNP_DIST_GUBBINS, MIN_SNP_DIST_GUBBINS, SNP_DIST_GUBBINS, STRONG_LINKAGE_GUBBINS, INTER_LINKAGE_GUBBINS, LENGTH, ALIGNED, UNALIGNED, VARIANT, HET, MASKED, LOWCOV, PER_GENFRAC, PER_LOWCOV, PER_HET)

## make file name
filename <- paste0(run_id,"-",taxa,"-",cluster,"-summary.tsv")
## write table
write.table(x = summary, file=filename, quote = F, sep = "\t", row.names = F)
