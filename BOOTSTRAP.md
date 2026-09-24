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

## Yetki sertleştirme — `sql/05_harden_grants.sql`

`02_clean_install.sql`, `.org`'un yapılandırmasını birebir taşıdığı için
public'teki **her tabloya ve her view'e** `anon` dahil üç role de tam yetki
veriyor (`grant all`); `alter default privileges` yüzünden yeni tablolar da
aynı yetkiyi otomatik alıyor. `04` yalnızca kendi tablosunda yetkiyi geri
alıyordu; genel sertleştirme bu dosyada.

**Bu teorik bir risk değildi — yerelde üretip doğruladım.** `public` şemasındaki
10 view `security_invoker=off` ve sahibi `postgres`, yani taban tablonun
RLS'ini atlıyor. Okuma tarafında bu kasıtlı (kamuya açık vitrinler). Ama üçü
aynı zamanda otomatik-güncellenebilir:

- `gm_providers_public`
- `convexus_demand_signals_public`
- `conventus_selection_verification_status`

`anon` bunlarda `UPDATE`/`DELETE` yetkisine sahip olduğu için taban tablodaki
satırları **RLS hiç devreye girmeden** değiştirip silebiliyordu. PostgREST
view'leri de endpoint olarak açtığından bu, internetten anon anahtarıyla
erişilebilir bir açıktı.

Öncesi/sonrası kanıtı (`scripts/test-harden-grants.sh`):

| Deneme (anon) | 05 öncesi | 05 sonrası |
|---|---|---|
| `gm_providers_public` SELECT (vitrin) | ✅ | ✅ |
| `conventus_managed_events` SELECT | ✅ | ✅ |
| `conventity_access_requests` INSERT (form) | ✅ | ✅ |
| `gm_providers_public` UPDATE → taban tablo | ✅ **geçti** | ❌ yetki yok |
| `gm_providers_public` DELETE → taban tablo | ✅ **satır silindi** | ❌ yetki yok |

`05` **SELECT'e dokunmuyor** — okuma sınırını RLS ve definer view'ler çiziyor,
mevcut durum kasıtlı (`04`, `conventity_access_requests`'te `anon`'a SELECT'i
bilerek hiç vermiyor; oraya blanket `grant select` eklemek onu geri açardı).
Sertleştirme sonrası `anon` yetki matrisi: 73 tabloda `SELECT`, 10 view'de
`SELECT`, ve yalnız politikayla izin verilmiş 7 tabloda `INSERT`
(`conventity_access_requests`, `conventus_selection_app_criteria`,
`conventus_selection_app_needs`, `conventus_selection_applications`,
`conventus_selection_materials`, `convexus_activity_records`,
`convexus_engagement_requests`). `UPDATE`/`DELETE`/`TRUNCATE`/`REFERENCES`/
`TRIGGER` hiçbir yerde yok.

Çalıştırma sırası: **02 → 04 → 05**. `02`'yi her yeniden çalıştırdığında `04`
ve `05`'i de tekrar çalıştır (02 yetkileri geri açıyor). Geri alma:
`sql/05_harden_grants_ROLLBACK.sql` — ardından `04`'ü tekrar çalıştır,
çünkü rollback her tabloya `grant all` verip `04`'ün revoke'unu da siliyor.

> **Aynı açık canlı `.org` sitesinde de var.** Şema oradan kopyalandı; view'ler,
> yetkiler ve `alter default privileges` aynı. `.org`'da `05`'i olduğu gibi
> çalıştırma (yanlış proje koruması zaten durdurur) — orası için ayrı bir
> sürüm gerekiyor, `.org`'un "RLS sertleştirme" açık işiyle birlikte.

**Kalan açık iş:** `authenticated` rolü de her tabloda `TRUNCATE`/`REFERENCES`/
`TRIGGER` yetkisine sahip. `TRUNCATE` RLS'i tamamen atlar. PostgREST bu
komutları doğrudan açmadığı için pratik erişim yolu görünmüyor; yine de
gereksiz. View'lerde `authenticated`'ın yazma yetkisi `05` ile kaldırıldı.

## LANDCOM Konferansı 2026 — ilk dikey dilim

Kurulum: **`sql/08_landcom_conference.sql`** → LANDCOM topluluğu + konferans +
omurga bağı (`conventity_activities`) + sahibe `community/owner` rolü.
Tekrar çalıştırılabilir; mevcut kaydı **ezmez** (arayüzden düzenlediğini bozmaz).

Yeni kod yazılmadı — Conventus etkinlik makinesi `.org`'dan taşındı ve
çağırdığı her şey şemada var. Şema iki katılım yolunu zaten destekliyor:

| Yol | Nasıl | Politika |
|---|---|---|
| **Başvuru** | aday kendi kaydını açar, organizatör onaylar | `reg_self_insert_open` (yalnız `registration_open=true` iken) |
| **Davet** | organizatör `event-manage` → "adına kayıt" (tekli/toplu) | `reg_manager_insert` (`registered_by = auth.uid()`) |

Etkinlik ayarı: `visibility='public'` · `invite_only=false` ·
`requires_approval=true` · `waitlist_enabled=true` · kontenjan 150.

Duman testi `scripts/smoke-landcom-conference.sql` — 8 senaryo, tekrar
çalıştırılabilir: aday başvurur · yalnız kendi kaydını görür · ilgisiz
kullanıcı hiçbir şey görmez · yabancı onaylayamaz · organizatör görür ve
onaylar · davet yoluyla adına kayıt açılır · kayıt kapanınca başvuru
reddedilir · omurga bağı duruyor.

> **Bilinmesi gereken davranış:** `conventus_managed_events` üzerinde
> `cme_visibility_gate` RESTRICTIVE, permissive tarafta ise dışarıya açık tek
> politika `events: public read open` ve o `registration_open=true` istiyor.
> Yani **kayıt kapandığı anda etkinlik ilgisiz kullanıcılara tamamen görünmez
> oluyor** — sadece başvuru kapanmıyor, ajanda/duyuru sayfası da kayboluyor.
> `.org`'dan gelen davranış; konferans için muhtemelen istenmeyen bir şey.
> Değiştirmek ayrı bir iş (yeni bir permissive SELECT politikası yeter).

## Test takımı — tek komut

```bash
scripts/test-all.sh
```

SQL testleri · yetki sertleştirme öncesi/sonrası · anon okuma regresyonu ·
politika fonksiyonlarının anon'a açık olup olmadığı · sayfa↔şema kontrolü ·
JS sözdizimi + bütünlük · tarayıcı testleri. Çıkış kodu 0 = hepsi yeşil.

**Bakım kuralı:** `07_harden_functions.sql` beyaz listeyi `pg_policies`ten
türetir. 07'den sonra eklenen bir politika **yeni** bir fonksiyon çağırırsa o
fonksiyon anon'da kapalı kalır ve ilgili okuma
`permission denied for function …` ile patlar. Yeni politika eklediğin her
migration'dan sonra **07'yi tekrar çalıştır**; `test-all.sh` bunu ayrı bir
adım olarak sınıyor.

## SQL sırası — CANLIDA TAMAM (2026-09-23)

`conventity-prod` (`tstlireeidnpchadgjly`) üzerinde çalıştırıldı ve doğrulandı:

| Dosya | Ne yapar | Durum |
|---|---|---|
| `02_clean_install.sql` | boş omurga + Conventus/Convexus/Connectus şeması | ✅ |
| `03_bootstrap_owner.sql` | ilk ekosistem admini | ✅ |
| `04_access_requests.sql` | erişim talebi tablosu + RLS | ✅ |
| `05_harden_grants.sql` | anon'un tablo/view yazma yetkileri | ✅ |
| `06_pending_members.sql` | bekleyen kayıtlar RPC'leri | ✅ |
| `07_harden_functions.sql` | anon'un fonksiyon yetkileri | ✅ |

`07` canlı doğrulaması: **64 fonksiyon · anon 12 · politika bekçisi 12 ·
açıkta kalan 0 · authenticated 64.**

Sayfa ↔ şema kontrolü (`scripts/check-page-schema-refs.py`): launch
kapsamındaki **30 sayfanın** çağırdığı 26 tablo/view ve 7 RPC'nin hepsi
şemada var. Yani Conventus etkinlik sayfalarının tesisatı hazır — eksik olan
tek şey veri.

## Fonksiyon yetkileri — `sql/07_harden_functions.sql`

`06` çalıştıktan sonra doğrulama çıktısı `anon=X/postgres` gösterdi: ekosistem
yöneticisine özel iki fonksiyonu `anon` da çağırabiliyordu. `06`'daki
`revoke all ... from public` bir role **doğrudan** verilmiş yetkiyi kaldırmaz,
Supabase ise `alter default privileges ... grant all on functions to anon` ile
geliyor. Yani `public` şemasında açılan her fonksiyon anon'a açık doğuyordu.

`06` için sızıntı değildi (gövdenin ilk satırı admin kontrolü) ama aynı
varsayılan başka fonksiyonlarda ciddiydi: iç yetki kontrolü **olmayan** 9
SECURITY DEFINER fonksiyon var ve definer oldukları için RLS'i atlıyorlar —
`connectus_directory`, `connectus_org_detail`, `connectus_post_comments`,
`convexus_import_pool_to_event`, `conventus_clone_rating_dims`,
`conventus_sel_clone_default_form` ve üç boolean yardımcı. PostgREST
fonksiyonları `/rest/v1/rpc/<ad>` olarak açtığı için bunlar internetten anon
anahtarıyla çağrılabiliyordu. (Şema boş olduğu için eldeki veri yoktu.)

**İki tur sürdü, ikisini de test yakaladı:**

1. Yalnız `anon`dan geri aldım — hiçbir şey değişmedi. PostgreSQL fonksiyonlara
   varsayılan olarak `PUBLIC`'e de EXECUTE veriyor, `anon` onu rol olarak
   devralıyor. İki kanal da kapatılmalı.
2. `PUBLIC`'i de kaldırınca `conventus_managed_events` okuması
   `permission denied for function is_cv_admin` ile patladı. Meğer **RLS
   politikasının içindeki fonksiyon, sorguyu atan rolün yetkisiyle çalışıyor.**
   İlk testimde bunu kaçırmıştım: yalnız `anon`dan almıştım, `PUBLIC` durduğu
   için politika çalışmaya devam etmiş ve testi yanıltmıştı.

Çözüm: beyaz liste elle yazılmıyor, **`pg_policies`ten türetiliyor** — adı
herhangi bir politika ifadesinde geçen fonksiyonun EXECUTE'u korunuyor.
Politikalar değişince liste kendiliğinden güncelleniyor.

Sonuç: anon 63 fonksiyondan **12**'sini çağırabiliyor, hepsi boolean/uid
döndüren kapı bekçisi (`conventity_is_admin`, `can_manage_*`,
`cn_is_group_member`, …); veri kümesi döndüren hiçbiri yok.

| Deneme (anon) | 07 öncesi | 07 sonrası |
|---|---|---|
| `connectus_directory(5)` | ✅ çalıştı | ❌ yetki yok |
| `convexus_import_pool_to_event()` | ✅ çalıştı | ❌ yetki yok |
| `conventity_pending_members()` | ❌ (iç kontrol) | ❌ yetki yok |
| `gm_providers_public` SELECT | ✅ | ✅ |
| `conventus_managed_events` SELECT | ✅ | ✅ |
| `conventity_access_requests` INSERT | ✅ | ✅ |

Regresyon: anon'un SELECT yetkisi olan **83 tablo/view'in hepsi** hatasız
okunuyor (`scripts/test-anon-read-regression.sql`), `04`/`05` testleri 10/10,
`06` testleri 8/8. Geri alma: `sql/07_harden_functions_ROLLBACK.sql`.

## Bekleyen kayıtlar — `sql/06_pending_members.sql`

Kapalı testte kayıt olmak tek başına erişim vermiyor: `conventity_is_member()`
fail-closed, rolü ya da `conventity_people` kaydı olmayan hesabı içeri almıyor.
Yöneticinin kimin kayıt olduğunu görebileceği yer yoktu (`auth.users` istemciye
kapalı, öyle kalmalı). İki admin-only RPC + `core.html` → **Bekleyen kayıtlar**
sekmesi bunu kapatıyor. Onay tek tıkla kişi + rol kaydı açıyor.

Testler: `scripts/test-pending-members.sql` (8 senaryo),
`scripts/test-core-pending-panel.mjs` (sahte RPC ile tarayıcı).

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
