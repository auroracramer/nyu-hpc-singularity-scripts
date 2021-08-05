set -e
CONDADIR="/ext3/miniconda3"
CODEDIR="/ext3/code"
TMPDIR="/state/partition1/$SLURM_JOB_ID-tmp"
BINDIR="/ext3/bin"
WORKDIR="$TMPDIR/hear2021-workdir"
TASKDIR="$TMPDIR/hear2021-tasks"
EMBSDIR="$TMPDIR/hear2021-embeddings"

# Set up miniconda
if [[ ! -d "$CONDADIR" ]]; then
    cd /ext3
    wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b -p $CONDADIR
fi

# Create python environment
if [[ -z "$(conda env list | grep -F hear2021)" ]]; then
    conda create -y -n hear2021 python=3.8
fi

# Set up environment script
mkdir -p $BINDIR
cat > /ext3/env.sh <<EOL
#!/bin/bash

source $CONDADIR/etc/profile.d/conda.sh
export PATH="$BINDIR:$CONDADIR/bin:\$PATH"

conda activate hear2021

EOL
source /ext3/env.sh

# Set up code dir
mkdir -p $CODEDIR
cd $CODEDIR

# Manually install certain packages
if [[ ! -f "$BINDIR/ffmpeg" ]]; then
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
    mkdir -p $ffmpeg_build_dir/lib
    cd $CODEDIR/ffmpeg-4.4
    PATH="$BINDIR:$PATH" PKG_CONFIG_PATH="$CODEDIR/lib/pkgconfig" ./configure \
      --prefix="$ffmpeg_build_dir" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$CODEDIR/soxr/build/output/include" \
      --extra-ldflags="-L$CODEDIR/soxr/build/output/lib" \
      --extra-libs="-lpthread -lm" \
      --ld="g++" \
      --bindir="$BINDIR" \
      --enable-libsoxr
    PATH="$BINDIR:$PATH" make && make install
    cd $CODEDIR
fi
conda install -y -c conda-forge squashfs-tools
yes | pip install intervaltree

# Clone relevant repos if not cloned
if [[ ! -d "$CODEDIR/hear-eval-kit" ]]; then
    git clone https://github.com/neuralaudio/hear-eval-kit.git
fi
if [[ ! -d "$CODEDIR/hear-validator" ]]; then
    git clone https://github.com/neuralaudio/hear-validator.git
fi
if [[ ! -d "$CODEDIR/hear-baseline" ]]; then
    git clone https://github.com/neuralaudio/hear-baseline.git
fi
if [[ ! -d "$CODEDIR/openl3-hear" ]]; then
    git clone https://github.com/marl/openl3-hear.git
fi

# Make sure we get the correct hear-eval-kit version
cd $CODEDIR/hear-eval-kit
git fetch
git checkout updated-install2

# In place bug-fix prior to patch
sed -i -e 's|\[\["relpath", "slug", "subsample_key", "split", "label"\]\]||g' $CODEDIR/hear-eval-kit/heareval/tasks/nsynth_pitch.py

# Replace default directories in eval kit with cluster-friendly ones
for f in $(grep -Rl '"_workdir"' $CODEDIR/hear-eval-kit/*); do
    sed -i -e "s|\"_workdir\"|\"$WORKDIR\"|g" $f;
done
for f in $(grep -Rl '"tasks"' $CODEDIR/hear-eval-kit/*); do
    sed -i -e "s|\"tasks\"|\"$TASKDIR\"|g" $f;
done
for f in $(grep -Rl '"embeddings"' $CODEDIR/hear-eval-kit/*); do
    sed -i -e "s|\"embeddings\"|\"$EMBSDIR\"|g" $f;
done

# Install all of the packages
if [[ "$(python -m pip list | grep -F hearbaseline)" ]]; then
    python -m pip uninstall --yes hearbaseline
fi
yes | python -m pip install -e $CODEDIR/hear-baseline
if [[ ! -f "./naive_baseline.pt" ]]; then
    wget https://github.com/neuralaudio/hear-baseline/raw/main/saved_models/naive_baseline.pt
fi

if [[ "$(python -m pip list | grep -F hearvalidator)" ]]; then
    python -m pip uninstall --yes hearvalidator
fi
yes | python -m pip install -e $CODEDIR/hear-validator

if [[ "$(python -m pip list | grep -F heareval)" ]]; then
    python -m pip uninstall --yes heareval
fi
yes | python -m pip install -e $CODEDIR/hear-eval-kit


#cd $CODEDIR/openl3-hear
#if [[ "$(pip list | grep -F openl3-hear)" ]]; then
#    pip uninstall --yes openl3-hear
#fi
#yes | pip install -e .


# Download and preprocess data
mkdir -p $WORKDIR
mkdir -p $TASKDIR
echo "*****************************"
echo "Preprocessing speech_commands"
echo "*****************************"
python -m heareval.tasks.runner speech_commands
echo "*****************************"
echo "Preprocessing nsynth_pitch"
echo "*****************************"
python -m heareval.tasks.runner nsynth_pitch
echo "*****************************"
echo "Preprocessing dcase2016_task2"
echo "*****************************"
python -m heareval.tasks.runner dcase2016_task2

# Compute baseline embeddings
mkdir -p $EMBSDIR
python -m heareval.embeddings.runner hearbaseline --model $CODEDIR/hear-baseline/naive_baseline.pt --tasks-dir $TASKDIR

# Compress results
if [[ -d "$TASKDIR" ]]; then
    mksquashfs $TASKDIR /scratch/jtc440/sqfdata/hear2021-tasks -keep-as-directory -processors 2 -noappend
fi
if [[ -d "$EMBSDIR" ]]; then
    mksquashfs $EMBSDIR /scratch/jtc440/sqfdata/hear2021-embeddings -keep-as-directory -processors 2 -noappend
fi

