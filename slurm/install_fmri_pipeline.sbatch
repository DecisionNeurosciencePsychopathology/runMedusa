#!/bin/bash
#SBATCH --job-name=install_fmri_pipeline
#SBATCH --partition=htc
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=/ix1/adombrovski/DNPL_DataMesh/Data/MEDuSA/logs/install_fmri_pipeline_%j.out
#SBATCH --error=/ix1/adombrovski/DNPL_DataMesh/Data/MEDuSA/logs/install_fmri_pipeline_%j.err

set -euo pipefail

REPO_DIR="/ix1/adombrovski/DNPL_DataMesh/Data/MEDuSA"
PROJECT_LIBRARY="${REPO_DIR}/R_library/4.4"
GGBRAIN_SOURCE="${REPO_DIR}/dependencies/ggbrain"
FMRI_PIPELINE_SOURCE="${REPO_DIR}/dependencies/fmri.pipeline"

module purge
module load r/4.4.0

# Prevent obsolete personal R startup settings from overriding R 4.4.0.
unset R_HOME
export R_PROFILE_USER="/dev/null"
export R_ENVIRON_USER="/dev/null"

# Put the project-specific package library first.
export R_LIBS_USER="${PROJECT_LIBRARY}"

# Install packages serially so dependency failures remain visible.
export MAKEFLAGS="-j1"

mkdir -p "${PROJECT_LIBRARY}"
mkdir -p "${REPO_DIR}/logs"

cd "${REPO_DIR}"

echo "Installation started: $(date)"
echo "Node: $(hostname)"
echo "R executable: $(which R)"
echo "Rscript executable: $(which Rscript)"
echo "Project library: ${PROJECT_LIBRARY}"

echo
echo "R initialization:"

Rscript --vanilla -e '
cat("R version:", R.version.string, "\n")
cat("R home:", R.home(), "\n")
cat("Library paths:\n")
print(.libPaths())
'

echo
echo "Checking source directories..."

if [[ ! -f "${GGBRAIN_SOURCE}/DESCRIPTION" ]]; then
    echo "ERROR: ggbrain source package not found:"
    echo "${GGBRAIN_SOURCE}"
    exit 1
fi

if [[ ! -f "${FMRI_PIPELINE_SOURCE}/DESCRIPTION" ]]; then
    echo "ERROR: fmri.pipeline source package not found:"
    echo "${FMRI_PIPELINE_SOURCE}"
    exit 1
fi

echo
echo "ggbrain source information:"
grep -E '^(Package|Version|Date):' "${GGBRAIN_SOURCE}/DESCRIPTION"
echo "Commit:"
git -C "${GGBRAIN_SOURCE}" rev-parse HEAD

echo
echo "fmri.pipeline source information:"
grep -E '^(Package|Version|Date):' "${FMRI_PIPELINE_SOURCE}/DESCRIPTION"
echo "Commit:"
git -C "${FMRI_PIPELINE_SOURCE}" rev-parse HEAD

echo
echo "Checking project Matrix installation..."

Rscript --vanilla -e '
project_library <- Sys.getenv("R_LIBS_USER")
.libPaths(c(project_library, .libPaths()))

minimum_version <- package_version("1.7.6")

location <- find.package(
  "Matrix",
  lib.loc = project_library,
  quiet = TRUE
)

needs_install <- (
  length(location) != 1L ||
  packageVersion("Matrix", lib.loc = project_library) < minimum_version
)

if (needs_install) {
  cat("Installing Matrix into the project library...\n")

  install.packages(
    "Matrix",
    lib = project_library,
    repos = "https://cloud.r-project.org",
    dependencies = NA,
    Ncpus = 1
  )
} else {
  cat("Compatible project Matrix is already installed.\n")
}

location <- find.package(
  "Matrix",
  lib.loc = project_library,
  quiet = TRUE
)

if (length(location) != 1L || !nzchar(location)) {
  stop("Matrix was not installed into the project library.")
}

library(Matrix, lib.loc = project_library)

cat(
  "Matrix version:",
  as.character(packageVersion("Matrix", lib.loc = project_library)),
  "\n"
)

cat("Matrix location:", location, "\n")
'

echo
echo "Installing a compatible tidyverse dependency chain serially..."

Rscript --vanilla -e '
project_library <- Sys.getenv("R_LIBS_USER")
.libPaths(c(project_library, .libPaths()))

minimum_versions <- c(
  cli        = "3.4.0",
  generics   = "0.1.3",
  glue       = "1.6.0",
  magrittr   = "2.0.0",
  R6         = "2.5.0",
  utf8       = "1.2.0",
  withr      = "2.5.0",
  rlang      = "1.3.0",
  lifecycle  = "1.0.5",
  vctrs      = "0.7.3",
  pillar     = "1.9.0",
  tibble     = "3.2.0",
  tidyselect = "1.2.0",
  dplyr      = "1.2.1"
)

for (package in names(minimum_versions)) {
  minimum_version <- package_version(minimum_versions[[package]])

  project_location <- find.package(
    package,
    lib.loc = project_library,
    quiet = TRUE
  )

  project_version <- if (length(project_location) == 1L) {
    packageVersion(package, lib.loc = project_library)
  } else {
    NULL
  }

  needs_install <- (
    is.null(project_version) ||
    project_version < minimum_version
  )

  if (needs_install) {
    cat(
      "\nInstalling",
      package,
      "(minimum version",
      as.character(minimum_version),
      ")...\n"
    )

    install.packages(
      package,
      lib = project_library,
      repos = "https://cloud.r-project.org",
      dependencies = NA,
      Ncpus = 1
    )
  } else {
    cat(
      "\nCompatible project package already installed:",
      package,
      as.character(project_version),
      "\n"
    )
  }

  project_location <- find.package(
    package,
    lib.loc = project_library,
    quiet = TRUE
  )

  if (length(project_location) != 1L || !nzchar(project_location)) {
    stop(
      package,
      " was not installed into the project library."
    )
  }

  installed_version <- packageVersion(
    package,
    lib.loc = project_library
  )

  if (installed_version < minimum_version) {
    stop(
      package,
      " version ",
      installed_version,
      " is older than required version ",
      minimum_version,
      "."
    )
  }

  cat(
    package,
    "version:",
    as.character(installed_version),
    "\n"
  )

  cat(
    package,
    "location:",
    project_location,
    "\n"
  )
}

if (!exists(
  "reframe",
  envir = asNamespace("dplyr"),
  inherits = FALSE
)) {
  stop("The project dplyr does not export reframe().")
}

cat("\nThe tidyverse dependency chain is valid.\n")
'

echo
echo "Installing a toolchain-compatible igraph dependency chain..."

Rscript --vanilla -e '
project_library <- Sys.getenv("R_LIBS_USER")
.libPaths(c(project_library, .libPaths()))

packages <- c(
  "cpp11",
  "pkgconfig",
  "igraph"
)

for (package in packages) {
  cat("\nInstalling", package, "...\n")

  install.packages(
    package,
    lib = project_library,
    repos = "https://cloud.r-project.org",
    dependencies = NA,
    Ncpus = 1
  )

  location <- find.package(
    package,
    lib.loc = project_library,
    quiet = TRUE
  )

  if (length(location) != 1L || !nzchar(location)) {
    stop(
      package,
      " was not installed into the project library."
    )
  }

  cat(
    package,
    "version:",
    as.character(packageVersion(package, lib.loc = project_library)),
    "\n"
  )

  cat(
    package,
    "location:",
    location,
    "\n"
  )
}

library(igraph, lib.loc = project_library)

cat("Project igraph loaded successfully.\n")
'

echo
echo "Installing readbitmap and its required dependencies..."

Rscript --vanilla -e '
project_library <- Sys.getenv("R_LIBS_USER")
.libPaths(c(project_library, .libPaths()))

install.packages(
  "readbitmap",
  lib = project_library,
  repos = "https://cloud.r-project.org",
  dependencies = NA,
  Ncpus = 1
)

location <- find.package(
  "readbitmap",
  lib.loc = project_library,
  quiet = TRUE
)

if (length(location) != 1L || !nzchar(location)) {
  stop("readbitmap was not installed into the project library.")
}

library(readbitmap, lib.loc = project_library)

cat(
  "readbitmap version:",
  as.character(packageVersion("readbitmap", lib.loc = project_library)),
  "\n"
)

cat("readbitmap location:", location, "\n")
'

echo
echo "Installing ggbrain..."

R CMD INSTALL \
    --library="${PROJECT_LIBRARY}" \
    "${GGBRAIN_SOURCE}"

echo
echo "Validating ggbrain..."

Rscript --vanilla -e '
project_library <- Sys.getenv("R_LIBS_USER")
.libPaths(c(project_library, .libPaths()))

library(ggbrain)

cat(
  "ggbrain version:",
  as.character(packageVersion("ggbrain")),
  "\n"
)

cat(
  "ggbrain location:",
  find.package("ggbrain"),
  "\n"
)
'

echo
echo "Installing fmri.pipeline..."

R CMD INSTALL \
    --library="${PROJECT_LIBRARY}" \
    "${FMRI_PIPELINE_SOURCE}"

echo
echo "Validating fmri.pipeline..."

Rscript --vanilla -e '
project_library <- Sys.getenv("R_LIBS_USER")
.libPaths(c(project_library, .libPaths()))

library(fmri.pipeline)

cat(
  "fmri.pipeline version:",
  as.character(packageVersion("fmri.pipeline")),
  "\n"
)

cat(
  "fmri.pipeline location:",
  find.package("fmri.pipeline"),
  "\n"
)

required_objects <- c(
  "fmri_ts",
  "get_medusa_interpolated_ts",
  "voxelwise_deconvolution"
)

available <- vapply(
  required_objects,
  exists,
  logical(1),
  envir = asNamespace("fmri.pipeline"),
  inherits = FALSE
)

print(available)

if (!all(available)) {
  stop("One or more required fmri.pipeline objects are unavailable.")
}

cat("fmri.pipeline installation validated successfully.\n")
'

echo
echo "Installation completed successfully: $(date)"