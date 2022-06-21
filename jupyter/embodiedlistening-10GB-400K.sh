#!/bin/bash

#SBATCH --job-name=jupyter
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=12GB
#SBATCH --time=10:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=$USER@nyu.edu

# Import common stuff
source /scratch/jtc440/overlay/scripts/common/common.sh

bash $jupyter_dir/launchnb.sh $launch_dir/embodiedlistening-10GB-400K.sh
