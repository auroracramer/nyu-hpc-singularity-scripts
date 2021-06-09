#!/bin/bash

common_dir="/scratch/$USER/overlay/scripts/common"
launch_dir="/scratch/$USER/overlay/scripts/launch"
jupyter_dir="/scratch/$USER/overlay/scripts/jupyter"
pyenvs_dir="/scratch/$USER/overlay/pyenvs"
sqf_dir="/scratch/$USER/sqfdata"

# Useful boilerplate commands
env_load_cmds="if [[ -r \"/ext3/env.sh\" ]]; then source /ext3/env.sh && echo \"loaded singularity environment\"; fi"
