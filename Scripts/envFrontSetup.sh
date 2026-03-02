#!/usr/bin/env bash

SSH_PRIVATE_KEY=/home/cmfrench/.ssh/wpiMlopsKey
PORT=22000
NAME=group10
HOST=paffenroth-23.dyn.wpi.edu
REPO_DIR=/home/group10/movie-mood-fe-be
## Copy only neccessary files to backend
cd /home/cmfrench/Documents/MLops/movie-mood-fe-be # TODO: Make this more general

## TODO: Update our Known hosts with the ssh key (if the VM restarts this is necessary)

## Copy Frontend files to Frontend machine
echo "[INFO] Copying files to machine..."
scp -q -i ${SSH_PRIVATE_KEY} -P ${PORT} \
    front.py \
    Scripts/frontEnvDeploy.sh \
    Scripts/activateFrontend.sh \
    pythonEnviroments/linuxFrontReqs.txt \
    ${NAME}@${HOST}:${REPO_DIR}/

echo "[INFO] SSHing into machine..."

## TODO: Error checking.
## Install Frontend Dependencies
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} ${NAME}@${HOST} " 
    cd ${REPO_DIR}
    chmod +x frontEnvDeploy.sh
    chmod +x activateFrontend.sh

    # Run scripts
    echo '[INFO] Installing dependencies...'
    ./frontEnvDeploy.sh
"

## Start our frontend Script
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    # Start server
    ./activateFrontend.sh
"

