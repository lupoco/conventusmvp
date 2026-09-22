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
- [ ] **Sıradaki (Serkan):** `sql/02_clean_install.sql`'i **conventity-prod**
      SQL Editor'ünde çalıştır.

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

## §4 — İlk admin (chicken-egg)

1. Serkan local'de uygulamadan sign up olur.
2. `select id, email from auth.users;` → uid.
3. ```sql
   insert into conventity_roles (auth_user_id, scope, role, status, note)
   values ('<serkan-uid>', 'ecosystem', 'admin', 'active', 'bootstrap owner')
   on conflict do nothing;
   ```

`auth_user_id` boşsa rol RLS'te etkisizdir.

## §6 — Deploy

Hostinger'da `conventity.com` **ayrı** bir dizine/siteye bağlanır (`.org`'un
hedefine değil). `lupoco/conventusmvp` → `main` → conventity.com. Döngü yeşil
olana kadar yalnız local.
