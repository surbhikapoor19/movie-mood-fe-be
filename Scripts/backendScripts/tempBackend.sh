#!/usr/bin/env bash
set -euo pipefail
REPO_DIR=/home/group10/movie-mood-fe-be

## start by killing any existing tmux terminals
tmux kill-server 2>/dev/null || true

## start up an new tmux session and store the PID
SESSION_NAME="tempHealth"
tmux new-session -d -s "$SESSION_NAME" "\
    cd ${REPO_DIR} &&\
    python3.11 tempHealthPage.py\
"