# The docker image

This image is based on 
 - Ubuntu 20.04
 - CUDA 11.4
 
Emulate ssh-ing into a remote machine. This is as opposed to using docker API, although one can still use it.
Not focusing on production - only on development. Optimizes:
 - user experience, no steep learning curve
 - simplicity 
Doesn't optimize (less attention to https://pythonspeed.com/articles/official-docker-best-practices/):
 - image size -> no docker file tricks, just plain copypaste
 - security -> running as root as docker default

Features:
 - opengl and graphics (`glxgears` works)
 - desktop GUI via browser (VNC is open at `<this_ip>:8080/vnc.html` by default)
 - passwordless ssh access
 - GPU training (e.g. with Torch)
 
# New repo setup

You probably already have some repo that you want to dockerize.
First decision point to pick:
(1) Add Dockerfile right into your repo (easiest)
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
PROJECT_NAME=<YOUR_REPO_NAME>
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

Install docker if needed `./install_docker.sh`

Run `./sandbox.sh`. It should build a docker image with your project name and then drop you into a developer sandbox.

The sandbox is running in docker and you always can exit and then ssh into it again.
You can always rerun `./sandbox.sh` if you don't want to ssh. Its going to quickly rebuild it since docker caches build stages.

Your repo is available under `~/` directory in the sandbox. 
Additionally, a storage folder `~/storage` in the container is mapped to `~/.${project_name}_storage` folder on your desktop.
Use it for artifacts that you want to persist between rebuilds (e.g. network weights).

*Currently, your sandbox is not very useful. You need to add your custom setup into the `Dockerfile`:*
First, run some `apt-gets` if needed and then choose your development environment: conda, venv or system python (see below).
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

 - Create `requirements.txt`.
 - ssh into the container (e.g. by running `./sandbox.sh`), cd into `~/<YOUR_REPO_NAME>` folder, you should find `requirements.txt` there
 - Run `pip-compile --generate-hashes --output-file=requirements.txt.lock --resolver=backtracking requirements.txt`. NOTE: you'll need at least 16GB RAM for this!
 - You should be able to find `requirements.txt.lock` file on your host repo now. Commit both files.
 - Add the following in your `Dockerfile`
```dockerfile
COPY requirements.txt.lock requirements.txt.lock
RUN python -m pip --no-cache-dir install --no-deps --ignore-installed -r requirements.txt.lock
# Add the /src/ folder to pythonpath. A sandbox will mount there the default python code
ENV PYTHONPATH "${PYTHONPATH}:~/<YOUR_REPO_NAME>"
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
USER docker
WORKDIR /home/docker/
ENV VIRTUAL_ENV=/home/docker/venv
RUN python3.8 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN echo "source venv/bin/activate" >> ~/.bashrc

COPY --chown=docker:docker ./folder_to_install /home/docker/folder_to_install
WORKDIR /home/docker/folder_to_install
RUN pip install -e .
```

# Use GUI utils (e.g. matplotlib) with VNC

When sandbox is running, you can open `<this_ip>:8080/vnc.html` and see a simple desktop.
You can run GUI utils there, e.g. `matplotlib`, `opencv` or `pygame`.

The sandbox supports 3d rendering: check that GPU rendering works with `glxgears` (you should see a spinning gear).
So you can run 3d simulators like `gym` or `pybullet` there.

## How to setup proxy jump ssh
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


# Google Cloud setup

## Make ssh key for your dev instances
https://cloud.google.com/compute/docs/connect/create-ssh-keys
The `USERNAME` below is your 
```bash
ssh-keygen -t rsa -f ~/.ssh/gce_key -C <USERNAME> -b 2048
```
To see the generated public key that you're going to add to GCE:
```bash
cat ~/.ssh/gce_key.pub 
```
(optional) Add this ssh key [globally](https://cloud.google.com/compute/docs/connect/add-ssh-keys)

## Create the cheapest test CPU VM to practice from scratch

Go to [Google Compute Engine (GCE)](https://console.cloud.google.com/compute), turn on GCE API.
You should see creating
Create a VM with the following options:
 - default region is the cheapest
 - E2 is a good cheapest option, but you need at least 16GB of RAM if you'll use `pip`
 - "Availability policies", choose "Spot" to save money
 - Check "Enable display service"
 - Boot disk, "Change", Choose Ubuntu 20.04
 - Boot disk, "Change", make it at least 20Gb (10 is not enough)
 - Firewall, check "Allow HTTP/HTTPS traffic"
 - Advanced options, Disks, Add new disk, pick "Standard" (cheapest)
 - Advanced options, Security, Manage Access, Add manually generated SSH keys, add the content of `~/.ssh/gce_key.pub`

Now create the instance, you should see a green checkmark in "Status" column.

Add this to your `~/.ssh/config`. Your `USERNAME` is what's before your `@gmail.com`.
`EXTERNAL_IP` is what you see in "External IP" column of your running instance
```shell
Host gce
  HostName <EXTERNAL_IP>
  User <USERNAME>
  IdentityFile ~/.ssh/gce_key
```

You should be able to login `ssh gce` from your laptop.
Call `sudo passwd` to change the password.

### Format your empty disk
Follow (this tutorial)[https://cloud.google.com/compute/docs/disks/format-mount-disk-linux].
In short:
```
sudo lsblk
# you should see your large disk size under sdb. Now create the filesystem
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
# mount the disk
sudo mkdir -p /mnt/disks/disk-1
sudo mount -o discard,defaults /dev/sdb /mnt/disks/disk-1
# mount on boot
sudo blkid /dev/sdb
sudo vim /etc/fstab , Shift+G, o
# add this:
UUID="<UUID_FROM_ABOVE>" /mnt/disks/disk-1 ext4 discard,defaults 0 2
```

## Move home folder onto the large drive:
```
cd /mnt/disks/disk-1
mkdir -p home/<USERNAME> 
sudo rsync -avz --progress /home/<USERNAME>/ /mnt/disks/disk-1/home/<USERNAME>/
sudo vim /etc/passwd
# find your username entry and change /home/<USERNAME> to /mnt/disks/disk-1/home/<USERNAME>
sudo chown -R <USERNAME> <USERNAME> /mnt/disks/disk-1/home/<USERNAME> 
sudo reboot
```
Now when you ssh again into `~` and call `pwd` you should see `/mnt/disks/disk-1/home/<USERNAME> `


## Setup github keys

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

Add a `~/.ssh/gce_key` to your GitHub account.
Copy the keys from your laptop to the dev VM:
`scp ~/.ssh/gce_key* gce:~/.ssh/`
Add the following at the end of `~/.bashrc`
```bash
eval $(ssh-agent)
ssh-add ~/.ssh/gce_key
```
Now you should be able to clone your repo.


## MISC
### This is based on the following images/tutorials

Install docker deepo container dependencies so that it works (you don't need deepo itself):
`https://github.com/ufoym/deepo`

Enable default gpu support by picking nvidia runtime: 
`https://stackoverflow.com/questions/59652992/pycharm-debugging-using-docker-with-gpus`

Make docker daemon available on a fixed port:
`https://dockerlabs.collabnix.com/beginners/components/daemon/access-daemon-externally.html`

### How VNC works
`xvfb` - create a virtual X11 display
`fluxbox` - uses a virtual X11 and creates a windowmanager (`xterm` - adds a terminal)
`X11Vnc` - exposes all that via VNC server (makes it available for VNC clients)
`websockify` - translates WebSockets traffic to normal socket traffic to be available via browser

### How to build cudagl base image
Install `https://github.com/docker/buildx`.
Clone `https://gitlab.com/nvidia/container-images/cuda`

Run `build.sh` from `https://gitlab.com/nvidia/container-images/cuda/-/blob/master/build.sh`
This is an example (you can add ` --push` to push the image):
```bash
./build.sh -d --image-name <yourname>/cudagl --cuda-version 11.6.1 --os ubuntu --os-version 20.04 --arch x86_64 --cudagl
```
