#!/usr/bin/env bash
# backEnvDeploy.sh — Runs ON THE VM to create venv and install backend deps.
set -euo pipefail

## Install our virtual enviroments on the machine - Run once to setup backend and frontend python virtual enviroments
REPO_DIR=/home/group10/movie-mood-fe-be
BACKEND_VENV_NAME=backVenv
BE_REQUIREMENTS=linuxBackReqs.txt

cd ${REPO_DIR}

if [[ ! -f "$BE_REQUIREMENTS" ]]; then
  echo "[ERROR] Requirements file not found: $REPO_DIR/$BE_REQUIREMENTS" >&2
  exit 1
fi

if [[ ! -d "$BACKEND_VENV_NAME" ]]; then
  echo "[INFO] Creating backend venv: $BACKEND_VENV_NAME"
  python3.11 -m venv "$BACKEND_VENV_NAME"
else
  echo "[INFO] Using existing backend venv: $BACKEND_VENV_NAME"
fi

source ${BACKEND_VENV_NAME}/bin/activate

echo "[INFO] Installing backend requirements from: $BE_REQUIREMENTS"
python -m pip install --prefer-binary -r "$BE_REQUIREMENTS"
