#!/bin/bash

# Author : Aurora Cramer
# Date   : Jun 2022
# NetID  : jtc440

set -e

ENV_OVERLAY="/scratch/$USER/overlay/pyenvs/soundspacesv2-32GB-400K.ext3"
SIF_PATH="/scratch/$USER/overlay/sif/cuda10.2-opengl-devel-ubuntu18.04.sif"

CONDADIR="/ext3/miniconda3"
CODEDIR="/ext3/code"
LIBDIR="/ext3/lib"
TMPDIR="/state/partition1/$SLURM_JOB_ID-tmp"
BINDIR="/ext3/bin"
SQFDIR="/scratch/$USER/sqfdata/soundspaces"

#SOUNDSPACES_SQF_DIR="/scratch/work/marl/datasets/soundspaces/sqf"
SOUNDSPACES_SQF_DIR="/scratch/work/marl/datasets/soundspaces/sqf-20220623"
DATADIR="$TMPDIR/soundspaces-workdir"
NUM_CORES=$SLURM_CPUS_PER_TASK

mkdir $TMPDIR

# Set up repo dirs
HABITAT_LAB_DIR="$CODEDIR/habitat-lab"
HABITAT_SIM_DIR="$CODEDIR/habitat-sim"
SOUNDSPACES_DIR="$CODEDIR/sound-spaces"
REPLICA_DIR="$CODEDIR/Replica-Dataset"
GLIBC_DIR="$CODEDIR/glibc-2.29"

# Create new overlay for code
if [[ ! -f "$ENV_OVERLAY" ]]; then
    cp /scratch/work/public/overlay-fs-ext3/overlay-10GB-400K.ext3.gz $ENV_OVERLAY.gz
    gunzip $ENV_OVERLAY.gz
    # Extend overlay to 32GB
    e2fsck -y -f $ENV_OVERLAY
    resize2fs $ENV_OVERLAY 32G
fi

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

# Create python environment
if [[ -z "\$(conda env list | grep -F soundspaces)" ]]; then
    conda create -y -n soundspaces python=3.8 cmake=3.14.0
fi

# Set up environment script
mkdir -p $BINDIR
mkdir -p $LIBDIR
cat > /ext3/env.sh <<EOL
#!/bin/bash

source $CONDADIR/etc/profile.d/conda.sh
export PATH="\\\$PATH:$BINDIR:$CONDADIR/bin"

# To suppress benign Tensorflow CUDA warnings
export TF_CPP_MIN_LOG_LEVEL=2

conda activate soundspaces
EOL

# Environment hacks

# Create init script dirs
mkdir -p /ext3/miniconda3/envs/soundspaces/etc/conda/activate.d
mkdir -p /ext3/miniconda3/envs/soundspaces/etc/conda/deactivate.d

cat > /ext3/miniconda3/envs/soundspaces/etc/conda/activate.d/env_vars.sh <<EOL
export OLD_LD_LIBRARY_PATH=\\\${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH=/ext3/miniconda3/envs/soundspaces/lib:$LIBDIR:\\\${LD_LIBRARY_PATH}
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

#conda install -y numpy pyyaml scipy ipython mkl mkl-include libgcc libstdcxx-ng -n soundspaces
#conda update -y libstdcxx-ng -n soundspaces
conda install -y numpy pyyaml scipy ipython mkl mkl-include -n soundspaces # habitat
conda install -y -c conda-forge squashfs-tools -n soundspaces # squashfs
conda install -y gawk bison -n soundspaces # glibc
conda install -y -c conda-forge ifcfg -n soundspaces # soundspaces
conda install -y pytorch==1.11.0 torchvision==0.12.0 torchaudio==0.11.0 cudatoolkit=10.2 -c pytorch -n soundspaces # make sure PyTorch is compatible with CUDA 10.2
conda clean -ya

# Set up code dir
mkdir -p $CODEDIR
cd $CODEDIR

# Build glibc 2.29 (
if [[ ! -d "$GLIBC_DIR" ]]; then
    wget http://ftp.gnu.org/gnu/glibc/glibc-2.29.tar.gz
    tar xzf glibc-2.29.tar.gz
    pushd $GLIBC_DIR
    mkdir build
    pushd build
    ../configure --prefix=/ext3/local
    make -j $NUM_CORES
    popd
    popd

    cp $GLIBC_DIR/build/math/libm.so.6 $LIBDIR
fi

# Install habitat-sim
# ! we're installing v0.2.2 despite docs saying v0.2.1 since the latter doesn't
# ! actually have the --audio flag
if [[ ! -d "$HABITAT_SIM_DIR" ]]; then
    git clone -b v0.2.2 git@github.com:facebookresearch/habitat-sim.git
fi
yes | pip install -r $HABITAT_SIM_DIR/requirements.txt
pushd $HABITAT_SIM_DIR
# Need the --parallel so we don't segfault
python setup.py build_ext --headless --audio --with-cuda --bullet --parallel $NUM_CORES install
popd

# Install habitat-lab
if [[ ! -d "$HABITAT_LAB_DIR" ]]; then
    git clone -b v0.2.2 git@github.com:facebookresearch/habitat-lab.git
fi
yes | pip install -e $HABITAT_LAB_DIR

# Install soundspaces
if [[ ! -d "$SOUNDSPACES_DIR" ]]; then
    git clone git@github.com:marl/sound-spaces.git
    pushd $SOUNDSPACES_DIR
    # Checkout main branch of Soundspaces 2.0
    # latest commit as of 20220706 is 4e400abaf65c7759a287355386dcd97de2b17e2b
    # (check diffs from now to then if issues come up)
    git checkout main
    popd

fi
# NOTE: pip might complain about gym being the wrong version for habitat. This
#       might be okay since SoundSpaces requires an older version?
yes | pip install -e $SOUNDSPACES_DIR

# Install other necessary pip packages
yes | pip install torchvision
EOF


data_overlay_opts="$(find $SOUNDSPACES_SQF_DIR -type f -name "soundspaces-binaural_rirs-mp3d.part-*.sqf" | while read line; do part_num=$(echo $line | xargs | sed "s|.*part-\([0-9]*\)\.sqf|\1|g"); echo "--bind $line:/soundspaces-binaural_rirs-mp3d/$part_num:image-src=/soundspaces-binaural_rirs-mp3d.part-$part_num,ro"; done)"

# Restart singularity so conda stuff works
singularity exec --overlay $ENV_OVERLAY $data_overlay_opts $SIF_PATH /bin/bash << EOF
set -e

# set up soundspaces data links, only necessary for MP3D RIRs
mkdir -p $SOUNDSPACES_DIR/data/binaural_rirs/mp3d
ln -s /soundspaces-binaural_rirs-mp3d/**/* $SOUNDSPACES_DIR/data/binaural_rirs/mp3d/

EOF

# Set permissions
singularity exec --overlay $ENV_OVERLAY $SIF_PATH /bin/bash << EOF
source /ext3/env.sh

chmod -R o=u /ext3/* || true

EOF

chmod 644 $ENV_OVERLAY
setfacl -m u:sd5397:rw $ENV_OVERLAY
