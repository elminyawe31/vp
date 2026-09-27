#!/usr/bin/env bash

set -Eeuo pipefail

echo "=============================================="
echo "=       Selkies + Cloudflare Quick Tunnel    ="
echo "=============================================="

# Start the original Selkies entrypoint in the background.
echo "[1/2] Starting Selkies..."

if [[ -x /entrypoint.sh ]]; then
    /entrypoint.sh &
elif [[ -x /usr/local/bin/entrypoint ]]; then
    /usr/local/bin/entrypoint &
else
    echo "ERROR: Could not find the Selkies entrypoint."
    exit 1
fi

SELKIES_PID=$!

echo "[2/2] Waiting for Selkies on port ${SELKIES_PORT:-8080}..."

for i in $(seq 1 120); do
    if (echo > /dev/tcp/127.0.0.1/${SELKIES_PORT:-8080}) >/dev/null 2>&1; then
        break
    fi

    if ! kill -0 "$SELKIES_PID" >/dev/null 2>&1; then
        echo "ERROR: Selkies stopped unexpectedly."
        wait "$SELKIES_PID" || true
        exit 1
    fi

    sleep 1
done

if ! (echo > /dev/tcp/127.0.0.1/${SELKIES_PORT:-8080}) >/dev/null 2>&1; then
    echo "ERROR: Selkies did not start on port ${SELKIES_PORT:-8080}."
    exit 1
fi

echo ""
echo "=============================================="
echo "=          Selkies is running                ="
echo "=          http://127.0.0.1:8080             ="
echo "=============================================="
echo ""
echo "Starting Cloudflare Quick Tunnel..."
echo ""

cloudflared tunnel \
    --no-autoupdate \
    --url "http://127.0.0.1:${SELKIES_PORT:-8080}" &

CF_PID=$!

cleanup() {
    echo ""
    echo "Stopping Cloudflare Tunnel..."
    kill "$CF_PID" 2>/dev/null || true

    echo "Stopping Selkies..."
    kill "$SELKIES_PID" 2>/dev/null || true

    wait "$CF_PID" 2>/dev/null || true
    wait "$SELKIES_PID" 2>/dev/null || true
}

trap cleanup SIGTERM SIGINT EXIT

wait "$SELKIES_PID"
