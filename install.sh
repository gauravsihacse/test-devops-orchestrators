#!/bin/bash

LOGDIR="logs"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
LOGFILE="$LOGDIR/setup_install_$TIMESTAMP.log"
REPO_URL="https://github.com/veltrix-capital/test-devops-orchestrators.git"
REPO_DIR="test-devops-orchestrators"

mkdir -p "$LOGDIR"

exec > >(tee -a "$LOGFILE") 2>&1

echo "[${TIMESTAMP}] Starting install.sh..."

# Pre-flight check: git existence
if ! command -v git &>/dev/null; then
    echo "[ERROR] git is not installed or not in PATH. Please install git first."
    exit 1
fi

# Clone or update repo
if [ -d "$REPO_DIR/.git" ]; then
    echo "[INFO] Repository exists, pulling latest changes..."
    cd "$REPO_DIR" || { echo "[ERROR] Failed to cd into $REPO_DIR"; exit 1; }
    git pull || { echo "[ERROR] git pull failed"; exit 1; }
else
    echo "[INFO] Cloning repository..."
    git clone "$REPO_URL" "$REPO_DIR" || { echo "[ERROR] git clone failed"; exit 1; }
    cd "$REPO_DIR" || { echo "[ERROR] Failed to cd into $REPO_DIR"; exit 1; }
fi

# Make necessary scripts executable
echo "[INFO] Setting execute permissions on setup.sh and start.sh"
chmod +x setup.sh start.sh || { echo "[ERROR] Failed chmod"; exit 1; }

# Run setup script
echo "[INFO] Executing setup.sh"
./setup.sh || { echo "[ERROR] setup.sh failed"; exit 1; }

echo "[${TIMESTAMP}] install.sh completed successfully."
