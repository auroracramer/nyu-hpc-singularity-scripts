# latest (git 'main') versions of all HEAR packages.

# ==================================================================
# module list
# ------------------------------------------------------------------
# python        3.8    (apt)
# pytorch       latest (docker)
# tensorflow    latest (pip)
# keras         latest (pip)
# ==================================================================

FROM nvidia/cuda:11.2.0-cudnn8-devel-ubuntu18.04

ENV LANG C.UTF-8

RUN echo ''
RUN rm -rf /var/lib/apt/lists/* \
           /etc/apt/sources.list.d/cuda.list \
           /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get update
    #   apt-get update && \

# ==================================================================
# tools
# ------------------------------------------------------------------
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    PIP_INSTALL="python -m pip --no-cache-dir install --upgrade" && \
    GIT_CLONE="git clone --depth 10" && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ="America/New_York" $APT_INSTALL \
        build-essential \
        apt-utils \
        ca-certificates \
        wget \
        clang \
        ccache \
        git \
        vim \
        libssl-dev \
        curl \
        bc \
        less \
        locate \
        unzip \
        tzdata \
        gfortran \
        flex \
        bison \
        autoconf \
        automake \
        lsb-core \
        libexpat1-dev \
        iproute2 \
        strace \
        uuid-runtime \
        xvfb \
        swig \
        python-opengl \
        perl \
        sqlite3 \
        libswiss-perl \
        libxml-parser-perl \
        libxml2 \
        libxml2-dev \
        libx11-dev \
        libgl1-mesa-dev \
        xorg-dev \
        libjpeg62 \
        make \
        unrar \
        libqt4-dev \
        libjack-dev \
        libsndfile1-dev \
        libasound2-dev

RUN rm -rf /etc/localtime && cp -rp /usr/share/zoneinfo/EST /etc/localtime

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && apt-get install -y -q

RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ bionic main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null && \
    apt-get update && \
    rm /usr/share/keyrings/kitware-archive-keyring.gpg && \
    $APT_INSTALL kitware-archive-keyring && \
    $APT_INSTALL cmake

# set up ccache - https://askubuntu.com/a/470636
RUN /usr/sbin/update-ccache-symlinks && \
    echo 'export PATH="/usr/lib/ccache:$PATH"' | tee -a /etc/profile.d/ccache.sh

# fftw3
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    wget -qO- http://www.fftw.org/fftw-3.3.10.tar.gz | tar xz -C ~/ && \
    cd ~/fftw-3.3.10 && \
    ./configure --enable-float CFLAGS="-fPIC" && make && make install

# ==================================================================
# python
# ------------------------------------------------------------------

RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    DEBIAN_FRONTEND=noninteractive $APT_INSTALL \
        software-properties-common \
        && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive $APT_INSTALL \
        python3.8 \
        python3.8-dev \
        python3-distutils-extra \
        && \
    wget -O ~/get-pip.py \
        https://bootstrap.pypa.io/get-pip.py && \
    python3.8 ~/get-pip.py && \
    ln -s /usr/bin/python3.8 /usr/local/bin/python3 && \
    ln -s /usr/bin/python3.8 /usr/local/bin/python

RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    PIP_INSTALL="python -m pip --no-cache-dir install --upgrade" && \
    GIT_CLONE="git clone --depth 10" && \
    $PIP_INSTALL \
        setuptools \
        pipdeptree

# Hack to get tf 2.4.2 to play nice with CUDA 11.2
# https://medium.com/mlearning-ai/tensorflow-2-4-with-cuda-11-2-gpu-training-fix-87f205215419
RUN ln -s /usr/local/cuda-11.2/targets/x86_64-linux/lib/libcusolver.so.11 /usr/local/cuda-11.2/targets/x86_64-linux/lib/libcusolver.so.10
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/cuda-11.2/targets/x86_64-linux/lib"

RUN apt update
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    $APT_INSTALL software-properties-common
RUN apt update
RUN apt upgrade -y
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    $APT_INSTALL sox

# h5
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    $APT_INSTALL pkg-config libhdf5-100 libhdf5-dev

# LLVM >= 9.0
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    $APT_INSTALL --reinstall python3-apt && \
    $APT_INSTALL gpg-agent
RUN wget --no-check-certificate -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
# Might need to change python version: nano /usr/bin/add-apt-repository
#RUN add-apt-repository 'deb http://apt.llvm.org/bionic/   llvm-toolchain-bionic-10  main'
RUN add-apt-repository 'deb http://apt.llvm.org/bionic/   llvm-toolchain-bionic-11  main'
RUN apt update
#RUN $APT_INSTALL llvm-10 lldb-10 llvm-10-dev libllvm10 llvm-10-runtime
#RUN update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-10 10
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    $APT_INSTALL llvm-11 lldb-11 llvm-11-dev libllvm11 llvm-11-runtime
RUN update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-11 11
RUN update-alternatives --config llvm-config


# For ffmpeg >= 4.2
# Could also build from source:
# https://github.com/jrottenberg/ffmpeg/blob/master/docker-images/4.3/ubuntu1804/Dockerfile
RUN add-apt-repository ppa:jonathonf/ffmpeg-4
RUN apt-get update
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    $APT_INSTALL ffmpeg



# ==================================================================
# TODO Move this earlier
# ------------------------------------------------------------------

RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    GIT_CLONE="git clone --depth 10" && \
    $APT_INSTALL screen tmux



# ==================================================================
# config & cleanup
# ------------------------------------------------------------------

RUN \
    ldconfig && \
    apt-get clean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* ~/*

RUN updatedb

EXPOSE 6006
