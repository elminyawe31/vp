#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Selkies + Cloudflare Quick Tunnel Supervisor
# ============================================================

SELKIES_PORT="${SELKIES_PORT:-8080}"

SELKIES_LOG="/tmp/selkies.log"
CLOUDFLARE_LOG="/tmp/cloudflared.log"

SELKIES_PID=""
CF_PID=""

# ============================================================
# Helpers
# ============================================================

clear_screen() {
    printf '\033[2J\033[H'
}

log() {
    echo "[VP] $*"
}

# ============================================================
# Cleanup
# ============================================================

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

    if [[ -n "${CF_PID}" ]]; then
        wait "${CF_PID}" 2>/dev/null || true
    fi

    if [[ -n "${SELKIES_PID}" ]]; then
        wait "${SELKIES_PID}" 2>/dev/null || true
    fi

    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================
# Find original Selkies entrypoint
# ============================================================

find_selkies_entrypoint() {

    # The official Selkies image normally provides /entrypoint.sh.
    if [[ -x /entrypoint.sh ]]; then
        echo "/entrypoint.sh"
        return 0
    fi

    # Fallback for images that use /usr/local/bin/entrypoint.
    if [[ -x /usr/local/bin/entrypoint ]]; then
        echo "/usr/local/bin/entrypoint"
        return 0
    fi

    return 1
}

# ============================================================
# Start Selkies
# ============================================================

start_selkies() {

    local original_entrypoint

    original_entrypoint="$(find_selkies_entrypoint)" || {
        echo "ERROR: Original Selkies entrypoint was not found."
        echo ""
        echo "Checked:"
        echo "  /entrypoint.sh"
        echo "  /usr/local/bin/entrypoint"
        echo ""
        exit 1
    }

    echo "=============================================="
    echo "=        Selkies + Cloudflare Tunnel        ="
    echo "=============================================="
    echo ""
    echo "[1/2] Starting Selkies..."
    echo ""

    # --------------------------------------------------------
    # IMPORTANT:
    # Selkies startup output goes into a log file.
    # This prevents Coturn/X11/DBus/Polkit/etc. noise from
    # flooding the terminal.
    # --------------------------------------------------------

    : > "${SELKIES_LOG}"

    "${original_entrypoint}" \
        >"${SELKIES_LOG}" \
        2>&1 &

    SELKIES_PID=$!

    echo "[2/2] Waiting for Selkies on port ${SELKIES_PORT}..."

    # --------------------------------------------------------
    # Wait up to 120 seconds for Selkies.
    # --------------------------------------------------------

    local ready=0

    for _ in $(seq 1 120); do

        if (echo >"/dev/tcp/127.0.0.1/${SELKIES_PORT}") \
            >/dev/null 2>&1; then

            ready=1
            break
        fi

        if ! kill -0 "${SELKIES_PID}" >/dev/null 2>&1; then

            echo ""
            echo "ERROR: Selkies stopped during startup."
            echo ""
            echo "Last Selkies messages:"
            tail -n 30 "${SELKIES_LOG}" 2>/dev/null || true
            echo ""

            wait "${SELKIES_PID}" 2>/dev/null || true
            exit 1
        fi

        sleep 1
    done

    if [[ "${ready}" != "1" ]]; then

        echo ""
        echo "ERROR: Selkies did not start on port ${SELKIES_PORT}."
        echo ""
        echo "Last Selkies messages:"
        tail -n 30 "${SELKIES_LOG}" 2>/dev/null || true
        echo ""

        exit 1
    fi

    echo ""
    echo "Selkies is ready."
    echo "Internal: http://127.0.0.1:${SELKIES_PORT}"
    echo ""
}

# ============================================================
# Start Cloudflare Quick Tunnel
# ============================================================

start_cloudflare() {

    # --------------------------------------------------------
    # Stop previous Cloudflare process if one exists.
    # --------------------------------------------------------

    if [[ -n "${CF_PID}" ]] && kill -0 "${CF_PID}" >/dev/null 2>&1; then
        kill "${CF_PID}" 2>/dev/null || true
        wait "${CF_PID}" 2>/dev/null || true
    fi

    # --------------------------------------------------------
    # Fresh Cloudflare log for this attempt.
    # --------------------------------------------------------

    : > "${CLOUDFLARE_LOG}"

    echo ""
    echo "Starting Cloudflare..."
    echo ""

    # --------------------------------------------------------
    # Start cloudflared silently.
    # --------------------------------------------------------

    cloudflared tunnel \
        --no-autoupdate \
        --url "http://127.0.0.1:${SELKIES_PORT}" \
        >"${CLOUDFLARE_LOG}" \
        2>&1 &

    CF_PID=$!

    # --------------------------------------------------------
    # Wait for Quick Tunnel URL.
    # --------------------------------------------------------

    local tunnel_url=""
    local attempts=0

    while [[ "${attempts}" -lt 60 ]]; do

        # Cloudflared died before generating URL.
        if ! kill -0 "${CF_PID}" >/dev/null 2>&1; then

            echo ""
            echo "Cloudflare exited before creating the tunnel."
            echo ""
            echo "Last Cloudflare messages:"
            tail -n 20 "${CLOUDFLARE_LOG}" 2>/dev/null || true
            echo ""

            return 1
        fi

        tunnel_url="$(
            grep -oE \
                'https://[a-zA-Z0-9-]+\.trycloudflare\.com' \
                "${CLOUDFLARE_LOG}" \
                2>/dev/null |
            head -n 1 || true
        )"

        if [[ -n "${tunnel_url}" ]]; then
            break
        fi

        sleep 1
        attempts=$((attempts + 1))
    done

    # --------------------------------------------------------
    # No URL received.
    # --------------------------------------------------------

    if [[ -z "${tunnel_url}" ]]; then

        echo ""
        echo "Cloudflare did not provide a tunnel URL."
        echo ""
        echo "Last Cloudflare messages:"
        tail -n 20 "${CLOUDFLARE_LOG}" 2>/dev/null || true
        echo ""

        return 1
    fi

    # --------------------------------------------------------
    # SUCCESS
    #
    # Remove all startup noise from the terminal and show only
    # useful information.
    # --------------------------------------------------------

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
    echo "Cloudflare watchdog: ACTIVE"
    echo "=============================================="
    echo ""
    echo "If Cloudflare stops, it will restart"
    echo "automatically and a new URL will be shown."
    echo ""

    return 0
}

# ============================================================
# Main
# ============================================================

start_selkies

# ============================================================
# Cloudflare watchdog
# ============================================================

while true; do

    # --------------------------------------------------------
    # Selkies must always remain alive.
    # --------------------------------------------------------

    if ! kill -0 "${SELKIES_PID}" >/dev/null 2>&1; then

        clear_screen

        echo "=============================================="
        echo "=             SELKIES STOPPED               ="
        echo "=============================================="
        echo ""
        echo "Selkies exited unexpectedly."
        echo ""
        echo "Last Selkies messages:"
        tail -n 30 "${SELKIES_LOG}" 2>/dev/null || true
        echo ""

        exit 1
    fi

    # --------------------------------------------------------
    # Start Cloudflare.
    # --------------------------------------------------------

    if ! start_cloudflare; then

        clear_screen

        echo "=============================================="
        echo "=        CLOUDFLARE START FAILED            ="
        echo "=============================================="
        echo ""
        echo "Retrying Cloudflare in 5 seconds..."
        echo ""

        sleep 5

        continue
    fi

    # --------------------------------------------------------
    # Monitor Cloudflare.
    # --------------------------------------------------------

    while true; do

        # ----------------------------------------------------
        # Selkies died.
        # ----------------------------------------------------

        if ! kill -0 "${SELKIES_PID}" >/dev/null 2>&1; then

            clear_screen

            echo "=============================================="
            echo "=             SELKIES STOPPED               ="
            echo "=============================================="
            echo ""
            echo "Selkies exited unexpectedly."
            echo ""
            echo "Last Selkies messages:"
            tail -n 30 "${SELKIES_LOG}" 2>/dev/null || true
            echo ""

            exit 1
        fi

        # ----------------------------------------------------
        # Cloudflare died.
        # ----------------------------------------------------

        if ! kill -0 "${CF_PID}" >/dev/null 2>&1; then

            clear_screen

            echo "=============================================="
            echo "=       CLOUDFLARE TUNNEL DISCONNECTED      ="
            echo "=============================================="
            echo ""
            echo "Cloudflare stopped."
            echo ""
            echo "Restarting in 3 seconds..."
            echo ""

            sleep 3

            # Exit inner monitor.
            # Outer loop creates a completely new tunnel.
            break
        fi

        sleep 2
    done

done
