#!/bin/bash

LOGDIR="logs"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
LOGFILE="$LOGDIR/run_$TIMESTAMP.log"
PIDFILE="orchestrator.pid"

mkdir -p "$LOGDIR"

# Prevent double start with PID lock
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" &>/dev/null; then
        echo "[ERROR] Orchestrator already running with PID $PID."
        exit 1
    else
        echo "[WARN] Stale PID file found. Removing."
        rm -f "$PIDFILE"
    fi
fi

# Run the app, tee output to log
echo $$ > "$PIDFILE"
echo "[INFO] Starting orchestrator with PID $$, logging to $LOGFILE"

# Run simple health and readiness probe server in background
start_probe_server() {
    while true; do
        if ! command -v nc &>/dev/null; then
            echo "[WARN] netcat (nc) not found, health endpoints disabled."
            break
        fi

        # Simple TCP server for health endpoints
        nc -l -p 8080 -q 1 | while read line; do
            if [[ "$line" =~ GET\ /healthz ]]; then
                echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"success\":true}"
            elif [[ "$line" =~ GET\ /readyz ]]; then
                # In production check real dependencies here
                echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"success\":true}"
            else
                echo -e "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\nNot Found"
            fi
        done
    done
}

start_probe_server &

# Run main node app, tee output to log file
npm run start 2>&1 | tee -a "$LOGFILE"
EXIT_CODE=${PIPESTATUS[0]}

rm -f "$PIDFILE"

if [ $EXIT_CODE -ne 0 ]; then
    echo "[ERROR] Orchestrator exited with code $EXIT_CODE"
    exit $EXIT_CODE
else
    echo "[INFO] Orchestrator exited normally."
fi
