#!/bin/bash

#SBATCH --job-name=hearsetup
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8GB
#SBATCH --time=3:00:00
#SBATCH --output="/scratch/%u/logs/setup-hear2021-overlay_%A-%a.out"

# Author : Aurora Cramer
# Date   : Jun 2022
# NetID  : jtc440

set -e

NUM_CORES=$SLURM_CPUS_PER_TASK
NUM_WORKERS=$((NUM_CORES > 1 ? NUM_CORES - 1 : 1))

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
    pushd $CODEDIR/soxr/build
    cmake -Wno-dev -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=$CODEDIR/soxr/build/output ..
    make -j $NUM_WORKERS && make test && make install
    popd
    # Install ffmpeg
    if [[ ! -d "$CODEDIR/ffmpeg-4.4" ]]; then
        if [[ ! -f "$CODEDIR/ffmpeg-4.4.tar.gz" ]]; then
            wget https://www.ffmpeg.org/releases/ffmpeg-4.4.tar.gz
        fi
        tar xvfz ffmpeg-4.4.tar.gz
    fi
    ffmpeg_build_dir="$CODEDIR/ffmpeg_build"
    mkdir -p \$ffmpeg_build_dir/lib

    pushd $CODEDIR/ffmpeg-4.4
    PATH="$BINDIR:\$PATH" PKG_CONFIG_PATH="$CODEDIR/lib/pkgconfig" ./configure \
      --prefix="\$ffmpeg_build_dir" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$CODEDIR/soxr/build/output/include" \
      --extra-ldflags="-L$CODEDIR/soxr/build/output/lib" \
      --extra-libs="-lpthread -lm" \
      --ld="g++" \
      --bindir="$BINDIR" \
      --enable-libsoxr
    PATH="$BINDIR:\$PATH" make -j $NUM_WORKERS && make install
    popd
fi
conda install -y -c conda-forge squashfs-tools
conda install -y zip
yes | pip install soundata
yes | pip install intervaltree
yes | pip install hearvalidator

# Build IEM ambisonics plugins
if [[ ! -d "$CODEDIR/IEMPluginSuite" ]]; then
    git clone --recurse-submodules --shallow-submodules https://git.iem.at/audioplugins/IEMPluginSuite.git
	pushd "$CODEDIR/IEMPluginSuite"
	mkdir build
	cd build
	mkdir -p /ext3/vst3
	cmake .. -DIEM_BUILD_VST3=ON -DIEM_BUILD_VST2=OFF -DIEM_BUILD_STANDALONE=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ext3/vst3
	cmake --build . -- -j $NUM_WORKERS
	popd
fi

# Install pedalboard to use ambisonics VST3
if [[ ! -d "$CODEDIR/pedalboard" ]]; then
    git clone --recurse-submodules --shallow-submodules https://github.com/spotify/pedalboard.git
    pushd "$CODEDIR/pedalboard"
    pip install pybind11

	# Remove channel limit
    git am << 'EOF2'
diff --git a/pedalboard/BufferUtils.h b/pedalboard/BufferUtils.h
index d5f2e40..5958cae 100644
--- a/pedalboard/BufferUtils.h
+++ b/pedalboard/BufferUtils.h
@@ -81,8 +81,6 @@ copyPyArrayIntoJuceBuffer(const py::array_t<T, py::array::c_style> inputArray) {
 
   if (numChannels == 0) {
     throw std::runtime_error("No channels passed!");
-  } else if (numChannels > 2) {
-    throw std::runtime_error("More than two channels received!");
   }
 
   juce::AudioBuffer<T> ioBuffer(numChannels, numSamples);
EOF2

    pip install .

    ###### Run if you want to run tests
    #
	# conda install -y tox
	# # Convert JUCE test to Python 3
	# 2to3 -w -n vendors/lame/test/lametest.py
	# # Fix star imports
	# sed -i -e 's/from string import \*/from string import split, atof, find, replace, rstrip/g' vendors/lame/test/lametest.py
	# # Fix style things
	# sed -i -e "s/  (diff/    (diff/g" vendors/lame/test/lametest.py
	# sed -i -e "s/% \\\\$/%/g" vendors/lame/test/lametest.py
    # tox
    #
    ######

    popd
fi

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
