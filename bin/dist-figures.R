#!/usr/bin/env Rscript

#----- LOAD PACKAGES -----#
library(tidyverse)
library(phangorn)
library(ggtree)

#---- LOAD ARGUMENTS ----#
args <- commandArgs(trailingOnly = T)
dist_path <- args[1]
tree_path <- args[2]
manifest_path <- args[3]
input_format <- args[4] # 'long' or 'wide'
input_type <- args[5] # 'SNP' or 'Accessory'
input_source <- args[6]
threshold <- args[7] # 100 or 1
prefix <- args[8] # output prefix

#---- LOAD DISTANCE MATRIX & CLEAN UP ----#
if(input_format == "wide"){
  # create wide format
  df.wide <- read_tsv(dist_path) %>%
    rename('null' = 1)
  # create long format
  df.long <- read_tsv(dist_path) %>%
    rename(ID1 = 1) %>%
    pivot_longer(names_to = "ID2", values_to = "dist", cols = 2:ncol(.)) %>%
    drop_na()
  # set plot data to long format
  df <- df.long
}else if(input_format == "long"){
  # create long format
  ## create upper triangle
  upper <- read_tsv(dist_path) %>%
    rename(ID1 = 1,
           ID2 = 2,
           dist = 3) %>%
    select(1:3)
  ## create diagonal
  diag <- data.frame(ID1 = unique(c(upper$ID1,upper$ID2))) %>%
    mutate(ID2 = ID1,
           dist = rep(0, nrow(.)))
  ## create lower triangle
  lower <- upper %>%
    rename(id1 = ID1,
           id2 = ID2) %>%
    mutate(ID1 = id2,
           ID2 = id1) %>%
    select(ID1, ID2, dist)
  ## combine and filter unique
  df.long <- do.call(rbind, list(upper, diag, lower)) %>%
    unique() %>%
    drop_na()
  # create wide format
  df.wide <- df.long %>%
    pivot_wider(names_from = ID2, values_from = dist) %>%
    rename('null' = ID1)
  # set plot data to long format
  df <- df.long
}else{
  cat("\nError: Please specifiy either 'long' or 'wide' input format.\n" )
  quit(status=1)
}

#---- ARRANGE BY TREE TIP ORDER (IF TREE PROVIDED) ----#
if(file.exists(tree_path)){
  # load tree
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
  # plot tree
  p_tree <- ggtree(tree)
  # get tip order
  sample_order <- p_tree$data %>%
    subset(isTip == TRUE) %>%
    arrange(y) %>%
    .$label
  # set factor level
  df <- df %>%
    mutate(ID1 = factor(ID1, levels = sample_order),
           ID2 = factor(ID2, levels = sample_order))

}

#---- CREATE METADATA----#
# load list of new samples
new_samples <- read.csv(manifest_path) %>% .$sample
# create metadata
df.meta <- df %>%
  mutate(sample = ID1,
         font_face = "plain",
         font_color = "darkgrey") %>%
  select(sample, font_color, font_face) %>%
  unique() %>%
  mutate(font_face = case_when(sample %in% new_samples ~ "bold",
                          TRUE ~ font_face),
         font_color = case_when(sample %in% new_samples ~ "black",
                          TRUE ~ font_color)) %>%
  arrange(sample)

#---- PLOT DISTANCE MATRIX ----#
p_mat <- ggplot(df, aes(x=ID1, y=ID2, fill=dist))+
  geom_tile()+
  geom_text(data=filter(df, dist < threshold), aes(label=dist))+
  theme(axis.text.x = element_text(angle=90, 
                                   face = df.meta$font_face, 
                                   color = df.meta$font_color),
        axis.text.y = element_text(face = df.meta$font_face, 
                                   color = df.meta$font_color))+
  scale_fill_gradient(low = "#009E73", high = "white")+
  labs(fill=paste(input_type,"Distance"))
# determine matrix dimensions
if(n_iso > 10){
  wdth <- 0.45*n_iso
  hght <- 0.4*n_iso
}else{
   wdth <- 10
   hght <- 8.5
}

#---- SAVE FILES ----#
# base filename
ext.type <- str_replace_all(tolower(input_type), pattern = " ", replacement = "-")
basename <- paste0(prefix,"-",ext.type,".",input_source)
# plot image
ggsave(filename = paste0(basename,"-dist.jpg"), plot = p_mat, dpi = 300, width = wdth, height = hght, limitsize = F)
# distance matrix
## long format
write.csv(x = df.long, file = paste0(basename,"-dist-long.csv"), quote = F, row.names = F)
## wide format
write.csv(x = df.wide, file = paste0(basename,"-dist-wide.csv"), quote = F, row.names = F)