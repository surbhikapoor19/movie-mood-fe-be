#!/usr/bin/env bash
# recover.sh — Run from university server (e.g. linux.wpi.edu) via cron.
# Checks if Group 10 backend is alive; if not, SCPs repo and restarts it.
set -uo pipefail

# ============================================================================
# CONFIG
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_HOST="paffenroth-23.dyn.wpi.edu"
VM_PORT="22010"
VM_USER="group10"
SSH_KEY="$HOME/.ssh/Mlops_key"
HEALTH_URL="http://${VM_HOST}:9010/health"
LOCAL_REPO="$SCRIPT_DIR"
REMOTE_DIR="/home/${VM_USER}/movie-mood-fe-be"
LOG_FILE="$SCRIPT_DIR/recover.log"

SSH_CMD="ssh -i $SSH_KEY -p $VM_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${VM_USER}@${VM_HOST}"
SCP_CMD="scp -i $SSH_KEY -P $VM_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ============================================================================
# 1. HEALTH CHECK
# ============================================================================
if curl -sf --head --max-time 10 "$HEALTH_URL" > /dev/null 2>&1; then
    exit 0  # Backend is healthy, nothing to do
fi

log "Backend DOWN — starting recovery"

# ============================================================================
# 2. CHECK SSH CONNECTIVITY
# ============================================================================
if ! $SSH_CMD "echo ok" > /dev/null 2>&1; then
    log "FAIL — cannot SSH into VM, it may be completely down"
    exit 1
fi

log "SSH connection OK — pushing code"

# ============================================================================
# 3. SCP REPO FILES TO VM
# ============================================================================
$SSH_CMD "mkdir -p $REMOTE_DIR"

$SCP_CMD \
    "$LOCAL_REPO/backend.py" \
    "$LOCAL_REPO/requirements.txt" \
    "$LOCAL_REPO/deploy.sh" \
    "$LOCAL_REPO/watchdog.sh" \
    "$LOCAL_REPO/secure.sh" \
    "${VM_USER}@${VM_HOST}:${REMOTE_DIR}/"

log "Files copied to VM"

# ============================================================================
# 4. INSTALL DEPS + RESTART BACKEND ON VM
# ============================================================================
$SSH_CMD << 'REMOTE'
set -euo pipefail

REPO_DIR="$HOME/movie-mood-fe-be"
VENV_DIR="$REPO_DIR/venv"
PID_FILE="$REPO_DIR/backend.pid"
LOG_FILE="$REPO_DIR/backend.log"

cd "$REPO_DIR"

# Create venv if wiped
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install -q fastapi uvicorn

# Kill old process if any
if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

# Also kill anything else on port 9010
lsof -ti :9010 | xargs kill 2>/dev/null || true
sleep 1

# Start backend
nohup "$VENV_DIR/bin/python" backend.py >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 2
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Backend restarted (PID $(cat "$PID_FILE"))"
else
    echo "FAIL — backend did not start"
    exit 1
fi
REMOTE

log "Recovery complete — backend restarted"
