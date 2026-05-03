#!/bin/sh
# ── Ergenekon Network Watchdog ──────────────────────────────────────────────
# Container Station / Portainer / herhangi bir UI iç ağı kaldırırsa
# bu watchdog 10 saniye içinde otomatik olarak geri bağlar.
#
# Çalışma prensibi:
#   1. Tüm ergenekon container'larını listele
#   2. Her birinin ergenekon_net'e bağlı olup olmadığını kontrol et
#   3. Bağlı değilse `docker network connect` ile geri bağla
#   4. 10 saniyede bir tekrarla
# ─────────────────────────────────────────────────────────────────────────────

set -eu

NETWORK_NAME="${NETWORK_NAME:-entegresistem_ergenekon_net}"
INTERVAL="${INTERVAL:-10}"
CONTAINERS="ergenekon-db ergenekon-redis ergenekon-proxy umay-backend umay-frontend umay-worker otuken-backend otuken-frontend otuken-sync-worker"

echo "[watchdog] starting — network=$NETWORK_NAME interval=${INTERVAL}s"

while true; do
    for c in $CONTAINERS; do
        # Container çalışıyor mu?
        if ! docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
            continue
        fi

        # Bu ağa bağlı mı?
        if ! docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$c" 2>/dev/null | grep -q "$NETWORK_NAME"; then
            echo "[watchdog] $c iç ağdan kopuk — yeniden bağlanıyor..."
            if docker network connect "$NETWORK_NAME" "$c" 2>&1; then
                echo "[watchdog] $c → $NETWORK_NAME yeniden bağlandı ✓"
            else
                echo "[watchdog] $c yeniden bağlanamadı ✗"
            fi
        fi
    done
    sleep "$INTERVAL"
done
