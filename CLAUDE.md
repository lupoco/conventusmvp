# CLAUDE.md — Conventity (.com · conventusmvp)

Bu dosya depo kökündedir ve Claude Code tarafından otomatik okunur.
**Çalışma dili: Türkçe** (iç/teknik). Dış belgeler İngilizce.

---

## İZOLASYON — İHLAL ETME

Bu repo `conventity.com` için **temiz kurulumdur**. `conventity.org`
(`lupoco/conventityme` + oradaki Supabase projesi) **çalışma alanı olarak
kalır ve dokunulmaz.**

- ❌ `lupoco/conventityme`'ye commit/push YOK. Oradan yalnız okunur.
- ❌ `.org` Supabase projesine SQL YOK. Bu repo ayrı, boş bir projeye bağlanır.
- ❌ 147 org / convexus / matching verisi taşınmaz. Boş omurga şeması +
  MVP seed yeter; gerisi ihtiyaç oldukça.
- ✅ Frontend `.org`'dan kopyalandı (iyi durumda) — yeniden yazma.

Nerede durulduğu: [`BOOTSTRAP.md`](BOOTSTRAP.md).

---

## Proje

Conventity = NATO inovasyon ekosisteminin **unclass orkestrasyon + ekosistem-hafıza katmanı**. Köprü, superset değil.
Altı platform (Convexus · Conventus · ConventLab · Connectus · Consultus · Convergens) tek omurgaya oturur.

**Çekirdek döngü (canlı, çalışıyor):**
```
Problem (talep sinyali)
  -> Eşleştirme (kural-tabanlı, açıklanabilir skor)
  -> Karar (kısa liste / iletişim / elendi / angaje)
  -> Faaliyete davet (conventity_participation)
  -> Kanıt (conventity_evidence, append-only)
  -> Taşınabilir doğrulama (verified.html?s=<slug>)
```

Prensipler: **omurga önce · discovery before DDL · correctness over speed · RLS gerçek sınır · AI önerir, insan karar verir.**

---

## Depo yapısı (gerçek)

```
/                              kök = Hostinger public_html
  core.html                    ekosistem yönetim konsolu (11 sekme) ← ana çalışma dosyası
  verified.html                kamuya açık kanıt sayfası (?s=<slug>)
  verified-directory.html      kamuya açık doğrulanmış yetenekler vitrini
  index.html  login.html  register.html  forgot-password.html  settings.html
  convexus-selection-setup.html   convexus-selection-apply.html   sel-event-setup.html
  shared.css   favicon.svg   README.md   BOOTSTRAP.md
  admin/       dashboard/     assets/
  assets/js/cv-config.js       ortam yapılandırması — TEK KAYNAK (URL + anon key)
  platforms/
    conventus/   index overview event-studio new-event my-events my-event applications
                 event-manage go-and-test go-and-meet gm-plan gm-provider product-studio
                 communities community community-admin programme agenda announcements
                 handbook register-conventus register settings cv-skin.js support.js
    convexus/    index new convexus-engagement convexus-engagement-triage settings
    convergens/
```

**Deploy:** `main` push → Hostinger. Site: `conventity.com` (`.org`'dan **ayrı**
hedef; döngü yeşil olana kadar yalnız local).
**Yollar root-absolute olmalı** (`/platforms/conventus/x.html`), göreli değil.

---

## Stack kuralları (ihlal etme)

- **Vanilla HTML/CSS/JS.** React yok, Tailwind yok, build adımı yok. Tek dosya sayfalar.
- **Ortam TEK KAYNAK: `/assets/js/cv-config.js`.** Supabase URL + publishable
  anon key **yalnız** burada durur; hiçbir sayfa/asset bunları kendi içine
  gömmez. Her sayfanın `<head>`'inde, diğer TÜM JS'ten önce include edilir:
  `<script src="/assets/js/cv-config.js"></script>`. Yer tutucu kalmışsa
  sayfanın üstüne kırmızı uyarı şeridi basar — sessiz düşme yok.
- Supabase JS v2 CDN'den. Paylaşımlı client: `window.__cvSb` (varsa kullan, yoksa kur);
  URL `window.__CV_SUPABASE_URL`, anahtar `window.__CV_ANON_KEY` (ikisi de cv-config'ten).
- **Paylaşılan çekirdek: `/assets/cv-core.js`** (cv-config.js ve supabase-js CDN'inden SONRA include et). Sağladıkları: `cvClient()` (tek client), `cvIsMember()`/`cvGuardMember()` (fail-closed üyelik guard'ı — kopyalama), `CV.roles`/`CV.scopes`/`CV.partRoles`/`CV.homeFor()` (rol/scope TEK KAYNAK). Yeni sayfa yazarken client bootstrap'ı ve üyelik guard'ını elle kopyalama — cv-core kullan.
- **Native date input yasak** — DD.MM.YYYY maskeli giriş kullan.
- `localStorage` her zaman try/catch içinde (`lsGet`/`lsSet` yardımcıları var) — engellenmiş tarayıcıda script'i öldürüyordu.
- Sürüm rozeti: `<span class="ver">vX.Y</span>` — her deploy'da artır, önbellek teşhisi için kritik.

## Supabase

**Yeni, temiz proje: `conventity-prod`** (ref `tstlireeidnpchadgjly`).
URL + publishable anon key **yalnız** `/assets/js/cv-config.js` içinde durur;
başka hiçbir yere yazılmaz. `sb_secret_…` bu repoya hiç girmez.

```js
window.__CV_SUPABASE_URL = 'https://tstlireeidnpchadgjly.supabase.co';
window.__CV_ANON_KEY     = 'sb_publishable_…';
```

anon key publishable → istemcide durması normal, sızıntı değil. Gerçek sınır RLS.

**Şema henüz kurulmadı.** Aşağıdaki omurga/yetki kuralları `.org`'dan taşınan
sözleşmedir; `conventus_mvp_foundation.sql` çalıştırıldığında geçerli olur
(sıra: `BOOTSTRAP.md` §3).

**Omurga tabloları:** `conventity_orgs · people · roles · problems · capabilities · solutions · activities · participation · evidence · matches` (+ ilişki tabloları)

**Yetki — TEK KAYNAK: `conventity_roles`.**
- `conventity_is_admin(p_scope text)` → Core'un kapısı, `p_scope='ecosystem'`
- `is_convexus_admin()` / `is_cv_admin()` → gövdeleri `conventity_roles`'tan
  okur (`.org`'da böyle düzeltildi; temiz kuruluma da böyle gelir).
- `convexus_admins` / `cv_admins` → **kurulmaz**. `.org`'da devre dışı yedekti;
  burada hiç yaratma.
- Rol kaydının çalışması için `auth_user_id` DOLU olmalı; boşsa RLS'te etkisizdir (arayüz kırmızı "etkisiz" etiketiyle uyarır).

**SQL kuralları:** idempotent · `IF NOT EXISTS` · `text + CHECK` (enum yok) · `source_ref` evrensel idempotency anahtarı · her insert `NOT EXISTS` guard'lı (SQL Editor tek transaction çalıştırır; bir satır patlarsa **hepsi rollback olur**).
`ALTER TABLE ... ADD COLUMN` sonrası → `notify pgrst, 'reload schema';` (yoksa PostgREST kolonu görmez).

---

## Tasarım sistemi (v6)

Instrument Serif (display) · Manrope (gövde) · JetBrains Mono (etiket/mono)
cream `#F5F2EC` · navy `#0E2148` · Conventus blue `#004990`/`#06488A` · gold `#E2B65E`
Platform aksanları: Convexus `#5B5BD6` · Conventus `#06488A` · Consultus `#18B8C6` · Connectus `#1F9E50` · Convergens `#8B47CE` · ConventLab `#DC7B5B`
localStorage anahtarları: `cn-dark` (koyu tema) · `cv-lang` (TR/EN)

**Panel deseni:** mono gold eyebrow → serif başlık → açıklama → hairline → sayaç/aksiyon → tablo.

**Tasnif şeridi YOK.** Conventity sivil, dual-use bir web platformu; açık internette
duran bir sayfaya tasnif işareti basmak yanlış sinyal verir (zaten tasnif dışı —
burada kısıtlı hiçbir şey tutulmuyor). `UNCLASSIFIED` / `Tasnif dışı` / `Hizmete özel`
gibi şeritleri hiçbir sayfaya ekleme; eskiden vardı, 2026-09'da hepsi kaldırıldı.

## i18n (zorunlu)

- Sözlük: `I18N.tr` + `I18N.en`, erişim `T('anahtar')`, formatlı `Tf('anahtar', deger)`
- HTML metinleri `data-i="anahtar"`, placeholder `data-ph="anahtar"`
- **Executable JS'te sabit metin OLMAZ** — hepsi `T()` üzerinden
- Yeni sekme eklerken gereken anahtarlar: `tab_X`, `eb_X` (eyebrow), `info_X` (açıklama)

## Test

```bash
# JS sözdizimi
python3 -c "import re;h=open('core.html').read();open('/tmp/c.js','w').write('\n'.join(re.findall(r'<script>(.*?)</script>',h,re.S)))"
node --check /tmp/c.js

# bütünlük (hepsi 1 olmalı — çift içerik hatası yakalar)
grep -c "<!DOCTYPE html>\|<body>\|id=\"signinBtn\"" core.html
```
Büyük dosyayı tek seferde yazma; parça parça `str_replace` ile ilerle, her adımda kontrol et.

---

## GEÇMİŞ HATALAR (tekrarlama)

| Hata | Sebep | Kural |
|---|---|---|
| Import 0 satır geçerli | eşleme hedef isimleri normalize edilmemişti | Gerçek CSV ile **offline test et** |
| `orion` NULL kaldı | PostgREST şema önbelleği | `notify pgrst, 'reload schema';` + sessiz fallback yerine **görünür uyarı** |
| Tekrar import düzeltmiyordu | `ignoreDuplicates:true` | Onarım gerekiyorsa upsert **update** yapmalı |
| Demo veri hiç yazılmadı | tek transaction + UNIQUE ihlali → rollback | Her insert `NOT EXISTS` guard'lı |
| Davet çalışmadı | `part_role:'candidate'` CHECK'te yok | İzinli: `participant·organizer·evaluator·observer·vendor` |
| Mobilde "Core" kayboldu | `.brand span{display:none}` tüm span'leri gizledi | Gizleme kuralını **sınıfla daralt** |
| Giriş ölü, TR/EN vurgusuz | dosya GitHub'a **çift içerikli** yüklendi | Bütünlük kontrolü çalıştır |
| Script hiç başlamadı | `localStorage` engelli tarayıcıda fırlattı | try/catch zorunlu |

---

## AÇIK İŞLER (bootstrap sırası — atlama)

Tam girdi: [`BOOTSTRAP.md`](BOOTSTRAP.md).

### §3 — Temiz Supabase · ŞU AN BURADA
Serkan projeyi açar, `ref` + anon key'i `cv-config.js`'e koyar, Auth → URL
Configuration'ı ayarlar. Sonra SQL sırası yazılır:
1. **Boş omurga DDL — seed INSERT'siz** (`sql/00_introspect_v2.sql` ile
   introspect; 147 org / demo veri **atlanır**). MVP minimumu:
   `conventity_orgs`, `conventity_activities`, `conventity_roles`,
   `conventity_is_admin(text)`.
2. **`conventus_mvp_foundation.sql`** — LANDCOM seed + etkinlik bağı + rol
   genişletme + 2 yetki fonksiyonu + `gm_providers`/`gm_offers`
   (temiz DB'de yok → `create table if not exists`) + `service_requests`
   + RLS + doğrulama SELECT.
3. Doğrulama SELECT çıktısı paylaşılır.

### §4 — İlk admin
Serkan sign up olur → `auth.users`'tan uid → `conventity_roles`'a
`ecosystem/admin/active` satırı. `auth_user_id` boşsa rol RLS'te etkisizdir.

### §6 — Deploy
Hostinger'da `conventity.com` ayrı hedefe bağlanır; `main` → conventity.com.
Döngü yeşil olana kadar yalnız local (`python3 -m http.server 8000`).

### Devamı (şema kurulduktan sonra)
- Denetim kaydı (`conventity_audit`, append-only, trigger'lar + Core "Denetim"
  sekmesi) — launch öncesi.
- `.htaccess` `verified/<slug>` rewrite'ı zaten var — doğrula.
- `index.html`'e "Verified" menü linki (`/verified-directory.html`).
- Convexus geldiğinde: problems/capabilities/solutions/evidence/participation
  + link tabloları.

---

## YASAKLAR

- Artefaktlara **"SACEUR"** veya toplantıya özgü etiket (Top Ten, SHAPE HLSG, FA-numaraları) yazma. Nötr tut.
- **Tasnif şeridi/etiketi ekleme** (`UNCLASSIFIED`, `Tasnif dışı`, `Hizmete özel`).
  Platform sivil ve dual-use; açık web'de tasnif işaretinin yeri yok.
- Kanıtta **NATO mührü basma** — "nato" yalnızca referans; mühür Conventity'nindir.
- Orion FIT çıktısını asla "validated" diye sunma — **tavsiye**dir, karar DPP'nindir.
- `conventity_evidence` append-only: edit/delete arayüzü ekleme.
