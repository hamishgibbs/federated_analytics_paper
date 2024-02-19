#!/bin/bash

JOB_SCRIPT="${@: -1}"

SCRIPT_DIR=$(dirname "$JOB_SCRIPT")

NEW_JOB_SCRIPT="$SCRIPT_DIR/env_setup_$(basename "$JOB_SCRIPT")"

mkdir -p "$SCRIPT_DIR"

# We need to load conda before running the original job script
{
    echo "#!/bin/sh"
    echo "module load python/miniconda3/4.10.3"
    echo "source \$UCL_CONDA_PATH/etc/profile.d/conda.sh"
} > "$NEW_JOB_SCRIPT"

cat "$JOB_SCRIPT" >> "$NEW_JOB_SCRIPT"

chmod +x "$NEW_JOB_SCRIPT"

qsub "${@:1:$#-1}" "$NEW_JOB_SCRIPT"
