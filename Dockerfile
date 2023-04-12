FROM nvidia/cudagl:11.4.2-devel-ubuntu20.04
ARG VNC_PORT=8080
ARG JUPYTER_PORT=8894

USER root

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND noninteractive
ENV APT_INSTALL "apt-get install -y --no-install-recommends"
RUN rm -rf /var/lib/apt/lists/* \
           /etc/apt/sources.list.d/cuda.list \
           /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get update

# ==================================================================
# tools
# ------------------------------------------------------------------
RUN $APT_INSTALL \
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

RUN $APT_INSTALL \
    cmake  \
    protobuf-compiler

# ==================================================================
# SSH
# ------------------------------------------------------------------
RUN apt-get update && $APT_INSTALL openssh-server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config


# ==================================================================
# python
# ------------------------------------------------------------------
RUN $APT_INSTALL \
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
# Install simd pillow separately
# RUN CC="cc -mavx2" python -m pip install --no-deps --force-reinstall --upgrade pillow-simd==7.0.0.post3

# ==================================================================
# Add the /src/ folder to pythonpath. A sandbox will mount there the default python code
# ------------------------------------------------------------------
ENV PYTHONPATH "${PYTHONPATH}:/src/"

# ==================================================================
# GUI
# ------------------------------------------------------------------
RUN $APT_INSTALL libsm6 libxext6 libxrender-dev mesa-utils

# Setup demo environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:0.0 \
    DISPLAY_WIDTH=1024 \
    DISPLAY_HEIGHT=768

RUN set -ex; \
    apt-get update; \
    $APT_INSTALL \
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
EXPOSE $VNC_PORT

# ==================================================================
# jupyterlab
# ------------------------------------------------------------------
EXPOSE $JUPYTER_PORT
COPY scripts/jupyter_notebook_config.py /etc/jupyter/
RUN echo "c.NotebookApp.port = $JUPYTER_PORT" > /etc/jupyter/jupyter_notebook_config.py

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

# https://stackoverflow.com/questions/21553353/what-is-the-difference-between-cmd-and-entrypoint-in-a-dockerfile
# The ENTRYPOINT specifies a command that will always be executed when the container starts.
# The CMD specifies arguments that will be fed to the ENTRYPOINT.
ENTRYPOINT ["/on_docker_start.sh"]
