#!/usr/bin/env bash

set -Eeuo pipefail

SELKIES_PORT="${SELKIES_PORT:-8080}"
CF_LOG="/tmp/cloudflared.log"

echo ""
echo "=========================================================="
echo "        CLOUDFLARE QUICK TUNNEL STARTING"
echo "=========================================================="
echo ""

rm -f "${CF_LOG}"
touch "${CF_LOG}"

(
    while true; do
        echo "[Cloudflare] Starting tunnel..."

        /usr/local/bin/cloudflared tunnel \
            --no-autoupdate \
            --url "http://127.0.0.1:${SELKIES_PORT}" \
            >> "${CF_LOG}" 2>&1

        EXIT_CODE=$?

        echo "[Cloudflare] Tunnel stopped with exit code ${EXIT_CODE}."
        echo "[Cloudflare] Restarting in 5 seconds..."

        sleep 5
    done
) &

CF_WRAPPER_PID=$!

(
    LAST_URL=""

    while true; do

        URL="$(
            grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' \
                "${CF_LOG}" 2>/dev/null |
            tail -n 1 || true
        )"

        if [[ -n "${URL}" && "${URL}" != "${LAST_URL}" ]]; then
            LAST_URL="${URL}"

            echo ""
            echo "=========================================================="
            echo "           CLOUDFLARE TUNNEL IS READY"
            echo "=========================================================="
            echo ""
            echo "  URL: ${URL}"
            echo ""
            echo "  Selkies: http://127.0.0.1:${SELKIES_PORT}"
            echo ""
            echo "  STATUS: ONLINE"
            echo ""
            echo "=========================================================="
            echo ""
        fi

        # ======================================================
        # Repeat the current Cloudflare URL every 60 seconds
        # ======================================================

        if [[ -n "${LAST_URL}" ]]; then
            sleep 60

            # Re-check in case Cloudflare generated a new URL
            NEW_URL="$(
                grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' \
                    "${CF_LOG}" 2>/dev/null |
                tail -n 1 || true
            )"

            if [[ -n "${NEW_URL}" ]]; then
                LAST_URL="${NEW_URL}"
            fi

            echo ""
            echo "=========================================================="
            echo "           CLOUDFLARE TUNNEL"
            echo "=========================================================="
            echo ""
            echo "  URL: ${LAST_URL}"
            echo ""
            echo "  Selkies: http://127.0.0.1:${SELKIES_PORT}"
            echo ""
            echo "  STATUS: ONLINE"
            echo ""
            echo "=========================================================="
            echo ""

        else
            # No URL yet, check again quickly
            sleep 2
        fi

    done
) &

echo "Cloudflare background service started."
echo "Starting Selkies..."
echo ""

exec /etc/container-entrypoint.sh
