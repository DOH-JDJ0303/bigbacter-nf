#!/usr/bin/env Rscript

# load packages
library(tidyverse)
library(phangorn)

# load arguments
args <- commandArgs(trailingOnly = TRUE)
dist_file <- args[1]
tree_file <- args[2]

## load tree
tree_path <- args[1]
tree <- read.tree(tree_file)
# determine if tree can be rooted
n_iso <- tree$tip.label %>% length()
if(n_iso > 3){
  tree <- midpoint(tree)
}
# get tip order
sample_order <- tree$tip.label

# load distance matrix
df <- read_tsv(dist_file) %>%
  rename(ID1 = ...1) %>%
  pivot_longer(names_to = "ID2", values_to = "snps", cols = 2:ncol(.)) %>%
  mutate(ID1 = factor(ID1, levels = sample_order),
         ID2 = factor(ID2, levels = sample_order))
# plot matrix
p <- ggplot(df, aes(x=ID1, y=ID2, fill=snps))+
  geom_tile()+
  geom_text(data=filter(df, snps < 100), aes(label=snps))+
  theme(axis.text.x = element_text(angle=90))+
  scale_fill_gradient(low = "#009E73", high = "white")+
  labs(fill="")
# determine matrix dimensions
if(n_iso > 10){
  wdth <- 0.45*n_iso
  hght <- 0.4*n_iso
}else{
   wdth <- 10
   hght <- 8.5
}
# save figure
ggsave(filename = "snp-matrix.jpg", plot = p, dpi = 300, width = wdth, height = hght, limitsize = F)
