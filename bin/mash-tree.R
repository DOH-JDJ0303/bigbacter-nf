#!/usr/bin/env Rscript

# load packahes
library(tidyverse)
library(phangorn)

# load arguments
args <- commandArgs(trailingOnly=TRUE)

# load tree file
mash_file <- args[1]
mash.all <- read_tsv(mash_file, col_names = F, show_col_types = FALSE)
# create files name for output
tree_name <- str_sub(mash_file, end = -5)
# check if there are at least 3 observations - minimum for nj()
if(length(unique(mash.all$X1)) < 3){
  system(paste0("echo 'Must have 3 or more samples to create a neighbor joining tree'"))
}else{
  # clean up names
  mash.all$X1 <- str_remove_all(mash.all$X1, pattern = ".*/") %>%  str_remove_all(pattern = ".fa")
  mash.all$X2 <- str_remove_all(mash.all$X2, pattern = ".*/") %>%  str_remove_all(pattern = ".fa")
  # convert to matrix
  mash.all <- mash.all[,1:3] %>% 
    unique() %>% 
    spread(key = "X2", value = "X3") %>% column_to_rownames(var="X1") %>% 
    as.matrix()
  # create distance matrix
  dist <- dist(mash.all, method = "euclidean")
  # create tree and save
  tree <- nj(dist) %>% midpoint()
  write.tree(phy = tree, file = paste0(tree_name,".treefile"))
}
