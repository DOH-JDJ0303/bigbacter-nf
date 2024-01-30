#!/usr/bin/env Rscript

#---- LOAD PACKAGES ----#
library(tidyverse)
library(phangorn)
library(ggtree)

#---- LOAD ARGUMENTS ----#
args <- commandArgs(trailingOnly=TRUE)
tree_path <- args[1]
manifest_path <- args[2]
tree_type <- args[3]
tree_method <- args[4]
tree_source <- args[5]
prefix <- args[6]
core_stats <- args[7]

#---- EXTRACT BASE FILENAME ----#
ext.type <- str_replace_all(tolower(tree_type), pattern = " ", replacement = "-")
ext.method <- sapply( tree_method, function(x)
                  paste(substr(strsplit(x, " ")[[1]], 1, 1), collapse="") )
filebase <- paste0(prefix,"_",ext.type,"_",ext.method,".",tree_source)
#---- LOAD TREE & CLEAN UP ----#
# load tree
tree <- read.tree(tree_path)
# clean up sample names
tree$tip.label <- str_remove_all(tree$tip.label, pattern = "'")
# set negative branch lengths to zero
if(sum(tree$edge.length < 0) > 0){
  tree$edge.length[tree$edge.length < 0] <- 0
  write.tree(tree, paste0(filebase,".corrected.nwk"))
}
# determine if tree can be rooted
n_iso <- tree$tip.label %>% length()
if(n_iso > 3){
  tree <- midpoint(tree)
}

#---- CREATE METADATA----#
# load list of new samples
new_samples <- read.csv(manifest_path) %>% .$sample
# create metadata
df.meta <- data.frame(sample = tree$tip.label, font_face = "plain", status = "OLD") %>%
  mutate(font_face = case_when(sample %in%new_samples ~ "bold",
                          TRUE ~ font_face),
         status = case_when(sample %in% new_samples ~ "NEW",
                          TRUE ~ status))

#---- RESCALE BRANCH LENGTHS (SNIPPY W/ ML ONLY) ----#
if(tree_source == "snippy" & tree_method == "Maximum Likelihood"){
  ref_length <- read_tsv(core_stats) %>%
    slice(1) %>%
    .$LENGTH
  tree$edge.length <- as.numeric(tree$edge.length) * as.numeric(ref_length)
  x_label <- "Estimated Nucleotide Substitutions"
  write.tree(tree, paste0(filebase,".scaled.nwk"))
}else if(tree_source == "gubbins"){
  x_label <- "Estimated Nucleotide Substitutions"
}else{
  x_label <- "Divergence"
}

#---- PLOT TREE ----#
# simplify bootstrapping values, if calculated
if(!is.null(tree$node.label)){
  tree$node.label <- as.numeric(tree$node.label) > 70
  tree$node.label[tree$node.label] <- NA
}

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
  theme_tree2(legend.position = "none")+
  xlim(0,as.numeric(x_max))+
  labs(x=x_label)
# add bootstrap values if calculated
if(!is.null(tree$node.label)){
  p_tree <- p_tree+
    geom_nodepoint(aes(shape = label), size = 1)+
    scale_shape_manual(values = c(8))
}
# add tree label
p_tree <- p_tree+
  ggtitle(paste0("Input: ",tree_type,"\nMethod: ",tree_method,"\nSource: ",str_to_title(tree_source)))
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
ggsave(plot = p_tree, filename = paste0(filebase,".jpg"), width = wdth, height = hght, dpi = 300, limitsize = F)
