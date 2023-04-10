# The docker image

This image is based on 
 - Ubuntu 20.04
 - CUDA 11.4
 - Torch 1.13.1

Emulate ssh-ing into a remote machine. This is as opposed to using docker API, although one can still use it.

Features:
 - GPU training with Torch
 - opengl and graphics (`glxgears` works)
 - desktop GUI via browser
 - passwordless ssh access

# This is based on the following images/tutorials

Install docker deepo container dependencies so that it works (you don't need deepo itself):
`https://github.com/ufoym/deepo`

Enable default gpu support by picking nvidia runtime: 
`https://stackoverflow.com/questions/59652992/pycharm-debugging-using-docker-with-gpus`

Make docker daemon available on a fixed port:
`https://dockerlabs.collabnix.com/beginners/components/daemon/access-daemon-externally.html`

# run MNIST training and some random examples

```bash
python /example/mnist.py
python /example/examples.py
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



