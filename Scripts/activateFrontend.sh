#!/usr/bin/env bash
set -euo pipefail
REPO_DIR=/home/group10/movie-mood-fe-be
FRONTEND_VENV=frontEnd

## start by killing any existing tmux terminals
tmux kill-server 2>/dev/null || true

## start up an new tmux session and store the PID
SESSION_NAME="frontend"
tmux new-session -d -s "$SESSION_NAME" "\
    cd ${REPO_DIR} &&\
    source ${FRONTEND_VENV}/bin/activate &&\
    python front.py\
"

if tmux has-session -t ${SESSION_NAME} 2>/dev/null; then
    echo "[OK] Successfully start tmux session."
else
    echo "[ERROR] Tmux session failed to start" >&2
    exit
fi