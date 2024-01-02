#!/usr/bin/env Rscript

#---- LOAD PACKAGES ----#
library(tidyverse)
library(phangorn)
library(ggtree)

#---- LOAD ARGUMENTS ----#
args <- commandArgs(trailingOnly=TRUE)
tree_path <- args[1]
manifest_path <- args[2]



#---- LOAD TREE & CLEAN UP ----#
# load tree
tree <- read.tree(tree_path)
# clean up sample names
tree$tip.label <- str_remove_all(tree$tip.label, pattern = "'")
# set negative branch lengths to zero
if(sum(tree$edge.length < 0) > 0){
  tree$edge.length[tree$edge.length < 0] <- 0
  write.tree(tree, "corrected.nwk")
}
# determine if tree can be rooted
n_iso <- tree$tip.label %>% length()
if(n_iso > 3){
  tree <- midpoint(tree)
}

#---- LOAD MANIFEST FILE & CREATE METADATA----#
# load manifest file
df.manifest <- read.csv(manifest_path)
# create metadata
df.meta <- data.frame(sample = tree$tip.label, font_face = "plain", status = "OLD") %>%
  mutate(font_face = case_when(sample %in% df.manifest$sample ~ "bold",
                          TRUE ~ font_face),
         status = case_when(sample %in% df.manifest$sample ~ "NEW",
                          TRUE ~ status))

#---- PLOT TREE ----#
# initial plot
p_tree <- ggtree(tree)
# get sizing info
size_tree <- function(plot){
  # extract plot data
  data <- plot$data
  # determine limits
  ## max sample name length
  max_name <- nchar(data$label) %>% max(na.rm = T)
  if(max_name > 100){
    max_name <- 30
  }
  ## max x-coordinate
  max_x <- max(data$x)
  return(list(max_name,max_x))
}
maxs <- size_tree(p_tree) %>% unlist()
name_size=as.numeric(maxs[1])/15
x_max=as.numeric(maxs[2])*1.2
# re-plot tree with sizing info & metadata
p_tree <- p_tree%<+%df.meta+
  geom_tiplab(aes(fontface = font_face, color = status))+
  scale_color_manual(values = c("black", "darkgrey"), breaks = c("NEW", "OLD"))+
  theme(legend.position = "none")+
  xlim(0,as.numeric(x_max))
# save image
n_iso <- p_tree$data %>%
  drop_na() %>%
  nrow()
# set image dimensions
wdth <- n_iso/5
if(wdth < 10){
  wdth <- 10
}
hght=n_iso/5
if(hght < 10){
  hght <- 10
}

# save plot
ggsave(plot = p_tree, filename = paste0(tree_path,".jpg"), width = wdth, height = hght, dpi = 300, limitsize = F)
