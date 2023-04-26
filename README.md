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

You probably already have some repo that you want to dockerize.
First decision point to pick:
(1) Add Dockerize right into your repo (easiest)
(2) Make a highlevel repo, into which you put your existing repo as a submodule or subtree (a bit cleaner, but with some hassle)
Option (1) is suboptimal if you have `setup.py` in the root of your repo AND you want to install it into venv inside docker AND
you want to edit files.

Add this repo as a subtree:
```bash
git subtree add --prefix docker_mlgl git@github.com:olegsinavski/docker_mlgl.git main --squash
```
(or submodule - not recommended `git submodule add git@github.com:olegsinavski/docker_mlgl.git docker_mlgl`)

Create a `sandbox.sh` script with this content:
```bash
#!/usr/bin/env bash
set -e
PROJECT_NAME=smarts
PYTHON_VERSION=3.9

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
./docker_mlgl/stop_sandbox.sh $PROJECT_NAME
# Build parent image
./docker_mlgl/build.sh mlgl_sandbox $PYTHON_VERSION
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
Note, that since the container is completely isolated you don't *have to* use conda or venv for isolation.
If it's easy for you, just install things into the system. Here are some examples.

## Run apt-gets or other system install scripts

If you have some apt-get installs or a system script, simply call it from the dockerfile.
Parent dockerfile defines `APT_INSTALL` variable to install packages without manual interface.
For example, if you need to install `libsfml-dev`, run:
```dockerfile
RUN apt-get update && $APT_INSTALL libsfml-dev
```
If you have a some `setup.sh` script, add:
```dockerfile
COPY <path_to_setup_sh>/setup.sh /root/setup.sh
RUN chmod +x /root/setup.sh
RUN /root/setup.sh
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

Also notice, that you can change system python version with `PYTHON_VERSION` variable in `sandbox.sh` (tested with 3.8 and 3.9 so far).

## Use `conda`

If you have `environment.yml` file in your repo, add the following to docker:
```dockerfile
USER docker
COPY environment.yml /home/docker/environment.yml
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

# Use `venv`

Based on (this)[https://pythonspeed.com/articles/activate-virtualenv-dockerfile/]
```dockerfile
# use non-root user and switch to the repo
USER docker
WORKDIR /home/docker/<PROJECT_NAME>

ENV VIRTUAL_ENV=/home/docker/<PROJECT_NAME>/venv
RUN python3.8 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
```


# This is based on the following images/tutorials

Install docker deepo container dependencies so that it works (you don't need deepo itself):
`https://github.com/ufoym/deepo`

Enable default gpu support by picking nvidia runtime: 
`https://stackoverflow.com/questions/59652992/pycharm-debugging-using-docker-with-gpus`

Make docker daemon available on a fixed port:
`https://dockerlabs.collabnix.com/beginners/components/daemon/access-daemon-externally.html`

# run MNIST training and some random examples
TODO: add requirements example
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

Notice `172.17.0.2` as explicit address, but your docker container address could be different.
To get your IP address, you can run `docker inspect -f '{{ .NetworkSettings.IPAddress }}' <PROJECT_NAME>`

# Users

There is a default `docker` user created during build and a `root` user. 
We recommend using `docker` for all user installations, such as venvs and conda.
There is a paswordless `sudo` for the `docker` user in case you need it.

# Troubleshooting
```
invalid argument <XXX> for "-t, --tag" flag: invalid reference format: repository name must be lowercase
```

Docker wants full lowercase name for the image. Use lowercase in `sandbox.sh`, `PROJECT_NAME` variable.


