#!/bin/bash

# Import common stuff
source /scratch/$USER/overlay/scripts/common/common.sh

# Sanitize pass-thru arguments
args=$(get_sanitized_passthru_args)
#sif="/scratch/$USER/overlay/sif/cuda11.3.0-cudnn8-opengl-devel-ubuntu20.04.sif"
sif="/scratch/$USER/overlay/sif/cuda10.1-opengl-devel-ubuntu16.04.sif"

soundspaces_dir="/scratch/work/marl/datasets/soundspaces"
soundspaces_base_sqf="$soundspaces_dir/sqf/soundspaces-base.sqf"
replica_scene_datasets_sqf="$soundspaces_dir/sqf/soundspaces-scene_datasets-replica.sqf"
mp3d_scene_datasets_sqf="$soundspaces_dir/sqf/soundspaces-scene_datasets-mp3d.sqf"
replica_binaural_rirs_sqf="$soundspaces_dir/sqf/soundspaces-binaural_rirs-replica.sqf"
soundspaces_data_dir="/ext3/code/sound-spaces/data"

for fname in datasets metadata sounds pretrained_weights; do
    data_overlay_opts="$data_overlay_opts --bind $soundspaces_base_sqf:$soundspaces_data_dir/$fname:image-src=/soundspaces-base/$fname,ro"
done
data_overlay_opts="$data_overlay_opts --bind $replica_scene_datasets_sqf:$soundspaces_data_dir/scene_datasets/replica:image-src=/soundspaces-scene_datasets-replica,ro"
data_overlay_opts="$data_overlay_opts --bind $mp3d_scene_datasets_sqf:$soundspaces_data_dir/scene_datasets/mp3d:image-src=/soundspaces-scene_datasets-mp3d/mp3d,ro"
data_overlay_opts="$data_overlay_opts --bind $replica_binaural_rirs_sqf:$soundspaces_data_dir/binaural_rirs/replica:image-src=/soundspaces-binaural_rirs-replica,ro"
data_overlay_opts="$data_overlay_opts $(find $soundspaces_dir/sqf -type f -name "soundspaces-binaural_rirs-mp3d.part-*.sqf" | while read line; do part_num=$(echo $line | xargs | sed "s|.*part-\([0-9]*\)\.sqf|\1|g"); echo "--bind $line:/soundspaces-binaural_rirs-mp3d/$part_num:image-src=/soundspaces-binaural_rirs-mp3d.part-$part_num,ro"; done)"

# Cached observations
data_overlay_opts="$data_overlay_opts --bind /scratch/$USER/soundspaces/scene_observations/audionav-telephone-pointgoal_rgb:$soundspaces_data_dir/scene_observations"


singularity exec \
            --nv \
            --overlay $pyenvs_dir/soundspaces-10GB-400K.ext3 \
            $data_overlay_opts \
            $sif bash -c "$(get_launch_init_cmds); $args"
