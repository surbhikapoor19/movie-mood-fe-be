#!/usr/bin/env bash

PORT=22010
NAME=group10
HOST=paffenroth-23.dyn.wpi.edu
REPO_DIR=/home/group10/movie-mood-fe-be
SCRIPT_DIR="backendScripts"

# Auto-detect SSH key — supports both team members
if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
    : # use explicit override
elif [ -f "$HOME/.ssh/MlopKey" ]; then
    SSH_PRIVATE_KEY="$HOME/.ssh/MlopKey"
elif [ -f "$HOME/.ssh/wpiMlopsKey" ]; then
    SSH_PRIVATE_KEY="$HOME/.ssh/wpiMlopsKey"
else
    echo "[ERROR] No SSH key found. Set SSH_PRIVATE_KEY or place key at ~/.ssh/MlopKey or ~/.ssh/wpiMlopsKey"
    exit 1
fi

# Auto-detect repo directory
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "$(cd "$SCRIPT_PATH/../.." && pwd)"

# Clear stale host key (VM resets change it)
ssh-keygen -R "[${HOST}]:${PORT}" 2>/dev/null || true


## Copy only neccessary files to backend
echo "[INFO] Copying files to machine"
scp -q -i ${SSH_PRIVATE_KEY} -P ${PORT} -o StrictHostKeyChecking=no -r \
    .env \
    back.py \
    Scripts/$SCRIPT_DIR \
    tempHealthPage.py \
    pythonEnviroments/linuxBackReqs.txt \
    ${NAME}@${HOST}:${REPO_DIR}/

# Make scripts executable
echo "[INFO] Setting up machine"
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} -o StrictHostKeyChecking=no ${NAME}@${HOST} " 
    cd ${REPO_DIR}
    chmod +x $SCRIPT_DIR/*
"

## Install required packages
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} -o StrictHostKeyChecking=no ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    echo '[INFO] Installing dependencies'
    $SCRIPT_DIR/backEnvDeploy.sh
"

## Start our temporary health directory
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} -o StrictHostKeyChecking=no ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    echo '[INFO] Starting Temp Health Page'
    $SCRIPT_DIR/tempBackend.sh
"

## Download our Venv requirements
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} -o StrictHostKeyChecking=no ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    echo '[INFO] Installing Venv Packages'
    $SCRIPT_DIR/backVenvDeploy.sh
"

## Start our backend Script
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} -o StrictHostKeyChecking=no ${NAME}@${HOST} " 
    cd ${REPO_DIR}

    # Start server
    echo '[INFO] Starting Backend'
    $SCRIPT_DIR/activateBackend.sh
"

