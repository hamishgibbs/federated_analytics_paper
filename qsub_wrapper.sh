#!/bin/bash

JOB_SCRIPT="${@: -1}"

NEW_JOB_SCRIPT="env_setup_${JOB_SCRIPT}"

# Conda is not available in the default environment, so we need to load it
echo "#!/bin/sh" > "$NEW_JOB_SCRIPT"
echo "module load python/miniconda3/4.10.3" >> "$NEW_JOB_SCRIPT"
echo "source \$UCL_CONDA_PATH/etc/profile.d/conda.sh" >> "$NEW_JOB_SCRIPT"

cat "$JOB_SCRIPT" >> "$NEW_JOB_SCRIPT"

qsub "${@:1:$#-1}" "$NEW_JOB_SCRIPT"
