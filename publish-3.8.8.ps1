#!/usr/bin/env pwsh
# ============================================================================
# Ergenekon - DockerHub Publish 3.8.8  (run from anywhere; uses C:\ergenekon-stack)
# publish-3.8.7.ps1 prosedürünün birebir aynısı, VERSION=3.8.8.
#  - VERSION = 3.8.8  (NO 'v' prefix -> updates.py regex ^\d+\.\d+\.\d+$)
#  - 6 app services + DB
#  - alembic head sanity gate (1 head each) -> avoids 502 migrate loop
#  - APP_VERSION baked via shell override (.env is Docker-locked)
#  3.8.8 içeriği:
#   * Para/sayı girişlerinde YAZARKEN canlı binlik ayırıcı (tr-TR): mobil
#     NumberInput + masaüstü MoneyInput (Umay+Ötüken). FX ondalık düzeltmesi.
#   * Tarih alanlarında takvim (DateField mobil + masaüstü <input date>).
#   * Kart görünümü (solid zemin + renkli parıltı, okunur). Bu-ay varsayılan
#     filtreler (işlemler/hesap/operasyon/satış). Login hızlandırma.
#   * ADMIN piyasa veri-çekim paneli (Piyasa sayfası, ⚙️ modal): dinamik çekim
#     aralığı + semboller arası bekleme + jitter + SAKLAMA SÜRESİ + piyasa-saati
#     kapısı + canlı DB-yük/risk tahmini. Worker poll'u cron yerine kendini-
#     yeniden-zamanlayan döngü (dinamik interval); purge retention ayardan okur.
#   * Sembol silinince ona ait piyasa verisi (PriceSnapshot) + grafik çizimleri
#     (overlay) cascade silinir.
#   * Çok-ajanlı denetim sonrası düzeltmeler (overlay dedup + resolution koru, vb.)
#  Bu sürümde YENİ migration YOK (poll ayarları system_settings'te; overlay 0085'te).
#  alembic head zinciri 3.8.7 ile aynı (tek head). Gate doğrular.
# ============================================================================
$VERSION  = "3.8.8"
$HUB_USER = "signorali"
$STACK    = "C:\ergenekon-stack"
$COMPOSE  = "$STACK\docker-compose.yml"

$SERVICES = [ordered]@{
    "ergenekon-stack-umay-backend"       = "umay-backend"
    "ergenekon-stack-umay-frontend"      = "umay-frontend"
    "ergenekon-stack-umay-worker"        = "umay-worker"
    "ergenekon-stack-otuken-backend"     = "otuken-backend"
    "ergenekon-stack-otuken-frontend"    = "otuken-frontend"
    "ergenekon-stack-otuken-sync-worker" = "otuken-sync-worker"
}
$DB_IMAGE = "signorali/postgis-pgvector:16-3.4"

Write-Host "=== Ergenekon Publish $VERSION (from C:) ==="

# [0.5] Build the 6 app services with APP_VERSION baked.
$env:APP_VERSION = $VERSION
Write-Host "[0.5] docker compose build (APP_VERSION=$VERSION) ..."
docker compose -p ergenekon-stack --project-directory "$STACK" -f "$COMPOSE" build `
    umay-backend umay-worker umay-frontend otuken-backend otuken-frontend otuken-sync-worker
if ($LASTEXITCODE -ne 0) { Write-Host "RESULT: BUILD_FAILED"; exit 1 }
Write-Host "[0.5] BUILD_OK"

# [0.7] CRITICAL: exactly 1 alembic head per backend (else migrate fail -> 502 loop)
Write-Host "[0.7] alembic head sanity ..."
$umayHeads   = docker run --rm --entrypoint sh ergenekon-stack-umay-backend:latest   -c "cd /app && alembic heads 2>/dev/null | grep -c '(head)'"
$otukenHeads = docker run --rm --entrypoint sh ergenekon-stack-otuken-backend:latest -c "cd /app && alembic heads 2>/dev/null | grep -c '(head)'"
Write-Host "      umay heads=$umayHeads  otuken heads=$otukenHeads"
if ([int]$umayHeads -ne 1 -or [int]$otukenHeads -ne 1) { Write-Host "RESULT: ALEMBIC_MULTI_HEAD"; exit 1 }
Write-Host "[0.7] ALEMBIC_OK"

# [1] verify local images present
foreach ($local in $SERVICES.Keys) {
    $exists = docker images --format "{{.Repository}}" | Where-Object { $_ -eq $local }
    if (-not $exists) { Write-Host "RESULT: MISSING $local"; exit 1 }
    Write-Host "[1] ok $local"
}

# [2] tag :VERSION + :latest  (NO 'v')
foreach ($local in $SERVICES.Keys) {
    $hub = "$HUB_USER/$($SERVICES[$local])"
    docker tag "${local}:latest" "${hub}:${VERSION}"; if ($LASTEXITCODE -ne 0){Write-Host "RESULT: TAGFAIL ${hub}:${VERSION}";exit 1}
    docker tag "${local}:latest" "${hub}:latest";     if ($LASTEXITCODE -ne 0){Write-Host "RESULT: TAGFAIL ${hub}:latest";exit 1}
    Write-Host "[2] tagged $hub ($VERSION + latest)"
}

# [3] push DB (expect no-op 'already exists') then the 6 services
Write-Host "[3] push $DB_IMAGE ..."
docker push $DB_IMAGE; if ($LASTEXITCODE -ne 0){Write-Host "RESULT: PUSHFAIL db";exit 1}
foreach ($local in $SERVICES.Keys) {
    $hub = "$HUB_USER/$($SERVICES[$local])"
    Write-Host "[3] push ${hub}:${VERSION} ..."
    docker push "${hub}:${VERSION}"; if ($LASTEXITCODE -ne 0){Write-Host "RESULT: PUSHFAIL ${hub}:${VERSION}";exit 1}
    docker push "${hub}:latest";     if ($LASTEXITCODE -ne 0){Write-Host "RESULT: PUSHFAIL ${hub}:latest";exit 1}
    Write-Host "[3] pushed $hub ($VERSION + latest)"
}

Write-Host "RESULT: ALL_PUBLISHED $VERSION"
