# ⚡ Ergenekon - Hızlı Başlangıç

## 5 Dakikalık Setup

### 1️⃣ Environment Hazırla
```bash
# Gerekli paketleri kontrol et
docker --version
docker-compose --version
```

### 2️⃣ Konfigürasyon
```bash
# E:\Entegre sistem klasörüne git
cd E:\Entegre sistem

# .env dosyasını kontrol et (genellikle hazır)
cat .env
```

### 3️⃣ Servisleri Başlat

```bash
# Tüm servisleri başlat (ilk kez ~5-10 dakika)
docker-compose up -d

# Başlama durumunu kontrol et
docker-compose ps
```

### 4️⃣ Erişim

**Umay (Finansal):**
- 🌐 Frontend: http://localhost:1881
- 🔌 API: http://localhost:1923/docs

**Ötüken (Operasyonel):**
- 🌐 Frontend: http://localhost:5174
- 🔌 API: http://localhost:8080/docs

---

## 🔍 Beklenen Çıkış

```
NAME                    STATUS
ergenekon-db           Up (healthy)
ergenekon-redis        Up (healthy)
umay-backend           Up
umay-frontend          Up
umay-worker            Up
otuken-backend         Up
otuken-frontend        Up
otuken-sync-worker     Up
```

---

## ⚠️ Yaygın Sorunlar

### "Cannot connect to database"
```bash
# Database log'unu kontrol et
docker-compose logs db

# Database'i sıfırla
docker-compose down -v && docker-compose up -d db
```

### "Port already in use"
`.env` dosyasında port değiştir:
```
UMAY_FRONTEND_PORT=1881     # 1881 → 1882?
UMAY_BACKEND_PORT=1923      # 1923 → 1924?
OTUKEN_FRONTEND_PORT=5174   # 5174 → 5175?
OTUKEN_BACKEND_PORT=8080    # 8080 → 8081?
```

### "Docker image build failed"
```bash
# Rebuild et
docker-compose build --no-cache

# Sonra başlat
docker-compose up -d
```

---

## 📊 Sistem Durumu

```bash
# Tüm logları göster
docker-compose logs

# Belirli servis logu
docker-compose logs otuken-backend

# Real-time izleme
docker-compose logs -f umay-backend
```

---

## 🛑 Durdurma

```bash
# Devam etmek için (data korunur)
docker-compose stop

# Yeniden başlat
docker-compose start

# Tamamen sil (data korunur)
docker-compose down

# Tümünü sil (VERİTABANI SİLİNİR)
docker-compose down -v
```

---

## 📚 Sonraki Adımlar

1. Umay'da **finansal kaydı** yap
2. Ötüken'de **operasyonel kaydı** yap
3. Veritabanı entegrasyonunu kontrol et
4. Redis Pub/Sub event flow'unu ayarla (daha sonra)

---

**🏰 Ergenekon Hazır!**
