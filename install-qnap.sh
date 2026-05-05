#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║           ERGENEKON — QNAP Container Station Kurulum Scripti           ║
# ║                         Versiyon: 3.5.0                                ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Kullanım:
#   1. Bu dosyayı QNAP'a kopyala (SCP veya QNAP File Manager)
#   2. SSH ile QNAP'a bağlan
#   3. chmod +x install-qnap.sh && ./install-qnap.sh
#
# Not: Docker ve docker-compose QNAP Container Station ile birlikte gelir.

set -e

VERSION="3.5.0"
HUB="signorali"
INSTALL_DIR="/share/Container/ergenekon"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🏰 ERGENEKON QNAP KURULUM — v${VERSION}      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Dizinleri oluştur ────────────────────────────────────────────────────
echo -e "${YELLOW}[1/7] Dizinler oluşturuluyor...${NC}"
mkdir -p "$INSTALL_DIR"/{nginx/certs,postgres,scripts}
cd "$INSTALL_DIR"
echo -e "${GREEN}  ✓ $INSTALL_DIR${NC}"

# ── 2. postgres/init.sql ────────────────────────────────────────────────────
echo -e "${YELLOW}[2/7] PostgreSQL init script yazılıyor...${NC}"
cat > postgres/init.sql << 'PGSQL'
-- Ergenekon PostgreSQL Başlangıç Scripti
SELECT 'CREATE DATABASE umay'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'umay')
\gexec
PGSQL
echo -e "${GREEN}  ✓ postgres/init.sql${NC}"

# ── 3. network-watchdog.sh ──────────────────────────────────────────────────
echo -e "${YELLOW}[3/7] Network watchdog yazılıyor...${NC}"
cat > scripts/network-watchdog.sh << 'WATCHDOG'
#!/bin/sh
set -eu
NETWORK_NAME="${NETWORK_NAME:-ergenekon_ergenekon_net}"
INTERVAL="${INTERVAL:-10}"
CONTAINERS="ergenekon-db ergenekon-redis ergenekon-proxy umay-backend umay-frontend umay-worker otuken-backend otuken-frontend otuken-sync-worker"
echo "[watchdog] starting — network=$NETWORK_NAME interval=${INTERVAL}s"
while true; do
    for c in $CONTAINERS; do
        if ! docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
            continue
        fi
        if ! docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$c" 2>/dev/null | grep -q "$NETWORK_NAME"; then
            echo "[watchdog] $c iç ağdan kopuk — yeniden bağlanıyor..."
            docker network connect "$NETWORK_NAME" "$c" 2>&1 && echo "[watchdog] $c yeniden bağlandı ✓"
        fi
    done
    sleep "$INTERVAL"
done
WATCHDOG
chmod +x scripts/network-watchdog.sh
echo -e "${GREEN}  ✓ scripts/network-watchdog.sh${NC}"

# ── 4. nginx.conf ───────────────────────────────────────────────────────────
echo -e "${YELLOW}[4/7] Nginx konfigürasyonu yazılıyor...${NC}"
cat > nginx/nginx.conf << 'NGINXCONF'
events { worker_connections 1024; }

http {
    include      /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile     on;
    server_tokens off;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers               ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache         shared:SSL:10m;
    ssl_session_timeout       1d;
    ssl_session_tickets       off;

    resolver 127.0.0.11 valid=10s ipv6=off;

    proxy_http_version  1.1;
    proxy_set_header    Host               $host;
    proxy_set_header    X-Real-IP          $remote_addr;
    proxy_set_header    X-Forwarded-For    $remote_addr;
    proxy_set_header    X-Forwarded-Proto  $scheme;
    proxy_set_header    Upgrade            $http_upgrade;
    proxy_set_header    Connection         $connection_upgrade;
    proxy_cache_bypass  $http_upgrade;
    proxy_read_timeout  300s;
    proxy_connect_timeout 75s;
    client_max_body_size  50m;

    limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=api_limit:10m  rate=120r/m;
    limit_req_status 429;

    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    server {
        listen      443 ssl;
        server_name _;

        ssl_certificate     /etc/nginx/certs/server.crt;
        ssl_certificate_key /etc/nginx/certs/server.key;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options           "SAMEORIGIN"                          always;
        add_header X-Content-Type-Options    "nosniff"                             always;

        location / {
            set $umay_frontend http://umay-frontend:80;
            proxy_pass $umay_frontend;
        }

        location ~ ^/api/v1/auth/(login|token) {
            limit_req zone=auth_limit burst=3 nodelay;
            set $umay_backend http://umay-backend:8000;
            proxy_pass $umay_backend;
        }

        location /api/ {
            limit_req zone=api_limit burst=30 nodelay;
            set $umay_backend http://umay-backend:8000;
            proxy_pass $umay_backend;
        }

        location /otuken-api/ {
            proxy_pass http://otuken-backend:8080/;
        }

        location /uptime/ {
            set $uptime_kuma http://uptime-kuma:3001;
            proxy_pass $uptime_kuma/;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }

    server {
        listen      4443 ssl;
        server_name _;

        ssl_certificate     /etc/nginx/certs/server.crt;
        ssl_certificate_key /etc/nginx/certs/server.key;

        add_header X-Frame-Options    "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;

        location / {
            set $otuken_frontend http://otuken-frontend:80;
            proxy_pass $otuken_frontend;
        }

        location ~ ^/api/v1/auth/(login|token) {
            limit_req zone=auth_limit burst=3 nodelay;
            set $otuken_backend http://otuken-backend:8080;
            proxy_pass $otuken_backend;
        }

        location /api/ {
            limit_req zone=api_limit burst=30 nodelay;
            set $otuken_backend http://otuken-backend:8080;
            proxy_pass $otuken_backend;
        }
    }
}
NGINXCONF
echo -e "${GREEN}  ✓ nginx/nginx.conf${NC}"

# ── 5. .env dosyaları ───────────────────────────────────────────────────────
echo -e "${YELLOW}[5/7] Ortam değişkenleri yazılıyor...${NC}"

# Ana .env
cat > .env << 'MAINENV'
DB_NAME=ergenekon
DB_USER=postgres
DB_PASSWORD=qXPIdcXehUwjyyCJJpZNEbB6YmfHWUi9oNJBR7m2UXg
DB_PORT=5432
REDIS_PASSWORD=5ab4ff588a3fae52fc66f88c953410948e2cc6796d1ceff0
REDIS_PORT=6379
INTERNAL_API_KEY=KULQaTIiMK8viPgnarplXYmV4N9UcHVQWWN50yt4yqU
APP_VERSION=3.5.0
PROXY_HTTP_PORT=80
PROXY_HTTPS_PORT=443
PROXY_OTUKEN_PORT=4443
MAINENV

# .env.umay
cat > .env.umay << 'UMAYENV'
APP_ENV=production
APP_DEBUG=false
APP_SECRET_KEY=Amn1an1M49wfFx5b3s7thHoEIm0-vHMUrpI5MWr4SqLmfjFsfTX1LynMTtAtgckN
APP_NAME=Umay
APP_VERSION=3.5.0
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=umay
POSTGRES_USER=postgres
POSTGRES_PASSWORD=qXPIdcXehUwjyyCJJpZNEbB6YmfHWUi9oNJBR7m2UXg
DATABASE_URL=postgresql+asyncpg://postgres:qXPIdcXehUwjyyCJJpZNEbB6YmfHWUi9oNJBR7m2UXg@db:5432/umay
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=5ab4ff588a3fae52fc66f88c953410948e2cc6796d1ceff0
REDIS_URL=redis://:5ab4ff588a3fae52fc66f88c953410948e2cc6796d1ceff0@redis:6379/0
JWT_SECRET_KEY=yjPGHOUSKraqr5Poss6rkLj0vTkdbiS1CrtKIVDgNJukBFIf3gtgqtvTYzghdJ-o
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRE_DAYS=3
CORS_ORIGINS=https://localhost,https://localhost:4443
STORAGE_PATH=/app/storage
MAX_UPLOAD_SIZE_MB=10
BACKUP_PATH=/app/backups
BACKUP_ENCRYPTION_KEY=YklD4d7wqVUEseVtKMA8017_6-h_o0o9BSytVs1CgF4
FIRST_ADMIN_EMAIL=admin@umay.local
FIRST_ADMIN_PASSWORD=Admin2026!
FIRST_TENANT_NAME=Default
OTUKEN_BASE_URL=http://otuken-backend:8080
OTUKEN_API_KEY=KULQaTIiMK8viPgnarplXYmV4N9UcHVQWWN50yt4yqU
LICENSE_KEY=
UMAYENV

# .env.otuken
cat > .env.otuken << 'OTUKENENV'
APP_NAME=Ötüken Arazi Modülü
ENVIRONMENT=production
POSTGRES_HOST=db
POSTGRES_DB=umay
POSTGRES_USER=postgres
POSTGRES_PASSWORD=qXPIdcXehUwjyyCJJpZNEbB6YmfHWUi9oNJBR7m2UXg
DATABASE_URL=postgresql+psycopg://postgres:qXPIdcXehUwjyyCJJpZNEbB6YmfHWUi9oNJBR7m2UXg@db:5432/umay
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=5ab4ff588a3fae52fc66f88c953410948e2cc6796d1ceff0
CORS_ALLOW_ORIGINS=https://localhost,https://localhost:4443
INTERNAL_API_KEY=KULQaTIiMK8viPgnarplXYmV4N9UcHVQWWN50yt4yqU
UMAY_BASE_URL=http://umay-backend:8000
UMAY_USERNAME=arazi_module_user
UMAY_PASSWORD=YB7bddnlw_RwLhSuwnR6-0Qqg8N1oSEu
UMAY_GROUP_CODE=ARAZI
UMAY_DEFAULT_GROUP_CODE=ARAZI
APP_VERSION=3.5.0
OTUKENENV

echo -e "${GREEN}  ✓ .env, .env.umay, .env.otuken${NC}"

# ── 6. docker-compose.yml (image: — kaynak kod gerekmez) ───────────────────
echo -e "${YELLOW}[6/7] docker-compose.yml yazılıyor (Hub images)...${NC}"
cat > docker-compose.yml << COMPOSEFILE
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:

  db:
    image: postgis/postgis:16-3.4
    container_name: ergenekon-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: \${DB_NAME:-ergenekon}
      POSTGRES_USER: \${DB_USER:-postgres}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-postgres}
    command:
      - "postgres"
      - "-c" - "shared_buffers=256MB"
      - "-c" - "effective_cache_size=1GB"
      - "-c" - "work_mem=4MB"
      - "-c" - "max_connections=300"
    volumes:
      - ergenekon_pgdata:/var/lib/postgresql/data
      - ergenekon_backups:/var/lib/postgresql/backups
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${DB_USER:-postgres} -d \${DB_NAME:-ergenekon}"]
      interval: 10s
      timeout: 5s
      retries: 5
    logging: *default-logging
    networks:
      - ergenekon_net

  redis:
    image: redis:7-alpine
    container_name: ergenekon-redis
    restart: unless-stopped
    command: >
      redis-server
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass \${REDIS_PASSWORD:-changeme}
    volumes:
      - ergenekon_redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "\${REDIS_PASSWORD:-changeme}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    logging: *default-logging
    networks:
      - ergenekon_net

  cert-init:
    image: alpine:3.19
    container_name: ergenekon-cert-init
    network_mode: host
    volumes:
      - ./nginx/certs:/certs
    command:
      - sh
      - -c
      - |
        apk add --no-cache openssl > /dev/null 2>&1
        if [ -f /certs/server.crt ]; then
          echo "[cert-init] Sertifikalar zaten mevcut, atlaniyor."
          exit 0
        fi
        echo "[cert-init] Host IP'leri tespit ediliyor..."
        SAN="DNS:localhost,IP:127.0.0.1"
        for IP in \$(ip -4 addr show 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print \$2}'); do
          case "\$IP" in
            127.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|169.254.*) continue ;;
            *) SAN="\${SAN},IP:\${IP}" ;;
          esac
        done
        echo "[cert-init] Kapsanan IP'ler: \$SAN"
        openssl genrsa -out /certs/ca.key 4096 2>/dev/null
        openssl req -new -x509 -days 3650 \\
          -key /certs/ca.key \\
          -out /certs/ca.crt \\
          -subj "/CN=Ergenekon Local CA/O=Ergenekon/C=TR"
        openssl genrsa -out /certs/server.key 2048 2>/dev/null
        openssl req -new \\
          -key /certs/server.key \\
          -out /certs/server.csr \\
          -subj "/CN=localhost/O=Ergenekon/C=TR"
        printf "subjectAltName=\${SAN}\nextendedKeyUsage=serverAuth\n" > /tmp/san.ext
        openssl x509 -req -days 3650 \\
          -in /certs/server.csr \\
          -CA /certs/ca.crt -CAkey /certs/ca.key -CAcreateserial \\
          -out /certs/server.crt \\
          -extfile /tmp/san.ext 2>/dev/null
        chmod 644 /certs/ca.crt /certs/server.crt
        chmod 600 /certs/ca.key /certs/server.key
        echo "[cert-init] Sertifikalar hazir!"
    restart: "no"

  ergenekon-proxy:
    image: nginx:1.27-alpine
    container_name: ergenekon-proxy
    restart: unless-stopped
    depends_on:
      cert-init:
        condition: service_completed_successfully
      umay-frontend:
        condition: service_started
      umay-backend:
        condition: service_started
      otuken-frontend:
        condition: service_started
      otuken-backend:
        condition: service_started
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    ports:
      - "\${PROXY_HTTP_PORT:-80}:80"
      - "\${PROXY_HTTPS_PORT:-443}:443"
      - "\${PROXY_OTUKEN_PORT:-4443}:4443"
    logging: *default-logging
    networks:
      - ergenekon_net

  umay-backend:
    image: ${HUB}/umay-backend:${VERSION}
    container_name: umay-backend
    restart: unless-stopped
    env_file:
      - .env.umay
    environment:
      POSTGRES_HOST: db
      POSTGRES_DB: umay
      POSTGRES_USER: \${DB_USER:-postgres}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-postgres}
      REDIS_HOST: redis
      REDIS_PASSWORD: \${REDIS_PASSWORD:-}
    volumes:
      - umay_backend_storage:/app/storage
      - umay_backend_backups:/app/backups
      - /var/run/docker.sock:/var/run/docker.sock
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    logging: *default-logging
    networks:
      - ergenekon_net

  umay-frontend:
    image: ${HUB}/umay-frontend:${VERSION}
    container_name: umay-frontend
    restart: unless-stopped
    depends_on:
      - umay-backend
    logging: *default-logging
    networks:
      - ergenekon_net

  umay-worker:
    image: ${HUB}/umay-worker:${VERSION}
    container_name: umay-worker
    restart: unless-stopped
    command: ["arq", "app.worker.WorkerSettings"]
    env_file:
      - .env.umay
    environment:
      POSTGRES_HOST: db
      POSTGRES_DB: umay
      POSTGRES_USER: \${DB_USER:-postgres}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-postgres}
      REDIS_HOST: redis
      REDIS_PASSWORD: \${REDIS_PASSWORD:-}
    volumes:
      - umay_backend_storage:/app/storage
      - umay_backend_backups:/app/backups
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    logging: *default-logging
    networks:
      - ergenekon_net

  otuken-backend:
    image: ${HUB}/otuken-backend:${VERSION}
    container_name: otuken-backend
    restart: unless-stopped
    env_file:
      - .env.otuken
    environment:
      POSTGRES_HOST: db
      POSTGRES_DB: umay
      POSTGRES_USER: \${DB_USER:-postgres}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-postgres}
      DATABASE_URL: postgresql+psycopg://\${DB_USER:-postgres}:\${DB_PASSWORD:-postgres}@db:5432/umay
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: \${REDIS_PASSWORD:-}
      UMAY_BASE_URL: http://umay-backend:8000
      INTERNAL_API_KEY: \${INTERNAL_API_KEY}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      umay-backend:
        condition: service_started
    logging: *default-logging
    networks:
      - ergenekon_net

  otuken-frontend:
    image: ${HUB}/otuken-frontend:${VERSION}
    container_name: otuken-frontend
    restart: unless-stopped
    depends_on:
      - otuken-backend
    logging: *default-logging
    networks:
      - ergenekon_net

  otuken-sync-worker:
    image: ${HUB}/otuken-sync-worker:${VERSION}
    container_name: otuken-sync-worker
    restart: unless-stopped
    command:
      - "python"
      - "/app/scripts/sync_queue_worker.py"
      - "--base-url" - "http://otuken-backend:8080"
      - "--api-key" - "\${INTERNAL_API_KEY}"
      - "--batch-limit" - "100"
      - "--interval-seconds" - "30"
    env_file:
      - .env.otuken
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      umay-backend:
        condition: service_started
      otuken-backend:
        condition: service_started
    logging: *default-logging
    networks:
      - ergenekon_net

  ergenekon-watchdog:
    image: docker:27-cli
    container_name: ergenekon-watchdog
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./scripts/network-watchdog.sh:/watchdog.sh:ro
    environment:
      NETWORK_NAME: ergenekon_ergenekon_net
      INTERVAL: "10"
    entrypoint: ["sh", "/watchdog.sh"]
    logging: *default-logging
    networks:
      - ergenekon_net
    depends_on:
      - ergenekon-proxy

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: ergenekon-uptime-kuma
    restart: unless-stopped
    volumes:
      - uptime_kuma_data:/app/data
    logging: *default-logging
    networks:
      - ergenekon_net

networks:
  ergenekon_net:
    driver: bridge

volumes:
  ergenekon_pgdata:
  ergenekon_backups:
  ergenekon_redis_data:
  umay_backend_storage:
  umay_backend_backups:
  uptime_kuma_data:
COMPOSEFILE

echo -e "${GREEN}  ✓ docker-compose.yml (Hub images: ${HUB}/*:${VERSION})${NC}"

# ── 7. Docker Hub'dan çek ve başlat ─────────────────────────────────────────
echo ""
echo -e "${YELLOW}[7/7] Docker Hub'dan image'lar çekiliyor ve sistem başlatılıyor...${NC}"
echo -e "      (İlk çekim 3-5 dakika sürebilir)"
echo ""

docker compose pull 2>&1 | grep -E "Pulling|Pull complete|Already exists|Error" || true

echo ""
echo -e "${YELLOW}    Servisler başlatılıyor...${NC}"
docker compose up -d

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           🏰 ERGENEKON KURULUM TAMAMLANDI               ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"

# QNAP'ın IP'sini bul
QNAP_IP=$(ip -4 addr show | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
  | awk '{print $2}' | grep -v '127\.' | grep -v '172\.' | head -1)

echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║  Umay (Finansal):                                        ║${NC}"
echo -e "${GREEN}║    https://${QNAP_IP}${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║  Ötüken (Operasyonel):                                   ║${NC}"
echo -e "${GREEN}║    https://${QNAP_IP}:4443${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║  Admin Giriş:                                            ║${NC}"
echo -e "${YELLOW}║    E-posta  : admin@umay.local                           ║${NC}"
echo -e "${YELLOW}║    Şifre    : Admin2026!                                 ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║  ⚠️  Tarayıcı SSL uyarısı verirse:                        ║${NC}"
echo -e "${CYAN}║    Gelişmiş → Güvensiz devam et                          ║${NC}"
echo -e "${CYAN}║    (Self-signed sertifika — yerel ağ için normaldir)     ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Container durumları
echo -e "${YELLOW}Container durumları:${NC}"
docker compose ps
