#!/usr/bin/env bash
# deploy.sh — Install deps + launch persistent backend API for Group 10
# Can be re-run safely — stops old instance before starting new one.
set -euo pipefail

REPO_DIR="$HOME/movie-mood-fe-be"
VENV_DIR="$REPO_DIR/venv"
PID_FILE="$REPO_DIR/backend.pid"
LOG_FILE="$REPO_DIR/backend.log"

# ============================================================================
# 1. ENVIRONMENT SETUP
# ============================================================================
echo "=== Environment Setup ==="

sudo apt-get update -qq
sudo apt-get install -y -qq python3 python3-pip python3-venv git > /dev/null

cd "$REPO_DIR"

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "[OK] Virtual environment created"
fi

source "$VENV_DIR/bin/activate"
pip install -q -r requirements.txt
echo "[OK] Dependencies installed"
echo ""

# ============================================================================
# 2. STOP OLD INSTANCE (if running)
# ============================================================================
echo "=== Deploying Backend ==="

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[INFO] Stopping old backend (PID $OLD_PID)..."
        kill "$OLD_PID"
        sleep 2
    fi
    rm -f "$PID_FILE"
fi

# ============================================================================
# 3. START BACKEND (persistent via nohup)
# ============================================================================
nohup "$VENV_DIR/bin/python" backend.py >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "[OK] Backend started (PID $(cat "$PID_FILE")), logging to $LOG_FILE"

sleep 2
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[OK] Backend is running on port 9010"
else
    echo "[FAIL] Backend failed to start. Check $LOG_FILE"
    exit 1
fi

echo ""
echo "=== Deployment complete ==="
echo "Test: curl -I http://$(hostname):9010/health"
