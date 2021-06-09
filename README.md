My personal framework for managing singularity environments on NYU's HPC.

# Conventions:
* `/scratch/$USER/overlay/scripts/common/` - "header" bash scripts
* `/scratch/$USER/overlay/scripts/launch/` - scripts for launching singularity containers with the associated data loaded. handles arguments being passed into the script to be launched in the container. note that these are not sbatch scripts.
* `/scratch/$USER/overlay/scripts/jupyter/` - scripts for launching jupyter notebooks. aside from `launchnb.sh` (which takes a launch script name as an argument), scripts generally expected to work as sbatch scripts
* `/scratch/$USER/overlay/scripts/setup/` - misc. scripts for setting up singularity containers
* `/scratch/$USER/overlay/pyenvs/` - directory of environment data volumes`(e.g. overlay-10GB-400K.ext3)
* `/scratch/$USER/logs/` - directory for logs
* `/scratch/$USER/jobs/` - directory for sbatch scripts, which generally invoke a launch script if using singularity environments
* `/scratch/$USER/sqfdata/` - directory for squashfs data (`.sqf` files)

