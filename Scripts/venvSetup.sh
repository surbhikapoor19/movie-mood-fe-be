#!/usr/bin/env bash

## venvSetup.sh - Run once to setup backend and frontend python virtual enviroments
PATH_TO_ENVIROMENTS=pythonEnviroments
BACKEND_VENV_NAME=backEnd
FRONTEND_VENV_NAME=frontEnd
BE_REQUIREMENTS=linuxBackReqs.txt
FE_REQUIREMENTS=linuxFrontReqs.txt

## move into our directory
cd ${PATH_TO_ENVIROMENTS}

## delete existing virtual enviroments
echo "removing existing Venv"
rm -r ${BACKEND_VENV_NAME}
rm -r ${FRONTEND_VENV_NAME}

## create our virual enviroments, and install required libraries wihtin them.

echo "Installing Frontend Venv"
python3.11 -m venv ${FRONTEND_VENV_NAME}
source ${FRONTEND_VENV_NAME}/bin/activate
pip install -r ${FE_REQUIREMENTS}

echo "Installing Backend Venv"
python3.11 -m venv ${BACKEND_VENV_NAME}
source ${BACKEND_VENV_NAME}/bin/activate
pip install -r ${BE_REQUIREMENTS}

