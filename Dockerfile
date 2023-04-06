FROM nvidia/cudagl:11.4.2-devel-ubuntu20.04

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND noninteractive
RUN rm -rf /var/lib/apt/lists/* \
           /etc/apt/sources.list.d/cuda.list \
           /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get update

# ==================================================================
# tools
# ------------------------------------------------------------------
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    $APT_INSTALL \
        build-essential \
        apt-utils \
        ca-certificates \
        wget \
        git \
        vim \
        libssl-dev \
        curl \
        unzip \
        unrar \
        zlib1g-dev \
        libjpeg8-dev \
        freeglut3-dev \
        iputils-ping

RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    $APT_INSTALL \
    cmake  \
    protobuf-compiler

# ==================================================================
# SSH
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y openssh-server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config


# ==================================================================
# python
# ------------------------------------------------------------------
RUN APT_INSTALL="apt-get install -y --no-install-recommends" && \
    $APT_INSTALL \
        software-properties-common \
        && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    $APT_INSTALL \
        python3.9 \
        python3.9-dev \
        python3-distutils-extra \
        && \
    wget -O ~/get-pip.py \
        https://bootstrap.pypa.io/get-pip.py && \
    python3.9 ~/get-pip.py pip setuptools wheel pip-tools && \
    ln -s /usr/bin/python3.9 /usr/local/bin/python3 && \
    ln -s /usr/bin/python3.9 /usr/local/bin/python

# Some system utils need setuptools by system python
RUN /usr/bin/python3 ~/get-pip.py pip setuptools
# Link 3.9 pip so that a user can install packages into system with a correct version
RUN ln -sf /usr/local/bin/pip3.9 /usr/local/bin/pip

# to change requirements.txt.lock, change requirements.txt, login into the container, then run
# pip-compile --generate-hashes --output-file=requirements.txt.lock --resolver=backtracking requirements.txt
COPY requirements.txt.lock requirements.txt.lock
RUN python -m pip --no-cache-dir install --no-deps -r requirements.txt.lock

# RUN CC="cc -mavx2" python -m pip install --no-deps --force-reinstall --upgrade pillow-simd==7.0.0.post3
# fix opencv imshow
# RUN python -m pip install --no-deps --force-reinstall --upgrade opencv-python==4.5.2.54

# ==================================================================
# Rust
# ------------------------------------------------------------------
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -y | sh
# RUN echo 'source $HOME/.cargo/env' >> $HOME/.bashrc

# ==================================================================
# Kaggle
# ------------------------------------------------------------------
#RUN python -m pip install kaggle==1.5.12
#ENV KAGGLE_USERNAME olegsinavski
#ENV KAGGLE_KEY 63f692b5d2f5b055bc31258a5db26d23

# ==================================================================
# Bazel
# ------------------------------------------------------------------
#RUN curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg; \
#    mv bazel.gpg /etc/apt/trusted.gpg.d/ ;\
#    echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list; \
#    apt-get update; \
#    apt-get install -y \
#      bazel-4.1.0
#RUN ln -s /usr/bin/bazel-4.1.0 /usr/bin/bazel

# ==================================================================
# Hyperparameters with ray
# ------------------------------------------------------------------
#RUN python -m pip install ray[rllib]==1.3.0 nevergrad==0.4.3
#EXPOSE 8265


# ==================================================================
# GUI
# ------------------------------------------------------------------
RUN apt-get install --no-install-recommends -y libsm6 libxext6 libxrender-dev mesa-utils

# Setup demo environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:0.0 \
    DISPLAY_WIDTH=1024 \
    DISPLAY_HEIGHT=768

RUN set -ex; \
    apt-get update; \
    apt-get install -y \
      fluxbox \
      net-tools \
      novnc \
      supervisor \
      x11vnc \
      xterm \
      xvfb \
      python3-tk \
      libgtk2.0-dev

COPY dep/vnc /vnc
EXPOSE 8080

# ==================================================================
# jupyterlab
# ------------------------------------------------------------------
EXPOSE 8894
COPY scripts/jupyter_notebook_config.py /etc/jupyter/

# ==================================================================
# Add the src folder to pythonpath
# ------------------------------------------------------------------
ENV PYTHONPATH "${PYTHONPATH}:/sota/src"

## ==================================================================
## Startup
## ------------------------------------------------------------------
COPY scripts/on_docker_start.sh /on_docker_start.sh
RUN chmod +x /on_docker_start.sh

## ==================================================================
## config & cleanup
## ------------------------------------------------------------------
RUN ldconfig && \
    apt-get clean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* ~/*

ENTRYPOINT ["/on_docker_start.sh"]
