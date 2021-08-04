#!/bin/bash

common_dir="/scratch/$USER/overlay/scripts/common"
launch_dir="/scratch/$USER/overlay/scripts/launch"
jupyter_dir="/scratch/$USER/overlay/scripts/jupyter"
pyenvs_dir="/scratch/$USER/overlay/pyenvs"
sqf_dir="/scratch/$USER/sqfdata"

# Useful boilerplate commands
env_load_cmds="if [[ -r \"/ext3/env.sh\" ]]; then source /ext3/env.sh && echo \"loaded singularity environment\"; fi"


get_launch_init_cmds () {
    # Call via `init_cmds="$(get_launch_init_cmds)"
    if [[ -z "$LAUNCH_SOURCE_ENV" || "$LAUNCH_SOURCE_ENV" = false ]]; then
        local init_cmds=""
    else
        local init_cmds="$env_load_cmds"
    fi
    echo "$env_load_cmds"
}


get_sanitized_passthru_args () {
    args=''
    for i in "$@"; do
        i="${i//\\/\\\\}"
        args="$args \"${i//\"/\\\"}\""
    done

    if [ "$args" == "" ]; then args="/bin/bash"; fi
    echo $args
}
