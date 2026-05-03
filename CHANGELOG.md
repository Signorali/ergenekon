# Changelog

Tüm önemli değişiklikler bu dosyada belgelenir.  
All notable changes are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/) · Versioning: [Semantic Versioning](https://semver.org/)

---

## [3.4.0] - 2026-05-03

### Eklendi / Added
- **Ötüken Alış / Gider:** Stok kartı seçimi artık opsiyonel — stoksuz gider satırları (yakıt, işçilik, internet vb.) doğrudan açıklama + tutar ile kaydedilebilir
- **Ötüken Alış formu:** İki modlu satır — "📦 Stoklu Alış" ve "💸 Stoksuz Gider" arasında geçiş
- **Umay Kredi Kartı (Peşin Alışveriş):** Arazi kategorilerinde "Stok hareketi de oluştur" toggle'ı; varsayılan kapalı, opt-in
- **Umay İşlemler:** Aynı opt-in toggle Arazi gelir/gider işlemlerinde de aktif
- **Umay Eski Kredi UX:** "Eski Kredi" işaretlenince gereksiz alanlar (hesap, net tutar, masraf) gizlenir; bilgilendirme kutusu eklendi
- Backend `LoanCreate` schema: `disbursed_amount` eski kredide opsiyonel, principal'a fallback yapar

### Düzeltildi / Fixed
- **Ötüken → Umay senkronizasyon:** Frontend'de `create_finance_event=false` hardcoded'du; artık `true` — Ötüken'de yapılan satın almalar Umay'a gider olarak otomatik yansıyor
- Eski kredilerde `fees` zorla 0'a çekilir (yanlışlıkla gönderilse bile) — backend'de masraf gideri oluşturulmuyor

### Değişti / Changed
- `PurchaseLine.inventory_item_id` artık nullable (DB migration `0022`)
- Yeni kolon: `purchase_lines.description` (stoksuz gider açıklaması)
- CHECK constraint: bir satırda ya stok kartı ya açıklama olmalı

---

## [3.3.1] - 2026-05-03

### Eklendi / Added
- Evrensel HTTPS sertifika desteği — kurulum sırasında tüm sunucu IP'leri otomatik tespit edilir
- CA sertifikası HTTP üzerinden indirilebilir (`/ca.crt` endpoint)
- Kurulum scriptine domain adı sorusu eklendi (SSL SAN için)
- QNAP Container Station için ayrı yapılandırma dosyası
- HTTP redirect artık doğru HTTPS portuna yönlendirir
- `server_name _` ile tüm hostname/IP kombinasyonları kapsanır

### Düzeltildi / Fixed
- QNAP'ta HTTP → HTTPS redirect port uyumsuzluğu giderildi (9080 → 9443)
- Docker volume isimleri `ergenekon_` öneki ile tutarlı hale getirildi
- Veritabanı bağlantı adı uyumsuzluğu (`umay` → `ergenekon`) düzeltildi

### Değişti / Changed
- cert-init artık `network_mode: host` ile çalışarak gerçek sunucu IP'lerini tespit eder
- nginx `server_name localhost` → `server_name _` (catch-all)
- Kurulum özeti ekranı zenginleştirildi — platform bazlı sertifika kurulum talimatları

---

## [3.3.0] - 2026-04-15

### Eklendi / Added
- Umay tablet Android uygulaması
- Planlı ödeme worker servisi
- Kredi kartı kapanma tarihi bildirimleri
- Ötüken → Umay finansal senkronizasyon worker'ı

### Düzeltildi / Fixed
- CORS politikası güçlendirildi
- Rate limiting brute-force koruması iyileştirildi

---

## [3.2.0] - 2026-03-01

### Eklendi / Added
- Çoklu banka hesabı desteği
- Dönemsel raporlama modülü
- Rol tabanlı kullanıcı yönetimi

---

<!-- 
Yeni sürüm eklemek için:
1. Bu dosyaya yeni bir ## [x.y.z] - YYYY-MM-DD bölümü ekleyin
2. git tag vX.Y.Z && git push --tags
3. GitHub Action otomatik olarak Release oluşturur
-->
