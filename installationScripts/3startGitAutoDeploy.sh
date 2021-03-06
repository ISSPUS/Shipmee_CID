#!/bin/bash 


URL_VIRTUAL_HOST="autodeploy.shipmee.es"
PATH_ROOT="/home/core/Shipmee_CID_Workspace"
CONFIG_ROOT="/home/core/Shipmee_CID"
PRIVATE_CONFIG_ROOT="/home/core/Shipmee_Priv_Config"

git clone https://github.com/olipo186/Git-Auto-Deploy.git /home/core/Git-Auto-Deploy

# Los webhooks de github configurarlos en json

mkdir -p $PATH_ROOT
mkdir -p $CONFIG_ROOT

docker pull python:2.7

docker run -d \
    --restart=always \
    --name Git-Auto-Deploy \
    -v $PATH_ROOT:$PATH_ROOT \
    -v $CONFIG_ROOT:$CONFIG_ROOT \
    -v $PRIVATE_CONFIG_ROOT:$PRIVATE_CONFIG_ROOT \
    -v /home/core/Git-Auto-Deploy:/Git-Auto-Deploy \
    -w /Git-Auto-Deploy \
    -e VIRTUAL_HOST="$URL_VIRTUAL_HOST" \
    -e VIRTUAL_PORT=8001 \
    --expose=8001 \
    -e "LETSENCRYPT_HOST=$URL_VIRTUAL_HOST" \
    -e "LETSENCRYPT_EMAIL=shipmee.contact@gmail.com" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(which docker):/bin/docker \
    python:2.7 \
    bash -c "pip install -r requirements.txt && \
    python -m gitautodeploy --config /home/core/Shipmee_CID/git_auto_deploy_config.json"

