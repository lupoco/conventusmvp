# conventity.com — bootstrap durumu

Kaynak: "CONVENTITY.COM — BOOTSTRAP NOTU". Bu dosya nerede durulduğunu ve
sıradaki adımın tam girdisini tutar.

## §0 — İzolasyon (ihlal edilmedi)

- `lupoco/conventityme`'ye **hiçbir commit atılmadı**; oradan yalnız okundu.
- Mevcut (`.org`) Supabase'e **hiçbir SQL çalıştırılmadı**.
- 147 org / convexus / matching **verisi taşınmadı** (şema bile henüz yok).
- Frontend kopyalandı, yeniden yazılmadı.

## §1 — Repo · TAMAM

`conventityme` çalışma ağacı (`.git` hariç) olduğu gibi kopyalandı:
67 HTML + `/assets` + `/platforms` + `/admin` + `/dashboard` + `/legal` +
`/docs` + `/sql` + `/supabase` + `.htaccess` + `shared.css`.

**Launch nav'ından çıkarılanlar** (dosyalar duruyor, yalnız erişim kapandı —
hepsi "Yakında / Soon" rozetiyle kilitli):

| Sayfa | Nerede kilitlendi |
|---|---|
| `conventus/go-and-meet.html` | `core.html` launch listesi; hub hero CTA → `go-and-test.html` |
| `conventus/gm-provider.html` | `core.html`; hub "Service Provider" kapısı; `start.html` Provider kapısı; `cv-core.js` `homeFor('vendor')` |
| `conventus/product-studio.html` | `core.html`; hub "Product Studio" kartı |
| `conventus/settings.html` | `core.html`; hub "Full settings" linki → kök `/settings.html` |

**Döngü sayfaları duruyor:** `index`, `communities`, `community`, `event-studio`,
`my-events`, `my-event`, `register-conventus`, `applications`, `agenda`,
`programme`, `announcements`, `gm-plan`, `handbook` (+ `go-and-test`, `new-event`,
`event-manage`, `start`).

**`Admin_dc.html` → stub:** bu depoda `Admin_dc.html` diye bir dosya **yok**.
Aynı konsolidasyon başka adla zaten yapılmış: `platforms/conventus/overview.html`
artık `event-studio.html`'e yönlendiren bir stub ("Consolidated into
event-studio.html"). Yeni bir dosya uydurulmadı. Bootstrap notundaki
`my-event_dc.html` de burada `platforms/conventus/my-event.html`.

## §2 — Config seam · TAMAM (değerler dolu)

`/assets/js/cv-config.js` tek kaynak. 66 HTML sayfasının `<head>`'ine, diğer
**tüm** JS'ten önce eklendi (67. dosya `docs/conventus-architecture.html`'in
`<head>`'i ve JS'i yok).

Gömülü kimlik bilgisi taşıyan **33 dosya** rewire edildi; depoda
`shbwylrwpioqypbdhjgn` ve `sb_publishable_…` literali **kalmadı**.

`cv-core.js` artık URL/key'in kendi kopyasını tutmaz; `cvClient()` seam
yüklenmemişse `null` döner ve konsola yazar. `cv-config.js` yer tutucu
değerleri görürse sayfanın üstüne kırmızı bir uyarı şeridi basar — sessiz
düşme yok.

Bağlı proje: **`conventity-prod`** · ref `tstlireeidnpchadgjly` ·
`https://tstlireeidnpchadgjly.supabase.co`. Publishable anon key dolu;
`sb_secret_…` bu repoya **hiç girmez**.

## §3 — Temiz Supabase

- [x] Supabase → New project (**"conventity-prod"**) açıldı.
- [x] `ref` + publishable anon key `/assets/js/cv-config.js`'e yazıldı.
- [x] Auth → URL Configuration yapıldı (Site URL + iki redirect).
- [x] **Keşif:** `sql/01_dump_org_schema.sql` `.org`'da çalıştırıldı; `public`
      şeması döküldü (74 tablo, 10 view, 60+ fonksiyon, 130+ politika).
      Salt okunur tek `select` — hiçbir şey değişmedi, veri dökülmedi.
      *Neden gerekliydi:* `conventity_orgs · people · roles · activities ·
      conventus_managed_events · conventus_registrations` gibi temel tabloların
      ilk `create table`'ı bu depoda **yok** (`sql/` yalnız migration tutuyor).
      Koddan tahmin edilseydi kolon tipleri/CHECK'leri yanlış çıkardı —
      "discovery before DDL".
- [ ] **Temiz kurulum SQL'i:** döküm CSV'si `scripts/dump-to-clean-install.py`
      ile `sql/02_clean_install.sql`'e çevrilir (elle yazılmaz — 300 KB DDL'de
      transkripsiyon hatası kaçınılmaz).
      Dönüştürücü ne yapar: kısıt/FK → katalog kontrollü `do` döngüsü ·
      `create index` → `if not exists` · trigger/politika → önce
      `drop ... if exists` · `create type` → `duplicate_object` yutulur ·
      ~1100 grant satırı → tek döngü · 74 `enable row level security` → tek
      döngü · view'lar bağımlılık sırasına dizilir (alfabetik sıra
      view-üstüne-view'da kırılıyor) · **hiçbir `insert` üretilmez**.
      Doğrulama: `scripts/verify-clean-install.sh` — yerel PostgreSQL 16'da
      boş şemaya 3 kez çalıştırır, envanteri sayar, tek satır veri yazılmadığını
      kanıtlar.
- [x] **`sql/02_clean_install.sql` üretildi ve doğrulandı** (3675 satır).
      Envanter: 73 tablo · 10 view · 61 fonksiyon · 314 kısıt · 183 indeks ·
      202 politika · 30 trigger · RLS kapalı tablo 0 · veri 0 satır.
      Sayılar dökümle birebir tutuyor.
      `scripts/smoke-mvp-loop.sql` ile döngü de denendi: ekosistem admin →
      LANDCOM topluluğu → `conventus_create_managed_event` (omurgaya
      `conventity_activities` satırı da yazıldı) → kayıt → trigger'lar
      (kayıt olayı, rol olayı, denetim kaydı) → **yetkisiz kullanıcı RLS'e
      takıldı.**
- [x] **`sql/02_clean_install.sql` conventity-prod'da çalıştırıldı** —
      73 tablo kuruldu, doğrulandı.
- [x] **Sayfa ↔ şema kontrolü:** launch kapsamındaki 30 sayfanın çağırdığı
      25 tablo/view ve 5 RPC'nin hepsi şemada var
      (`scripts/check-page-schema-refs.py`).
- [x] *(kapatıldı)* `02_clean_install.sql` ilk denemede `.org` sekmesinde
      çalıştı; idempotent olduğu için sessizce "Success" dedi ve hiçbir şey
      yapmadı — kurulum yapıldı sanıldı.
      *Tuzak:* iki proje açıkken sekmeler karışıyor. Dosya idempotent olduğu
      için `.org`'da çalıştırılırsa sessizce "Success" der ve hiçbir şey
      yapmaz — kurulum yapıldı sanılır. Bu yüzden dosyanın başına
      **yanlış proje koruması** eklendi: `convexus_profiles`,
      `conventity_orgs` ya da `conventus_selection_assessments` 100+ satır
      taşıyorsa hiçbir şey yazmadan durur ve doğru projenin linkini verir.
      Doğru ref: **tstlireeidnpchadgjly** (yanlış: shbwylrwpioqypbdhjgn).

SQL sırası (bu repoda henüz **yok**):

1. **Boş omurga DDL — seed INSERT'siz.** `sql/00_introspect_v2.sql` ile `.org`
   şemasından introspect; DDL'i al, 147 org / demo veri INSERT'lerini **atla**.
   MVP'nin gerçekten ihtiyacı: `conventity_orgs`, `conventity_activities`,
   `conventity_roles`, `conventity_is_admin(text)`. Şüphede kalınırsa tüm şema
   boş kurulur (tablo ucuz), yalnız seed atlanır.
2. **`conventus_mvp_foundation.sql`** (roadmap v2 §2): LANDCOM seed + etkinlik
   bağı + rol genişletme + 2 yetki fonksiyonu + `gm_providers`/`gm_offers`
   (temiz DB'de yok → `create table if not exists`, v2'deki `alter`'lar
   `create`'e döner) + `service_requests` + RLS + doğrulama SELECT.
3. Doğrulama SELECT çıktısı paylaşılır: LANDCOM + 5 otel + 1 acente + boş
   omurga tabloları.

SQL kuralları (depo standardı): idempotent · `IF NOT EXISTS` · `text + CHECK`
(enum yok) · `source_ref` idempotency anahtarı · her insert `NOT EXISTS`
guard'lı (SQL Editor tek transaction — bir satır patlarsa hepsi rollback) ·
`ALTER TABLE ... ADD COLUMN` sonrası `notify pgrst, 'reload schema';`

## §4 — İlk admin (chicken-egg) · TAMAM

`serkancopul@gmail.com` → `ecosystem/admin/active`, `auth_user_id` dolu
(RLS'te etkili). Aşağıdaki adımlar kayıt için duruyor.

1. **Hesabı aç.** Supabase → Authentication → Users → **Add user** →
   e-posta + parola (*Auto Confirm User* açık). Alternatif: local'de
   uygulamadan sign up.
2. **`sql/03_bootstrap_owner.sql`**'i conventity-prod SQL Editor'ünde çalıştır.
   uid'i e-postadan kendisi bulur — elle kopyalama yok. Tekrar
   çalıştırılabilir. Üç şey yapar: kurulumu sayar, `conventity_roles`'a
   `ecosystem/admin/active` satırını `NOT EXISTS` guard'lı yazar, sonucu
   `rls_de_etkili` kolonuyla doğrular.
3. `auth_user_id` boşsa rol RLS'te etkisizdir — doğrulama sorgusu bunu gösterir.

Sonrasında `core.html` → Topluluklar'dan LANDCOM kurulabilir, etkinlik
yöneticisi atanabilir.

## Erişim talepleri (§6 ile birlikte)

"Yakında" sayfasındaki form → `conventity_access_requests` → core.html
"Erişim talepleri" sekmesi.

Kurulum: **`sql/04_access_requests.sql`**'i conventity-prod'da çalıştır.
(Yanlış proje koruması var; tekrar çalıştırılabilir.)

Güvenlik sınırı — form site parolasının ÖNÜNDE çalıştığı için yazma yetkisi
`anon` rolünde olmak zorunda; sınırı RLS çiziyor:

| Deneme | Sonuç |
|---|---|
| Geçerli talep bırakma | ✅ kabul |
| `status='invited'` yazma | ❌ RLS reddetti |
| Başkasının talebine `note` düşme | ❌ RLS reddetti |
| Talepleri okuma | ❌ yetki yok |
| Bozuk e-posta | ❌ CHECK reddetti |
| Aynı e-postayla ikinci açık talep | ❌ tekil indeks reddetti |
| 1000+ karakter açıklama | ❌ CHECK reddetti |
| Ekosistem admin okuma/güncelleme | ✅ |
| Admin olmayan giriş yapmış kullanıcı | 0 satır görüyor |

Testler: `scripts/test-access-requests.sql` (RLS),
`scripts/test-access-form.mjs` (form davranışı),
`scripts/test-core-access-panel.mjs` (konsol paneli).

**Dikkat:** `02_clean_install.sql`, `.org`'un yapılandırmasını birebir taşıdığı
için public'teki tüm tablolara `anon` dahil üç role de tam yetki veriyor ve
`alter default privileges` yüzünden yeni tablolar da aynı yetkiyi otomatik
alıyor. `04` bu tabloda yetkiyi açıkça geri alıyor. Genel sertleştirme
(`anon`'dan gereksiz yetkileri toplu geri alma) ayrı bir iş — `.org`'daki
"RLS sertleştirme" açık işiyle aynı sınıf.

## §6 — Deploy · ŞU AN BURADA

### Kapalı test kilidi (yayına çıkana kadar)

İki ayrı katman:

| Katman | Ne yapar | Nerede |
|---|---|---|
| **Site parolası** | Ortak kullanıcı adı/parola. Bilmeyene hiçbir sayfa açılmaz, arama motoru giremez. | `.htaccess` (Apache Basic Auth) |
| **Hesap girişi** | Site parolasından sonra kendi Supabase hesabınla oturum. Yetkiyi RLS belirler. | Supabase Auth |

Parolayı bilmeyen ya da iptal eden `under-construction.html`'i görür
(`ErrorDocument 401/403`) — tarayıcının çirkin hata sayfası yerine markalı
"Çalışma altında" ekranı. O sayfa auth'suz servis edilmek zorunda olduğu için
**tek dosya**: `/assets`'e hiç bağımlı değil (aksi halde 401 döngüsü).

`robots.txt` → `Disallow: /`, ayrıca `.htaccess`'te
`X-Robots-Tag: noindex, nofollow, noarchive`.

**Kurulum (Hostinger hPanel):**
1. Websites → conventity.com → GitHub bağlantısı: `lupoco/conventusmvp`, dal `main`.
   Hedef dizin `.org`'unkinden **ayrı** olmalı.
2. Gelişmiş → **Dizin Şifreleme** (Password Protect Directories) → `public_html`
   → kullanıcı adı + parola. hPanel `.htpasswd`'yi kendi üretir.
   *(Elle kurulum istenirse `.htaccess`'teki `AuthType/AuthUserFile/Require`
   satırlarının yorumu kaldırılıp `AuthUserFile` yolu gerçek mutlak yolla
   değiştirilir.)*
3. Test: gizli sekmede `https://conventity.com` → parola sorulmalı; iptal
   edince "Çalışma altında" ekranı çıkmalı.

**Yayına çıkarken:** `.htaccess`'teki "KAPALI TEST KİLİDİ" bloğunu sil,
`robots.txt`'i güncelle.

## §6 — Deploy (genel)

Hostinger'da `conventity.com` **ayrı** bir dizine/siteye bağlanır (`.org`'un
hedefine değil). `lupoco/conventusmvp` → `main` → conventity.com. Döngü yeşil
olana kadar yalnız local.
