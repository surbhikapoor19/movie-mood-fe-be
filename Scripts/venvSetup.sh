#!/usr/bin/env bash

## venvSetup.sh - Run once to setup backend and frontend python virtual enviroments
PATH_TO_ENVIROMENTS=pythonEnviroments
BACKEND_VENV_NAME=backEnd
FRONTEND_VENV_NAME=frontEnd
BE_REQUIREMENTS=backendRequirements.txt
FE_REQUIREMENTS=frontendRequirements.txt

## move into our directory
cd ${PATH_TO_ENVIROMENTS}

## delete existing virtual enviroments
rm -r ${BACKEND_VENV_NAME}
rm -r ${FRONTEND_VENV_NAME}

## create our virual enviroments, and install required libraries wihtin them.
python -m venv ${FRONTEND_VENV_NAME}
${FRONTEND_VENV_NAME}/Scripts/activate
pip install -r ${FE_REQUIREMENTS}

python -m venv ${BACKEND_VENV_NAME}
${BACKEND_VENV_NAME}/Scripts/activate
pip install -r ${BE_REQUIREMENTS}

