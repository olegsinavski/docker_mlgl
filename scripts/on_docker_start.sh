#!/bin/bash
set -e

service ssh start >/dev/null 2>&1

function setup_passwordless_ssh() {
    local user="$1"
    local authorized_keys="$2"

    if [ "${authorized_keys}" != "**None**" ]; then
        home_dir=$(eval echo ~${user})
        ssh_dir="${home_dir}/.ssh"

        mkdir -p "${ssh_dir}"
        chown ${user}:${user} "${ssh_dir}"
        chmod 700 "${ssh_dir}"

        touch "${ssh_dir}/authorized_keys"
        chown ${user}:${user} "${ssh_dir}/authorized_keys"
        chmod 600 "${ssh_dir}/authorized_keys"

        IFS=$'\n'
        arr=$(echo ${authorized_keys} | tr "," "\n")

        for x in $arr
        do
            x=$(echo $x | sed -e 's/^ *//' -e 's/ *$//')
            echo "$x" >> "${ssh_dir}/authorized_keys"
        done
    else
        echo "ERROR: No authorized keys found in \$AUTHORIZED_KEYS for user ${user}"
        exit 1
    fi
}

setup_passwordless_ssh "root" "${AUTHORIZED_KEYS}"

# Launch VNC
exec supervisord -c /vnc/supervisord.conf &

export DISPLAY=:0.0
env | egrep -v "^(HOME=|USER=|MAIL=|LC_ALL=|LS_COLORS=|LANG=|HOSTNAME=|PWD=|TERM=|SHLVL=|LANGUAGE=|_=)" >> /etc/environment

jupyter-lab &

exec "$@"
