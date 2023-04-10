#!/usr/bin/env bash
set -e
hostip="<hostip>"
max_retries=5
retry_interval=1

for i in $(seq 1 $max_retries); do
    output=$(docker exec -it $1 jupyter server list 2>/dev/null)
    if [ $? -eq 0 ]; then
        port_token=$(echo "$output" | grep -oP '\d+\/\?token=[a-zA-Z0-9]+')
        echo "Jupyter is available at $hostip:${port_token}"
        break
    else
        if [ $i -eq $max_retries ]; then
            echo "Failed to get Jupyter server list after $max_retries attempts. Please make sure the Jupyter server is running."
            exit 1
        else
            echo "Retrying in $retry_interval seconds... ($i/$max_retries)"
            sleep $retry_interval
        fi
    fi
done