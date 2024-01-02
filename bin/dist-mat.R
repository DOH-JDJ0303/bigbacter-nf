#!/usr/bin/env Rscript

#---- LOAD PACKAGES ----#
library(tidyverse)
library(phangorn)
library(ggtree)

#---- LOAD ARGUMENTS ----#
args <- commandArgs(trailingOnly = TRUE)
dist_path <- args[1]
tree_path <- args[2]
manifest_path <- args[3]

#---- LOAD TREE & CLEAN UP ----#
tree <- read.tree(tree_path)
# clean up sample names
tree$tip.label <- str_remove_all(tree$tip.label, pattern = "'")
# set negative branch lengths to zero
tree$edge.length[tree$edge.length < 0] <- 0
# determine if tree can be rooted
n_iso <- tree$tip.label %>% length()
if(n_iso > 3){
  tree <- midpoint(tree)
}

#---- PLOT TREE FOR TIP ORDER ----#
# initial plot
p_tree <- ggtree(tree)
# get tip order
sample_order <- p_tree$data %>%
  subset(isTip == TRUE) %>%
  arrange(y) %>%
  .$label

#---- LOAD DISTANCE MATRIX & CLEAN UP ----#
df <- read_tsv(dist_path) %>%
  rename(ID1 = ...1) %>%
  pivot_longer(names_to = "ID2", values_to = "snps", cols = 2:ncol(.)) %>%
  mutate(ID1 = factor(ID1, levels = sample_order),
         ID2 = factor(ID2, levels = sample_order))

#---- LOAD MANIFEST FILE & CREATE METADATA----#
# load manifest file
df.manifest <- read.csv(manifest_path)
# create metadata
df.meta <- df %>%
  mutate(sample = ID1,
         font_face = "plain",
         font_color = "darkgrey") %>%
  select(sample, font_color, font_face) %>%
  unique() %>%
  mutate(font_face = case_when(sample %in% df.manifest$sample ~ "bold",
                          TRUE ~ font_face),
         font_color = case_when(sample %in% df.manifest$sample ~ "black",
                          TRUE ~ font_color)) %>%
  arrange(sample)

#---- PLOT DISTANCE MATRIX ----#
p_mat <- ggplot(df, aes(x=ID1, y=ID2, fill=snps))+
  geom_tile()+
  geom_text(data=filter(df, snps < 100), aes(label=snps))+
  theme(axis.text.x = element_text(angle=90, 
                                   face = df.meta$font_face, 
                                   color = df.meta$font_color),
        axis.text.y = element_text(face = df.meta$font_face, 
                                   color = df.meta$font_color))+
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
ggsave(filename = "snp-matrix.jpg", plot = p_mat, dpi = 300, width = wdth, height = hght, limitsize = F)
