#!/usr/bin/env Rscript

# Memory-safe MEDuSA-compatible event alignment.
#
# This script:
#   1. Reads only the required columns from voxelwise deconvolved data.
#   2. Calculates parcel-level mean, median, and SD at every volume.
#   3. Discards the voxelwise data.
#   4. Aligns the parcel summaries to behavioral events.
#   5. Uses the same linear interpolation grid as fmri.pipeline.
#
# Required arguments:
#   --decon-file=PATH
#   --event-file=PATH
#   --output-file=PATH
#   --event-column=COLUMN
#   --subject=ID
#   --run=NUMBER
#
# Optional arguments:
#   --tr=0.8
#   --time-before=-6
#   --time-after=9
#   --timing-shift=-0.4
#   --pad-before=-1.5
#   --pad-after=1.5
#   --trial-column=trial_within_run
#   --aggregate-column=atlas_value
#   --overwrite=FALSE

`%||%` <- function(left, right) {
  if (
    is.null(left) ||
    length(left) == 0 ||
    is.na(left) ||
    !nzchar(left)
  ) {
    right
  } else {
    left
  }
}

parse_arguments <- function(arguments) {
  parsed <- list()

  for (argument in arguments) {
    if (
      !startsWith(argument, "--") ||
      !grepl("=", argument, fixed = TRUE)
    ) {
      stop(
        "Every argument must use the form --name=value. ",
        "Invalid argument: ",
        argument
      )
    }

    argument <- substring(argument, 3)
    pieces <- strsplit(
      argument,
      "=",
      fixed = TRUE
    )[[1]]

    name <- pieces[1]
    value <- paste(
      pieces[-1],
      collapse = "="
    )

    parsed[[name]] <- value
  }

  parsed
}

require_argument <- function(arguments, name) {
  value <- arguments[[name]]

  if (is.null(value) || !nzchar(value)) {
    stop(
      "Missing required argument: --",
      name,
      "=VALUE"
    )
  }

  value
}

as_number_argument <- function(
  arguments,
  name,
  default
) {
  value <- arguments[[name]]

  if (is.null(value)) {
    return(default)
  }

  value <- suppressWarnings(
    as.numeric(value)
  )

  if (is.na(value)) {
    stop(
      "--",
      name,
      " must be numeric."
    )
  }

  value
}

as_logical_argument <- function(
  arguments,
  name,
  default = FALSE
) {
  value <- arguments[[name]]

  if (is.null(value)) {
    return(default)
  }

  normalized <- tolower(value)

  if (normalized %in% c(
    "true", "t", "1", "yes", "y"
  )) {
    return(TRUE)
  }

  if (normalized %in% c(
    "false", "f", "0", "no", "n"
  )) {
    return(FALSE)
  }

  stop(
    "--",
    name,
    " must be TRUE or FALSE."
  )
}

find_column <- function(
  data,
  candidates,
  description
) {
  matches <- intersect(
    candidates,
    names(data)
  )

  if (length(matches) == 0) {
    stop(
      "Could not find a ",
      description,
      " column. Tried: ",
      paste(candidates, collapse = ", ")
    )
  }

  matches[1]
}

format_bytes <- function(bytes) {
  units <- c(
    "bytes", "KB", "MB", "GB", "TB"
  )

  unit_index <- 1

  while (
    bytes >= 1024 &&
    unit_index < length(units)
  ) {
    bytes <- bytes / 1024
    unit_index <- unit_index + 1
  }

  paste0(
    format(
      round(bytes, 2),
      nsmall = 2
    ),
    " ",
    units[unit_index]
  )
}

safe_mean <- function(values) {
  if (all(is.na(values))) {
    return(NA_real_)
  }

  mean(
    values,
    na.rm = TRUE
  )
}

safe_median <- function(values) {
  if (all(is.na(values))) {
    return(NA_real_)
  }

  median(
    values,
    na.rm = TRUE
  )
}

safe_sd <- function(values) {
  valid_values <- values[
    is.finite(values)
  ]

  if (length(valid_values) < 2) {
    return(NA_real_)
  }

  sd(valid_values)
}

interpolate_values <- function(
  observed_time,
  observed_value,
  output_time
) {
  usable <- is.finite(observed_time) &
    is.finite(observed_value)

  if (sum(usable) < 2) {
    return(
      rep(
        NA_real_,
        length(output_time)
      )
    )
  }

  observed_time <- observed_time[usable]
  observed_value <- observed_value[usable]

  ordering <- order(observed_time)

  observed_time <- observed_time[ordering]
  observed_value <- observed_value[ordering]

  stats::approx(
    x = observed_time,
    y = observed_value,
    xout = output_time,
    method = "linear",
    rule = 1,
    ties = "ordered"
  )$y
}

create_output_grid <- function(
  time_before,
  time_after,
  resolution
) {
  first_negative_index <- ceiling(
    time_before / resolution
  )

  last_positive_index <- floor(
    time_after / resolution
  )

  negative_times <- numeric(0)
  positive_times <- numeric(0)

  if (first_negative_index <= -1) {
    negative_times <- seq(
      from = first_negative_index,
      to = -1
    ) * resolution
  }

  if (last_positive_index >= 1) {
    positive_times <- seq(
      from = 1,
      to = last_positive_index
    ) * resolution
  }

  c(
    negative_times,
    0,
    positive_times
  )
}

arguments <- parse_arguments(
  commandArgs(trailingOnly = TRUE)
)

decon_file <- normalizePath(
  require_argument(
    arguments,
    "decon-file"
  ),
  mustWork = TRUE
)

event_file <- normalizePath(
  require_argument(
    arguments,
    "event-file"
  ),
  mustWork = TRUE
)

output_file <- require_argument(
  arguments,
  "output-file"
)

event_column <- require_argument(
  arguments,
  "event-column"
)

subject <- require_argument(
  arguments,
  "subject"
)

scanner_run <- require_argument(
  arguments,
  "run"
)

tr <- as_number_argument(
  arguments,
  "tr",
  0.8
)

time_before <- as_number_argument(
  arguments,
  "time-before",
  -6
)

time_after <- as_number_argument(
  arguments,
  "time-after",
  9
)

timing_shift <- as_number_argument(
  arguments,
  "timing-shift",
  -(tr / 2)
)

pad_before <- as_number_argument(
  arguments,
  "pad-before",
  -1.5
)

pad_after <- as_number_argument(
  arguments,
  "pad-after",
  1.5
)

trial_column <- arguments[["trial-column"]] %||%
  "trial_within_run"

aggregate_column <-
  arguments[["aggregate-column"]] %||%
  "atlas_value"

overwrite <- as_logical_argument(
  arguments,
  "overwrite",
  FALSE
)

if (tr <= 0) {
  stop("--tr must be greater than zero.")
}

if (time_before > 0) {
  stop("--time-before must be zero or negative.")
}

if (time_after < 0) {
  stop("--time-after must be zero or positive.")
}

if (time_before >= time_after) {
  stop(
    "--time-before must be less than --time-after."
  )
}

if (pad_before > 0) {
  stop("--pad-before must be zero or negative.")
}

if (pad_after < 0) {
  stop("--pad-after must be zero or positive.")
}

if (
  file.exists(output_file) &&
  !overwrite
) {
  stop(
    "Output already exists: ",
    output_file,
    "\nUse --overwrite=TRUE only if replacing it is intentional."
  )
}

suppressPackageStartupMessages({
  library(data.table)
})

cat(
  "Memory-safe MEDuSA-compatible alignment\n"
)

cat(
  "Started: ",
  format(Sys.time()),
  "\n",
  sep = ""
)

cat(
  "Reading event data:\n  ",
  event_file,
  "\n",
  sep = ""
)

event_data <- data.table::fread(
  event_file,
  data.table = TRUE
)

required_event_columns <- c(
  event_column,
  trial_column
)

missing_event_columns <- setdiff(
  required_event_columns,
  names(event_data)
)

if (length(missing_event_columns) > 0) {
  stop(
    "Event data are missing columns: ",
    paste(
      missing_event_columns,
      collapse = ", "
    )
  )
}

participant_column <- find_column(
  event_data,
  c(
    "Participant",
    "participant",
    "subject",
    "subj",
    "id"
  ),
  "participant"
)

run_column <- find_column(
  event_data,
  c(
    "scanner_run",
    "run",
    "Run"
  ),
  "scanner run"
)

cat(
  "Detected participant column: ",
  participant_column,
  "\n",
  sep = ""
)

cat(
  "Detected run column: ",
  run_column,
  "\n",
  sep = ""
)

event_data <- event_data[
  as.character(
    get(participant_column)
  ) == subject
]

event_data <- event_data[
  as.character(
    get(run_column)
  ) == scanner_run
]

if (nrow(event_data) == 0) {
  stop(
    "No events remain for subject ",
    subject,
    " and run ",
    scanner_run,
    "."
  )
}

event_data[
  ,
  (event_column) :=
    suppressWarnings(
      as.numeric(
        get(event_column)
      )
    )
]

event_data[
  ,
  (trial_column) :=
    suppressWarnings(
      as.integer(
        get(trial_column)
      )
    )
]

if (anyNA(event_data[[trial_column]])) {
  stop(
    "The trial column contains missing ",
    "or non-integer values."
  )
}

if (
  anyDuplicated(
    event_data[[trial_column]]
  )
) {
  stop(
    "The trial column contains duplicate ",
    "trial identifiers."
  )
}

valid_event <- is.finite(
  event_data[[event_column]]
)

if (!all(valid_event)) {
  cat(
    "Removing ",
    sum(!valid_event),
    " event(s) with missing or nonfinite times.\n",
    sep = ""
  )

  event_data <- event_data[valid_event]
}

if (nrow(event_data) == 0) {
  stop("No valid event times remain.")
}

corrected_event_column <- paste0(
  event_column,
  "_medusa_corrected"
)

event_data[
  ,
  (corrected_event_column) :=
    get(event_column) + timing_shift
]

data.table::setorderv(
  event_data,
  trial_column
)

output_grid <- create_output_grid(
  time_before = time_before,
  time_after = time_after,
  resolution = tr
)

cat("\nAlignment configuration:\n")
cat("  Subject:          ", subject, "\n", sep = "")
cat("  Run:              ", scanner_run, "\n", sep = "")
cat("  Event column:     ", event_column, "\n", sep = "")
cat(
  "  Corrected column: ",
  corrected_event_column,
  "\n",
  sep = ""
)
cat(
  "  Number of events: ",
  nrow(event_data),
  "\n",
  sep = ""
)
cat("  TR:               ", tr, " seconds\n", sep = "")
cat(
  "  Timing shift:     ",
  timing_shift,
  " seconds\n",
  sep = ""
)
cat(
  "  Requested window: ",
  time_before,
  " to ",
  time_after,
  " seconds\n",
  sep = ""
)
cat(
  "  Actual grid:      ",
  min(output_grid),
  " to ",
  max(output_grid),
  " seconds\n",
  sep = ""
)
cat(
  "  Grid points:      ",
  length(output_grid),
  "\n",
  sep = ""
)
cat(
  "  Padding:          ",
  pad_before,
  " to +",
  pad_after,
  " seconds\n",
  sep = ""
)
cat(
  "  Trial column:     ",
  trial_column,
  "\n",
  sep = ""
)
cat(
  "  Aggregate column: ",
  aggregate_column,
  "\n",
  sep = ""
)

columns_to_read <- unique(
  c(
    "volume",
    "time",
    "decon",
    aggregate_column
  )
)

cat(
  "\nReading required deconvolution columns:\n  ",
  paste(
    columns_to_read,
    collapse = ", "
  ),
  "\n",
  sep = ""
)

decon_data <- data.table::fread(
  decon_file,
  select = columns_to_read,
  data.table = TRUE,
  showProgress = TRUE
)

cat(
  "Voxelwise rows read: ",
  format(
    nrow(decon_data),
    big.mark = ","
  ),
  "\n",
  sep = ""
)

cat(
  "Voxelwise object size: ",
  format_bytes(
    as.numeric(
      object.size(decon_data)
    )
  ),
  "\n",
  sep = ""
)

missing_decon_columns <- setdiff(
  columns_to_read,
  names(decon_data)
)

if (length(missing_decon_columns) > 0) {
  stop(
    "Deconvolved data are missing columns: ",
    paste(
      missing_decon_columns,
      collapse = ", "
    )
  )
}

decon_data[
  ,
  volume := suppressWarnings(
    as.numeric(volume)
  )
]

decon_data[
  ,
  time := suppressWarnings(
    as.numeric(time)
  )
]

decon_data[
  ,
  decon := suppressWarnings(
    as.numeric(decon)
  )
]

decon_data[
  ,
  (aggregate_column) :=
    suppressWarnings(
      as.numeric(
        get(aggregate_column)
      )
    )
]

if (
  anyNA(decon_data$volume) ||
  anyNA(decon_data$time)
) {
  stop(
    "The volume or time column contains ",
    "missing or nonnumeric values."
  )
}

if (
  anyNA(
    decon_data[[aggregate_column]]
  )
) {
  stop(
    "The aggregation column contains ",
    "missing or nonnumeric values."
  )
}

expected_times <- (
  decon_data$volume - 1
) * tr

maximum_time_difference <- max(
  abs(
    decon_data$time -
      expected_times
  ),
  na.rm = TRUE
)

rm(expected_times)
invisible(gc())

time_tolerance <- max(
  1e-6,
  tr * 1e-6
)

if (
  !is.finite(maximum_time_difference) ||
  maximum_time_difference >
    time_tolerance
) {
  stop(
    "Deconvolved time values do not match ",
    "the requested TR. Maximum difference = ",
    signif(
      maximum_time_difference,
      6
    ),
    " seconds."
  )
}

cat(
  "Maximum TR/time difference: ",
  signif(
    maximum_time_difference,
    6
  ),
  " seconds\n",
  sep = ""
)

cat(
  "\nAggregating voxels within atlas parcels...\n"
)

grouping_columns <- c(
  aggregate_column,
  "volume",
  "time"
)

parcel_data <- decon_data[
  ,
  .(
    decon_mean = safe_mean(decon),
    decon_median = safe_median(decon),
    decon_sd = safe_sd(decon)
  ),
  by = grouping_columns
]

rm(decon_data)
invisible(gc())

data.table::setorderv(
  parcel_data,
  c(
    aggregate_column,
    "time"
  )
)

cat(
  "Parcel-level rows: ",
  format(
    nrow(parcel_data),
    big.mark = ","
  ),
  "\n",
  sep = ""
)

cat(
  "Unique parcels: ",
  data.table::uniqueN(
    parcel_data[[aggregate_column]]
  ),
  "\n",
  sep = ""
)

cat(
  "Parcel-level object size: ",
  format_bytes(
    as.numeric(
      object.size(parcel_data)
    )
  ),
  "\n",
  sep = ""
)

cat(
  "\nAligning parcel summaries to events...\n"
)

aligned_trials <- vector(
  mode = "list",
  length = nrow(event_data)
)

for (
  event_index in seq_len(
    nrow(event_data)
  )
) {
  trial_id <- event_data[[trial_column]][event_index]

  event_onset <-
    event_data[[corrected_event_column]][event_index]

  window_start <- event_onset +
    time_before +
    pad_before

  window_end <- event_onset +
    time_after +
    pad_after

  trial_data <- parcel_data[
    time >= window_start &
      time <= window_end
  ]

  trial_data[
    ,
    evt_time := time - event_onset
  ]

  interpolated_trial <- trial_data[
    ,
    .(
      evt_time = output_grid,
      decon_mean = interpolate_values(
        evt_time,
        decon_mean,
        output_grid
      ),
      decon_median = interpolate_values(
        evt_time,
        decon_median,
        output_grid
      ),
      decon_sd = interpolate_values(
        evt_time,
        decon_sd,
        output_grid
      )
    ),
    by = aggregate_column
  ]

  interpolated_trial[
    ,
    trial := trial_id
  ]

  data.table::setcolorder(
    interpolated_trial,
    c(
      aggregate_column,
      "trial",
      "evt_time",
      "decon_mean",
      "decon_median",
      "decon_sd"
    )
  )

  aligned_trials[[event_index]] <-
    interpolated_trial

  if (
    event_index == 1 ||
    event_index %% 5 == 0 ||
    event_index == nrow(event_data)
  ) {
    cat(
      "  Completed event ",
      event_index,
      " of ",
      nrow(event_data),
      "\n",
      sep = ""
    )
  }

  rm(
    trial_data,
    interpolated_trial
  )
}

aligned_data <- data.table::rbindlist(
  aligned_trials,
  use.names = TRUE,
  fill = TRUE
)

rm(aligned_trials)
invisible(gc())

data.table::setorderv(
  aligned_data,
  c(
    "trial",
    aggregate_column,
    "evt_time"
  )
)

aligned_data[
  ,
  subject := subject
]

aligned_data[
  ,
  scanner_run := scanner_run
]

aligned_data[
  ,
  alignment_event := event_column
]

aligned_data[
  ,
  timing_shift_seconds := timing_shift
]

aligned_data[
  ,
  tr_seconds := tr
]

aligned_data[
  ,
  alignment_time_before := time_before
]

aligned_data[
  ,
  alignment_time_after := time_after
]

aligned_data[
  ,
  source_decon_file := basename(decon_file)
]

aligned_data[
  ,
  source_event_file := basename(event_file)
]

expected_output_rows <-
  nrow(event_data) *
  data.table::uniqueN(
    parcel_data[[aggregate_column]]
  ) *
  length(output_grid)

cat(
  "\nExpected output rows: ",
  format(
    expected_output_rows,
    big.mark = ","
  ),
  "\n",
  sep = ""
)

cat(
  "Observed output rows: ",
  format(
    nrow(aligned_data),
    big.mark = ","
  ),
  "\n",
  sep = ""
)

if (
  nrow(aligned_data) !=
    expected_output_rows
) {
  warning(
    "Observed output row count differs ",
    "from the expected rectangular output."
  )
}

output_directory <- dirname(
  output_file
)

if (!dir.exists(output_directory)) {
  dir.create(
    output_directory,
    recursive = TRUE
  )
}

temporary_output <- paste0(
  output_file,
  ".temporary-",
  Sys.getpid(),
  ".gz"
)

cat(
  "Writing temporary output:\n  ",
  temporary_output,
  "\n",
  sep = ""
)

data.table::fwrite(
  aligned_data,
  file = temporary_output,
  compress = "gzip"
)

if (
  file.exists(output_file) &&
  overwrite
) {
  unlink(output_file)

  if (file.exists(output_file)) {
    unlink(temporary_output)

    stop(
      "Could not remove the previous output: ",
      output_file
    )
  }
}

if (
  !file.rename(
    temporary_output,
    output_file
  )
) {
  unlink(temporary_output)

  stop(
    "Could not move temporary output to: ",
    output_file
  )
}

cat("\nAlignment completed successfully.\n")
cat(
  "Rows written: ",
  format(
    nrow(aligned_data),
    big.mark = ","
  ),
  "\n",
  sep = ""
)
cat(
  "Output:\n  ",
  normalizePath(output_file),
  "\n",
  sep = ""
)
cat(
  "Completed: ",
  format(Sys.time()),
  "\n",
  sep = ""
)