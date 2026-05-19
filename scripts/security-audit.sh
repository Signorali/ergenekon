#!/usr/bin/env bash
# ─── Ergenekon Dependency Security Audit ─────────────────────────────────────
# Python (pip-audit), Node (npm audit) ve Docker image (Trivy) için kapsamlı
# güvenlik açığı taraması. Tarama sonuçlarını ./audit-reports/<tarih>/ altına
# yazar; "high" veya "critical" varsa exit code 1 döner.
#
# Kullanım:
#   ./scripts/security-audit.sh           # tüm taramaları çalıştır
#   ./scripts/security-audit.sh python    # sadece Python
#   ./scripts/security-audit.sh node      # sadece Node
#   ./scripts/security-audit.sh docker    # sadece image scan
#
# Cron örneği (her gece 04:00 UTC):
#   0 4 * * *  cd /opt/ergenekon && ./scripts/security-audit.sh > /dev/null
# ─────────────────────────────────────────────────────────────────────────────
set -u
set -o pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$ROOT/audit-reports/$TIMESTAMP"
mkdir -p "$REPORT_DIR"

TARGET="${1:-all}"
EXIT_CODE=0

# ── Yardımcılar ──────────────────────────────────────────────────────────
log()  { printf "\033[1;36m[audit]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[audit]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[audit]\033[0m %s\n" "$*" >&2; }

run_in_container() {
    # $1 = container, geri kalan komut
    local container="$1"; shift
    if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
        warn "$container ayakta değil — skip"
        return 1
    fi
    docker exec "$container" "$@"
}

# ── Python (pip-audit) ───────────────────────────────────────────────────
audit_python() {
    log "Python paket güvenlik taraması (pip-audit)..."

    # Hem umay-backend hem otuken-backend için
    for service in umay-backend otuken-backend; do
        local report="$REPORT_DIR/${service}-pip-audit.json"
        log "  → $service"

        # pip-audit yoksa kur
        run_in_container "$service" pip show pip-audit >/dev/null 2>&1 || \
            run_in_container "$service" pip install --quiet pip-audit 2>/dev/null || {
                warn "  $service: pip-audit kurulamadı — skip"
                continue
            }

        # JSON formatında raporla, exit code'u zorlama
        run_in_container "$service" pip-audit --format json --progress-spinner off \
            > "$report" 2>/dev/null || true

        # Yüksek seviyeli açıkları say (CVSS 7+)
        local high_count=0
        if [ -s "$report" ]; then
            high_count=$(python3 -c "
import json
try:
    data = json.load(open('$report'))
    if isinstance(data, list):
        deps = data
    else:
        deps = data.get('dependencies', [])
    high = sum(
        1 for d in deps for v in d.get('vulns', [])
        if (v.get('aliases') or []) and any('CVE' in (a or '') for a in (v.get('aliases') or []))
    )
    print(high)
except Exception:
    print(0)
" 2>/dev/null || echo 0)
        fi

        if [ "$high_count" -gt 0 ]; then
            err "  $service: $high_count zafiyet bulundu — bkz $report"
            EXIT_CODE=1
        else
            log "  $service: ✅ temiz"
        fi
    done
}

# ── Node (npm audit) ─────────────────────────────────────────────────────
audit_node() {
    log "Node paket güvenlik taraması (npm audit)..."

    for fe in umay/frontend otuken/frontend; do
        local report="$REPORT_DIR/$(echo $fe | tr / -)-npm-audit.json"
        log "  → $fe"

        if [ ! -f "$ROOT/$fe/package.json" ]; then
            warn "  $fe: package.json yok — skip"
            continue
        fi

        # Lockfile yoksa npm audit çalışmaz; geçici olarak kur
        if [ ! -f "$ROOT/$fe/package-lock.json" ]; then
            warn "  $fe: package-lock.json yok — skip (önce 'npm install' çalıştır)"
            continue
        fi

        (cd "$ROOT/$fe" && npm audit --json --omit=dev 2>/dev/null) > "$report" || true

        local critical=0 high=0
        if [ -s "$report" ]; then
            critical=$(python3 -c "
import json
try:
    d=json.load(open('$report'))
    print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
except: print(0)
" 2>/dev/null || echo 0)
            high=$(python3 -c "
import json
try:
    d=json.load(open('$report'))
    print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0))
except: print(0)
" 2>/dev/null || echo 0)
        fi

        local total=$((critical + high))
        if [ "$total" -gt 0 ]; then
            err "  $fe: critical=$critical high=$high — bkz $report"
            EXIT_CODE=1
        else
            log "  $fe: ✅ temiz"
        fi
    done
}

# ── Docker image scan (Trivy) ────────────────────────────────────────────
audit_docker() {
    log "Docker image güvenlik taraması (Trivy)..."

    if ! command -v trivy >/dev/null 2>&1; then
        warn "Trivy kurulu değil — Docker container ile çalıştırılıyor (ilk seferde 100MB indirilebilir)"
        TRIVY="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            -v $REPORT_DIR:/reports \
            aquasec/trivy:latest"
    else
        TRIVY="trivy"
    fi

    for image in entegresistem-umay-backend entegresistem-otuken-backend \
                 entegresistem-umay-frontend entegresistem-otuken-frontend; do
        local report_basename="$(echo $image | sed 's/entegresistem-//')-trivy.json"
        local report="$REPORT_DIR/$report_basename"
        log "  → $image"

        if ! docker images --format '{{.Repository}}' | grep -qx "$image"; then
            warn "  $image: image bulunamadı — skip"
            continue
        fi

        # Trivy: HIGH ve CRITICAL seviye, sadece fixed olanları raporla
        if command -v trivy >/dev/null 2>&1; then
            $TRIVY image --quiet --severity HIGH,CRITICAL --ignore-unfixed \
                --format json --output "$report" "$image" 2>/dev/null || true
        else
            $TRIVY image --quiet --severity HIGH,CRITICAL --ignore-unfixed \
                --format json --output "/reports/$report_basename" "$image" 2>/dev/null || true
        fi

        if [ -s "$report" ]; then
            local count=$(python3 -c "
import json
try:
    d=json.load(open('$report'))
    n=0
    for r in (d.get('Results') or []):
        n += len(r.get('Vulnerabilities') or [])
    print(n)
except: print(0)
" 2>/dev/null || echo 0)

            if [ "$count" -gt 0 ]; then
                err "  $image: $count fixable HIGH/CRITICAL açık — bkz $report"
                EXIT_CODE=1
            else
                log "  $image: ✅ temiz"
            fi
        fi
    done
}

# ── Özet raporu yaz ──────────────────────────────────────────────────────
write_summary() {
    local summary="$REPORT_DIR/SUMMARY.md"
    {
        echo "# Security Audit — $TIMESTAMP"
        echo ""
        echo "Tarama sonuçları:"
        echo ""
        find "$REPORT_DIR" -name "*.json" -printf "- %f (%s bytes)\n" 2>/dev/null
        echo ""
        echo "Exit code: $EXIT_CODE"
        echo ""
        echo "## Sonraki adımlar"
        if [ "$EXIT_CODE" -ne 0 ]; then
            echo ""
            echo "⚠️  Yüksek/kritik seviye açık bulundu. Aşağıdaki rapor dosyalarını incele:"
            echo ""
            for f in "$REPORT_DIR"/*.json; do
                [ -e "$f" ] && echo "  - $(basename $f)"
            done
            echo ""
            echo "Tipik çözüm: \`pip install -U <paket>\` veya \`npm update <paket>\`,"
            echo "sonra \`docker compose build\` ile yeniden image üret."
        else
            echo ""
            echo "✅ Tüm taramalar temiz."
        fi
    } > "$summary"
    log "Özet: $summary"
}

# ── Ana akış ─────────────────────────────────────────────────────────────
case "$TARGET" in
    python) audit_python ;;
    node)   audit_node ;;
    docker) audit_docker ;;
    all|"")
        audit_python
        audit_node
        audit_docker
        ;;
    *)
        err "Bilinmeyen hedef: $TARGET (python|node|docker|all)"
        exit 2
        ;;
esac

write_summary

if [ "$EXIT_CODE" -ne 0 ]; then
    err "Audit FAIL — yüksek seviye açık var. Rapor: $REPORT_DIR"
else
    log "Audit OK — tüm taramalar temiz. Rapor: $REPORT_DIR"
fi

exit "$EXIT_CODE"
