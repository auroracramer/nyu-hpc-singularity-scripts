#!/bin/bash

# Import common stuff
source /scratch/jtc440/overlay/scripts/common/common.sh

# Sanitize pass-thru arguments
args=$(get_sanitized_passthru_args)

if [[ "$(hostname)" =~ ^g ]]; then nv="--nv"; fi

# Process envvar flags
WRITABLE=$(parse_bool "$WRITABLE" "false")
ext3_suffix=$(cond_str "$WRITABLE" "" ":ro")
OVERLAY_SS_DATASET=$(parse_bool "$OVERLAY_SS_DATASET" "true")
OVERLAY_SS_CACHED_OBS=$(parse_bool "$OVERLAY_SS_CACHED_OBS" "false")
if [[ -z "$CACHED_OBS_DIR" ]]; then
    CACHED_OBS_DIR="/scratch/jtc440/soundspaces/scene_observations/audionav-telephone-pointgoal_rgb"
fi


sif="/scratch/jtc440/overlay/sif/cuda10.1-opengl-devel-ubuntu16.04.sif"

soundspaces_dir="/scratch/work/marl/datasets/soundspaces"
soundspaces_base_sqf="$soundspaces_dir/sqf/soundspaces-base.sqf"
replica_scene_datasets_sqf="$soundspaces_dir/sqf/soundspaces-scene_datasets-replica.sqf"
mp3d_scene_datasets_sqf="$soundspaces_dir/sqf/soundspaces-scene_datasets-mp3d.sqf"
replica_binaural_rirs_sqf="$soundspaces_dir/sqf/soundspaces-binaural_rirs-replica.sqf"
soundspaces_data_dir="/ext3/code/sound-spaces/data"


# Set up overlay arguments for SoundSpaces datasets
if [[ "$OVERLAY_SS_DATASET" == "true" ]]; then
    echo "overlaying soundspaces datasets"
    for fname in datasets metadata sounds pretrained_weights; do
        data_overlay_opts="$data_overlay_opts --bind $soundspaces_base_sqf:$soundspaces_data_dir/$fname:image-src=/soundspaces-base/$fname,ro"
    done
    data_overlay_opts="$data_overlay_opts --bind $replica_scene_datasets_sqf:$soundspaces_data_dir/scene_datasets/replica:image-src=/soundspaces-scene_datasets-replica,ro"
    data_overlay_opts="$data_overlay_opts --bind $mp3d_scene_datasets_sqf:$soundspaces_data_dir/scene_datasets/mp3d:image-src=/soundspaces-scene_datasets-mp3d/mp3d,ro"
    data_overlay_opts="$data_overlay_opts --bind $replica_binaural_rirs_sqf:$soundspaces_data_dir/binaural_rirs/replica:image-src=/soundspaces-binaural_rirs-replica,ro"
    data_overlay_opts="$data_overlay_opts $(find $soundspaces_dir/sqf -type f -name "soundspaces-binaural_rirs-mp3d.part-*.sqf" | while read line; do part_num=$(echo $line | xargs | sed "s|.*part-\([0-9]*\)\.sqf|\1|g"); echo "--bind $line:/soundspaces-binaural_rirs-mp3d/$part_num:image-src=/soundspaces-binaural_rirs-mp3d.part-$part_num,ro"; done)"
fi

# Set up overlay arguments for cached observations
if [[ "$OVERLAY_SS_CACHED_OBS" == "true" ]]; then
    echo "overlaying cached observations"
    # Cached observations
    data_overlay_opts="$data_overlay_opts --bind $CACHED_OBS_DIR:$soundspaces_data_dir/scene_observations"
fi


if [[ "$WRITABLE" == "true" ]]; then
    echo "loading singularity environment in WRITABLE mode"
else
    echo "loading singularity environment in READ-ONLY mode"
fi

singularity exec $nv \
            $data_overlay_opts \
            --overlay $pyenvs_dir/soundspaces-10GB-400K.ext3${ext3_suffix} \
            $sif bash -c "$(get_launch_init_cmds); $args"
