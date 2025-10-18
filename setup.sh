#!/bin/bash

LOGDIR="logs"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
LOGFILE="$LOGDIR/setup_setup_$TIMESTAMP.log"

mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGFILE") 2>&1

echo "[${TIMESTAMP}] Setup started."

# Detect OS
OS="$(uname -s)"
echo "[INFO] Detected OS: $OS"

check_node_version() {
    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        echo "[WARN] Node.js or npm not found."
        return 1
    fi

    NODE_VER=$(node -v | sed 's/v//')
    NODE_MAJOR=${NODE_VER%%.*}
    if [ "$NODE_MAJOR" -lt 18 ]; then
        echo "[ERROR] Node.js version must be 18 or higher. Found version $NODE_VER"
        exit 1
    else
        echo "[INFO] Node.js version $NODE_VER is sufficient."
    fi
    return 0
}

install_node() {
    echo "[INFO] Installing Node.js..."

    case "$OS" in
        Linux*)
            if [ -f /etc/debian_version ]; then
                curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
                sudo apt-get install -y nodejs
            elif [ -f /etc/redhat-release ]; then
                curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
                sudo yum install -y nodejs
            else
                echo "[ERROR] Unsupported Linux distro. Please install Node.js manually."
                exit 1
            fi
            ;;
        Darwin*)
            if command -v brew &>/dev/null; then
                brew install node
            else
                echo "[ERROR] Homebrew not found. Please install Node.js manually."
                exit 1
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "[ERROR] Windows Git Bash or similar detected. Please install Node.js manually."
            exit 1
            ;;
        *)
            echo "[ERROR] Unknown OS: $OS"
            exit 1
            ;;
    esac
}

check_node_version || install_node

echo "[INFO] Preparing logs directory..."
mkdir -p logs

echo "[INFO] Installing npm dependencies..."
npm install || { echo "[ERROR] npm install failed"; exit 1; }

# .env setup
if [ ! -f .env ]; then
    if [ -f .env_example ]; then
        cp .env_example .env
        echo "[INFO] .env file created from .env_example. Please update INFURA_URL in .env."
    else
        echo "[ERROR] Neither .env nor .env_example found."
        exit 1
    fi
fi

echo "[${TIMESTAMP}] Setup completed successfully."

# Start the app in dev mode
npm run dev
