#!/bin/bash

#SBATCH --job-name=jupyter
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8GB
#SBATCH --time=04:00:00

if [[ ! ("$WRITABLE" = 0 || "$WRITABLE" = "true") ]]; then
    SUFFIX="-readonly"
fi

# Import common stuff
source /scratch/$USER/overlay/scripts/common/common.sh

bash $jupyter_dir/launchnb.sh $launch_dir/birdvox-10GB-400K${SUFFIX}.sh /ext3/code
