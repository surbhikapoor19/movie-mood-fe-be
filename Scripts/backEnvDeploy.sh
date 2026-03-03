#!/usr/bin/env bash
# backEnvDeploy.sh — Runs ON THE VM to create venv and install backend deps.
set -euo pipefail

# Make sure our required dependencies are installed
sudo apt-get update -qq
sudo apt-get install -y -qq python3.11 python3-pip python3.11-venv git > /dev/null

REPO_DIR=/home/group10/movie-mood-fe-be
BACKEND_VENV_NAME=backEnd
# Use the requirements file passed from envBackSetup.sh, fallback to requirements_local.txt
BE_REQUIREMENTS="${REQS_FILE:-requirements_local.txt}"

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
python -m pip install -q -r "$BE_REQUIREMENTS"

echo "[INFO] Backend dependencies installed!"