#!/bin/bash

# Import common stuff
source /scratch/$USER/overlay/scripts/common/common.sh

# Sanitize pass-thru arguments
args=$(get_sanitized_passthru_args)
sif="/scratch/work/public/singularity/cuda11.3.0-cudnn8-devel-ubuntu20.04.sif"

data_overlay_opts=""
#data_overlay_opts="--overlay $sqf_dir/speech"

singularity exec \
            --nv \
            --overlay $pyenvs_dir/embodiedlistening-10GB-400K.ext3 \
            $data_overlay_opts \
            $sif bash -c "$(get_launch_init_cmds); $args"
