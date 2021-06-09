#!/bin/bash

#SBATCH --job-name=jupyter
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8GB
#SBATCH --time=04:00:00

# Import common stuff
source /scratch/$USER/overlay/scripts/common/common.sh

bash $jupyter_dir/launchnb.sh $launch_dir/sssle-10GB-400K.sh /ext3/code
