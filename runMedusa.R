#!/ihome/crc/install/gcc-12.2.0/r/4.4.0/bin/Rscript

afnidir <- '/ihome/crc/install/afni/18.0.22/bin'
Sys.setenv(AFNIDIR=afnidir)

# load argparse
library(argparse)

# create the argparser
parser <- ArgumentParser(description='Run Medusa.')
parser$add_argument('--process', help="Deconvolution, alignment, or concatenation.", required=TRUE)
parser$add_argument('--repo', help="Full path to runMedusa repo.", default="/bgfs/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa", required=TRUE)
parser$add_argument('--get_files', help="TRUE or FALSE. Whether or not to run the getFiles function to generate a CSV of run level NIfTI files for deconvolution.", required=FALSE, default=FALSE)
parser$add_argument('--overwrite', help="TRUE or FALSE. Defaults to FALSE.", required=FALSE, default=FALSE)
parser$add_argument('--mask', help="Supported masks: vmPFC, hippocampus (submits 2 jobs per run for HC-L and HC-R), whole brain (444 parcellation)", required=TRUE)
parser$add_argument('--subj', help="Used to specify which subjects to execute over. If NULL, will process entire sample.", default=NULL, nargs='+', required=FALSE)
parser$add_argument('--sample', help="Supported samples: BSOCIAL, EXPLORE.", required=TRUE)
parser$add_argument('--task', help="Supported tasks: Clock (BSOCIAL, Explore), Trust (BSOCIAL).", required=TRUE)
parsed_args <- parser$parse_args()

# source internal functions
source(file.path(parsed_args$repo, "getFiles.R"))
source(file.path(parsed_args$repo, "dataConcat.R"))

# print statements for command line
print("Process:")
print(parsed_args$process)
print("Mask:")
print(parsed_args$mask)
print("Subjects:")
print(parsed_args$subj)
print("Sample:")
print(paste(parsed_args$sample, parsed_args$task))

# load tidyverse
library(tidyverse)
setwd("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa")

# getFiles
if (parsed_args$get_files == TRUE) {
    sub_df <- getFiles(sample=parsed_args$sample, task=parsed_args$task, write=T)
} else if (parsed_args$get_files == FALSE & parsed_args$process == "deconvolution") {
    if (parsed_args$sample == "explore") {
        run_level_niftis <- read.csv('explore_clock.csv')
    } else if (parsed_args$sample == "bsocial") {
        if (parsed_args$task == "clock") {
            run_level_niftis <- read.csv('bsocial_clock.csv')
        }
        if (parsed_args$task == "trust") {
            run_level_niftis <- read.csv('bsocial_trust.csv')
        }
    }
}

# decon outdir
decon_outdir <- file.path(parsed_args$repo, "medusaPreanalyzed", parsed_args$task, parsed_args$sample)
task <- parsed_args$task
sample <- parsed_args$sample
medusa_preanalyzed <- file.path(parsed_args$repo, "medusaPreanalyzed")

# mask
if (parsed_args$mask == "hippocampus" | parsed_args$mask == "HC" | parsed_args$mask == "hc") {
    mask_list <- c(paste0(parsed_args$sample, "_", "hc_l"), paste0(parsed_args$sample, "_", "hc_r"))
} else if (parsed_args$mask == "vmpfc" | parsed_args$mask == "vmPFC"){
    mask <- paste0(parsed_args$sample, "_", "vmPFC")
} else if (parsed_args$mask == "wb" | parsed_args$mask == "whole brain" | parsed_args$mask == "WB"){
    mask <- paste0(parsed_args$sample, "_", "wholebrain_A")
} else if (parsed_args$mask == "trust" ){
    mask <- paste0(parsed_args$sample, "_", "trust_brainmask")
} else if (parsed_args$mask == "dan_redo" ){
    mask <- "bsocial_dan"
} else if (parsed_args$mask == "200Parcel_7Network_V1_M1"){
	mask <- "explore_clock_Schaefer2018_200Parcel_7Network_V1_M1"
} else if (parsed_args$mask == 'Trust_hippocampus'){
	mask_list <- c('trust-transformed-hc-l.nii.gz','trust-transformed-hc-r.nii.gz')
} else {
    mask <- paste0(parsed_args$sample, "_", parsed_args$mask)
}

# data concatenation
if (parsed_args$process == "concatenation") {
    #dataConcat(dir=medusa_preanalyzed, sample=sample, task=task, mask=mask)
    system(paste("sbatch -p htc -N 1 --mem 40g -n 1 -t 00:30:00 -c 1 --wrap 'source ~/.bashrc; Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/runDataConcat.R --dir", medusa_preanalyzed, "--sample", sample, "--task", task, "--mask", mask, "'"))
}

# subset run level niftis using id list (if given)
if (parsed_args$process == "deconvolution") {
    if (length(parsed_args$subj) >= 1) {
    if (parsed_args$task == "trust") {
        subjects <- run_level_niftis %>%
            filter(id %in% parsed_args$subj)
    } else {
        subjects <- run_level_niftis %>%
            filter(id %in% parsed_args$subj)
    }
    } else if (is.null(parsed_args$subj)) {
        subjects <- run_level_niftis
        subjects <- subjects %>%
            filter(!is.na(nifti))
    }
}

# deconvolution
if (parsed_args$process == "deconvolution") {
    for (i in 1:nrow(subjects)) {
        subj = subjects$id[i]
        nifti = subjects$nifti[i]
        if (parsed_args$sample == "bsocial") {
            run = subjects$run[i]
        } else {
            run = str_extract(str_extract(nifti, pattern="run-[0-9]"), pattern="[0-9]")
        }
        if (exists("mask_list")) {
            for (k in 1:length(mask_list)) {
                mask <- mask_list[k]
                d_file = file.path(decon_outdir, mask, "deconvolved", paste0("sub", subj, "_run", run, "_deconvolved.csv.gz"))
                if (!file.exists(d_file) & !is.na(nifti)) {
                    print(subj)
                    print(run)
                    print(mask)
                    system(paste("sbatch -p htc -N 1 --mem 20g -n 1 -t 23:00:00 -c 1 --wrap 'source ~/.bashrc; Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/deconvolution.R --subj", subj, "--run", run, "--decon_outdir", decon_outdir, "--mask", mask, "--l1_nifti", nifti, "'"))
                } else {
                    print(paste("Subject", subj, "run", run, "is already deconvolved with", mask, "or there is no NIFTI for this run."))
                }
            }
        } else {
            d_file = file.path(decon_outdir, mask, "deconvolved", paste0("sub", subj, "_run", run, "_deconvolved.csv.gz"))
            if ((!file.exists(d_file) & !is.na(nifti))) {
                if (mask==paste0(parsed_args$sample, "_", "trust_brainmask")) {
                    print("Creating sbatch script.")
                    setwd("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/logs2")
                    file.create(file.path(getwd(), paste0(subj, ".txt")))
                    fileconn <- file.path(getwd(), paste0(subj, ".txt"))
                    writeLines(c("#!/bin/bash","#SBATCH --partition=htc","#SBATCH --nodes=1","#SBATCH --mem=40g","#SBATCH --ntasks=1","#SBATCH --time=4-00:00:00", "#SBATCH --cpus-per-task=1",paste("Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/deconvolution.R", subj, run, nifti, decon_outdir, mask)), fileconn)
                    print("Submitting whole brain job with increased memory allocation.")
                    system(paste("sbatch", fileconn))
                    #system(paste("sbatch -p htc -N 1 --mem 40g -n 1 -t 4-00:00:00 -c 1 --wrap 'Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/deconvolution.R --subj", subj, "--run", run, "--decon_outdir", decon_outdir, "--mask", mask, "--l1_nifti", nifti, "'"))
                    #system(paste("sbatch -p htc -N 1 --mem 40g -n 1 -t 4-00:00:00 -c 1 --wrap 'Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/CLIarguments.R", subj, run, decon_outdir, mask, paste0(nifti, "'")))
                    #system(paste("Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/CLIarguments.R", subj, run, nifti, decon_outdir, mask))
                } else {
                    print("Creating sbatch script.")
                    setwd("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/logs3")
                    file.create(file.path(getwd(), paste0(subj, run, ".txt")))
                    fileconn <- file.path(getwd(), paste0(subj, run, ".txt"))
                    writeLines(c("#!/bin/bash","#SBATCH --partition=htc","#SBATCH --nodes=1","#SBATCH --mem=30g","#SBATCH --ntasks=1","#SBATCH --time=1-00:00:00", "#SBATCH --cpus-per-task=1",paste("Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/deconvolution.R", subj, run, nifti, decon_outdir, mask)), fileconn)
                    print("Submitting job.")
                    system(paste("sbatch", fileconn))
                    #system(paste("sbatch -p htc -N 1 --mem 20g -n 1 -t 23:00:00 -c 1 --wrap 'source ~/.bashrc; Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/deconvolution.R --subj", subj, "--run", run, "--decon_outdir", decon_outdir, "--mask", mask, "--overwrite", parsed_args$overwrite, "--l1_nifti", nifti, "'"))
                }
            } else {
                print(paste("Subject", subj, "run", run, "is already deconvolved or there is no NIFTI for this run."))
            }
        }
    }
}

# alignment
if (parsed_args$process == "alignment") {
    if (exists("mask_list")) {
        for (k in 1:length(mask_list)) {
            mask <- mask_list[k]
            d_files <- list.files(file.path(decon_outdir, mask, "deconvolved"), full.names=T)
            if (length(parsed_args$subj) >= 1) {
                string <- do.call(paste, c(as.list(parsed_args$subj), sep = "|"))
                d_files <- d_files[grep(string, d_files)]
            }
            for (i in 1:length(d_files)) {
                file_path <- d_files[i]
                subj <- gsub("sub", "", str_extract(file_path, pattern="sub[0-9]*"))
                run <- str_extract(str_extract(file_path, pattern="run[0-9]"), pattern="[0-9]")
                feedback_out <- file.path(decon_outdir, mask, "interpolated", "feedback_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz"))
                clock_out <- file.path(decon_outdir, mask, "interpolated", "clock_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz"))
                if (!file.exists(feedback_out) | !file.exists(clock_out)) {
                    print(paste("Submitting batch job for subject", subj, "run", run, "using mask", mask))
                    system(paste("sbatch -p htc -N 1 --mem 20g -n 1 -t 00:30:00 -c 1 --wrap 'source ~/.bashrc; Rscript /bgfs/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/alignment.R --subj", subj, "--run", run, "--decon_outdir", decon_outdir, "--mask", mask, "--sample", sample, "--task", task, "--d_file", file_path, "'"))
                } else {
                    print(paste("Subject", subj, "run", run, "is already done."))
                }
            }
        }
    } else {
        d_files <- list.files(file.path(decon_outdir, mask, "deconvolved"), full.names=T)
        if (length(parsed_args$subj) >= 1) {
            string <- do.call(paste, c(as.list(parsed_args$subj), sep = "|"))
            d_files <- d_files[grep(string, d_files)]
        }
        for (i in 1:length(d_files)) {
            file_path <- d_files[i]
            subj <- gsub("sub", "", str_extract(file_path, pattern="sub[0-9]*"))
            run <- str_extract(str_extract(file_path, pattern="run[0-9]"), pattern="[0-9]")
            if (task == "clock") {
                feedback_out <- file.path(decon_outdir, mask, "interpolated", "feedback_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz"))
                clock_out <- file.path(decon_outdir, mask, "interpolated", "clock_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz"))
                if (!file.exists(feedback_out) | !file.exists(clock_out)) {
                    print(paste("Submitting batch job for subject", subj, "run", run))
                    system(paste("sbatch -p htc -N 1 --mem 20g -n 1 -t 23:00:00 -c 1 --wrap 'source ~/.bashrc; Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/alignment.R --subj", subj, "--run", run, "--decon_outdir", decon_outdir, "--mask", mask, "--sample", sample, "--task", task, "--d_file", file_path, "'"))
                } else {
                    print(paste("Subject", subj, "run", run, "is already done."))
                }
            } else if (task == "trust") {
                outcome_out <- file.path(decon_outdir, mask, "interpolated", "outcome_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz"))
                if (!file.exists(outcome_out)) {
                    print(paste("Submitting batch job for subject", subj, "run", run))
                    system(paste("sbatch -p htc -N 1 --mem 40g -n 1 -t 23:00:00 -c 1 --wrap 'source ~/.bashrc; Rscript /ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/alignment.R --subj", subj, "--run", run, "--decon_outdir", decon_outdir, "--mask", mask, "--sample", sample, "--task", task, "--d_file", file_path, "'"))
                } else {
                    print(paste("Subject", subj, "run", run, "is already done."))
                }
            }
        }
    }
}
