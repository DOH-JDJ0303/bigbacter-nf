#!/usr/bin/env Rscript

# load packahes
library(tidyverse)
library(phangorn)
library(ggtree)

# load arguments
args <- commandArgs(trailingOnly=TRUE)

## load tree
tree_path <- args[1]
tree <- read.tree(tree_path)
# determine if tree can be rooted
n_iso <- tree$tip.label %>% length()
if(n_iso > 3){
  tree <- midpoint(tree)
}
## initial plot
p_tree <- ggtree(tree)
## get sizing info
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
## re-plot tree
p_tree <- p_tree+
  geom_tiplab()+ 
  xlim(0,as.numeric(x_max))
## save image
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
