#!/usr/bin/env pwsh
# ============================================================================
# Ergenekon - DockerHub Publish 3.8.7  (run from anywhere; uses C:\ergenekon-stack)
# publish-3.8.5.ps1 prosedürünün birebir aynısı, VERSION=3.8.7.
#  - VERSION = 3.8.7  (NO 'v' prefix -> updates.py regex ^\d+\.\d+\.\d+$)
#  - 6 app services + DB
#  - alembic head sanity gate (1 head each) -> avoids 502 migrate loop
#  - APP_VERSION baked via shell override (.env is Docker-locked)
#  3.8.7 içeriği:
#   * Piyasa grafiği: teknik analiz ÇİZİMLERİ kullanıcı+sembol başına KALICI
#     (masaüstü <-> APK aynı kullanıcı = aynı çizim + aynı zaman filtresi; başka
#     kullanıcı boş görür). MIKNATIS (weak/strong magnet), kilit, geri-al.
#     Yeni uçlar: GET/PUT /market/charts/overlays.
#   * Hesaplar: bakiye-azalan sıralama + 0/diğer-grup gizleme filtresi, kendi-grup
#     önce; hesap hareketi tıklayınca işlem detayı (web + mobil).
#   * Kategoriler: mobilde görünen kategoriler KULLANICI-BAZLI (ortak değil).
#   * Hava: zararlı hava olaylarında (don/dolu/fırtına) sticky push altyapısı;
#     otuken weather client retry+cache; "konum yok" mesaj ayrımı.
#   * Otuken operasyon/maliyet/ağaç/envanter iyileştirmeleri (3.8.5/3.8.6 hattı,
#     bu derlemede kaynaktan tam senkron).
#  Bu sürümde YENİ migration: market_chart_layouts zaten 0085'te (yeni tablo yok);
#  alembic head zinciri 3.8.6 ile aynı (tek head). Gate doğrular.
# ============================================================================
$VERSION  = "3.8.7"
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
