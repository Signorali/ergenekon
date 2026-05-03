#!/usr/bin/env bash
# =============================================================================
#  Ergenekon Sistemi — Tek Satır Kurulum
#  Umay (Finansal Yönetim) + Ötüken (Tarımsal Operasyon)
#
#  Kurulum:
#    curl -fsSL https://get.umay.app/install | sudo bash
#    veya
#    curl -fsSL https://raw.githubusercontent.com/signorali/ergenekon/main/install/install.sh | sudo bash
#
#  Çevre değişkenleri (override için):
#    INSTALL_DIR=/opt/ergenekon       # Kurulum dizini
#    BASE_URL=https://...              # Config dosyalarının URL'si
#    SKIP_PULL=1                       # Image pull'u atla (test için)
# =============================================================================

set -euo pipefail

# ── Renkler ──────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4); CYAN=$(tput setaf 6); MAGENTA=$(tput setaf 5)
else
  BOLD=""; DIM=""; RESET=""
  RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; MAGENTA=""
fi

# ── Konfigürasyon ────────────────────────────────────────────────────────────
INSTALL_DIR="${INSTALL_DIR:-/opt/ergenekon}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/signorali/ergenekon/main/install}"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# ── Yardımcılar ──────────────────────────────────────────────────────────────
log()  { printf "%s  %s\n" "${BLUE}[*]${RESET}" "$*"; }
ok()   { printf "%s %s\n"  "${GREEN}[✓]${RESET}" "$*"; }
warn() { printf "%s %s\n"  "${YELLOW}[!]${RESET}" "$*"; }
err()  { printf "%s %s\n"  "${RED}[✗]${RESET}" "$*" >&2; }
die()  { err "$*"; exit 1; }

step() {
  printf "\n${BOLD}${MAGENTA}==>${RESET} ${BOLD}%s${RESET}\n" "$*"
}

# ── ASCII Logo ───────────────────────────────────────────────────────────────
banner() {
  cat <<EOF
${BOLD}${CYAN}
   ╔══════════════════════════════════════════════════════╗
   ║                                                      ║
   ║       Ergenekon Sistemi — Tek Tık Kurulum            ║
   ║                                                      ║
   ║     ${RESET}${BOLD}🪙 Umay${CYAN} Finansal  ·  ${RESET}${BOLD}🌾 Ötüken${CYAN} Tarım           ║
   ║                                                      ║
   ╚══════════════════════════════════════════════════════╝
${RESET}
EOF
}

# ── 1. Yetki + sistem kontrolleri ────────────────────────────────────────────
check_prereqs() {
  step "1/7  Sistem Kontrolleri"

  # root yetkisi
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "Bu kurulum root yetkisi gerektirir. ${BOLD}sudo${RESET} ile çalıştırın."
  fi
  ok "Root yetkisi mevcut"

  # OS kontrolü
  local os_id=""
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_id="${ID:-unknown}"
  fi
  ok "İşletim sistemi: ${os_id:-belirsiz Linux}"

  # Mimari
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|aarch64|arm64|armv7l)
      ok "Mimari: $arch"
      ;;
    *)
      warn "Mimari $arch tam test edilmemiş — devam ediliyor"
      ;;
  esac

  # Disk alanı
  local free_gb
  free_gb="$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9')"
  if [ -n "$free_gb" ] && [ "$free_gb" -lt 5 ]; then
    warn "Boş disk alanı düşük: ${free_gb} GB (en az 5 GB önerilir)"
  else
    ok "Disk alanı: ${free_gb:-?} GB"
  fi

  # RAM kontrolü
  local mem_mb
  mem_mb="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)"
  if [ -n "$mem_mb" ] && [ "$mem_mb" -lt 1500 ]; then
    warn "RAM düşük: ${mem_mb} MB (en az 2 GB önerilir, Raspberry Pi 4 4GB+ ideal)"
  else
    ok "RAM: ${mem_mb} MB"
  fi
}

# ── 2. Docker kurulumu ───────────────────────────────────────────────────────
install_docker() {
  step "2/7  Docker Kurulumu"

  if command -v docker >/dev/null 2>&1; then
    local dv
    dv="$(docker --version | awk '{print $3}' | tr -d ',')"
    ok "Docker zaten kurulu: $dv"
  else
    log "Docker bulunamadı, kuruluyor (resmi script)..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker || true
    ok "Docker kuruldu"
  fi

  # Docker Compose v2 kontrolü (artık plugin)
  if docker compose version >/dev/null 2>&1; then
    local cv
    cv="$(docker compose version --short 2>/dev/null || echo 'v2')"
    ok "Docker Compose: $cv"
  elif command -v docker-compose >/dev/null 2>&1; then
    ok "Docker Compose (v1 legacy) kurulu — v2'ye geçilmesi önerilir"
  else
    log "Docker Compose plugin'i kuruluyor..."
    apt-get install -y docker-compose-plugin 2>/dev/null \
      || yum install -y docker-compose-plugin 2>/dev/null \
      || die "Docker Compose plugin'i kurulamadı. Manuel kurun: https://docs.docker.com/compose/install/"
    ok "Docker Compose kuruldu"
  fi

  # Daemon ayakta mı?
  if ! docker info >/dev/null 2>&1; then
    die "Docker daemon çalışmıyor. Çalıştır: ${BOLD}sudo systemctl start docker${RESET}"
  fi
}

# ── 3. Kurulum dizini ────────────────────────────────────────────────────────
prepare_dir() {
  step "3/7  Kurulum Dizini"

  # Dizin adı her zaman 'ergenekon' ile bitmeli
  local dir_name
  dir_name="$(basename "$INSTALL_DIR")"
  if [ "$dir_name" != "ergenekon" ]; then
    warn "INSTALL_DIR adı '$dir_name' — önerilen: 'ergenekon'"
    warn "Tüm Docker volume ve container adları 'ergenekon_' önekiyle oluşturulur."
  fi

  if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/$COMPOSE_FILE" ]; then
    warn "Mevcut kurulum tespit edildi: $INSTALL_DIR"
    log "Yapılandırma korunacak, sadece güncelleme yapılacak."
    UPGRADE_MODE=1
  else
    UPGRADE_MODE=0
    mkdir -p "$INSTALL_DIR"
    ok "Dizin oluşturuldu: $INSTALL_DIR"
  fi

  cd "$INSTALL_DIR"
}

# ── 4. Config dosyalarını indir ──────────────────────────────────────────────
download_configs() {
  step "4/7  Yapılandırma Dosyaları"

  local files=("$COMPOSE_FILE" "nginx/nginx.conf" "scripts/network-watchdog.sh")
  for f in "${files[@]}"; do
    local dir
    dir="$(dirname "$f")"
    [ "$dir" != "." ] && mkdir -p "$dir"
    if [ -f "$f" ] && [ "${UPGRADE_MODE:-0}" = "1" ]; then
      log "$f mevcut, atlanıyor (yükseltme modu)"
      continue
    fi
    log "İndiriliyor: $f"
    curl -fsSL "$BASE_URL/$f" -o "$f" \
      || die "İndirilemedi: $BASE_URL/$f"
  done
  chmod +x scripts/*.sh 2>/dev/null || true
  ok "Yapılandırma dosyaları hazır"
}

# ── 5. Secret oluştur ────────────────────────────────────────────────────────
generate_secrets() {
  step "5/7  Güvenlik Anahtarları"

  if [ -f "$ENV_FILE" ]; then
    ok ".env mevcut, korunuyor (yeni şifre üretilmedi)"
    return
  fi

  local db_pwd jwt_secret redis_pwd internal_key
  db_pwd="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
  jwt_secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64)"
  redis_pwd="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
  internal_key="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)"

  cat > "$ENV_FILE" <<EOF
# =============================================================================
#  Ergenekon Sistemi — Otomatik Üretilen .env
#  Üretildi: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#  ⚠ Bu dosyayı yedekleyin! Şifreler kaybolursa veriye erişim de kaybedilir.
# =============================================================================

# Versiyon (Docker Hub tag)
APP_VERSION=latest

# Domain adı — boş bırakılırsa IP ile self-signed sertifika kullanılır
DOMAIN=

# Veritabanı
DB_USER=postgres
DB_PASSWORD=$db_pwd

# Redis
REDIS_PASSWORD=$redis_pwd

# Backend secrets
JWT_SECRET=$jwt_secret
INTERNAL_API_KEY=$internal_key

# Port'lar (host'ta hangi portlardan erişilecek)
PROXY_HTTP_PORT=80
PROXY_HTTPS_PORT=443
PROXY_OTUKEN_PORT=4443
UMAY_BACKEND_PORT=1923
UMAY_FRONTEND_PORT=1881
OTUKEN_BACKEND_PORT=8080
OTUKEN_FRONTEND_PORT=5174

# Loglama
LOG_LEVEL=INFO
EOF
  chmod 600 "$ENV_FILE"
  ok "Yeni secret'lar üretildi ve $ENV_FILE'a kaydedildi (chmod 600)"
}

# ── 5.5. Domain yapılandırması ────────────────────────────────────────────────
configure_domain() {
  step "5.5/7  Domain & Sertifika Yapılandırması"

  # Yükseltme modunda mevcut ayarı koru
  if [ "${UPGRADE_MODE:-0}" = "1" ]; then
    local existing_domain
    existing_domain="$(grep -E "^DOMAIN=" "$ENV_FILE" 2>/dev/null | cut -d= -f2)"
    ok "Mevcut domain: '${existing_domain:-boş}' — korunuyor"
    return
  fi

  log "Sisteme bir domain adı atanacak mı? (örn: umay.sirket.com)"
  log "Domain varsa HTTPS sertifikası o isim için de geçerli olur."
  log "Yoksa Enter ile geçin — sunucu IP'si ile çalışır."
  printf "\n  ${BOLD}Domain [boş bırakın = IP ile kullan]:${RESET} "

  local domain=""
  if [ -t 0 ]; then
    read -r domain
    domain="$(printf '%s' "$domain" | tr -d '[:space:]')"
  fi

  # .env'deki DOMAIN= satırını güncelle
  if [ -n "$domain" ]; then
    sed -i "s|^DOMAIN=.*|DOMAIN=${domain}|" "$ENV_FILE"
    ok "Domain kaydedildi: ${BOLD}$domain${RESET}"
  else
    ok "Domain tanımlanmadı — sertifika sunucu IP'si için üretilecek"
  fi
}

# ── 6. Image pull ────────────────────────────────────────────────────────────
pull_images() {
  step "6/7  Docker Image'ları İndiriliyor"

  if [ "${SKIP_PULL:-0}" = "1" ]; then
    warn "SKIP_PULL=1 — image indirme atlanıyor (test modu)"
    return
  fi

  log "Docker Hub'dan image'lar çekiliyor..."
  if docker compose -f "$COMPOSE_FILE" pull; then
    ok "Tüm image'lar indirildi"
  else
    err "Bir veya daha fazla image indirilemedi"
    die "İnternet bağlantınızı kontrol edin ve tekrar deneyin"
  fi
}

# ── 7. Servisleri başlat ─────────────────────────────────────────────────────
start_services() {
  step "7/7  Servisler Başlatılıyor"

  log "docker compose up -d ..."
  docker compose -f "$COMPOSE_FILE" up -d

  log "Sağlık kontrolleri (en fazla 90 saniye)..."
  local i=0
  while [ "$i" -lt 18 ]; do
    sleep 5
    if docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null \
       | grep -q '"State":"running"'; then
      ok "Servisler ayakta"
      break
    fi
    printf "."
    i=$((i + 1))
  done
  echo ""
}

# ── Sonuç ekranı ─────────────────────────────────────────────────────────────
show_summary() {
  local ip domain
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -z "$ip" ] && ip="<sunucu-ip>"
  domain="$(grep -E "^DOMAIN=" "$ENV_FILE" 2>/dev/null | cut -d= -f2)"

  local primary_host="${domain:-$ip}"

  cat <<EOF

${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗
║                                                      ║
║   ✅  Kurulum Tamamlandı!                            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝${RESET}

${BOLD}🌐 Erişim adresleri:${RESET}

  ${BOLD}Umay${RESET}  (Finansal Yönetim)
    → https://${primary_host}
    → https://${ip}           ${DIM}# IP ile direkt erişim${RESET}

  ${BOLD}Ötüken${RESET} (Tarımsal Operasyon — Enterprise lisans gerektirir)
    → https://${primary_host}:4443
    → https://${ip}:4443

${BOLD}🔒 HTTPS Sertifikası — Tek Seferlik Kurulum:${RESET}

  Sertifika sistemin kendi CA'sı tarafından imzalanmıştır.
  Tarayıcı uyarısını gidermek için CA sertifikasını yükleyin:

  ${BOLD}${CYAN}→ http://${ip}/ca.crt${RESET}   ${DIM}← Bu adresten indirin${RESET}

  ${BOLD}Windows:${RESET}  İndirilen .crt → Çift tıkla → Güvenilen Kök CA → Yükle
  ${BOLD}macOS:${RESET}    İndirilen .crt → Çift tıkla → Anahtarlık → "Her Zaman Güven"
  ${BOLD}Linux:${RESET}    sudo cp ergenekon-ca.crt /usr/local/share/ca-certificates/
             sudo update-ca-certificates
  ${BOLD}Android:${RESET}  Ayarlar → Güvenlik → Sertifika Yükle → CA Sertifikası
  ${BOLD}iOS:${RESET}      İndir → Ayarlar → İndirilen Profil → Yükle → Güven Etkinleştir

  ${DIM}CA sertifikası sunucu değişmediği sürece geçerlidir (10 yıl).${RESET}

${BOLD}🔐 İlk açılışta:${RESET}
   Tarayıcıdan Umay'a girip kurulum sihirbazıyla
   yönetici hesabı oluşturun.

${BOLD}📁 Kurulum dizini:${RESET}    $INSTALL_DIR
${BOLD}🛠 Komutlar:${RESET}
   cd $INSTALL_DIR
   docker compose ps              ${DIM}# durum${RESET}
   docker compose logs -f         ${DIM}# canlı log${RESET}
   docker compose restart         ${DIM}# yeniden başlat${RESET}
   docker compose pull && docker compose up -d  ${DIM}# güncelle${RESET}

${YELLOW}⚠ .env dosyasını yedekleyin (${INSTALL_DIR}/.env)
   İçinde DB şifresi ve JWT secret var.${RESET}

EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  banner
  check_prereqs
  install_docker
  prepare_dir
  download_configs
  generate_secrets
  configure_domain
  pull_images
  start_services
  show_summary
}

main "$@"
