#!/usr/bin/env bash

SSH_PRIVATE_KEY=/home/cmfrench/.ssh/wpiMlopsKey
PORT=22000
NAME=group10
HOST=paffenroth-23.dyn.wpi.edu
REPO_DIR=/home/group10/movie-mood-fe-be
SCRIPT_DIR="frontendScripts"

# TODO: Make this more general
cd /home/cmfrench/Documents/MLops/movie-mood-fe-be

## TODO: Update our Known hosts with the ssh key (if the VM restarts this is necessary)

## Copy only neccessary files to frontend
echo "[INFO] Copying files to machine"
scp -q -i ${SSH_PRIVATE_KEY} -P ${PORT} -r \
    front.py \
    Scripts/$SCRIPT_DIR \
    pythonEnviroments/linuxFrontReqs.txt \
    ${NAME}@${HOST}:${REPO_DIR}/

# Make scripts executable
echo "[INFO] Setting up machine"
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} ${NAME}@${HOST} " 
    cd ${REPO_DIR}
    chmod +x $SCRIPT_DIR/*
"

## Install required packages
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    echo '[INFO] Installing dependencies'
    $SCRIPT_DIR/frontEnvDeploy.sh
"

## Download our Venv requirements
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    echo '[INFO] Installing Venv Packages'
    $SCRIPT_DIR/frontVenvDeploy.sh
"

## Start our backend Script
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    # Start server
    echo '[INFO] Starting Frontend'
    $SCRIPT_DIR/activateFrontend.sh
"

