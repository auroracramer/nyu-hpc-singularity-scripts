#!/bin/bash

#SBATCH --job-name=hearsetup
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8GB
#SBATCH --time=4:00:00
#SBATCH --output="/scratch/%u/logs/setup-hear2021-overlay_%A-%a.out"

# Author : Aurora Cramer
# Date   : Nov 2022
# NetID  : jtc440

set -e

NUM_CORES=$SLURM_CPUS_PER_TASK
NUM_WORKERS=$((NUM_CORES > 1 ? NUM_CORES - 1 : 1))

PYENVS_DIR="/scratch/jtc440/overlay/pyenvs"
BASE_OVERLAY="/scratch/work/public/overlay-fs-ext3/overlay-10GB-400K.ext3.gz"
BASE_OVERLAY_FNAME="$(basename $BASE_OVERLAY .gz)"

ENV_OVERLAY="$PYENVS_DIR/ytasmr300k-dl.ext3"
SIF_PATH="/scratch/work/public/singularity/cuda11.0-cudnn8-devel-ubuntu18.04.sif"


CONDADIR="/ext3/miniconda3"
CODEDIR="/ext3/code"
TMPDIR="/state/partition1/$SLURM_JOB_ID-tmp"
BINDIR="/ext3/bin"
mkdir -p $TMPDIR

if [[ -f "$ENV_OVERLAY" ]]; then
    echo "! overlay ext3 exists, backing up"
    mv $ENV_OVERLAY ${ENV_OVERLAY}.bak
fi

echo "- copying overlay ext3"
cp $BASE_OVERLAY $PYENVS_DIR
gunzip $PYENVS_DIR/${BASE_OVERLAY_FNAME}.gz
mv $PYENVS_DIR/${BASE_OVERLAY_FNAME} $ENV_OVERLAY

singularity exec --overlay $ENV_OVERLAY $SIF_PATH /bin/bash << EOF
set -e

# Set up miniconda
if [[ ! -d "$CONDADIR" ]]; then
    cd /ext3
    if [[ ! -f "Miniconda3-latest-Linux-x86_64.sh" ]]; then
        wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
    fi
    bash Miniconda3-latest-Linux-x86_64.sh -b -p $CONDADIR
fi
source $CONDADIR/etc/profile.d/conda.sh

exit 0;
EOF

# Restart singularity so conda stuff works
singularity exec --overlay $ENV_OVERLAY $SIF_PATH /bin/bash << EOF
set -e

source $CONDADIR/etc/profile.d/conda.sh
export PATH="$BINDIR:$CONDADIR/bin:\$PATH"

# Set up environment script
mkdir -p $BINDIR
cat > /ext3/env.sh <<EOL
#!/bin/bash

source $CONDADIR/etc/profile.d/conda.sh
export PATH="\\\$PATH:$BINDIR:$CONDADIR/bin"

conda activate yt-asmr
EOL

source $CONDADIR/etc/profile.d/conda.sh
export PATH="\$PATH:$BINDIR:$CONDADIR/bin"
# Set up code dir
mkdir -p $CODEDIR
cd $CODEDIR

git clone https://github.com/karreny/telling-left-from-right.git

cd $CODEDIR/telling-left-from-right
git checkout dataset

# Create python environment
if [[ -z "\$(conda env list | grep -F yt-asmr)" ]]; then
    conda env create -n yt-asmr -f $CODEDIR/telling-left-from-right/environment.yml
fi

conda activate yt-asmr
yes | conda install -c conda-forge sox

EOF
