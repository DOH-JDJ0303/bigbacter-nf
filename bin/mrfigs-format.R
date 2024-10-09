#!/usr/bin/env Rscript

# libraries
library(tidyverse)

# inputs
args <- commandArgs(trailingOnly=TRUE)
meta_file <- args[1]
summary_file <- args[2]
outfile <- args[3]

# function for adding quotes
unfudge <- function(str) {
    str <- str %>%
      str_remove_all(pattern = " ") %>%
      str_replace_all(pattern = ",", replacement = ":")

    return(paste0("'",str,"'"))
}
meta <- read_csv(meta_file) %>% 
  select(-STATUS)

summary <- read_tsv(summary_file) %>%
  mutate(STRONG_LINKAGE_SNIPPY = unfudge(STRONG_LINKAGE_SNIPPY),
         STRONG_LINKAGE_GUBBINS = unfudge(STRONG_LINKAGE_GUBBINS),
         INTER_LINKAGE_SNIPPY = unfudge(INTER_LINKAGE_SNIPPY),
         INTER_LINKAGE_GUBBINS = unfudge(INTER_LINKAGE_GUBBINS))

merged <- merge(meta, summary, by = "ID", all = T)

write.csv(x = merged, file = outfile, quote = F, row.names = F)