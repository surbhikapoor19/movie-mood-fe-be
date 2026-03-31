#!/usr/bin/env bash
set -euo pipefail
REPO_DIR=/home/group10/movie-mood-fe-be
BACKEND_VIEW=backVenv

## start by killing any existing tmux terminals
tmux kill-server 2>/dev/null || true

## start up an new tmux session and store the PID
SESSION_NAME="backend"
tmux new-session -d -s "$SESSION_NAME" "\
    cd ${REPO_DIR} &&\
    source ${BACKEND_VIEW}/bin/activate &&\
    python back.py\
"

if tmux has-session -t ${SESSION_NAME} 2>/dev/null; then
    echo "[OK] Successfully start tmux session."
else
    echo "[ERROR] Tmux session failed to start" >&2
    exit
fi