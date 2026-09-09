#!/bin/bash
#SBATCH --job-name=raise006_align
#SBATCH --partition=htc
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --output=/ix1/adombrovski/DNPL_DataMesh/Data/MEDuSA/logs/raise006_align_%j.out
#SBATCH --error=/ix1/adombrovski/DNPL_DataMesh/Data/MEDuSA/logs/raise006_align_%j.err

set -euo pipefail

REPO_DIR="/ix1/adombrovski/DNPL_DataMesh/Data/MEDuSA"
PROJECT_LIBRARY="${REPO_DIR}/R_library/4.4"

DECON_FILE="/ix1/mpecina/shared/mpecina_ayd1_bel52/sub1_run1_deconvolved.csv.gz"
EVENT_FILE="/ix1/mpecina/shared/mpecina_ayd1_bel52/behavioral_data/RAISE006/RAISE006_run1_medusa_events.csv"

OUTPUT_DIR="/ix1/mpecina/shared/mpecina_ayd1_bel52/medusa_aligned/RAISE006/run1"
OUTPUT_FILE="${OUTPUT_DIR}/RAISE006_run1_Feed1Onset_aligned.csv.gz"

module purge
module load r/4.4.0

export R_LIBS_USER="${PROJECT_LIBRARY}"

mkdir -p "${OUTPUT_DIR}"
cd "${REPO_DIR}"

echo "Job started: $(date)"
echo "Node: $(hostname)"
echo "Rscript: $(which Rscript)"
echo "Input deconvolution: ${DECON_FILE}"
echo "Input events: ${EVENT_FILE}"
echo "Output: ${OUTPUT_FILE}"

Rscript --vanilla scripts/align_medusa.R \
  --decon-file="${DECON_FILE}" \
  --event-file="${EVENT_FILE}" \
  --output-file="${OUTPUT_FILE}" \
  --event-column="Feed1Onset_continuous" \
  --subject="RAISE_006" \
  --run="1" \
  --tr="0.8" \
  --time-before="-6" \
  --time-after="9" \
  --timing-shift="-0.4" \
  --pad-before="-1.5" \
  --pad-after="1.5" \
  --trial-column="trial_within_run" \
  --aggregate-column="atlas_value" \
  --overwrite="FALSE"

echo "Job completed: $(date)"