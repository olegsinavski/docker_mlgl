# The docker image

This image is based on 
 - Ubuntu 20.04
 - CUDA 11.4
 - Torch 1.13.1

Emulate ssh-ing into a remote machine. This is as opposed to using docker API, although one can still use it.
Not focusing on production - only on development. Optimizes:
 - user experience, no steep learning curve
 - simplicity 
Doesn't optimize (less attention to https://pythonspeed.com/articles/official-docker-best-practices/):
 - image size -> no docker file tricks, just plain we copypaste
 - security -> running as root as docker default

Features:
 - GPU training with Torch
 - opengl and graphics (`glxgears` works)
 - desktop GUI via browser
 - passwordless ssh access


TODO add a user:
https://stackoverflow.com/questions/25845538/how-to-use-sudo-inside-a-docker-container

```bash
RUN useradd -m -s /bin/bash docker && \
    apt-get update && \
    apt-get install -y sudo && \
    echo "docker ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/docker
```


# New repo setup

Add this repo as a submodule (or a subtree):
```bash
git submodule add git@github.com:olegsinavski/docker_mlgl.git docker_mlgl
```

Create a `sandbox.sh` script with this content:
```bash
#!/usr/bin/env bash
set -e
PROJECT_NAME=<NAME_OF_YOUR_PROJECT>

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
./docker_mlgl/stop_sandbox.sh $PROJECT_NAME
# Build parent image
./docker_mlgl/build.sh mlgl_sandbox
docker build -t $PROJECT_NAME $SCRIPT_DIR
./docker_mlgl/start_sandbox.sh $PROJECT_NAME $SCRIPT_DIR

SANDBOX_IP="$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' $PROJECT_NAME)"
ssh docker@$SANDBOX_IP
```
Allow it to be executable: `chmod +x sandbox.sh`

Create a `Dockerfile` in the root with this content:
```bash
FROM mlgl_sandbox
```

Run `./sandbox.sh`. It should build a docker image with your project name and then drop you into a developer sandbox.
The sandbox is running in docker and you always can exit and then ssh into it again. 
You can always rerun `./sandbox.sh` if you don't want to ssh. Its going to quickly rebuild it since docker caches build stages.

Your repo is available under `/src` director in the sandbox. 
Additionally, your home folder in the container is mapped to `~/.${project_name}_home` folder on your desktop.

Now choose your development environment: conda, venv or system python.
Note, that since the container is completely isolated you don't have to use conda or venv for isolation.
If its easy for you, just install things into the system. Here are some examples.

## Run apt-gets or other system install scripts

If you have some apt-get installs or a system script, simply call it from the dockerfile.
Parent dockerfile defines `APT_INSTALL` variable to install packages without manual interface.
For example, if you need to install `libsfml-dev`, run:
```dockerfile
RUN apt-get update && $APT_INSTALL libsfml-dev
```

## System python installation with `requirements.txt`

The easiest and at the same time robust way to install requirements is to do with requirement locking.
Read [here](https://pythonspeed.com/articles/conda-dependency-management/) about the similar technique in `conda`. 

 - Create `requirements.txt` (you can copy one from this repo - it has a nice torch and torchvision versions with appropriate cuda version).
 - ssh into the container (e.g. by running `./sandbox.sh`), cd into `/src` folder, you should find `requirements.txt` there
 - Run `pip-compile --generate-hashes --output-file=requirements.txt.lock --resolver=backtracking requirements.txt`
 - You should be able to find `requirements.txt.lock` file on your host repo now. Commit both files.
 - Add the following in your `Dockerfile`
```dockerfile
COPY requirements.txt.lock requirements.txt.lock
RUN python -m pip --no-cache-dir install --no-deps --ignore-installed -r requirements.txt.lock
# Add the /src/ folder to pythonpath. A sandbox will mount there the default python code
ENV PYTHONPATH "${PYTHONPATH}:/src/"
```

## Run `conda`

If you have `environment.yml` file in your repo, add the following to docker:
```dockerfile
COPY environment.yml /root/environment.yml
RUN conda env create -f ~/environment.yml
# activate conda env on login
RUN echo "conda activate <YOUR_ENV_NAME>" >> ~/.bashrc
```

Notice that it does NOT activate conda environment during *build*, but only during ssh-ing into the sandbox.
If you want to run `conda` commands inside the env*during build*, use the following recipe from (here)[https://pythonspeed.com/articles/activate-conda-dockerfile/]:
```dockerfile
SHELL ["conda", "run", "-n", "<YOUR_ENV_NAME>", "/bin/bash", "-c"]
# this will run inside <YOUR_ENV_NAME> conda env
RUN python setup.py. develop 
```

# PIP and Conda

The goal here is to be able to copypaste installation instructions from the web, but still have a reproducible research environment.
Here is a good conda vs pip [article](https://pythonspeed.com/articles/conda-vs-pip/).
https://pythonspeed.com/articles/activate-conda-dockerfile/

# This is based on the following images/tutorials

Install docker deepo container dependencies so that it works (you don't need deepo itself):
`https://github.com/ufoym/deepo`

Enable default gpu support by picking nvidia runtime: 
`https://stackoverflow.com/questions/59652992/pycharm-debugging-using-docker-with-gpus`

Make docker daemon available on a fixed port:
`https://dockerlabs.collabnix.com/beginners/components/daemon/access-daemon-externally.html`

# run MNIST training and some random examples

```bash
python example/mnist.py
python example/examples.py
```

# How VNC works
`xvfb` - create a virtual X11 display
`fluxbox` - uses a virtual X11 and creates a windowmanager (`xterm` - adds a terminal)
`X11Vnc` - exposes all that via VNC server (makes it available for VNC clients)
`websockify` - translates WebSockets traffic to normal socket traffic to be available via browser

# How to build cudagl base image
Install `https://github.com/docker/buildx`.
Clone `https://gitlab.com/nvidia/container-images/cuda`

Run `build.sh` from `https://gitlab.com/nvidia/container-images/cuda/-/blob/master/build.sh`
This is an example (you can add ` --push` to push the image):
```bash
./build.sh -d --image-name <yourname>/cudagl --cuda-version 11.6.1 --os ubuntu --os-version 20.04 --arch x86_64 --cudagl
```

# How to setup proxy jump ssh
Copy your keys from your development laptop to the remote server:
```
scp ~/.ssh/id_ed25519 <ssh_name_of_the_server>:~/.ssh/
scp ~/.ssh/id_ed25519.pub <ssh_name_of_the_server>:~/.ssh/
```

On your development laptop, configure a proxy jump to the sandbox:
```
Host sandbox
 Hostname 172.17.0.2
 User <youruser>
 ProxyJump <ssh_name_of_the_server>
 StrictHostKeyChecking no
```



