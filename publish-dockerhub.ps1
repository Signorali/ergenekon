#!/usr/bin/env pwsh
# Ergenekon - Docker Hub Publish Script

$VERSION = "3.5.1"
$HUB_USER = "signorali"

$SERVICES = @{
    "entegresistem-umay-backend"        = "umay-backend"
    "entegresistem-umay-frontend"       = "umay-frontend"
    "entegresistem-umay-worker"         = "umay-worker"
    "entegresistem-otuken-backend"      = "otuken-backend"
    "entegresistem-otuken-frontend"     = "otuken-frontend"
    "entegresistem-otuken-sync-worker"  = "otuken-sync-worker"
}

Write-Host ""
Write-Host "=== Ergenekon Docker Hub Publisher ===" -ForegroundColor Cyan
Write-Host "    Version: $VERSION" -ForegroundColor Cyan
Write-Host ""

# 0. Sync APP_VERSION in .env files (image'a baked APP_VERSION buradan geliyor)
Write-Host "[0/4] Syncing APP_VERSION in .env files..." -ForegroundColor Blue
$envFiles = @(".env", ".env.umay", ".env.otuken")
foreach ($f in $envFiles) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw
        if ($content -match "APP_VERSION=") {
            $content = $content -replace "APP_VERSION=.*", "APP_VERSION=$VERSION"
        } else {
            $content = $content.TrimEnd() + "`nAPP_VERSION=$VERSION`n"
        }
        Set-Content -Path $f -Value $content -NoNewline
        Write-Host "  Updated: $f -> APP_VERSION=$VERSION" -ForegroundColor Green
    }
}

# 0.5. Rebuild ALL images with new APP_VERSION baked in (backend + frontend)
Write-Host ""
Write-Host "[0.5/4] Rebuilding all images with APP_VERSION=$VERSION..." -ForegroundColor Blue
$env:APP_VERSION = $VERSION
docker compose build umay-backend umay-worker umay-frontend otuken-backend otuken-frontend otuken-sync-worker 2>&1 | Select-String -Pattern "Built|ERROR|error" | Select-Object -Last 12
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed." -ForegroundColor Red
    exit 1
}
Write-Host "  Build complete." -ForegroundColor Green

# 0.7. Sanity check: alembic migration head sayısı = 1 mi?
# Bu kontrol 3.4.13 felaketinden sonra eklendi: iki migration dosyası aynı
# revision/down_revision aldığında alembic upgrade fail eder, backend
# startup loop'unda kalır, login dahil tüm endpoint'ler 502 döner. Önceden
# yakalamak için image'da `alembic heads` çalıştırıyoruz (DB gerekmez).
Write-Host ""
Write-Host "[0.7/4] Alembic migration head sanity check..." -ForegroundColor Blue
$umayHeads = docker run --rm --entrypoint sh entegresistem-umay-backend:latest -c "cd /app && alembic heads 2>/dev/null | grep -c '(head)'"
$otukenHeads = docker run --rm --entrypoint sh entegresistem-otuken-backend:latest -c "cd /app && alembic heads 2>/dev/null | grep -c '(head)'"
$umayHeadsInt = [int]$umayHeads
$otukenHeadsInt = [int]$otukenHeads
Write-Host "  umay heads: $umayHeadsInt"
Write-Host "  otuken heads: $otukenHeadsInt"
if ($umayHeadsInt -ne 1 -or $otukenHeadsInt -ne 1) {
    Write-Host "ERROR: Birden fazla alembic head var → backend migrate fail eder." -ForegroundColor Red
    Write-Host "  Çözüm: çakışan revision'lardan birini yeniden numaralandır." -ForegroundColor Red
    Write-Host "  Detay için: docker run --rm --entrypoint sh entegresistem-umay-backend:latest -c 'cd /app && alembic heads'" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Tek head — migration ağacı temiz" -ForegroundColor Green

# 1. Verify local images
Write-Host ""
Write-Host "[1/4] Checking local images..." -ForegroundColor Blue
$missing = @()
foreach ($local in $SERVICES.Keys) {
    $exists = docker images --format "{{.Repository}}" 2>&1 | Where-Object { $_ -eq $local }
    if (-not $exists) {
        $missing += $local
        Write-Host "  MISSING: $local" -ForegroundColor Red
    } else {
        Write-Host "  OK: $local" -ForegroundColor Green
    }
}
if ($missing.Count -gt 0) {
    Write-Host "ERROR: Missing images. Run 'docker compose build' first." -ForegroundColor Red
    exit 1
}

# 2. Tag
Write-Host ""
Write-Host "[2/3] Tagging images..." -ForegroundColor Blue
foreach ($local in $SERVICES.Keys) {
    $repo = $SERVICES[$local]
    $hubName = "$HUB_USER/$repo"

    docker tag "${local}:latest" "${hubName}:${VERSION}" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Tagged: $local -> ${hubName}:${VERSION}" -ForegroundColor Green
    } else {
        Write-Host "  FAILED: $local -> ${hubName}:${VERSION}" -ForegroundColor Red
        exit 1
    }

    docker tag "${local}:latest" "${hubName}:latest" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Tagged: $local -> ${hubName}:latest" -ForegroundColor Green
    } else {
        Write-Host "  FAILED: $local -> ${hubName}:latest" -ForegroundColor Red
        exit 1
    }
}

# 3. Push
Write-Host ""
Write-Host "[3/3] Pushing to Docker Hub..." -ForegroundColor Blue
foreach ($local in $SERVICES.Keys) {
    $repo = $SERVICES[$local]
    $hubName = "$HUB_USER/$repo"

    Write-Host ""
    Write-Host "  Pushing ${hubName}:${VERSION}..." -ForegroundColor Yellow
    docker push "${hubName}:${VERSION}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: ${hubName}:${VERSION}" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Pushing ${hubName}:latest..." -ForegroundColor Yellow
    docker push "${hubName}:latest" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: ${hubName}:latest" -ForegroundColor Red
        exit 1
    }

    Write-Host "  DONE: $hubName ($VERSION + latest)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== ALL IMAGES PUBLISHED SUCCESSFULLY ===" -ForegroundColor Green
Write-Host "Hub: https://hub.docker.com/u/$HUB_USER" -ForegroundColor Cyan
Write-Host ""
Write-Host "Published:" -ForegroundColor White
foreach ($local in $SERVICES.Keys) {
    $repo = $SERVICES[$local]
    Write-Host "  $HUB_USER/${repo}:${VERSION}" -ForegroundColor Gray
    Write-Host "  $HUB_USER/${repo}:latest" -ForegroundColor Gray
}
Write-Host ""
