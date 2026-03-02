#!/usr/bin/env bash

SSH_PRIVATE_KEY=/home/cmfrench/.ssh/wpiMlopsKey
PORT=22010
NAME=group10
HOST=paffenroth-23.dyn.wpi.edu
REPO_DIR=/home/group10/movie-mood-fe-be
## Copy only neccessary files to backend
# .env
# back.py
# Scripts/serverEnvDeploy.sh
# pythonEnviroments/linuxBackReqs.txt
# pythonEnviroments/backEnd
cd /home/cmfrench/Documents/MLops/movie-mood-fe-be # TODO: Make this more general
# TODO: First make sure that the venv exists on our local machine. if it doesn't make it first
echo "copying files to machine..."
scp -q -i ${SSH_PRIVATE_KEY} -P ${PORT} \
    .env \
    back.py \
    Scripts/serverEnvDeploy.sh \
    pythonEnviroments/linuxBackReqs.txt \
    ${NAME}@${HOST}:${REPO_DIR}/

## Run Environment setup scripts
# Make scripts executable
echo "sshing into machine..."

## TODO: Error checking.
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} ${NAME}@${HOST} " 
    cd ${REPO_DIR}
    chmod +x serverEnvDeploy.sh

    # Run scripts
    echo 'installing dependencies..'
    ./serverEnvDeploy.sh
"
echo "done!"


