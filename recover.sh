#!/usr/bin/env bash
# recover.sh — Run from university server (e.g. linux.wpi.edu) via cron.
# Checks if Group 10 backend is alive; if not, SCPs repo and restarts it.
#
# Crontab on linux.wpi.edu:
#   */2 * * * * /home/skapoor/movie-mood-fe-be/recover.sh
#   @reboot     eval "$(ssh-agent -s)" > /dev/null && ssh-add ~/.ssh/MlopKey 2>/dev/null; echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > ~/.ssh/agent_env; echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.ssh/agent_env
set -uo pipefail

# ============================================================================
# CONFIG
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_HOST="paffenroth-23.dyn.wpi.edu"
VM_PORT="22010"
VM_USER="group10"
SSH_KEY="$HOME/.ssh/MlopKey"
AGENT_ENV="$HOME/.ssh/agent_env"
HEALTH_URL="http://${VM_HOST}:9010/health"
LOCAL_REPO="$SCRIPT_DIR"
REMOTE_DIR="/home/${VM_USER}/movie-mood-fe-be"
LOG_FILE="$SCRIPT_DIR/recover.log"

# Which backend to deploy: "local" uses back_local.py (GGUF model),
# "api" uses back_api.py (HF Inference API)
BACKEND_MODE="${BACKEND_MODE:-local}"

# Load ssh-agent if available (needed for passphrase-protected keys in cron)
if [ -f "$AGENT_ENV" ]; then
    . "$AGENT_ENV" > /dev/null
fi

SSH_CMD="ssh -i $SSH_KEY -p $VM_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${VM_USER}@${VM_HOST}"
SCP_CMD="scp -i $SSH_KEY -P $VM_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ============================================================================
# 1. HEALTH CHECK
# ============================================================================
if curl -sf --max-time 10 "$HEALTH_URL" > /dev/null 2>&1; then
    exit 0  # Backend is healthy, nothing to do
fi

log "Backend DOWN — starting recovery (mode=$BACKEND_MODE)"

# ============================================================================
# 2. CHECK SSH CONNECTIVITY
# ============================================================================
if ! $SSH_CMD "echo ok" > /dev/null 2>&1; then
    log "FAIL — cannot SSH into VM, it may be completely down"
    exit 1
fi

log "SSH connection OK — pushing code"

# ============================================================================
# 3. CLEAN KNOWN HOSTS (VM reset changes host key)
# ============================================================================
ssh-keygen -R "[${VM_HOST}]:${VM_PORT}" 2>/dev/null || true

# ============================================================================
# 4. SCP FILES TO VM
# ============================================================================
$SSH_CMD "mkdir -p $REMOTE_DIR"

# Select the right backend file and requirements based on mode
if [ "$BACKEND_MODE" = "api" ]; then
    BACKEND_FILE="back_api.py"
    REQS_FILE="requirements_api.txt"
else
    BACKEND_FILE="back_local.py"
    REQS_FILE="requirements_local.txt"
fi

# Copy backend, requirements, frontend, and .env
$SCP_CMD \
    "$LOCAL_REPO/$BACKEND_FILE" \
    "$LOCAL_REPO/$REQS_FILE" \
    "$LOCAL_REPO/front.py" \
    "$LOCAL_REPO/watchdog.sh" \
    "${VM_USER}@${VM_HOST}:${REMOTE_DIR}/"

# Copy .env if it exists (contains API keys — not in git)
if [ -f "$LOCAL_REPO/.env" ]; then
    $SCP_CMD "$LOCAL_REPO/.env" "${VM_USER}@${VM_HOST}:${REMOTE_DIR}/"
fi

log "Files copied to VM ($BACKEND_FILE, $REQS_FILE)"

# ============================================================================
# 5. INSTALL DEPS + RESTART BACKEND ON VM
# ============================================================================
$SSH_CMD "BACKEND_FILE=$BACKEND_FILE REQS_FILE=$REQS_FILE" bash -s << 'REMOTE'
set -euo pipefail

REPO_DIR="$HOME/movie-mood-fe-be"
VENV_DIR="$REPO_DIR/backEnd"
PID_FILE="$REPO_DIR/backend.pid"
LOG_FILE="$REPO_DIR/backend.log"

cd "$REPO_DIR"

# Create venv if wiped (use python3.11 if available, else python3)
if [ ! -d "$VENV_DIR" ]; then
    if command -v python3.11 &>/dev/null; then
        python3.11 -m venv "$VENV_DIR"
    else
        python3 -m venv "$VENV_DIR"
    fi
fi

source "$VENV_DIR/bin/activate"
pip install -q -r "$REQS_FILE"

# Kill old process if any
if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

# Also kill anything else on port 9010
lsof -ti :9010 | xargs kill 2>/dev/null || true
sleep 1

# Start backend
nohup "$VENV_DIR/bin/python" "$BACKEND_FILE" >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 3
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Backend restarted (PID $(cat "$PID_FILE")), running $BACKEND_FILE"
else
    echo "FAIL — backend did not start, check $LOG_FILE"
    tail -20 "$LOG_FILE"
    exit 1
fi
REMOTE

log "Recovery complete — backend restarted ($BACKEND_FILE)"
