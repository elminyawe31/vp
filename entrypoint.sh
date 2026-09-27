#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Selkies + Cloudflare Quick Tunnel
# ============================================================

SELKIES_PORT="${SELKIES_PORT:-8080}"
CF_LOG="/tmp/cloudflared.log"

SELKIES_PID=""
CF_PID=""

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

clear_screen() {
    # Clear terminal without depending on the `clear` command.
    printf '\033[2J\033[H'
}

cleanup() {
    echo ""
    echo "=============================================="
    echo "Stopping services..."
    echo "=============================================="

    if [[ -n "${CF_PID}" ]] && kill -0 "${CF_PID}" >/dev/null 2>&1; then
        kill "${CF_PID}" 2>/dev/null || true
    fi

    if [[ -n "${SELKIES_PID}" ]] && kill -0 "${SELKIES_PID}" >/dev/null 2>&1; then
        kill "${SELKIES_PID}" 2>/dev/null || true
    fi

    wait "${CF_PID}" 2>/dev/null || true
    wait "${SELKIES_PID}" 2>/dev/null || true

    exit 0
}

trap cleanup SIGTERM SIGINT

# ------------------------------------------------------------
# Start Selkies
# ------------------------------------------------------------

echo "=============================================="
echo "= Selkies + Cloudflare Quick Tunnel ="
echo "=============================================="
echo ""
echo "[1/2] Starting Selkies..."

# Start the original Selkies entrypoint.
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

# ------------------------------------------------------------
# Wait for Selkies
# ------------------------------------------------------------

SELKIES_READY=0

for i in $(seq 1 120); do
    if (echo > "/dev/tcp/127.0.0.1/${SELKIES_PORT}") >/dev/null 2>&1; then
        SELKIES_READY=1
        break
    fi

    if ! kill -0 "${SELKIES_PID}" >/dev/null 2>&1; then
        echo "ERROR: Selkies stopped unexpectedly."
        wait "${SELKIES_PID}" || true
        exit 1
    fi

    sleep 1
done

if [[ "${SELKIES_READY}" != "1" ]]; then
    echo "ERROR: Selkies did not start on port ${SELKIES_PORT}."
    exit 1
fi

echo ""
echo "Selkies is ready."
echo "Internal: http://127.0.0.1:${SELKIES_PORT}"
echo ""

# ------------------------------------------------------------
# Cloudflare supervisor
# ------------------------------------------------------------

start_cloudflare() {
    # Make sure no old process remains.
    if [[ -n "${CF_PID}" ]] && kill -0 "${CF_PID}" >/dev/null 2>&1; then
        kill "${CF_PID}" 2>/dev/null || true
        wait "${CF_PID}" 2>/dev/null || true
    fi

    # Fresh log for this Cloudflare attempt.
    : > "${CF_LOG}"

    echo ""
    echo "=============================================="
    echo "= Starting Cloudflare Quick Tunnel ="
    echo "=============================================="
    echo ""

    # Run cloudflared silently into a temporary log.
    cloudflared tunnel \
        --no-autoupdate \
        --url "http://127.0.0.1:${SELKIES_PORT}" \
        >"${CF_LOG}" 2>&1 &

    CF_PID=$!

    # Wait for Cloudflare to generate the trycloudflare URL.
    local tunnel_url=""
    local attempts=0

    while [[ ${attempts} -lt 60 ]]; do

        # If cloudflared died before producing a URL.
        if ! kill -0 "${CF_PID}" >/dev/null 2>&1; then
            echo ""
            echo "Cloudflare exited before creating a tunnel."
            echo ""
            echo "Last Cloudflare messages:"
            tail -n 15 "${CF_LOG}" 2>/dev/null || true
            echo ""
            return 1
        fi

        tunnel_url="$(
            grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' \
            "${CF_LOG}" 2>/dev/null |
            head -n 1 || true
        )"

        if [[ -n "${tunnel_url}" ]]; then
            break
        fi

        sleep 1
        attempts=$((attempts + 1))
    done

    # --------------------------------------------------------
    # Clean terminal and show ONLY useful Cloudflare info.
    # --------------------------------------------------------

    if [[ -n "${tunnel_url}" ]]; then
        clear_screen

        echo "=============================================="
        echo "=          CLOUDFLARE TUNNEL READY          ="
        echo "=============================================="
        echo ""
        echo "URL:"
        echo ""
        echo "${tunnel_url}"
        echo ""
        echo "Selkies:"
        echo "http://127.0.0.1:${SELKIES_PORT}"
        echo ""
        echo "Status: ONLINE"
        echo ""
        echo "=============================================="
        echo "Cloudflare monitor is active."
        echo "If the tunnel stops, it will restart automatically."
        echo "=============================================="
        echo ""
    else
        echo ""
        echo "Cloudflare did not provide a tunnel URL."
        echo ""
        tail -n 20 "${CF_LOG}" 2>/dev/null || true
        echo ""
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Cloudflare watchdog
# ------------------------------------------------------------

while true; do

    # Make sure Selkies is still alive.
    if ! kill -0 "${SELKIES_PID}" >/dev/null 2>&1; then
        echo ""
        echo "ERROR: Selkies stopped."
        echo "Stopping container..."
        exit 1
    fi

    # Start Cloudflare.
    if ! start_cloudflare; then
        clear_screen

        echo "=============================================="
        echo "= Cloudflare failed to start                 ="
        echo "=============================================="
        echo ""
        echo "Retrying in 5 seconds..."
        echo ""

        sleep 5
        continue
    fi

    # --------------------------------------------------------
    # Monitor Cloudflare
    # --------------------------------------------------------

    while true; do

        # Selkies died -> entire container should stop.
        if ! kill -0 "${SELKIES_PID}" >/dev/null 2>&1; then
            echo ""
            echo "ERROR: Selkies stopped."
            exit 1
        fi

        # Cloudflare died -> restart it.
        if ! kill -0 "${CF_PID}" >/dev/null 2>&1; then

            clear_screen

            echo "=============================================="
            echo "=       CLOUDFLARE TUNNEL DISCONNECTED      ="
            echo "=============================================="
            echo ""
            echo "Cloudflare stopped."
            echo ""
            echo "Restarting Cloudflare in 3 seconds..."
            echo ""

            sleep 3

            # Break inner loop.
            # Outer loop starts a fresh tunnel.
            break
        fi

        sleep 2
    done

done
