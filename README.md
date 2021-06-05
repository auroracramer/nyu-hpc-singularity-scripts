My personal framework for managing singularity environments on NYU's HPC.

# Conventions:
* `/scratch/$USER/overlay/pyenvs/` - directory of environment data volumes`(e.g. overlay-10GB-400K.ext3)
* `/scratch/$USER/overlay/scripts/common/` - "header" bash scripts for importing
* `/scratch/$USER/overlay/scripts/jupyter/` - scripts for launching jupyter notebooks
* `/scratch/$USER/overlay/scripts/launch/` - scripts for launch singularity containers
* `/scratch/$USER/overlay/scripts/setup/` - misc. scripts for setting up singularity containers
* `/scratch/$USER/logs/ - directory for logs
* `/scratch/$USER/jobs/ - directory for sbatch scripts
* `/scratch/$USER/sqfdata/ - directory for squashfs data (`.sqf` files)

