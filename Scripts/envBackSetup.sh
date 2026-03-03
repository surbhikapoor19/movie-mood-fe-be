#!/usr/bin/env bash
# envBackSetup.sh — Deploy + recover backend for Group 10.
# Can be run manually OR via cron on linux.wpi.edu for auto-recovery.
#
# Manual deploy:  bash Scripts/envBackSetup.sh
# Cron recovery:  bash Scripts/envBackSetup.sh --cron
#
# Crontab on linux.wpi.edu:
#   */2 * * * * /home/skapoor/movie-mood-fe-be/Scripts/envBackSetup.sh --cron
#   @reboot     eval "$(ssh-agent -s)" > /dev/null && ssh-add ~/.ssh/MlopKey 2>/dev/null; echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > ~/.ssh/agent_env; echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.ssh/agent_env
set -uo pipefail

# ============================================================================
# CONFIG
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR_LOCAL="$(cd "$SCRIPT_DIR/.." && pwd)"

PORT=22010
NAME=group10
HOST=paffenroth-23.dyn.wpi.edu
REPO_DIR=/home/group10/movie-mood-fe-be
HEALTH_URL="http://${HOST}:9010/health"
LOG_FILE="$REPO_DIR_LOCAL/recover.log"
AGENT_ENV="$HOME/.ssh/agent_env"

# Which backend to deploy: "local" or "api"
BACKEND_MODE="${BACKEND_MODE:-local}"

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

# Load ssh-agent if available (needed for passphrase-protected keys in cron)
if [ -f "$AGENT_ENV" ]; then
    . "$AGENT_ENV" > /dev/null
fi

SSH_CMD="ssh -i $SSH_PRIVATE_KEY -p $PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${NAME}@${HOST}"
SCP_CMD="scp -i $SSH_PRIVATE_KEY -P $PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ============================================================================
# 1. HEALTH CHECK (only in --cron mode)
# ============================================================================
if [ "${1:-}" = "--cron" ]; then
    if curl -sf --max-time 10 "$HEALTH_URL" > /dev/null 2>&1; then
        exit 0  # Backend is healthy, nothing to do
    fi
    log "Backend DOWN — starting recovery (mode=$BACKEND_MODE)"
fi

# ============================================================================
# 2. CHECK SSH CONNECTIVITY
# ============================================================================
if ! $SSH_CMD "echo ok" > /dev/null 2>&1; then
    log "FAIL — cannot SSH into VM, it may be completely down"
    echo "[ERROR] Cannot SSH into VM"
    exit 1
fi

echo "[INFO] SSH connection OK"

# Clear stale host key (VM resets change it)
ssh-keygen -R "[${HOST}]:${PORT}" 2>/dev/null || true

# ============================================================================
# 3. SELECT BACKEND FILES
# ============================================================================
if [ "$BACKEND_MODE" = "api" ]; then
    BACKEND_FILE="back_api.py"
    REQS_FILE="requirements_api.txt"
else
    BACKEND_FILE="back_local.py"
    REQS_FILE="requirements_local.txt"
fi

# ============================================================================
# 4. SCP FILES TO VM
# ============================================================================
$SSH_CMD "mkdir -p $REPO_DIR"

cd "$REPO_DIR_LOCAL"

echo "[INFO] Copying backend files to VM ($BACKEND_MODE mode)..."
$SCP_CMD \
    "$BACKEND_FILE" \
    "$REQS_FILE" \
    Scripts/backEnvDeploy.sh \
    ${NAME}@${HOST}:${REPO_DIR}/

# Copy .env if it exists (contains API keys — not in git)
if [ -f .env ]; then
    $SCP_CMD .env ${NAME}@${HOST}:${REPO_DIR}/
fi

log "Files copied to VM ($BACKEND_FILE, $REQS_FILE)"

# ============================================================================
# 5. INSTALL DEPS + START BACKEND ON VM
# ============================================================================
echo "[INFO] Installing dependencies and starting backend..."
$SSH_CMD "BACKEND_FILE=$BACKEND_FILE REQS_FILE=$REQS_FILE" bash -s << 'REMOTE'
set -euo pipefail

REPO_DIR="$HOME/movie-mood-fe-be"
VENV_DIR="$REPO_DIR/backEnd"
PID_FILE="$REPO_DIR/backend.pid"
LOG_FILE="$REPO_DIR/backend.log"

cd "$REPO_DIR"

# Make deploy script executable and run it (creates venv + installs deps)
chmod +x backEnvDeploy.sh
./backEnvDeploy.sh

# Kill old process if any
if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

# Also kill anything else on port 9010
lsof -ti :9010 | xargs kill 2>/dev/null || true
sleep 1

# Start backend
source "$VENV_DIR/bin/activate"
nohup "$VENV_DIR/bin/python" "$BACKEND_FILE" >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 3
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[OK] Backend started (PID $(cat "$PID_FILE")), running $BACKEND_FILE"
else
    echo "[FAIL] Backend did not start, check $LOG_FILE"
    tail -20 "$LOG_FILE"
    exit 1
fi
REMOTE

log "Deploy complete — backend running ($BACKEND_FILE)"
echo "[INFO] Backend setup complete!"

# ============================================================================
# 6. DEPLOY FRONTEND
# ============================================================================
echo "[INFO] Deploying frontend..."
bash "$SCRIPT_DIR/envFrontSetup.sh"
