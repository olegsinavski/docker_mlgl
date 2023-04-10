#!/usr/bin/env bash
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

./stop_sandbox.sh mlgl_sandbox
./build.sh mlgl_sandbox
./start_sandbox.sh mlgl_sandbox $DIR
