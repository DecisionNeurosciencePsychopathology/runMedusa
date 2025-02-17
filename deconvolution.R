args <- commandArgs()

print(args)

subj <- args[6]
l1_nifti <- args[8]
run <- args[7]
decon_outdir <- args[9]
mask <- args[10]
#subj <- R.utils::cmdArg("subj")
#l1_nifti <- R.utils::cmdArg("l1_nifti")
#run <- R.utils::cmdArg("run")
#decon_outdir <- R.utils::cmdArg("decon_outdir")
#mask <- R.utils::cmdArg("mask")
#overwrite <- R.utils::cmdArg("overwrite")

l1_nifti <- file.path("/ix1/adombrovski/DNPL_DataMesh/Data/BSOC/data_fmriprep/fmriprep", paste0("sub-", subj), "func", l1_nifti)

print(run)
print(subj)
print(l1_nifti)
print(decon_outdir)
print(mask)

require(tidyverse)
require(foreach)
require(oro.nifti)
require(data.table)

setwd('/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa')
atlas_file <- file.path(getwd(), paste0(mask, ".nii.gz"))

#require("devtools")
library(fmri.pipeline)
source('/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/Medusa/fmri.pipeline/R/spm_funcs.R')

afnidir <- '/ihome/crc/install/afni/18.0.22/bin'
Sys.setenv(AFNIDIR=afnidir)

decon_beta <- 1 

metadata <- data.frame(TR = .6,
                       decon_beta = decon_beta)

### step 1. deconvolve signal
fmri.pipeline::voxelwise_deconvolution(l1_nifti, 
                        add_metadata=metadata, 
                        out_dir = decon_outdir, 
                        TR=metadata$TR,
                        atlas_files=atlas_file, 
                        decon_settings=list(nev_lr = .01, #neural events learning rate (default in algorithm)
                                            epsilon = .005, #convergence criterion (default)
                                            beta = decon_beta, #best from Bush 2015 update
                                            kernel = spm_hrf(metadata$TR)$hrf, #canonical SPM difference of gammas
                                            Nresample = 25),  
                        mask=NULL,
                        nprocs=1, 
                        save_original_ts=FALSE,  
                        out_file_expression=paste0("sub", subj, "_run", run),
                        #force_decon = TRUE
)

