#!/usr/bin/env bash

set -Eeuo pipefail

SELKIES_PORT="${SELKIES_PORT:-8080}"
SELKIES_URL="http://127.0.0.1:${SELKIES_PORT}"

echo "=============================================="
echo "=       Selkies + Cloudflare Quick Tunnel    ="
echo "=============================================="

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

echo "[2/2] Waiting for Selkies on port ${SELKIES_PORT}..."

SELKIES_READY=0

for i in $(seq 1 120); do
    if (echo > "/dev/tcp/127.0.0.1/${SELKIES_PORT}") >/dev/null 2>&1; then
        SELKIES_READY=1
        break
    fi

    if ! kill -0 "$SELKIES_PID" >/dev/null 2>&1; then
        echo "ERROR: Selkies stopped unexpectedly."
        wait "$SELKIES_PID" || true
        exit 1
    fi

    sleep 1
done

if [[ "$SELKIES_READY" != "1" ]]; then
    echo "ERROR: Selkies did not start on port ${SELKIES_PORT}."
    exit 1
fi

clear

echo "=============================================="
echo "=             Selkies is READY               ="
echo "=          ${SELKIES_URL}                    ="
echo "=============================================="
echo ""

cleanup() {
    echo ""
    echo "Stopping services..."

    if [[ -n "${CF_PID:-}" ]] && kill -0 "$CF_PID" 2>/dev/null; then
        kill "$CF_PID" 2>/dev/null || true
    fi

    if [[ -n "${SELKIES_PID:-}" ]] && kill -0 "$SELKIES_PID" 2>/dev/null; then
        kill "$SELKIES_PID" 2>/dev/null || true
    fi

    wait "${CF_PID:-}" 2>/dev/null || true
    wait "${SELKIES_PID:-}" 2>/dev/null || true
}

trap cleanup SIGTERM SIGINT EXIT

start_cloudflare() {
    echo ""
    echo "=============================================="
    echo "=        Starting Cloudflare Tunnel         ="
    echo "=============================================="
    echo ""

    cloudflared tunnel \
        --no-autoupdate \
        --url "$SELKIES_URL" &

    CF_PID=$!

    echo "Cloudflare started (PID: $CF_PID)"
    echo "Waiting for public URL..."
    echo ""

    return 0
}

while true; do

    start_cloudflare

    # Wait until cloudflared exits.
    wait "$CF_PID" || true

    echo ""
    echo "=============================================="
    echo "=      Cloudflare Tunnel stopped             ="
    echo "=      Restarting automatically...            ="
    echo "=============================================="
    echo ""

    CF_PID=""

    # Small delay prevents a tight restart loop.
    sleep 3

    # Verify Selkies is still alive.
    if ! kill -0 "$SELKIES_PID" >/dev/null 2>&1; then
        echo "ERROR: Selkies has stopped."
        exit 1
    fi

    clear

    echo "=============================================="
    echo "=       Selkies + Cloudflare Quick Tunnel    ="
    echo "=              Reconnecting...               ="
    echo "=============================================="
    echo ""
done
