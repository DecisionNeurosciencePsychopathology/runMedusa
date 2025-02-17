subj <- R.utils::cmdArg("subj")
d_file <- R.utils::cmdArg("d_file")
run <- R.utils::cmdArg("run")
decon_outdir <- R.utils::cmdArg("decon_outdir")
mask <- R.utils::cmdArg("mask")
sample <- R.utils::cmdArg("sample")
task <- R.utils::cmdArg("task")

setwd('/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa')

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

# get trial data
trial_df <- get_trial_data(repo_directory=getwd(),dataset="explore", groupfixed=T)
subj_df <- trial_df %>% filter(id == !!subj & run_number == !!run)
subj_df <- subj_df %>%
    mutate(feedback_onset_TR_corrected = feedback_onset - 0.3) %>%
    mutate(clock_onset_TR_corrected = clock_onset - 0.3) %>%
    mutate(feedback_onset_subtract_ISI = feedback_onset - 0.3 - 0.05)

# read decon data
cat("Reading deconvolved data from the following file: ", d_file, "\n")
d <- data.table::fread(d_file, data.table=FALSE)
d[[aggregate_by]] <- as.numeric(d[[aggregate_by]]) # convert atlas values to numbers explicitly


d_v1 <- d %>%
    filter(atlas_value %in% c(1:14,101:115))
d_m1 <- d %>%
    filter(atlas_value %in% c(15:30,116:134))

tsobj_v1 <- fmri_ts$new(
      ts_data = d_v1, event_data = subj_df, tr = tr,
      vm = list(value = c("decon"), key = c("vnum", aggregate_by))
)

tsobj_m1 <- fmri_ts$new(
      ts_data = d_m1, event_data = subj_df, tr = tr,
      vm = list(value = c("decon"), key = c("vnum", aggregate_by))
)

# CLOCK ALIGNED
  if (!file.exists(file.path(decon_outdir, mask, "interpolated", "clock_aligned", paste0("sub", subj, "_run", run, "_interpolated.csv.gz")))) {
    cat("Interpolating fMRI time series (clock aligned): \n")
    # clock aligned
    interp_dt_clock <- tryCatch({
      interp_dt_clock <- get_medusa_interpolated_ts(tsobj_v1, event="clock_onset_TR_corrected", time_before=-6, time_after=9,
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
      interp_dt_rt <- get_medusa_interpolated_ts(tsobj_m1, event="feedback_onset_subtract_ISI", time_before=-6, time_after=9,
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


