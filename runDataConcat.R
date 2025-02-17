dir <- R.utils::cmdArg("dir")
sample <- R.utils::cmdArg("sample")
task <- R.utils::cmdArg("task")
mask <- R.utils::cmdArg("mask")

library(tidyverse)

setwd("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa")
source("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/dataConcat.R")

dataConcat(dir=dir, sample=sample, task=task, mask=mask)