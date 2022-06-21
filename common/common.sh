#!/bin/bash

sif_dir="/scratch/jtc440/overlay/sif"
common_dir="/scratch/jtc440/overlay/scripts/common"
launch_dir="/scratch/jtc440/overlay/scripts/launch"
jupyter_dir="/scratch/jtc440/overlay/scripts/jupyter"
pyenvs_dir="/scratch/jtc440/overlay/pyenvs"
sqf_dir="/scratch/jtc440/sqfdata"

# Useful boilerplate commands
env_load_cmds="if [[ -r \"/ext3/env.sh\" ]]; then source /ext3/env.sh && echo \"loaded singularity environment\"; fi"


parse_bool () {
    val=$1
    default_val=$2
    if [[ -z "$default_val" ]]; then
        default_val="false"
    fi

    if [[ -z "$val" ]]; then
        echo "$default_val"
    elif [[ ("$val" -eq 1) || ("$val" == "true") ]]; then
        echo "true"
    elif [[ ("$val" -eq 0) || ("$val" == "false") ]]; then
        echo "false"
    else
        echo "Invalid bool value, must be 1/true or 0/false"
        exit -1;
    fi
}

cond_str () {
    val=$(parse_bool "$1" "$4")
    true_val=$2
    false_val=$3

    if [[ "$val" == "true" ]]; then
        echo $true_val
    else
        echo $false_val
    fi
}

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
    # MUST PASS IN $@ as argument
    args=''
    for i in "$@"; do
        i="${i//\\/\\\\}"
        args="$args \"${i//\"/\\\"}\""
    done

    if [ "$args" == "" ]; then args="/bin/bash"; fi
    echo $args
}


get_sqf_overlay_args () {
    subset=$1
    local all_sqf_dir=$sqf_dir
    if [[ ! -z $2 ]]; then
        all_sqf_dir=$2
    fi

    echo $(find $all_sqf_dir/$subset -type f -name "*.sqf" | while read line; do echo -n "--overlay $line:ro "; done)

}
