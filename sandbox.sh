set -e

# Robust way of locating script folder
# from http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SOURCE=${BASH_SOURCE:-$0}

DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

docker stop sota_sandbox >/dev/null 2>&1 || true && docker rm sota_sandbox >/dev/null 2>&1 || true

$DIR/build.sh

# how to get gpus?
# make nvidia-smi work on the host.
# https://stackoverflow.com/questions/59691207/docker-build-with-nvidia-runtime 
# https://github.com/NVIDIA/nvidia-docker/issues/1243
#

pub_key_file=$(find ~/.ssh -type f -name "*.pub" | head -n 1)

if [ -z "$pub_key_file" ]; then
  echo "No public key file found in ~/.ssh directory - ssh will not work"
fi

docker run  --name sota_sandbox -d -it \
  --gpus all \
  -p 8080:8080 \
  -p 5900:5900 \
  -p 8894:8894 \
  -p 0.0.0.0:8265:8265 \
  -p 0.0.0.0:6006:6006 \
  -e AUTHORIZED_KEYS="`cat $pub_key_file`" \
  -v $DIR:/sota \
  --ipc=host \
  -v ~/.sota_sandbox_home:/root \
  sota_sandbox bash >/dev/null

SANDBOX_IP="$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' sota_sandbox)"

# after a rebuild, we should remove the ssh identity
ssh-keygen -f "$HOME/.ssh/known_hosts" -R $SANDBOX_IP

echo "Successfully started the sandbox!"
echo "SSH with 'ssh root@$SANDBOX_IP'"
echo "VNC is availble at <hostip>:8080/vnc.html or via VNC client on port 5900"
$DIR/print_jupyter.sh
