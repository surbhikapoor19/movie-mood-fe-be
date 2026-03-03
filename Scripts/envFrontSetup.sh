#!/usr/bin/env bash
# envFrontSetup.sh — Copy frontend files to VM and install dependencies + start.
# Run from your local machine (or linux.wpi.edu).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR_LOCAL="$(cd "$SCRIPT_DIR/.." && pwd)"

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
PORT=22000
NAME=group10
HOST=paffenroth-23.dyn.wpi.edu
REPO_DIR=/home/group10/movie-mood-fe-be

cd "$REPO_DIR_LOCAL"

# Clear stale host key
ssh-keygen -R "[${HOST}]:${PORT}" 2>/dev/null || true

echo "[INFO] Copying frontend files to VM..."
scp -q -i ${SSH_PRIVATE_KEY} -P ${PORT} -o StrictHostKeyChecking=no \
    front.py \
    Scripts/frontEnvDeploy.sh \
    Scripts/activateFrontend.sh \
    pythonEnviroments/linuxFrontReqs.txt \
    ${NAME}@${HOST}:${REPO_DIR}/

# Copy .env if it exists
if [ -f .env ]; then
    scp -q -i ${SSH_PRIVATE_KEY} -P ${PORT} -o StrictHostKeyChecking=no \
        .env ${NAME}@${HOST}:${REPO_DIR}/
fi

echo "[INFO] SSHing into machine to install dependencies..."
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} -o StrictHostKeyChecking=no ${NAME}@${HOST} "
    cd ${REPO_DIR}
    chmod +x frontEnvDeploy.sh
    chmod +x activateFrontend.sh

    echo '[INFO] Installing dependencies...'
    ./frontEnvDeploy.sh
"

echo "[INFO] Starting frontend..."
ssh -i ${SSH_PRIVATE_KEY} -p ${PORT} -o StrictHostKeyChecking=no ${NAME}@${HOST} "
    cd ${REPO_DIR}
    ./activateFrontend.sh
"
echo "[INFO] Frontend setup complete!"

