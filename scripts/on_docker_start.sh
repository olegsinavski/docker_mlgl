#!/bin/bash
set -e

service ssh start >/dev/null 2>&1

if [ "${AUTHORIZED_KEYS}" != "**None**" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    IFS=$'\n'
    arr=$(echo ${AUTHORIZED_KEYS} | tr "," "\n")
    for x in $arr
    do
        x=$(echo $x | sed -e 's/^ *//' -e 's/ *$//')
        echo "$x" >> /root/.ssh/authorized_keys
    done
else
    echo "ERROR: No authorized keys found in \$AUTHORIZED_KEYS"
    exit 1
fi

# Launch VNC
exec supervisord -c /vnc/supervisord.conf &

export DISPLAY=:0.0
env | egrep -v "^(HOME=|USER=|MAIL=|LC_ALL=|LS_COLORS=|LANG=|HOSTNAME=|PWD=|TERM=|SHLVL=|LANGUAGE=|_=)" >> /etc/environment

jupyter-lab &

exec "$@"
