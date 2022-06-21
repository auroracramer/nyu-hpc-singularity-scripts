#!/bin/bash

#SBATCH --job-name=hearsetup
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4GB
#SBATCH --time=3:00:00
#SBATCH --output="/scratch/%u/logs/setup-hear2021-overlay_%A-%a.out"

# Author : Aurora Cramer
# Date   : Jun 2022
# NetID  : jtc440

set -e


PYENVS_DIR="/scratch/jtc440/overlay/pyenvs"
BASE_OVERLAY="/scratch/work/public/overlay-fs-ext3/overlay-10GB-400K.ext3.gz"
BASE_OVERLAY_FNAME="$(basename $BASE_OVERLAY .gz)"

ENV_OVERLAY="$PYENVS_DIR/embodied-listening-eval.ext3"
SIF_PATH="/scratch/jtc440/overlay/sif/embodied-listening-eval.sif"


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

# Create python environment
if [[ -z "\$(conda env list | grep -F embodied-listening-eval)" ]]; then
    conda create -y -n embodied-listening-eval python=3.8
fi

# Set up environment script
mkdir -p $BINDIR
cat > /ext3/env.sh <<EOL
#!/bin/bash

source $CONDADIR/etc/profile.d/conda.sh
export PATH="\\\$PATH:$BINDIR:$CONDADIR/bin"

conda activate embodied-listening-eval
EOL

source /ext3/env.sh

# Set up code dir
mkdir -p $CODEDIR
cd $CODEDIR

# Manually install certain packages
if [[ ! -f "$BINDIR/ffmpeg" ]]; then
    # install yasm
    conda install -y -c conda-forge yasm
    # Install libsoxr
    if [[ ! -d "$CODEDIR/soxr" ]]; then
        git clone https://github.com/chirlu/soxr.git
    fi
    mkdir -p $CODEDIR/soxr/build/lib
    cd $CODEDIR/soxr/build
    cmake -Wno-dev -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=$CODEDIR/soxr/build/output ..
    make && make test && make install
    # Install ffmpeg
    cd $CODEDIR
    if [[ ! -d "$CODEDIR/ffmpeg-4.4" ]]; then
        if [[ ! -f "$CODEDIR/ffmpeg-4.4.tar.gz" ]]; then
            wget https://www.ffmpeg.org/releases/ffmpeg-4.4.tar.gz
        fi
        tar xvfz ffmpeg-4.4.tar.gz
    fi
    ffmpeg_build_dir="$CODEDIR/ffmpeg_build"
    mkdir -p \$ffmpeg_build_dir/lib
    cd $CODEDIR/ffmpeg-4.4

    PATH="$BINDIR:\$PATH" PKG_CONFIG_PATH="$CODEDIR/lib/pkgconfig" ./configure \
      --prefix="\$ffmpeg_build_dir" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$CODEDIR/soxr/build/output/include" \
      --extra-ldflags="-L$CODEDIR/soxr/build/output/lib" \
      --extra-libs="-lpthread -lm" \
      --ld="g++" \
      --bindir="$BINDIR" \
      --enable-libsoxr
    PATH="$BINDIR:\$PATH" make && make install
    cd $CODEDIR
fi
conda install -y -c conda-forge squashfs-tools
yes | pip install intervaltree
yes | pip install hearvalidator

# Clone relevant repos if not cloned
if [[ ! -d "$CODEDIR/hear-eval-kit" ]]; then
    git clone https://github.com/hearbenchmark/hear-eval-kit.git
fi
if [[ ! -d "$CODEDIR/hear-baseline" ]]; then
    git clone https://github.com/hearbenchmark/hear-baseline.git
fi
if [[ ! -d "$CODEDIR/hear-preprocess" ]]; then
    git clone https://github.com/hearbenchmark/hear-preprocess.git
fi

# Install all of the packages
yes | python -m pip install -e $CODEDIR/hear-baseline
yes | python -m pip install -e $CODEDIR/hear-eval-kit
yes | python -m pip install -e $CODEDIR/hear-preprocess

EOF
