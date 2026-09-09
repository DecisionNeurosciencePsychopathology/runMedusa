#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/validate_raise_regressors.R",
      "<events_csv> <regressors_directory>"
    )
  )
}

events_file <- args[[1]]
regs_dir <- args[[2]]
tolerance <- 0.001

if (!file.exists(events_file)) {
  stop("Events file does not exist: ", events_file)
}

if (!dir.exists(regs_dir)) {
  stop("Regressors directory does not exist: ", regs_dir)
}

events <- read.csv(
  events_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA", "NaN")
)

read_regressor <- function(filename) {
  path <- file.path(regs_dir, filename)

  if (!file.exists(path)) {
    stop("Regressor file does not exist: ", path)
  }

  read.table(
    path,
    header = FALSE,
    col.names = c("onset", "duration", "amplitude")
  )
}

compare_regressor <- function(label, expected, filename) {
  observed <- read_regressor(filename)

  if (nrow(expected) != nrow(observed)) {
    cat(
      "FAIL:", label,
      "- expected", nrow(expected),
      "rows but found", nrow(observed), "\n"
    )

    return(FALSE)
  }

  if (any(!complete.cases(expected))) {
    cat("FAIL:", label, "- reconstructed data contain missing values\n")
    return(FALSE)
  }

  onset_difference <- max(abs(expected$onset - observed$onset))
  duration_difference <- max(abs(expected$duration - observed$duration))
  amplitude_matches <- all(observed$amplitude == 1)

  passed <- (
    onset_difference <= tolerance &&
    duration_difference <= tolerance &&
    amplitude_matches
  )

  cat(
    if (passed) "PASS:" else "FAIL:",
    label,
    "| rows =", nrow(expected),
    "| maximum onset difference =", format(onset_difference, digits = 6),
    "| maximum duration difference =", format(duration_difference, digits = 6),
    "| amplitudes all 1 =", amplitude_matches,
    "\n"
  )

  passed
}

make_events <- function(data, onset_column, duration_column) {
  data.frame(
    onset = data[[onset_column]],
    duration = data[[duration_column]],
    amplitude = 1
  )
}

results <- c(
  infusion_calibration = compare_regressor(
    "Infusion Calibration",
    make_events(
      events[events$infusion_condition == "Calibration", ],
      "InfOnset_continuous",
      "infusion_duration"
    ),
    "nfb_run-1_Infusion_Calibration_Event_pmod.txt"
  ),

  infusion_signal = compare_regressor(
    "Infusion Signal",
    make_events(
      events[events$infusion_condition == "Signal", ],
      "InfOnset_continuous",
      "infusion_duration"
    ),
    "nfb_run-1_Infusion_Signal_Event_pmod.txt"
  ),

  expectancy = compare_regressor(
    "Expectancy Rating",
    make_events(
      events,
      "WillImpOnset_continuous",
      "expectancy_duration"
    ),
    "nfb_run-1_Expectancy_Rating_Event_pmod.txt"
  ),

  feedback_baseline = compare_regressor(
    "Feedback Baseline",
    make_events(
      events,
      "Feed1Onset_continuous",
      "feedback_baseline_duration"
    ),
    "nfb_run-1_Feedback_Baseline_Event_pmod.txt"
  ),

  feedback_calibration = compare_regressor(
    "Feedback Calibration",
    make_events(
      events[events$feedback_condition == "Calibration", ],
      "Feed2Onset_continuous",
      "feedback_condition_duration"
    ),
    "nfb_run-1_Feedback_Calibration_Event_pmod.txt"
  ),

  feedback_signal = compare_regressor(
    "Feedback Signal",
    make_events(
      events[events$feedback_condition == "Signal", ],
      "Feed2Onset_continuous",
      "feedback_condition_duration"
    ),
    "nfb_run-1_Feedback_Signal_Event_pmod.txt"
  ),

  mood = compare_regressor(
    "Mood Rating",
    make_events(
      events,
      "ImprovedOnset_continuous",
      "mood_rating_duration"
    ),
    "nfb_run-1_Mood_Rating_Event_pmod.txt"
  )
)

cat("\nSummary:", sum(results), "of", length(results), "checks passed.\n")

if (!all(results)) {
  stop("Regressor validation failed.")
}

cat("All reconstructed Run 1 regressors match the originals.\n")