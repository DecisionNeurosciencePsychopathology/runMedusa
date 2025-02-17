subj <- R.utils::cmdArg("subj")
d_file <- R.utils::cmdArg("d_file")
run <- R.utils::cmdArg("run")
decon_outdir <- R.utils::cmdArg("decon_outdir")
mask <- R.utils::cmdArg("mask")
sample <- R.utils::cmdArg("sample")
task <- R.utils::cmdArg("task")

setwd('/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa')
#atlas_file <- file.path(getwd(), paste0(mask, ".nii.gz"))

require(tidyverse)
require(foreach)
require(oro.nifti)
require(data.table)
require(fmri.pipeline)

source('/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/Medusa/fmri.pipeline/R/spm_funcs.R')
source('/ix1/adombrovski/lab_resources/clock_analysis/fmri/keuka_brain_behavior_analyses/dan/get_trial_data.R')

afnidir <- '/ihome/crc/install/afni/18.0.22/bin'
Sys.setenv(AFNIDIR=afnidir)

decon_beta <- 1 
tr <- .6
aggregate_by <- "atlas_value"

if (task == "trust" & sample == "bsocial") {
  trial_df <- read.csv("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/trust_trialdf_bsoc_ksoc.csv")
  subj_df <- trial_df %>%
    filter(id == !!subj) %>%
    mutate(outcome_onset_TR_corrected = outcome_onset - .3) %>%
    mutate(run = 1) %>%
    select(id, run, trial, outcome_onset, outcome_onset_TR_corrected)
}

if (task == "clock" & sample == "explore") {
  cat("Loading trial_df. \n")
  trial_df <- get_trial_data(repo_directory=getwd(),dataset="explore", groupfixed=T)
  # subsetting for only this subject's data 
  subj_df <- trial_df %>% filter(id == !!subj & run_number == !!run)
  subj_df <- subj_df %>%
    mutate(feedback_onset_TR_corrected = feedback_onset - 0.3) %>%
    mutate(clock_onset_TR_corrected = clock_onset - 0.3)
}

if (task == "clock" & sample == "bsocial") {
  cat("Loading trial_df. \n")
  trial_df <- read.csv("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa/bsocial_clock_trial_df.csv")
  # subsetting for only this subject's data 
  trial_df <- trial_df %>% select(-run) %>% dplyr::rename("run"="scanner_run")
  subj_df <- trial_df %>% filter(id == !!subj & run == !!run)
  subj_df <- subj_df %>%
    mutate(feedback_onset_TR_corrected = feedback_onset - 0.3) %>%
    mutate(clock_onset_TR_corrected = clock_onset - 0.3) 
}

# read decon data
cat("Reading deconvolved data from the following file: ", d_file, "\n")
d <- data.table::fread(d_file, data.table=FALSE)
d[[aggregate_by]] <- as.numeric(d[[aggregate_by]]) # convert atlas values to numbers explicitly

### 2. event-lock and interpolate
# generate fmri_ts object
tsobj <- fmri_ts$new(
      ts_data = d, event_data = subj_df, tr = tr,
      vm = list(value = c("decon"), key = c("vnum", aggregate_by))
)

if (task == "clock") {
  # CLOCK ALIGNED
  if (!file.exists(file.path(decon_outdir, mask, "interpolated", "clock_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz")))) {
    cat("Interpolating fMRI time series (clock aligned): \n")
    # clock aligned
    interp_dt_clock <- tryCatch({
      interp_dt_clock <- get_medusa_interpolated_ts(tsobj, event="clock_onset_TR_corrected", time_before=-6, time_after=9,
                                                    output_resolution = tr,
                                                    group_by = c(aggregate_by, "trial"))
      #interp_dt_clock %>% mutate(id=subj, run=run) -> interp_dt_clock
    }, error=function(err) { print(as.character(err)); save(fmri_event_data, file="problem_case.RData"); return(NULL) })

    cat("Writing output... \n")
    if(!is.null(interp_dt_clock)){
      # saving event-locked and interpolated fmri_ts:
      interp_outdir_clock <- file.path(decon_outdir, mask, "interpolated", "clock_aligned")
      if(!dir.exists(interp_outdir_clock)) {dir.create(interp_outdir_clock)}
      write.csv(interp_dt_clock, file = file.path(interp_outdir_clock, paste0("sub", subj, "_run", run, "_interpolated.csv.gz")))
    } 
  } else {
    cat("The output file for clock aligned already exists. \n")
  }

  # RT ALIGNED
  if (!file.exists(file.path(decon_outdir, mask, "interpolated", "feedback_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz")))) {
    cat("Interpolating fMRI time series (feedback aligned): \n")
    # rt aligned
    interp_dt_rt <- tryCatch({
      interp_dt_rt <- get_medusa_interpolated_ts(tsobj, event="feedback_onset_TR_corrected", time_before=-6, time_after=9,
                                                 output_resolution = tr,
                                                 group_by = c(aggregate_by, "trial"))
      #interp_dt_rt %>% mutate(id=subj, run=run) -> interp_dt_rt
    }, error=function(err) { print(as.character(err)); save(fmri_event_data, file="problem_case.RData"); return(NULL) })

    cat("Writing output... \n")
    if(!is.null(interp_dt_rt)){
      # saving event-locked and interpolated fmri_ts:
      interp_outdir_rt <- file.path(decon_outdir, mask, "interpolated", "feedback_aligned")
      if(!dir.exists(interp_outdir_rt)) {dir.create(interp_outdir_rt)}
      write.csv(interp_dt_rt, file = file.path(interp_outdir_rt, paste0("sub", subj, "_run", run, "_interpolated.csv.gz")))
    }
  } else {
    cat("The output file for feedback aligned already exists.")
  }
}

if (task == "trust" & sample == "bsocial") {
  # OUTCOME ALIGNED
  if (!file.exists(file.path(decon_outdir, mask, "interpolated", "outcome_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz")))) {
    cat("Interpolating fMRI time series (outcome aligned): \n")
    # outcome aligned
    interp_dt_outcome <- tryCatch({
      interp_dt_outcome <- get_medusa_interpolated_ts(tsobj, event="outcome_onset_TR_corrected", time_before=-6, time_after=9,
                                                    output_resolution = tr,
                                                    group_by = c(aggregate_by, "trial"))
    }, error=function(err) { print(as.character(err)); save(fmri_event_data, file="problem_case.RData"); return(NULL) })

    cat("Writing output... \n")
    if(!is.null(interp_dt_outcome)){
      # saving event-locked and interpolated fmri_ts:
      interp_outdir_outcome <- file.path(decon_outdir, mask, "interpolated", "outcome_aligned")
      if(!dir.exists(interp_outdir_outcome)) {dir.create(interp_outdir_outcome)}
      write.csv(interp_dt_outcome, file = file.path(interp_outdir_outcome, paste0("sub", subj, "_run", run, "_interpolated.csv.gz")))
    } 
  } else {
    cat("The output file for outcome aligned already exists. \n")
  }
}