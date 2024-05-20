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
  
#---- MANIFEST ----#
# load list of new samples
new_samples <- read.csv(manifest_path) %>% .$sample

#---- STATS FILES ----#
# load Snippy SNP stats and add status (new or old)
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
# load Gubbins stats, if it exists
gubbins_stats <- snippy_stats %>%
    select(ID) %>%
    mutate(RECOMB = "not performed")
if(file.exists(gubbins_stats_file)){
  tmp <- read_tsv(gubbins_stats_file) %>%
      rename(ID = Node,
             RECOMB = 'Cumulative Bases in Recombinations') %>%
      select(ID, RECOMB)
  gubbins_stats <- gubbins_stats %>%
    filter(! ID %in% tmp$ID) %>%
    rbind(tmp)
}

#---- SNP DISTANCES ----#
snp_dist_metrics <- function(dist_file, source){
  # Load distance matrix - if the file exists
  if(file.exists(dist_file) & file.size(dist_file) != 0L){
    dist <- read_csv(dist_file) %>%
      rename(ID = 1) %>%
      pivot_longer(names_to = "ID2", values_to = "snps", cols = 2:ncol(.))

    # summarize SNP distances
    dist_summary <- dist %>% 
      subset(ID != ID2) %>%
      group_by(ID) %>%
      summarise(MEAN_SNP_DIST = round(mean(snps), digits = 0), MIN_SNP_DIST = min(snps), MAX_SNP_DIST = max(snps))
    
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
      result <- data.frame("ID" = id, STRONG_LINKAGE = strong_result, INTER_LINKAGE = int_result)
      return(result)
    }
    
    core_linkages <- do.call(rbind, lapply(unique(dist$ID), FUN=get_linkages, strong=strong_linkage_cutoff, intermediate=intermediate_linkage_cutoff))

  }else{
    # make tables with message
    dist_summary <- snippy_stats %>%
      select(ID) %>%
      mutate(MEAN_SNP_DIST = "not performed",
            MIN_SNP_DIST = "not performed",
            MAX_SNP_DIST = "not performed")

    core_linkages <- snippy_stats %>%
      select(ID) %>%
      mutate(STRONG_LINKAGE = "not performed",
             INTER_LINKAGE = "not performed")
  }

  # combine summary and core linkages
  snp_metrics <- merge(dist_summary, core_linkages, by = "ID")
  colnames(snp_metrics) <- c("ID",
                             paste("MEAN_SNP_DIST",source,sep="_"),
                             paste("MIN_SNP_DIST",source,sep="_"),
                             paste("MAX_SNP_DIST",source,sep="_"),
                             paste("STRONG_LINKAGE",source,sep="_"),
                             paste("INTER_LINKAGE",source,sep="_")
                            )
  return(snp_metrics)
}

snp_metrics.snippy <- snp_dist_metrics(snippy_dist_file, "SNIPPY")
snp_metrics.gubbins <- snp_dist_metrics(gubbins_dist_file, "GUBBINS")

# combine all together and save
## combine all
summary <- snippy_stats %>%
  merge(gubbins_stats) %>%
  merge(snp_metrics.snippy, by = "ID", all.x = T) %>%
  merge(snp_metrics.gubbins, by = "ID", all.x = T) %>%
  mutate(RUN_ID = run_id,
         TAXA = taxa,
         CLUSTER = cluster,
         ISO_IN_CLUSTER = n_iso,
         ISO_PASS_QC = n_iso_qc,
         ) %>%
  select(ID, STATUS, QUAL, RUN_ID, TAXA, CLUSTER, ISO_IN_CLUSTER, ISO_PASS_QC, MEAN_SNP_DIST_SNIPPY, MIN_SNP_DIST_SNIPPY, MAX_SNP_DIST_SNIPPY, STRONG_LINKAGE_SNIPPY, INTER_LINKAGE_SNIPPY, MEAN_SNP_DIST_GUBBINS, MIN_SNP_DIST_GUBBINS, MAX_SNP_DIST_GUBBINS, STRONG_LINKAGE_GUBBINS, INTER_LINKAGE_GUBBINS, LENGTH, ALIGNED, UNALIGNED, RECOMB, VARIANT, HET, MASKED, LOWCOV, PER_GENFRAC, PER_LOWCOV, PER_HET)

## make file name
filename <- paste0(run_id,"-",taxa,"-",cluster,"-summary.tsv")
## write table
write.table(x = summary, file=filename, quote = F, sep = "\t", row.names = F)
