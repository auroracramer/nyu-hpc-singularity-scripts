#!/bin/bash

# Import common stuff
source /scratch/$USER/overlay/scripts/common/common.sh

# Sanitize pass-thru arguments
args=$(get_sanitized_passthru_args)

# Initialize prince configuration
source $common_dir/prince_init.sh
data_overlay_opts="$(find $sqf_dir/birdvox -type f -name "birdvox-*" | while read line; do echo "--overlay $line:ro"; done)"

singularity exec $nv \
            --bind $binds \
            --bind /scratch/work/public/apps/prince/90-environment.sh:/.singularity.d/env/90-environment.sh:ro \
            --overlay $overlays \
            --overlay $pyenvs_dir/birdvox-10GB-400K.ext3 \
            $data_overlay_opts \
            $sif bash -c "$prince_setup_cmds; $(get_launch_init_cmds); $args"
