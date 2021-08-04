set -e
CONDADIR="/ext3/miniconda3"
CODEDIR="/ext3/code"

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
cat > /ext3/env.sh <<EOL
#!/bin/bash

source $CONDADIR/etc/profile.d/conda.sh
export PATH=$CONDADIR/bin:$PATH
conda activate hear2021

EOL
source /ext3/env.sh

# Set up code dir
mkdir -p /ext3/code
cd /ext3/code

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

# Replace default directories in eval kit with cluster-friendly ones
cd $CODEDIR/hear-eval-kit
TMPDIR="/state/partition1/$SLURM_JOB_ID-tmp"
mkdir -p $TMPDIR
WORKDIR="$TMPDIR/hear2021-workdir"
TASKDIR="$TMPDIR/hear2021-tasks"
EMBSDIR="$TMPDIR/hear2021-embeddings"
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
cd $CODEDIR/hear-baseline
if [[ "$(pip list | grep -F hear-baseline)" ]]; then
    pip uninstall --yes hear-baseline
fi
yes | pip install -e .
wget https://github.com/neuralaudio/hear-baseline/raw/main/saved_models/naive_baseline.pt

cd $CODEDIR/hear-validator
if [[ "$(pip list | grep -F hear-validator)" ]]; then
    pip uninstall --yes hear-validator
fi
yes | pip install -e .

cd $CODEDIR/openl3-hear
if [[ "$(pip list | grep -F openl3-hear)" ]]; then
    pip uninstall --yes openl3-hear
fi
yes | pip install -e .

cd $CODEDIR/hear-eval-kit
if [[ "$(pip list | grep -F hear-eval-kit)" ]]; then
    pip uninstall --yes hear-eval-kit
fi
yes | pip install -e .

# Download and preprocess data
python -m heareval.tasks.runner speech_commands
python -m heareval.tasks.runner nsynth_pitch
python -m heareval.tasks.runner dcase2016_task2

# Compute baseline embeddings
python -m heareval.embeddings.runner hearbaseline --model $CODEDIR/hear-baseline/naive_baseline.pt --tasks-dir $TASKDIR

# Compress results
if [[ -d "$TASKDIR" ]]; then
    mksquashfs $TASKDIR /scratch/jtc440/sqfdata/hear2021-tasks -keep-as-directory -processors 2 -noappend
fi
if [[ -d "$EMBSDIR" ]]; then
    mksquashfs $EMBSDIR /scratch/jtc440/sqfdata/hear2021-embeddings -keep-as-directory -processors 2 -noappend
fi

