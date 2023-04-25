FROM nvidia/cudagl:11.4.2-devel-ubuntu20.04
ARG VNC_PORT=8080
ARG JUPYTER_PORT=8894
ARG USER_UID=0
ARG USER_GID=0
ARG USER_NAME=docker

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
RUN apt-get update && $APT_INSTALL \
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
        iputils-ping \
        psmisc \
        sudo  \
        cmake

# ==================================================================
# SSH
# ------------------------------------------------------------------
RUN apt-get update && $APT_INSTALL openssh-server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# ==================================================================
# python
# ------------------------------------------------------------------
ENV PYTHON_VERSION 3.9
RUN $APT_INSTALL \
        software-properties-common \
        && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    $APT_INSTALL \
        python$PYTHON_VERSION \
        python$PYTHON_VERSION-dev \
        python3-distutils-extra \
        && \
    wget -O ~/get-pip.py \
        https://bootstrap.pypa.io/get-pip.py && \
    python$PYTHON_VERSION ~/get-pip.py pip setuptools wheel pip-tools && \
    ln -s /usr/bin/python$PYTHON_VERSION /usr/local/bin/python3 && \
    ln -s /usr/bin/python$PYTHON_VERSION /usr/local/bin/python

# Some system utils need setuptools by system python
RUN /usr/bin/python3 ~/get-pip.py pip setuptools
# Link new pip so that a user can install packages into system with a correct version
RUN ln -sf /usr/local/bin/pip$PYTHON_VERSION /usr/local/bin/pip

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

## ==================================================================
## Conda
## ------------------------------------------------------------------
# Install miniconda
ENV CONDA_DIR /opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
     /bin/bash ~/miniconda.sh -b -p $CONDA_DIR
# Put conda in path so we can use conda activate, also init the shell
ENV PATH=$PATH:$CONDA_DIR/bin
RUN conda install conda=23.3.1
RUN ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# ==================================================================
# jupyterlab configs
# ------------------------------------------------------------------
EXPOSE $JUPYTER_PORT
COPY scripts/jupyter_notebook_config.py /etc/jupyter/
RUN echo "c.NotebookApp.port = $JUPYTER_PORT" >> /etc/jupyter/jupyter_notebook_config.py

## ==================================================================
## config & cleanup
## ------------------------------------------------------------------
RUN ldconfig && \
    apt-get clean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* ~/*


## ==================================================================
## Non-root user
## ------------------------------------------------------------------
RUN echo ${USER_GID} ${USER_UID} ${USER_NAME}
RUN groupadd -g ${USER_GID} ${USER_NAME} && \
  useradd -u ${USER_UID} -g ${USER_GID} -m -s /bin/bash ${USER_NAME} && \
  echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

## ==================================================================
## Startup
## ------------------------------------------------------------------
# Only root can launch stuff in on_docker_start.sh
USER root
COPY scripts/on_docker_start.sh /on_docker_start.sh
RUN sudo chmod +x /on_docker_start.sh
# https://stackoverflow.com/questions/21553353/what-is-the-difference-between-cmd-and-entrypoint-in-a-dockerfile
# The ENTRYPOINT specifies a command that will always be executed when the container starts.
# The CMD specifies arguments that will be fed to the ENTRYPOINT.
ENTRYPOINT ["/on_docker_start.sh"]

