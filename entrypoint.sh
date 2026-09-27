#!/usr/bin/env bash

set -Eeuo pipefail

SELKIES_PORT="${SELKIES_PORT:-8080}"

echo "=============================================="
echo "=     Selkies + Cloudflare Quick Tunnel      ="
echo "=============================================="

echo "[1/2] Starting Selkies..."

if [[ -x /entrypoint.sh ]]; then
    /entrypoint.sh &
    SELKIES_PID=$!
elif [[ -x /usr/local/bin/entrypoint ]]; then
    /usr/local/bin/entrypoint &
    SELKIES_PID=$!
else
    echo "ERROR: Selkies entrypoint was not found."
    exit 1
fi

echo "[2/2] Waiting for Selkies on port ${SELKIES_PORT}..."

READY=0

for i in $(seq 1 120); do
    if (echo > "/dev/tcp/127.0.0.1/${SELKIES_PORT}") >/dev/null 2>&1; then
        READY=1
        break
    fi

    if ! kill -0 "$SELKIES_PID" >/dev/null 2>&1; then
        echo "ERROR: Selkies exited before becoming ready."
        wait "$SELKIES_PID" || true
        exit 1
    fi

    sleep 1
done

if [[ "$READY" != "1" ]]; then
    echo "ERROR: Selkies did not become ready on port ${SELKIES_PORT}."
    kill "$SELKIES_PID" 2>/dev/null || true
    exit 1
fi

echo ""
echo "=============================================="
echo "=             Selkies is READY               ="
echo "=        http://127.0.0.1:${SELKIES_PORT}          ="
echo "=============================================="
echo ""

echo "[+] Starting Cloudflare Quick Tunnel..."
echo ""

cloudflared tunnel \
    --no-autoupdate \
    --url "http://127.0.0.1:${SELKIES_PORT}" &

CF_PID=$!

cleanup() {
    echo ""
    echo "[+] Stopping Cloudflare Tunnel..."
    kill "$CF_PID" 2>/dev/null || true

    echo "[+] Stopping Selkies..."
    kill "$SELKIES_PID" 2>/dev/null || true

    wait "$CF_PID" 2>/dev/null || true
    wait "$SELKIES_PID" 2>/dev/null || true
}

trap cleanup SIGTERM SIGINT EXIT

while true; do
    if ! kill -0 "$SELKIES_PID" 2>/dev/null; then
        echo "ERROR: Selkies stopped."
        exit 1
    fi

    if ! kill -0 "$CF_PID" 2>/dev/null; then
        echo "ERROR: Cloudflare Tunnel stopped."
        exit 1
    fi

    sleep 5
done
