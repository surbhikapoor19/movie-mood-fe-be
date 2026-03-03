#!/usr/bin/env bash
set -euo pipefail

## Install our virtual enviroments on the machine - Run once to setup backend and frontend python virtual enviroments
REPO_DIR=/home/group10/movie-mood-fe-be
FRONTEND_VENV_NAME=frontEnd
FE_REQUIREMENTS=linuxFrontReqs.txt

## move into our directory
cd ${REPO_DIR}

## Check if our requirments file exists
if [[ ! -f "$FE_REQUIREMENTS" ]]; then
  echo "[ERROR] Requirements file not found: $REPO_DIR/$FE_REQUIREMENTS" >&2
  exit 1
fi

## check for existing venv; create if missing
if [[ ! -d "$FRONTEND_VENV_NAME" ]]; then
  echo "[INFO] Creating backend venv: $FRONTEND_VENV_NAME"
  python3.11 -m venv "$FRONTEND_VENV_NAME"
else
  echo "[INFO] Using existing backend venv: $FRONTEND_VENV_NAME"
fi

## activate our venv
source ${FRONTEND_VENV_NAME}/bin/activate

## install requirements if not already installed
echo "[INFO] Installing backend requirements from: $FE_REQUIREMENTS"
python -m pip install -q -r "$FE_REQUIREMENTS"