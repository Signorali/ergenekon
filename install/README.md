# Ergenekon Sistemi — Tek Tık Kurulum

Umay (finansal yönetim) + Ötüken (tarımsal operasyon) — Docker Compose tabanlı ev/ofis/küçük işletme self-hosted çözümü.

## ⚡ Kurulum

### Tek satırlık komut

```bash
curl -fsSL https://get.umay.app/install | sudo bash
```

Yedek URL (özel domain henüz yoksa):

```bash
curl -fsSL https://raw.githubusercontent.com/signorali/ergenekon/main/install/install.sh | sudo bash
```

### Çevre değişkenleriyle özelleştirme

```bash
# Farklı dizin
INSTALL_DIR=/srv/ergenekon curl -fsSL https://get.umay.app/install | sudo bash

# Farklı CDN/mirror
BASE_URL=https://my-mirror.example.com/install curl -fsSL ... | sudo bash

# Image pull'u atla (offline test)
SKIP_PULL=1 curl -fsSL https://get.umay.app/install | sudo bash
```

## 🖥 Sistem Gereksinimleri

| Bileşen | Min | Önerilen |
|---------|-----|----------|
| OS | Linux (kernel 4.x+) | Ubuntu 22.04 / Debian 12 / Raspbian |
| RAM | 2 GB | 4 GB+ |
| Disk | 5 GB boş | 20 GB+ (yedekler için) |
| Docker | — | Otomatik kurulur (`get.docker.com`) |
| Mimari | x86_64 / arm64 / armv7 | Raspberry Pi 4 4GB+ uyumlu |

**Test edilen platformlar:** Ubuntu 22.04, Debian 12, Raspberry Pi OS, QNAP Container Station, Synology Container Manager, CasaOS, Unraid.

## 🤖 Yapay Zeka Asistanı (Opsiyonel — Faz 3 için ekstra şart)

Umay AI Asistanı'nın gelişmiş özelliği (🧠 LLM modu, doğal dil sorgu)
yerel **Ollama** container'ı (`ergenekon-ai`) gerektirir.

| Mod | Gereksinim | Davranış |
|---|---|---|
| ⚡ Hızlı (Faz 1+2) | Standart kurulum yeterli | Kural tabanlı kategori önerisi, anomali tespiti, pgvector semantik arama |
| 🧠 Gelişmiş (Faz 3) | x86_64 CPU + 6 GB serbest RAM + ~5 GB disk | Yerel LLM ile doğal dil yardımcısı (Qwen 2.5 7B) |

**Gelişmiş modu aktif etmek için kurulumdan sonra:**

```bash
cd /opt/ergenekon
docker compose exec ergenekon-ai ollama pull qwen2.5:7b-instruct-q4_K_M
# ~4.4 GB model indirir, ~5 dk sürer
```

**ARM cihazlarda (Raspberry Pi, ARM QNAP):** Ollama image x86_64-only.
`ergenekon-ai` servisini compose'tan çıkarın. Faz 1+2 sorunsuz çalışmaya
devam eder; sadece 🧠 LLM butonu otomatik gizlenir (v3.7.1 probe sayesinde).

**Düşük RAM'li QNAP/NAS'larda:** AI'yi tenant ayarlarından kapatabilirsiniz
(`Ayarlar → AI Asistanı → ai_enabled = false`). Bu container ayakta kalsa
bile backend onu hiç çağırmaz, yük üretmez.

## 📋 Kurulum Adımları (script ne yapıyor?)

1. **Sistem kontrolleri** — root yetkisi, OS, RAM, disk
2. **Docker kurulumu** — yoksa `get.docker.com` ile kurar
3. **Kurulum dizini** — `/opt/ergenekon` (veya `INSTALL_DIR`)
4. **Yapılandırma** — `docker-compose.yml`, nginx config indirilir
5. **Güvenlik anahtarları** — DB şifresi, JWT secret, Redis şifresi rastgele üretilir, `.env`'e yazılır (`chmod 600`)
6. **Image pull** — Docker Hub'dan `signorali/umay-*` ve `signorali/otuken-*` çekilir
7. **Servisler** — `docker compose up -d`, sağlık kontrolü

## 🌐 Erişim

Kurulum sonrası:

- **Umay (Finansal):** `http://localhost` veya `http://<sunucu-ip>`
- **Ötüken (Tarım, Enterprise):** `http://localhost:4443`

İlk açılışta Umay kurulum sihirbazı açılır → yönetici hesabı oluştur → çalışmaya hazır.

## 🔄 Güncelleme

İki yol:

### A) Tek tık (önerilen)
Umay arayüzünden: **Ayarlar → Sistem → Şimdi Güncelle**

Backend Docker socket üzerinden Hub'dan en son image'ları çeker, container'ları yeniden oluşturur.

### B) Komut satırı
```bash
cd /opt/ergenekon
docker compose pull
docker compose up -d
```

## 🛠 Yararlı Komutlar

```bash
cd /opt/ergenekon

# Servis durumu
docker compose ps

# Canlı log
docker compose logs -f

# Sadece backend log'u
docker compose logs -f umay-backend

# Yeniden başlat
docker compose restart

# Belirli servisi yeniden başlat
docker compose restart umay-backend

# Veritabanı yedeği al
docker compose exec db pg_dumpall -U postgres > yedek-$(date +%F).sql

# Tüm sistemi durdur
docker compose down

# Verilerle birlikte sil (DİKKAT)
docker compose down -v
```

## 📁 Dosya Yapısı

```
/opt/ergenekon/
├── .env                    # Secret'lar (yedekleyin!)
├── docker-compose.yml      # Servis tanımları
├── nginx/
│   ├── nginx.conf
│   └── certs/              # Otomatik üretilen SSL
└── scripts/
    └── network-watchdog.sh
```

## 🔐 Güvenlik

- `.env` dosyası `chmod 600` ile sadece root tarafından okunabilir
- Tüm secret'lar (32-64 karakter) `/dev/urandom`'dan üretilir
- Servis port'ları varsayılan olarak `127.0.0.1`'e bağlı (sadece proxy public)
- Self-signed HTTPS sertifikası ilk kurulumda otomatik üretilir

## 🆘 Sorun Giderme

**Docker daemon çalışmıyor:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

**Port 80/443 başka bir servis kullanıyor:**
```bash
# .env'de değiştir
PROXY_HTTP_PORT=8080
PROXY_HTTPS_PORT=8443
docker compose up -d
```

**Tamamen sıfırla (DİKKAT, veri silinir):**
```bash
cd /opt/ergenekon
docker compose down -v
rm -rf /opt/ergenekon
curl -fsSL https://get.umay.app/install | sudo bash
```

**.env dosyasını kaybettim:**
DB şifresi olmadan eski verilere erişim yok. Mevcut PostgreSQL container çalışıyorsa
`docker exec ergenekon-db env | grep PASSWORD` ile alabilirsiniz.

## 📞 Destek

Sorunlar için: **alikoken@outlook.com**

Geri bildirim formu: Umay arayüzünde sağ alttaki ✉ butonu.

## 📜 Lisans

Trial sürümü ücretsiz, Enterprise (Ötüken dahil) için lisans gerekir. Bkz: Ayarlar → Lisans.
