set -e
CONDADIR="/ext3/miniconda3"
CODEDIR="/ext3/code"
TMPDIR="/state/partition1/$SLURM_JOB_ID-tmp"
BINDIR="/ext3/bin"
SQFDIR="/scratch/$USER/sqfdata/soundspaces"
DATADIR="$TMPDIR/embodiedlistening-workdir"
mkdir -p $SQFDIR
mkdir -p $WORKDIR

# Set up miniconda
if [[ ! -d "$CONDADIR" ]]; then
    cd /ext3
    wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b -p $CONDADIR
fi

# Create python environment
if [[ -z "$(conda env list | grep -F embodiedlistening)" ]]; then
    # NOTE: We're using 3.7 instead of 3.6 since 3.6 is EoL soon
    conda create -y -n embodiedlistening python=3.7 cmake=3.14.0
fi

# Set up environment script
mkdir -p $BINDIR
cat > /ext3/env.sh <<EOL
#!/bin/bash

source $CONDADIR/etc/profile.d/conda.sh
export PATH="$BINDIR:$CONDADIR/bin:\$PATH"

conda activate embodiedlistening

EOL
source /ext3/env.sh

# If you're setting up conda for the first time, you'll have to restart singularity

conda install -y habitat-sim==0.1.7 withbullet headless -c conda-forge -c aihabitat
conda install -y -c conda-forge squashfs-tools

# Set up code dir
mkdir -p $CODEDIR
cd $CODEDIR

# Set up repo dirs
HABITAT_LAB_DIR="$CODEDIR/habitat-lab"
SOUNDSPACES_DIR="$CODEDIR/sound-spaces"
REPLICA_DIR="$CODEDIR/Replica-Dataset"


# Install habitat-lab
if [[ ! -d "$HABITAT_LAB_DIR" ]]; then
    git clone -b v0.1.7 git@github.com:facebookresearch/habitat-lab.git
fi
pip install -e $HABITAT_LAB_DIR

# Install soundspaces
if [[ ! -d "$SOUNDSPACES_DIR" ]]; then
    git clone -b v0.1.2 git@github.com:facebookresearch/sound-spaces.git
fi
# NOTE: pip might complain about gym being the wrong version for habitat. This
#       might be okay since SoundSpaces requires an older version?
pip install -e $SOUNDSPACES_DIR

#SOUNDSPACES_DATA_DIR="$DATADIR/data"
#mkdir -p $SOUNDSPACES_DATA_DIR
#pushd $SOUNDSPACES_DATA_DIR
#wget http://dl.fbaipublicfiles.com/SoundSpaces/binaural_rirs.tar && tar xvf binaural_rirs.tar
#wget http://dl.fbaipublicfiles.com/SoundSpaces/metadata.tar.xz && tar xvf metadata.tar.xz
#wget http://dl.fbaipublicfiles.com/SoundSpaces/sounds.tar.xz && tar xvf sounds.tar.xz
#wget http://dl.fbaipublicfiles.com/SoundSpaces/datasets.tar.xz && tar xvf datasets.tar.xz
#wget http://dl.fbaipublicfiles.com/SoundSpaces/pretrained_weights.tar.xz && tar xvf pretrained_weights.tar.xz
#rm $SOUNDSPACES_DATA_DIR/*.tar.xz
#popd

