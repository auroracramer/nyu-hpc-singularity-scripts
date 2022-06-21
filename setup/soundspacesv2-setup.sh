#!/bin/bash

# Author : Aurora Cramer
# Date   : Jun 2022
# NetID  : jtc440

set -e

ENV_OVERLAY="/scratch/$USER/overlay/pyenvs/soundspacesv2-32GB-400K.ext3"
SIF_PATH="/scratch/$USER/overlay/sif/cuda10.1-opengl-devel-ubuntu16.04.sif"

CONDADIR="/ext3/miniconda3"
CODEDIR="/ext3/code"
TMPDIR="/state/partition1/$SLURM_JOB_ID-tmp"
BINDIR="/ext3/bin"
SQFDIR="/scratch/$USER/sqfdata/soundspaces"
DATADIR="$TMPDIR/soundspaces-workdir"

# Set up repo dirs
HABITAT_LAB_DIR="$CODEDIR/habitat-lab"
HABITAT_SIM_DIR="$CODEDIR/habitat-sim"
SOUNDSPACES_DIR="$CODEDIR/sound-spaces"
REPLICA_DIR="$CODEDIR/Replica-Dataset"

# Create new overlay for code
if [[ ! -f "$ENV_OVERLAY" ]]; then
    cp /scratch/work/public/overlay-fs-ext3/overlay-10GB-400K.ext3.gz $ENV_OVERLAY.gz
    gunzip $ENV_OVERLAY.gz
    # Extend overlay to 32GB
    e2fsck -f $ENV_OVERLAY
    resize2fs $ENV_OVERLAY 32G
fi

singularity exec --overlay $ENV_OVERLAY $SIF_PATH /bin/bash << EOF
set -e

mkdir -p $SQFDIR

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

# Create python environment
if [[ -z "\$(conda env list | grep -F soundspaces)" ]]; then
    conda create -y -n soundspaces python=3.8 cmake=3.14.0
fi

# Set up environment script
mkdir -p $BINDIR
cat > /ext3/env.sh <<EOL
#!/bin/bash

source $CONDADIR/etc/profile.d/conda.sh
export PATH="\\\$PATH:$BINDIR:$CONDADIR/bin"

conda activate soundspaces
EOL

# Environment hacks

# Create init script dirs
mkdir -p /ext3/miniconda3/envs/soundspaces/etc/conda/activate.d
mkdir -p /ext3/miniconda3/envs/soundspaces/etc/conda/deactivate.d

cat > /ext3/miniconda3/envs/soundspaces/etc/conda/activate.d/env_vars.sh <<EOL
export OLD_LD_LIBRARY_PATH=\\\${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH=/ext3/miniconda3/envs/soundspaces/lib:\\\${LD_LIBRARY_PATH}
EOL

cat > /ext3/miniconda3/envs/soundspaces/etc/conda/deactivate.d/env_vars.sh <<EOL
export LD_LIBRARY_PATH=\\\${OLD_LD_LIBRARY_PATH}
unset OLD_LD_LIBRARY_PATH
EOL

if [[ ! -f "/ext3/miniconda3/envs/soundspaces/etc/conda/activate.d/libblas_mkl_activate.sh" ]]; then

	cat > /ext3/miniconda3/envs/soundspaces/etc/conda/activate.d/libblas_mkl_activate.sh <<EOL
export CONDA_MKL_INTERFACE_LAYER_BACKUP=\\\${MKL_INTERFACE_LAYER}
export MKL_INTERFACE_LAYER=LP64,GNU
EOL

fi

if [[ ! -f "/ext3/miniconda3/envs/soundspaces/etc/conda/deactivate.d/libblas_mkl_deactivate.sh" ]]; then

	cat > /ext3/miniconda3/envs/soundspaces/etc/conda/deactivate.d/libblas_mkl_deactivate.sh <<EOL
if [ "${CONDA_MKL_INTERFACE_LAYER_BACKUP}" = "" ]
then
   unset MKL_INTERFACE_LAYER
else
   export MKL_INTERFACE_LAYER=${CONDA_MKL_INTERFACE_LAYER_BACKUP}
fi
unset CONDA_MKL_INTERFACE_LAYER_BACKUP
EOL

fi


source /ext3/env.sh

conda install -y numpy pyyaml scipy ipython mkl mkl-include libgcc libstdcxx-ng -n soundspaces
conda install -y -c conda-forge squashfs-tools -n soundspaces
conda update -y libstdcxx-ng -n soundspaces
conda clean -ya

# Set up code dir
mkdir -p $CODEDIR
cd $CODEDIR

# Install habitat-sim
# ! we're installing v0.2.2 despite docs saying v0.2.1 since the latter doesn't
# ! actually have the --audio flag
if [[ ! -d "$HABITAT_SIM_DIR" ]]; then
    git clone -b v0.2.2 git@github.com:facebookresearch/habitat-sim.git
fi
pip install -r $HABITAT_SIM_DIR/requirements.txt
pushd $HABITAT_SIM_DIR
# Need the --parallel 2 so we don't segfault
python setup.py build_ext --headless --audio --parallel 2
python setup.py install --headless --audio
popd

# Install habitat-lab
if [[ ! -d "$HABITAT_LAB_DIR" ]]; then
    git clone -b v0.2.2 git@github.com:facebookresearch/habitat-lab.git
fi
pip install -e $HABITAT_LAB_DIR

# Install soundspaces
if [[ ! -d "$SOUNDSPACES_DIR" ]]; then
    git clone git@github.com:marl/sound-spaces.git
    pushd $SOUNDSPACES_DIR
    # Checkout Soundspaces 2.0 (latest as of 20220621)
    git checkout 81ec95cb809b639f2126cb4435f229dbd2f23871
    popd

fi
# NOTE: pip might complain about gym being the wrong version for habitat. This
#       might be okay since SoundSpaces requires an older version?
pip install -e $SOUNDSPACES_DIR

EOF
