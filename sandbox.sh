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

$DIR/stop_sandbox.sh
$DIR/build.sh

pub_key_file=$(find ~/.ssh -type f -name "*.pub" | head -n 1)

if [ -z "$pub_key_file" ]; then
  echo "No public key file found in ~/.ssh directory - ssh will not work"
fi

docker run  --name mlgl_sandbox -d -it \
  --gpus all \
  -p 8080:8080 \
  -p 5900:5900 \
  -p 8894:8894 \
  -p 0.0.0.0:8265:8265 \
  -p 0.0.0.0:6006:6006 \
  -e AUTHORIZED_KEYS="`cat $pub_key_file`" \
  -v $DIR:/example \
  --ipc=host \
  -v ~/.mlgl_sandbox_home:/root \
  mlgl_sandbox bash >/dev/null

SANDBOX_IP="$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' mlgl_sandbox)"

# after a rebuild, we should remove the ssh identity
ssh-keygen -f "$HOME/.ssh/known_hosts" -R $SANDBOX_IP

echo "Successfully started the sandbox!"
echo "SSH with 'ssh root@$SANDBOX_IP'"
echo "VNC is availble at <hostip>:8080/vnc.html or via VNC client on port 5900"
$DIR/print_jupyter.sh
