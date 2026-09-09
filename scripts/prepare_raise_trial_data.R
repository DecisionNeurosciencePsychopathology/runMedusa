#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/prepare_raise_trial_data.R",
      "<block1_csv> <block2_csv> <output_csv>"
    )
  )
}

block1_file <- args[[1]]
block2_file <- args[[2]]
output_file <- args[[3]]

required_columns <- c(
  "Participant",
  "Run",
  "TrialNum",
  "Infusion",
  "Feedback",
  "InfOnset",
  "WillImpOnset",
  "J1Onset",
  "Feed1Onset",
  "Feed2Onset",
  "Feed3Onset",
  "ImprovedOnset",
  "J2Onset"
)

onset_columns <- c(
  "InfOnset",
  "WillImpOnset",
  "J1Onset",
  "Feed1Onset",
  "Feed2Onset",
  "Feed3Onset",
  "ImprovedOnset",
  "J2Onset"
)

read_block <- function(path, expected_block) {
  if (!file.exists(path)) {
    stop("Input file does not exist: ", path)
  }

  block <- read.csv(
    path,
    stringsAsFactors = FALSE,
    na.strings = c("", "NA", "NaN")
  )

  missing_columns <- setdiff(required_columns, names(block))

  if (length(missing_columns) > 0) {
    stop(
      "Missing required columns in ",
      path,
      ": ",
      paste(missing_columns, collapse = ", ")
    )
  }

  if (nrow(block) == 0) {
    stop("Input file contains no trials: ", path)
  }

  if (!all(block$Run == expected_block)) {
    stop(
      "Expected raw Run value ",
      expected_block,
      " in ",
      path,
      ". Found: ",
      paste(unique(block$Run), collapse = ", ")
    )
  }

  block
}

block1 <- read_block(block1_file, expected_block = 1)
block2 <- read_block(block2_file, expected_block = 2)

if (!identical(unique(block1$Participant), unique(block2$Participant))) {
  stop("Block 1 and Block 2 have different participant identifiers.")
}

# The Block 2 task clock restarts near zero. The original Run 1
# regressors place Block 2 after the final J2 onset from Block 1.
block2_offset <- max(block1$J2Onset, na.rm = TRUE)

block1$behavioral_block <- 1L
block2$behavioral_block <- 2L

block1$block_onset_offset <- 0
block2$block_onset_offset <- block2_offset

for (column in onset_columns) {
  block1[[paste0(column, "_continuous")]] <- block1[[column]]
  block2[[paste0(column, "_continuous")]] <-
    block2[[column]] + block2_offset
}

run1 <- rbind(block1, block2)

run1$scanner_run <- 1L
run1$trial_within_run <- seq_len(nrow(run1))

# Preserve the original variables while adding readable condition labels.
run1$infusion_condition <- ifelse(
  run1$Infusion %in% c("A", "B"),
  "Signal",
  ifelse(
    run1$Infusion %in% c("C", "D"),
    "Calibration",
    NA_character_
  )
)

run1$feedback_condition <- ifelse(
  run1$Feedback == "Signal",
  "Signal",
  ifelse(run1$Feedback == "Baseline", "Calibration", NA_character_)
)

# Checks
if (anyNA(run1$infusion_condition)) {
  unknown_codes <- unique(run1$Infusion[is.na(run1$infusion_condition)])

  stop(
    "Unrecognized infusion code(s): ",
    paste(unknown_codes, collapse = ", ")
  )
}

if (anyNA(run1$feedback_condition)) {
  unknown_labels <- unique(run1$Feedback[is.na(run1$feedback_condition)])

  stop(
    "Unrecognized feedback label(s): ",
    paste(unknown_labels, collapse = ", ")
  )
}

# Event durations reconstructed from the original regressor definitions.
run1$infusion_duration <-
  run1$WillImpOnset_continuous - run1$InfOnset_continuous

run1$expectancy_duration <-
  run1$Feed1Onset_continuous - run1$WillImpOnset_continuous

run1$feedback_baseline_duration <-
  run1$Feed2Onset_continuous - run1$Feed1Onset_continuous

run1$feedback_condition_duration <-
  run1$ImprovedOnset_continuous - run1$Feed2Onset_continuous

run1$mood_rating_duration <-
  run1$J2Onset_continuous - run1$ImprovedOnset_continuous

if (any(run1$trial_within_run != seq_len(nrow(run1)))) {
  stop("Run-level trial numbering is not sequential.")
}

if (any(run1$infusion_duration <= 0, na.rm = TRUE) ||
    any(run1$expectancy_duration <= 0, na.rm = TRUE) ||
    any(run1$feedback_baseline_duration <= 0, na.rm = TRUE) ||
    any(run1$feedback_condition_duration <= 0, na.rm = TRUE) ||
    any(run1$mood_rating_duration <= 0, na.rm = TRUE)) {
  stop("One or more reconstructed event durations are not positive.")
}

output_parent <- dirname(output_file)

if (!dir.exists(output_parent)) {
  dir.create(output_parent, recursive = TRUE)
}

write.csv(run1, output_file, row.names = FALSE, na = "")

cat("Participant:", unique(run1$Participant), "\n")
cat("Scanner run:", unique(run1$scanner_run), "\n")
cat("Block 1 trials:", nrow(block1), "\n")
cat("Block 2 trials:", nrow(block2), "\n")
cat("Total trials:", nrow(run1), "\n")
cat("Block 2 offset:", block2_offset, "seconds\n")
cat("Output:", output_file, "\n")
