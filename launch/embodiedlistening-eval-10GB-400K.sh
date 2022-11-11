#!/bin/bash

# Import common stuff
source /scratch/jtc440/overlay/scripts/common/common.sh

# Sanitize pass-thru arguments
args=$(get_sanitized_passthru_args)

if [[ "$(hostname)" =~ ^g ]]; then nv="--nv"; fi

# Process envvar flags
WRITABLE=$(parse_bool "$WRITABLE" "false")
ext3_suffix=$(cond_str "$WRITABLE" "" ":ro")
OVERLAY_EVAL_DATASETS=$(parse_bool "$OVERLAY_HEAR2021_DATASETS" "true")

sif="$sif_dir/embodied-listening-eval.sif"
SQF_HEAR2021="$sqf_dir/embodied-listening-eval"
LOCAL_HEAR2021_DIR="/scratch/jtc440/hear2021"


# Set up overlay arguments for evaluation datasets
if [[ "$OVERLAY_EVAL_DATASETS" == "true" ]]; then
    echo "overlaying eval datasets"
    #data_overlay_opts="$data_overlay_opts $(get_sqf_overlay_args "embodied-listening-eval")"
    data_overlay_opts="$data_overlay_opts $(get_sqf_bind_args "embodied-listening-eval" "/ext3/data/hear2021/tasks")"
    # Bind the local tasks so we can use them easily
    if [[ -d "$LOCAL_HEAR2021_DIR/tasks" ]]; then
        data_overlay_opts="$data_overlay_opts $(get_dir_bind_args "$LOCAL_HEAR2021_DIR/tasks" "/ext3/data/hear2021/tasks")"
    fi
    # Bind local embeddings
    if [[ -d "$LOCAL_HEAR2021_DIR/embeddings" ]]; then
        data_overlay_opts="$data_overlay_opts --bind $LOCAL_HEAR2021_DIR/embeddings:/ext3/data/hear2021/embeddings "
    fi
fi


if [[ "$WRITABLE" == "true" ]]; then
    echo "loading singularity environment in WRITABLE mode"
else
    echo "loading singularity environment in READ-ONLY mode"
fi

singularity exec $nv \
            $data_overlay_opts \
            --overlay $pyenvs_dir/embodied-listening-eval.ext3${ext3_suffix} \
            $sif bash -c "$(get_launch_init_cmds); $args"
