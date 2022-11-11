#!/bin/bash

# Import common stuff
source /scratch/jtc440/overlay/scripts/common/common.sh

# Sanitize pass-thru arguments
args=$(get_sanitized_passthru_args)

# Process envvar flags
WRITABLE=$(parse_bool "$WRITABLE" "false")
ext3_suffix=$(cond_str "$WRITABLE" "" ":ro")
sif="/scratch/work/public/singularity/cuda11.0-cudnn8-devel-ubuntu18.04.sif"
pyenv="/scratch/jtc440/overlay/pyenvs/ytasmr300k-dl.ext3"


if [[ "$WRITABLE" == "true" ]]; then
    echo "loading singularity environment in WRITABLE mode"
else
    echo "loading singularity environment in READ-ONLY mode"
fi

singularity exec \
            --overlay ${pyenv}${ext3_suffix} \
            $sif bash -c "$(get_launch_init_cmds); $args"
