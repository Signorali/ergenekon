# Changelog

Tüm önemli değişiklikler bu dosyada belgelenir.  
All notable changes are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/) · Versioning: [Semantic Versioning](https://semver.org/)

---

## [3.5.0] - 2026-05-05

### Yeni / Added — Tam Mobil Destek

- **Mobil alt navigasyon — Hesaplar sekmesi.** Ana alt çubuğa "Hesaplar" butonu eklendi. Kart/dikdörtgen ikonu ile temsil edilir; tıklandığında `MobileAccountsSheet` açılır. Yetki kontrolü (`accounts:view`) ile korunur. [AppShell.tsx + MobileAccountsSheet.tsx]

- **MobileAccountsSheet — Gruplu hesap listesi.** Tüm aktif hesaplar `group_name` alanına göre gruplandırılmış olarak gösterilir. Üstte toplam TRY bakiye özeti, her hesap satırında tip ikonu, kurum adı, bakiye ve `›` yönlendirme oku bulunur. Satıra tıklandığında sheet kapanır ve `/accounts/:id` detay sayfasına yönlendirilir. [MobileAccountsSheet.tsx]

- **AccountDetailPage — Mobil uyumlu hesap detayı.** Masaüstündeki tablonun yerini mobilde kart tabanlı işlem listesi alır: tarih + durum badge + açıklama solda, renkli tutar sağda. Filtre satırı compakt inline görünüme geçer (yükseklik 32px, etiket yok, sadece aktif filtreler ✕ butonu gösterir). IBAN mobilde kısaltılır (`TR12···3456`). Geri butonu mobilde gizlenir (masa üstü sayfasını yanlışlıkla açıyordu). [AccountDetailPage.tsx]

- **TransactionsPage — Mobil uyumlu işlemler sayfası.** KPI kartları kompakt görünüme geçer. İşlem tipi filtresi ve tarih kısayolları yatay kaydırmalı pill butonlarına dönüşür (taşma gizlenir). Dropdown filtreler mobilde tek sütuna geçer. "Kayıtlı İşlemler" butonu ve sayfa alt başlığı mobilde gizlenir. [TransactionsPage.tsx]

- **MobileTxForm — Hesap ve kategori gruplandırması.** Kaynak/hedef hesap seçicileri artık `group_name` alanına göre `<optgroup>` başlıklı gruplar halinde gösterilir. Kategori seçici de `group_id` eşleşmesiyle gruplandırılır. Tek grupta optgroup başlığı çıkmaz (gereksiz gürültü önlenir). `groups` prop `TransactionsPage`'den geçirildi. [MobileTxForm.tsx + TransactionsPage.tsx]

- **InvestmentsPage — Mobil portföy sayacı gizlendi.** 3. KPI kartı (portföy sayısı) mobilde gizlenir; grid 2 sütuna geçer. [InvestmentsPage.tsx]

### Düzeltildi / Fixed

- **MobilePlannedSheet — Planlı ödemeler artık form açıyor.** Önceki sürümde ekstre olmayan ödemeler için "Öde" butonuna basılınca `markPaid()` direkt çağrılıyor ve kayıt listenin dışına kayıyordu. Artık ekstre ödemelerindeki gibi bir form açılır: hesap seçimi (gruplu optgroup), tutar (değiştirilebilir) ve işlem tarihi. Submit'te `plannedPaymentsApi.execute()` çağrılır — masaüstü ile aynı davranış (gerçek finansal işlem oluşturulur). TRANSFER tipli ödemeler için hesap seçimi atlanır, kaynak/hedef hesaplar otomatik kullanılır. [MobilePlannedSheet.tsx]

- **MobilePlannedSheet — Hesap seçici gruplanması.** Hem ekstre hem planlı ödeme formundaki hesap `<select>` artık `<optgroup>` ile gruplandırılmış; CREDIT tipi hesaplar filtrelenir. Tekrarlı kod `AccountOptgroups` bileşenine çıkarıldı. [MobilePlannedSheet.tsx]

### İyileştirildi / Improved

- **CreditCardsPage — Alışverişler tablosuna Kategori sütunu eklendi.** Her KK harcamasının kategorisi ve grubu tablo satırında görünür. Grup adı kategori adının altında küçük bir etiket (badge) olarak gösterilir. Kategori atanmamışsa `—` gösterilir. [CreditCardsPage.tsx]

---

## [3.4.21] - 2026-05-04

### Düzeltildi / Fixed
- **F5 ile yenilemede ana sayfa hâlâ /transactions açıyordu.** 3.4.18'de eklenen `ReloadToDashboard` URL'i `/`'a değiştiriyordu ama TRIAL/STARTER planlarında `dashboard` feature'ı yoktu → `LicensedRoot` `Navigate to="/transactions"` ile geri fırlatıyordu. Sebep: dashboard yanlışlıkla "premium" feature olarak işaretlenmişti, oysa ana giriş ekranı.
  - **Backend:** `dashboard` feature'ı TRIAL plan'a eklendi (zincirleme STARTER, PROFESSIONAL, ENTERPRISE'a da yayıldı). [license_crypto.py]
  - **Frontend:** `LicensedRoot` artık `hasFeature('dashboard')` kontrolünü yapmıyor; authenticated kullanıcı her zaman dashboard'a iniyor. İçindeki widget'lar zaten kendi license/permission gate'lerini taşıyor. [App.tsx]

---

## [3.4.20] - 2026-05-04

### Güvenlik / Security (KRİTİK)
- **System endpoints — admin yetkisi zorunlu.** Eskiden sıradan kullanıcı `/system/flags/{flag_key}` PUT, `/system/maintenance/enable`, `/system/maintenance/windows` POST gibi endpoint'leri çağırabiliyordu. Saldırgan UPDATE_ENABLED gibi global flag'leri kapatabilir, sistemi maintenance moda alabilirdi. Artık `tenant_admin/superuser` zorunlu. [system.py]
- **Watchlist pin update — cross-tenant koruma.** `body.ordered_ids` içindeki UUID'lerin tenant'a ait olup olmadığı doğrulanmıyordu. Saldırgan başka tenant'ın WatchlistItem.id'lerini gönderirse pin tablosuna kendi user_id'siyle yazılıyordu (cross-tenant veri kirletme + bilgi sızıntısı). Artık tenant filtresiyle geçerli ID'ler ayıklanıyor; rejected sayısı response'a dahil. [market.py]
- **`INTERNAL_API_KEY` / `OTUKEN_API_KEY` production'da default değer reddedilir.** APP_ENV=production iken bu key'ler `CHANGE_ME_IN_PRODUCTION` veya boş ise backend startup'ta fail eder. Eskiden default değerle çıkıp Ötüken'in internal endpoint'i zayıf key ile herkese açıktı. [config.py]
- **`delete_request` target_id ownership doğrulaması.** Eskiden saldırgan ALLOWED_TARGET_TABLES içindeki herhangi bir tabloya rastgele UUID gönderebiliyordu (kuyruk kirletme + tenant probe). Artık target_id'nin gerçekten bu tenant'a ait, soft-delete edilmemiş olduğu doğrulanmadan kayıt yaratılmaz. [delete_request_service.py]

### Concurrency / Veri Bütünlüğü
- **Credit card row locks.** `create_purchase`, `pay_statement`, `generate_statement` paths artık `with_for_update()` ile kart satırını kilitliyor. Eskiden iki paralel `generate_statement` çağrısı aynı kart için iki OPEN statement yaratabiliyordu (concurrent finalize yarışı). Aynı durum balance update'lerde de geçerli — şimdi serileştiriliyor. [credit_card_service.py]
- **Investment soft-delete tek atomik transaction.** Account balance restore + LedgerEntry soft-delete + cash_tx soft-delete artık tek blokta; ledger silme fail olursa outer transaction rollback yapar. Eskiden ledger silme silently yutulup balance + cash_tx state'i değişmiş kalıyordu (tutarsızlık). Account row'u da `with_for_update()` ile kilitlendi. [investment_service.py]
- **TOTP replay koruması.** `pyotp.verify(valid_window=1)` ±30s tolerans tanır; saldırgan kullanıcının kodunu MITM ile yakalayıp aynı pencerede tekrar oynatabilirdi. Artık matched time-step `users.mfa_last_used_counter` kolonunda saklanıyor; sonraki denemelerde counter ≤ son kullanılan ise reddediliyor. [mfa_service.py + migration 0072]

### UX / DoS Koruması
- **Frontend Idempotency-Key otomatik enjeksiyonu.** Mutating finansal endpoint'ler (`/transactions`, `/credit-cards`, `/loans`, `/investments`, `/accounts`, `/budgets`, `/planned-payments`) için POST/PUT/PATCH isteklerinde otomatik UUID üretilir. Network kesintisinde axios retry ederse duplicate transaction oluşmaz. Manuel set edilmiş key varsa override edilmez. [frontend/src/api/client.ts]
- **Page size limit'leri kısıtlandı.** `planned_payments` `le=10000` → `le=200`; `credit_cards/purchases` `le=2000` → `le=200`. Saldırgan large response ile DoS uygulayabilirdi. [planned_payments.py, credit_cards.py]

### Test Edildi (lokal)
- ✅ Tüm modifiye edilen Python dosyaları `py_compile` geçiyor
- ✅ Migration 0072 (single head) — alembic head sayısı = 1
- ✅ Önceki düzeltmeler (3.4.10-3.4.19) etkilenmedi

### Migration
- `0072_mfa_last_used_counter.py` — `users.mfa_last_used_counter` BIGINT NULL kolonu eklenir.

---

## [3.4.19] - 2026-05-04

### Güvenlik / Veri Bütünlüğü
- **MFA token revoke artık fail-closed.** Eskiden Redis hatası durumunda `try/except: pass` ile sessizce yutuluyor, partial_token blacklist'e eklenemiyordu — saldırgan partial_token'ı yakalarsa replay edebilirdi. Artık Redis erişilemiyor veya revoke fail ise login REDDEDİLİYOR (kullanıcıya 401 + retry önerisi). [auth_service.py]
- **Investment ledger silme hatası gizlenmiyor.** Cash transaction silindi ama ledger'da yetim kayıt kalırsa rapor tutarsızlığı oluyordu. Artık `logger.exception` + `audit_log("investment_ledger_orphan_warning")` ile iz bırakılıyor — operatör fark eder. [investment_service.py]
- **PriceSnapshot soft-delete filter eklendi.** TODO yorumuna rağmen filter eksikti; silinmiş fiyat snapshot'ları `obligations` endpoint'inde gösterilebiliyordu. [obligations.py]

### UX / Sessiz Failure
- **Asset satışında FX hatası kullanıcıya bildiriliyor.** Cross-currency satışta market call veya conversion fail olursa, sessizce kur=1 ile kayıt etmek yerine `otuken_sync_warnings` üzerinden alert gösteriliyor (satış tutarı yanlış birime kaydedilmiş olabilir uyarısı). [asset_service.py]
- **Lisans aktivasyonunda dosya yazımı uyarısı.** `/app/storage/license.key` yazılamadıysa response'a `license_file_persisted: false` + `license_file_warning` ekleniyor — frontend kullanıcıya bildirir. Eskiden sessizce yutuluyordu, sonraki "Şimdi Güncelle" akışı kırılıyordu. [license.py + LicenseActivateResponse schema]
- **Frontend silme operasyonlarında alert.** AssetsPage, InstitutionsPage, DocumentsPage, PlannedPaymentsPage, TransactionsPage'de `.catch(() => {})` yutmaları kaldırıldı; başarısız delete'te kullanıcı "❌ Silme başarısız: {detail}" alert'i görüyor. Listeleme/refresh çağrılarında pattern korundu (sayfa boş görünür, hata kritik değil).
- **Logout server fail uyarısı.** Eskiden tamamen sessizdi; artık server token revoke fail olursa kullanıcıya "oturum sunucudan kapatılamadı, şüpheli durumda şifre değiştirin" uyarısı gösteriliyor. [AuthContext.tsx]

### Performans
- **Watchlist pin update batch INSERT.** 100 sembolde 100 ayrı `db.execute` (N+1) yerine tek `db.execute(stmt, [params...])` — drag-drop sıralaması anında uygulanır. [market.py]

### Kod Kalitesi
- **Export health stats dinamik tablo listesi.** Hardcoded inline liste yerine modül-level `_HEALTH_STAT_TABLES` constant. Yeni tablo eklendiğinde tek yerden ekleyip audit kapsamına alınır. Drift loglaması da debug seviyesinde aktif. [export_service.py]
- **`text(f"...{table}...")` kullanımına yorum eklendi.** restore_validator'daki güvenli pattern (whitelist + regex) gelecek developer'lar için açıklamalı; SQL injection riski yok ama bilinçli karar olarak işaretlendi.

### Test Edildi (lokal)
- ✅ Smoke: dashboard 9 öğe, cash_flow 9 öğe (2 statement), Investment + Auth import OK, export stats çalışıyor
- ✅ Geriye dönük: önceki düzeltmeler (3.4.10-3.4.18) etkilenmedi

---

## [3.4.18] - 2026-05-04

### Eklendi / Added
- **Sayfa yenileme (F5/Ctrl+R) sonrası otomatik dashboard açılır.** Önceden URL `/transactions` veya başka bir sayfada iken yenilemek aynı sayfayı tekrar yüklüyordu. Artık `PerformanceNavigationTiming.type === 'reload'` ile yenileme algılanır ve `/`'a yönlendirilir (login/setup/change-password sayfaları hariç). Tıklayarak başka sayfaya gitmek etkilenmez.

### Düzeltildi / Fixed
- **LicenseContext fetch'inde Authorization header eksikti.** Cookie auth yoksa (Bearer token akışında) `/api/v1/license/status` 401 alıyor, fallback `{features:[transactions,accounts]}` set ediliyor, `dashboard` feature görünmediği için `/`'a giden kullanıcılar `/transactions`'a yönlendiriliyordu. Artık `localStorage.access_token` varsa fetch'e Bearer header eklenir.

---

## [3.4.17] - 2026-05-04

### Değişti / Changed
- **Dashboard "Harcama Dağılımı" pasta grafiği — küçük dilimler "Diğer" altında toplanır.** Önceden tüm kategoriler tek tek gösteriliyordu, çok parçalı pastanın okunması zorlaşıyordu. Artık toplam içinde payı **%20'den az** olan kategoriler tek "Diğer" diliminde birleştirilir. Tüm kategorilerin payı %20'den azsa (eşit dağılım), en büyük 5'i ayrı tutulur, kalanı "Diğer" olur (anlamsız tek dilim oluşmaz).
- Eşik (`PIE_OTHER_THRESHOLD = 0.20`) DashboardPage.tsx'te tek satırda; ileride değiştirmek isterseniz oradan ayarlanır.

### Etki
Dashboard pastası daha okunaklı: 2-4 büyük dilim + 1 "Diğer". Kullanıcı 8-10 küçük parça yerine net oranları görür. Detay isteyen `Tümünü Gör` veya Raporlar sayfasından kategori listesinin tamamına ulaşır.

---

## [3.4.16] - 2026-05-04

### Eklendi / Added
- **Yaklaşan Ödemeler widget'ında kesinleşen kart ekstreleri.** Backend `cash_flow_projection` artık `credit_card_statements` tablosundan CLOSED/PARTIALLY_PAID/OVERDUE statement'ları da listeye dahil ediyor. Bireysel KK Taksit'leri zaten hariç (statement'ın parçası); kullanıcı kart başına TEK ekstre satırı görüyor: "${banka} ${kart} Ekstresi" + kalan tutar + due_date

### Değişti / Changed
- **Hızlı Demirbaş modu kaldırıldı (3.4.12'den beri lokalde).** Bu sürüm public:
  - Varlık formunda artık sadece "Kaydetme" + "📋 Detaylı Demirbaş" var
  - Detaylı moda geçişte miktar otomatik 1, birim otomatik ADET
  - Submit-time validation: farm/quantity eksikse blok
- **"Şimdi Güncelle" sonrası akıllı bekleme:** Sabit 8-12s timer yerine `/api/v1/system/version`'a aktif sağlık kontrolü (max 90s). Kullanıcı 502 görmüyor.

### Düzeltildi / Fixed
- **Dashboard widget'ında planlı ödeme görünmüyordu (group filter NULL bug).** `cash_flow_projection` `group_ids.in_(...)` filtresi NULL group_id'li planned_payment'ları hariç tutuyordu. Statement query zaten `OR group_id IS NULL` kullanıyordu — tutarsızlık. Düzeltildi: ikisi de NULL'u dahil ediyor (kredi taksiti, maaş gibi tenant-wide ödemeler her group user'ının dashboard'unda görünür)
- **Admin/Superuser dashboard'u boş görünüyordu (group scope bypass).** `enforce_group_scope=True` admin için de uygulanıyordu. Düzeltildi: admin/tenant_admin tüm tenant verilerini görür
- **Backend response field uyumu:** Frontend `planned_date` ve `credit_card_purchase_id` bekliyordu, backend `cash_flow_projection` sadece `date` döndürüyordu. Alias eklendi (transient).

### Test Edildi (lokal, kanıtla)
- ✅ DB'de 7 planned_payment + 2 statement → endpoint 9 öğe dönüyor
- ✅ Dashboard widget tarih sıralı INCOME + EXPENSE + KK Ekstre karışık gösteriyor
- ✅ Admin user: tüm tenant verileri (group filter bypass)
- ✅ Bireysel KK Taksit'leri yok (statement'ın parçası, doğru filtrelenmiş)

### Publish Prosedürü
publish-dockerhub.ps1'e `[0.7/4] Alembic migration head sanity check` eklendi. Build sonrası tag'lemeden önce her iki backend image'ında `alembic heads` çalıştırılıp >1 head varsa publish abort ediliyor (3.4.13 felaketi tekrarlanmaz).

---

## [3.4.15] - 2026-05-04

### Düzeltildi / Fixed
- **Dashboard "Yaklaşan Ödemeler" widget'ında sadece gelirler görünüyordu.** Frontend `plannedPaymentsApi.list({ skip: 0, limit: 500 })` çağırıyordu, ama backend endpoint `page` ve `page_size` parametreleri bekliyor (`skip`/`limit` ignore ediliyordu). Sonuç: default `page_size=50` ile sadece ilk 50 kayıt dönüyor, `planned_date ASC` sıralamasında eski/PAID kayıtlar 50'yi doldurup yeni PENDING expense'ler (kredi taksitleri vb.) dışarıda kalıyordu. Sadece INCOME görünüyordu çünkü o tarihte INCOME'lar daha erken sırada
- Çağrı `{ status: 'PENDING', page: 1, page_size: 500 }` olarak düzeltildi: backend artık doğru parametreleri alıyor, sadece bekleyen ödemelerin tümü widget'a giriyor (kredi taksitleri, kredi kartı taksitleri hariç — frontend filter zaten cc taksitleri eliyor)

### Etki
"Yaklaşan Ödemeler" artık hem gelir hem gider birlikte gösteriyor. Enpara/Garanti taksiti gibi yaklaşan kredi ödemeleri bekleyen INCOME'larla aynı listede tarihsel sırada görünür.

---

## [3.4.14] - 2026-05-04

### Düzeltildi / Fixed
- **KRİTİK: Backend başlatma — alembic "Multiple head revisions" hatası.** 3.4.13'te eklediğim `0070_legacy_loan_past_installments_paid.py` migration'ı, zaten var olan `0070_security_perf_indexes.py` ile aynı revision ID'sini aldı (ikisi de `revision="0070"`, `down_revision="0069"`). Alembic çatallaşma gördü, migration'ı reddetti, backend startup loop'unda kaldı, login dahil tüm istekler 502 dönüyordu (kullanıcı şikayeti: "kullanıcı adı şifre doğru ama giriş yapılamıyor")
- Migration `0071_legacy_loan_past_installments_paid` olarak yeniden adlandırıldı (`revision="0071"`, `down_revision="0070"`) — lineer ağaç düzeldi
- 3.4.13 yüklü kurulumlar için acil SSH çözümü: `docker exec umay-backend rm /app/alembic/versions/0070_legacy_loan_past_installments_paid.py && docker restart umay-backend`

### Etki
3.4.13 yükledikten sonra login yapamayan kullanıcılar 3.4.14'e geçince düzelir. Backend startup başarılı olur, eski kredinin geçmiş taksitleri 0071 migration'ı ile PAID olarak işaretlenir.

---

## [3.4.13] - 2026-05-04

### Düzeltildi / Fixed
- **Eski kredinin (is_legacy) geçmiş taksitleri "gecikmiş" gözüküyordu.** Kullanıcı eski bir krediyi sisteme eklediğinde (`is_legacy=True`), `loan_service.create()` tüm taksitleri PENDING olarak yaratıyordu. Sonuç: kullanıcının ZATEN ödediği geçmiş taksitler "Yaklaşan Ödemeler" widget'ında **kırmızı ⚠ gecikmiş** olarak görünüyordu — kanıt: kullanıcının "Enpara Taksit 1/6" (start_date 02.04.2026) bugün (04.05) gecikmiş gözüküyordu, ama eski kredi olduğu için aslında ödenmişti
- `loan_service.create()` artık `is_legacy=True` ise `due_date <= today` olan taksitleri **PAID** olarak yaratıyor. Yeni krediler etkilenmez (her zaman PENDING)
- Migration `0070_legacy_loan_past_installments_paid` eklendi — yayın öncesi oluşturulmuş eski kayıtları geriye dönük düzeltir (idempotent, downgrade no-op)

### Etki
"Yaklaşan Ödemeler" widget'ında artık sadece gerçekten yaklaşan veya yeni gecikmiş taksitler görünür. Eski kredilerin geçmiş taksitleri otomatik PAID — kullanıcı manuel düzeltmek zorunda değil.

---

## [3.4.12] - 2026-05-03

### Değişti / Changed
- **Hızlı Demirbaş modu kaldırıldı.** Bu mod sadece Ötüken'de inventory_item kartı oluşturuyor, **purchase movement oluşturmuyordu** → Ötüken envanter detayında bakiye 0 görünüyordu (test sonucu: `total_received=0, total_remaining=0`). UX tutarsızlık. Artık varlık ekleme formunda iki seçenek var:
  - **Kaydetme** — sadece Umay'a kaydet (Ötüken sync yok)
  - **📋 Detaylı Demirbaş** — tam akış (kart + purchase movement + bakiye=qty)
- Backend `otuken_register_demirbas` field'ı korunuyor (eski sürüm istemcileriyle uyumluluk için ölü kod)

### Düzeltildi / Fixed
- **"Şimdi Güncelle" sonrası "Backend hatası" görüntüsü.** Update progress polling tamamlandığında frontend sabit 8-12 saniye bekleyip sayfayı yeniliyordu. Backend henüz hazır olmadığı için login sayfasında "Backend sunucusuna bağlanılamıyor" görünüyordu. Artık reload öncesi `/api/v1/system/version`'a aktif sağlık kontrolü yapılıyor:
  - Backend 200 OK dönene kadar (max 90s) bekler
  - Her 3 saniyede mesaj güncellenir: "Backend yeniden başlatılıyor… (Xs) — hazır olunca otomatik açılacak"
  - 90s'de hazır olmazsa yine reload yapar (manuel devam imkânı)
  - Sonuç: kullanıcı 502 görmez, geçiş şeffaf

### Test Edildi (lokal)
- ✅ Yeni Varlık formunda sadece "Kaydetme" + "Detaylı Demirbaş" görünüyor
- ✅ Detaylı + qty=1 + ADET → Ötüken'e doğru birim ve bakiye gidiyor (3.4.10 + 3.4.11 fix'leri kalıcı)
- ✅ dispose flow → adjustment_out + deactivate (3.4.11 fix kalıcı)

### Etki
Yeni varlık ekleme akışı netleşti — kullanıcı Hızlı Demirbaş'ın yarım kalan davranışıyla karşılaşmıyor. "Şimdi Güncelle" akışı artık sorunsuz tamamlanıyor. Eski "Hızlı Demirbaş" ile oluşturulmuş asset'ler hâlâ çalışır (backend ayakta), sadece yeni oluşturma yolu kaldırıldı.

---

## [3.4.11] - 2026-05-03

### Düzeltildi / Fixed
- **Demirbaş satıldığında Ötüken'de bakiye düşmüyordu.** `dispose_asset` flow'u sadece `is_active=false` (pasifleştirme) yapıyor, **stok çıkışı (adjustment_out) kaydı oluşturmuyordu**. Sonuç: kullanıcı Umay'dan demirbaşı sattığında, Ötüken envanter detayında item "Pasif" görünüyor ama "Toplam Bakiye: 1, Toplam Çıkış: 0" — kullanıcı "satış belli olmuyor" diyor (kanıtlı: ekran görüntüsü Traktör DMR-002, 1 KG bakiye, 0 çıkış)
- `OtukenStockService`'e iki yeni method eklendi:
  - `list_lots(item_id, only_available)` — item'ın açık lot'larını listeler
  - `create_adjustment_out(...)` — `/api/v1/inventory/adjustments/out` endpoint'ine `HURDAYA_AYRILDI` reason ile çıkış kaydı atar
- `dispose_asset` artık şu sırayla çalışıyor:
  1. `notes`'tan `[OTUKEN_DEMIRBAS:xxx]` veya `[OTUKEN_STOCK:xxx]` ID'lerini çıkar
  2. Her ID için açık lot'ları getir (`list_lots`)
  3. Her lot için kalan miktarı (`quantity_remaining`) çıkış kaydı olarak yaz
  4. Sonra item'ı pasifleştir (`deactivate_inventory_item`)
- Hata olursa warning'lere eklenir, kullanıcıya alert gösterilir (silent fail yok)

### Test Edildi (lokal, kanıtla)
End-to-end test: Detaylı Demirbaş + qty=1 → Otuken `total_remaining=1` → dispose → Otuken `total_remaining=0, movement_out=1.0, is_active=False` ✅

### Ek Bug — `quantity_remaining` field adı
İlk implementasyonda field adı yanlış (`remaining_quantity`) yazılmıştı, lots'tan miktar 0 dönüp adjustment_out hiç tetiklenmiyordu. Otuken API'sinin gerçek field adı `quantity_remaining` (snake_case) olarak düzeltildi.

### Etki
Demirbaş satışı sonrası Ötüken envanter detayında bakiye 0 görünür, çıkış hareketi `HURDAYA_AYRILDI` olarak kaydedilir. Pasifleştirme korunur. Eski kayıtlar (3.4.11 öncesi satılanlar) Ötüken UI'sından manuel adjust_out ile düzeltilebilir.

---

## [3.4.10] - 2026-05-03

### Düzeltildi / Fixed
- **Detaylı Demirbaş — yanlış birim:** Form `otuken_unit_code` default değeri `'KG'` idi ama Detaylı modunun dropdown seçenekleri sadece `ADET/TAKIM/SET`. Kullanıcı dropdown'a dokunmazsa (varsayılan ADET sanmasına rağmen) form state'te `KG` kalıyor ve Ötüken'e `default_unit=KG` olarak yazılıyordu — kanıt: yeni demirbaş "Test_DetayliAuto" Otuken'de `default_unit=KG` olarak kaydedilmişti
- EMPTY_FORM default'u `'ADET'`'e çekildi (AssetsPage'in Detaylı modu sadece DEMIRBAS için, KG hiç anlamlı değil)
- Detaylı moduna geçişte ek koruma: state'teki `unit_code` geçerli liste dışındaysa otomatik `ADET`'e zorlanır (eski kullanıcı state'i de düzelir)

### Etki
Yeni Detaylı Demirbaş kayıtları artık doğru birimle Ötüken'e gidiyor. v3.4.10 öncesi yanlış birimle kaydedilen kayıtlar Ötüken UI'sından manuel düzeltilebilir.

---

## [3.4.9] - 2026-05-03

### Düzeltildi / Fixed
- **KRİTİK: Detaylı Demirbaş'ta sessiz başarısızlık.** Kullanıcı "Detaylı Demirbaş" seçtiğinde **Miktar** alanı boş bırakırsa frontend `parseFloat('') > 0 = false` koşulundan dolayı `otuken_stock_movement` field'ını **hiç göndermiyordu**. Backend ne sync deneyebiliyordu ne hata gösterebiliyordu — varlık sadece Umay'a kaydediliyor, Ötüken'e gitmiyordu. Kullanıcı UI'da "kaydedildi" gördüğü için sorunun farkına varamıyordu.
- **Smart default**: Artık "Detaylı Demirbaş" moduna geçildiğinde miktar otomatik `1` ile başlıyor (tek demirbaş alımları için en yaygın değer; 5 ekipman alındıysa kullanıcı override eder)
- **HTML `required` attribute**: Miktar input'una eklendi → tarayıcı kendi form validasyonu da boşsa submit'i engelliyor
- **Submit-time JS validation**: `mode='demirbas' && !farm_id` veya `mode='stok' && (!farm_id || !quantity>0)` durumlarında submit bloklanıyor, formError gösteriliyor
- Bu üç katmanlı koruma sayesinde kullanıcı bir daha "kaydedildi sandım ama Ötüken'de yok" durumu yaşamaz

### Test Edildi (lokal, kanıtla)
- ✅ Detaylı + yeni demirbaş + auto miktar=1 → Otuken'de `Test_DetayliAuto | DEMIRBAS` oluştu, tag yazıldı
- ✅ Hızlı Demirbaş + farm → Otuken sync başarılı (regresyon kontrolü)
- ✅ Detaylı + mevcut demirbaş + qty → Mevcut karta purchase eklendi
- ✅ Validation: farm seçilmeden submit → blocked + formError görünüyor
- ✅ Validation: qty=0 ile submit → blocked

### Etki
Yeni asset kayıtları artık güvenle Ötüken'e gidiyor. Eski "Solis 26", "Traktör" gibi notes'u boş kalan asset'ler manuel düzeltilmeli (yedekten geri yükleme veya silip Hızlı Demirbaş ile yeniden kayıt).

---

## [3.4.8] - 2026-05-03

### Düzeltildi / Fixed
- **KRİTİK: Varlık kayıt/satışında Ötüken senkron hatası sessizce yutuluyordu.** AssetService'in create ve dispose metodları Ötüken çağrılarındaki exception'ları sadece WARNING log'a yazıp kullanıcıya hiç bilgi vermiyordu. Sonuç: kullanıcı "Hızlı Demirbaş" seçer, asset Umay'a kaydolur, Ötüken'e gitmez, kullanıcı bunu fark etmez. Aynı şekilde satış sırasında da Ötüken pasifleştirmesi başarısız olsa kullanıcı haberdar olmuyordu
- Backend'e `otuken_sync_warnings: list[str]` field'ı eklendi (`AssetResponse` schema'sında). Sync sırasında oluşan her hata bu listeye eklenir, response'da kullanıcıya döner
- Frontend (AssetsPage) create + dispose handler'larında bu warning'leri okuyup alert ile gösteriyor: "⚠️ Ötüken senkronizasyon uyarısı: ..."

### Test Edildi (lokal, kanıtla)
- ✅ Otuken AÇIK + create → warnings=[], notes'a `[OTUKEN_DEMIRBAS:...]` tag yazıldı
- ✅ Otuken KAPALI + create → 1 warning surface etti, mesaj: "Ötüken'e demirbaş kaydedilemedi: [Errno -2]..."
- ✅ Otuken KAPALI + dispose → 1 warning surface etti, mesaj: "Ötüken'de demirbaş pasifleştirilemedi..."

### Etki
Kullanıcı artık Ötüken sync'in başarısız olduğunda derhal görüyor. "Sessiz başarısızlık" ortadan kalktı. Bu sayede kullanıcı ya tekrar deneyebilir ya da Ötüken'i manuel düzenleyebilir — eskiden bu durumdan haberdar olmadan saatlerce yanlış inanışla devam ediyordu.

### Bağlantılı Akış
Asset satışında demirbaşın Ötüken'de pasife düşmesi mevcut akışta var (`asset.notes` içindeki `[OTUKEN_DEMIRBAS:xxx]` tag'i okunur, `deactivate_inventory_item` çağrılır). Ama önceki sürümlerde tag yazılamamış asset'lerde bu çalışmaz; bu fix sayesinde kullanıcı eski kayıtları tespit edip yeniden bağlayabilir.

---

## [3.4.7] - 2026-05-03

### Düzeltildi / Fixed
- **KRİTİK: Backend recreate sonrası nginx upstream cache stale kalıyordu.** Container recreate sonrası yeni container farklı IP alır (`172.29.4.6` → `172.29.4.4`). nginx upstream block'u DNS'i sadece worker startup'ta resolve ettiği için (`resolver valid=10s` upstream block'lara uygulanmaz) eski IP'ye bağlanmaya devam eder → tüm `/api/*` istekleri **502 Bad Gateway**
- `updates.py` artık her container recreate sonrası `nginx -s reload` tetikliyor:
  - `_recreate_container` (frontend/Ötüken için): in-process reload (`docker exec ergenekon-proxy nginx -s reload`)
  - `_schedule_backend_recreate` sidecar (backend self-update için): yeni container hazır olduktan sonra (sleep 8) reload
- Manuel SSH çözümü: `docker exec ergenekon-proxy nginx -s reload`

### Teşhis Süreci
nginx error log'da net görüldü: `connect() failed (111: Connection refused) ... upstream: "http://172.29.4.6:8000/..."` ama `docker inspect umay-backend` IP'sinin `172.29.4.4` olduğunu gösterdi. Reload sonrası 502 → 401'e düştü (yani backend'e ulaşıldı, sadece auth gerekiyor).

### Etki
"Şimdi Güncelle" sonrası kullanıcılar artık birkaç saniye 502 hatası görmeyecek. Sayfa otomatik yenilendiğinde backend cevap verir, login ekranı sorunsuz açılır.

---

## [3.4.6] - 2026-05-03

### Düzeltildi / Fixed
- **Varlık Düzenle butonu ekran karartıyor.** AssetsPage'in edit handler'ı `setForm()`'a sadece 13 alan set ediyordu ama `EMPTY_FORM`'da 18+ alan var (`credit_card_charges`, tüm `otuken_*` alanları). Eksik alanlar undefined kalıp render sırasında `form.credit_card_charges.some(...)` → React tree crash → ekran karartı. Fix: `setForm({ ...EMPTY_FORM, <override'lar> })` — eksik alanlar default değerleriyle doldurulur
- **KRİTİK: Varlık sayfasında çiftlik dropdown'u boş geliyordu.** Container Station bu sefer `OTUKEN_API_KEY`'i drop etmişti. Umay backend Ötüken'e API key'siz istek gönderince Ötüken 401 döndürüyordu, dolayısıyla `/api/v1/integration/otuken/farms` endpoint'i 502 hatası veriyor ve dropdown boş kalıyordu
- Defansif validator'a 5. kural eklendi: `OTUKEN_API_KEY` eksikse `INTERNAL_API_KEY`'den, veya tersi şekilde fallback yapar (YAML'da ikisi aynı değere sahip)
- `INTERNAL_API_KEY` artık Settings field'ı olarak da tanımlandı (önceden sadece env'den okunuyordu)

### Test Edildi
- OTUKEN_API_KEY drop + INTERNAL_API_KEY var → fallback çalıştı ✓
- INTERNAL_API_KEY drop + OTUKEN_API_KEY var → ters fallback çalıştı ✓
- İkisi de var → hiçbiri ezilmedi ✓

### Etki
Varlıklar sayfasından demirbaş alımı yapan kullanıcılar artık çiftlik seçebilir, stok kartı oluşturabilir, Ötüken'e demirbaş kaydedebilir. Bu fix v3.4.5'e güncelleyen kullanıcıları otomatik koruyacaktı ama Container Station yine farklı vars drop etti — bu sürüm o senaryoyu da kapatıyor.

---

## [3.4.5] - 2026-05-03

### Düzeltildi / Fixed
- **KRİTİK: Container Station rastgele env drop'una karşı tam koruma.** v3.4.4'te REDIS_URL ve DATABASE_URL için defansif validator eklenmişti, ama Container Station deterministik değil — başka kurulumda farklı vars (APP_SECRET_KEY, POSTGRES_USER vb.) drop edebiliyor. Yeni validator tüm senaryoları kapsar:
  - **URL'ler** (REDIS_URL, DATABASE_URL): Eksikse parçalardan inşa edilir
  - **External system şifreleri** (POSTGRES_PASSWORD, REDIS_PASSWORD): Eksikse URL'den çıkarılır
  - **Config defaults** (POSTGRES_USER, POSTGRES_DB): Mantıklı default değer
  - **App secret'leri** (APP_SECRET_KEY, JWT_SECRET_KEY): Persistent storage'dan okunur veya generate edilip `/app/storage/.secrets/` altına kaydedilir
- Generate edilen secret'lar persistent volume'da yaşadığı için container recreate'lerinden bağımsız — kullanıcı oturumları korunur
- Test edildi: hiçbir secret env yokken bile backend başarıyla başlıyor

### Etki
Yüzlerce QNAP kurulumunda kullanıcı SSH'a girmeden çalışır. Container Station hangi env'leri drop ederse etsin, backend kendini onarır. Eski 3.4.4 kurulumlar `Şimdi Güncelle` ile bu sürüme geçtiğinde mevcut secret'lar otomatik korunur (env'den) veya kayıp olanlar storage'dan generate edilir.

---

## [3.4.4] - 2026-05-03

### Düzeltildi / Fixed
- **KRİTİK: QNAP Container Station deployment bug'ına karşı koruma.** Container Station 3.x kendi YAML deployment mekanizmasında belirli env vars'ları (REDIS_URL, POSTGRES_DB, APP_NAME, BACKUP_ENCRYPTION_KEY) parse sırasında drop ediyor. Sonuç: Backend default `redis://localhost:6379/0`'a düşüyor → "Backend sunucusuna bağlanılamıyor"
- Backend'e `model_validator` (mode="before") eklendi: `REDIS_URL` veya `DATABASE_URL` eksikse, mevcut parça değişkenlerden (`REDIS_HOST/PORT/PASSWORD`, `POSTGRES_HOST/PORT/DB/USER/PASSWORD`) otomatik inşa edilir
- Compose CLI ile direkt çalıştırıldığında bu drop yaşanmıyor; sorun sadece Container Station'ın UI deployment'ında. Ama defansif kod sayesinde her iki senaryoda da backend doğru bağlanır

### Teşhis Süreci
SSH ile QNAP'ta yapılan testler:
1. `docker inspect umay-backend` → 4 env eksik
2. `docker compose config umay-backend` → Tüm 34 env doğru parse ediliyor
3. `docker compose -p docker-compose up -d --no-deps umay-backend` → Tüm env'ler container'a girdi, backend başarıyla başladı
Bu üç adım sorunun Container Station deployment mekanizmasında olduğunu **kanıtladı** (Compose YAML parse'ı veya YAML'ın kendisi değil).

### Etki
Bu fix QNAP Container Station + Compose-aware orchestrator'lar için kritik. Yüzlerce kuruluma uyumlu, kullanıcı SSH'a girmeden çalışır. Eski kurulumlar `Şimdi Güncelle` ile bu sürüme geçtiğinde otomatik korunur.

---

## [3.4.3] - 2026-05-03

### Düzeltildi / Fixed
- **Umay → Ötüken dropdown'ları (CreditCardsPage & TransactionsPage):** Kredi kartı ve işlemler sayfalarındaki çiftlik/stok/DSI dropdown fetch çağrıları `otukenFetch` helper'ına taşındı — Authorization header artık her zaman gönderiliyor. Önceki plain `fetch()` çağrıları cookie expire olunca dropdown'ları boş bırakıyordu (özellikle Demirbaş, Tohum, DSI ve Stoklu alış kategorilerinde)

---

## [3.4.2] - 2026-05-03

### Düzeltildi / Fixed
- **KRİTİK: "Şimdi Güncelle" Compose stack'i parçalıyordu.** Backend, container'ları yeniden oluştururken Docker Compose label'larını (`com.docker.compose.project`, `com.docker.compose.service` vb.) yeni container'a aktarmıyordu. Sonuç: Container Station label'sız container'ları "ayrı stack" sayıp kendiliğinden yeni bir `entegresistem` veya benzeri stack uyduruyordu — orijinal `ergenekon` stack'inden 4 container eksiliyor, yeni stack'te aynı 4 container farklı ağda görünüyordu (umay-backend → DB'ye ulaşamayıp "Others" durumunda kalıyordu)
- Hem `_recreate_container` (frontend/Ötüken için) hem de `_schedule_backend_recreate` sidecar (backend self-update için) artık tüm container label'larını koruyor

### Etki
Bu fix QNAP Container Station ve diğer compose-aware orchestrator'larda kritik. Düzeltme öncesi "Şimdi Güncelle" basıldığında stack fragmente oluyor ve sistem çalışmaz hale geliyordu.

---

## [3.4.1] - 2026-05-03

### Düzeltildi / Fixed
- **Eski Kredi**: anapara yazılınca masraf otomatik olarak anaparayla eşit oluyordu (form.disbursed_amount alanı gizli olduğu için 0 sayılıp `fees = principal - 0` hesaplanıyordu). Artık eski kredide masraf hep 0
- **Aynı bankadan ikinci kredi**: backend `lender_name + group_id` ikilisini benzersiz sayıyordu — aynı bankadan farklı amaçlı 2. kredi açılamıyordu. Artık kontrol `lender_name + loan_purpose + group_id` üçlüsünde — aynı bankadan farklı amaçlı krediler açılabilir
- **Umay → Ötüken çiftlik/stok dropdown'ları**: Plain `fetch()` çağrıları Authorization header göndermiyor, sadece Ötüken cookie'sine (1 saat TTL) bağımlıydılar. Cookie expire olunca dropdown'lar boş kalıyordu (özellikle Demirbaş, Tohum, DSI gibi Arazi kategorilerinde). Yeni `otukenFetch` helper'ı Umay JWT'sini Bearer header olarak otomatik ekliyor — cookie state'inden bağımsız çalışıyor

### Eklendi / Added
- `umay/frontend/src/lib/otukenFetch.ts` — Ötüken API'sine yapılan tüm fetch çağrıları için ortak yardımcı (Authorization header otomatik eklenir)

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
