#!/bin/bash

# Original job script is the last argument
JOB_SCRIPT="${@: -1}"

# Directory where the original job script is located
SCRIPT_DIR=$(dirname "$JOB_SCRIPT")

# New job script with "env_setup_" prefix added to the filename, not the path
NEW_JOB_SCRIPT="$SCRIPT_DIR/env_setup_$(basename "$JOB_SCRIPT")"

# Ensure the directory exists and create the new job script
mkdir -p "$SCRIPT_DIR"

# Adding environment setup commands to the new job script
{
    echo "#!/bin/sh"
    echo "module load python/miniconda3/4.10.3"
    echo "source \$UCL_CONDA_PATH/etc/profile.d/conda.sh"
} > "$NEW_JOB_SCRIPT"

# Append the original job script content to the new script
cat "$JOB_SCRIPT" >> "$NEW_JOB_SCRIPT"

# Ensure the new job script is executable
chmod +x "$NEW_JOB_SCRIPT"

# Submit the new job script to qsub, passing along all arguments except the last one
qsub "${@:1:$#-1}" "$NEW_JOB_SCRIPT"
