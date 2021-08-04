#!/bin/bash

function cleanup_tmp()
{
    if [ "$LMOD" != "" ]; then
        if [ -e "$LMOD" ]; then rm -rf "$LMOD"; fi
    fi
}

trap cleanup_tmp SIGKILL EXIT

module purge

export SINGULARITY_BINDPATH=/mnt,/scratch
if [ -d /state/partition1 ]; then
    export SINGULARITY_BINDPATH=$SINGULARITY_BINDPATH,/state/partition1
fi

binds=/run/user:/run/user

export LMOD=$(mktemp --dry-run --directory /state/partition1/lmod.d-centos7-$USER-XXXXXX)
mkdir -m 700 -p $LMOD
binds=$binds,$LMOD:$HOME/.lmod.d

if [[ "$(hostname)" =~ ^g ]]; then nv="--nv"; fi
sif=/scratch/work/public/apps/prince/centos-7.8.2003.sif
overlays=/scratch/work/public/apps/prince/prince-share-apps.sqf:ro

if [[ "$(hostname -s)" =~ ^g ]]; then nv="--nv"; fi

prince_setup_cmds="source /opt/apps/lmod/lmod/init/bash
module use /share/apps/modulefiles
export LMOD_CACHED_LOADS=no
export LMOD_DISABLE_SAME_NAME_AUTOSWAP=no"
