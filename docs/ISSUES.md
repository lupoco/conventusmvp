# Conventus v2 — Sorun & Eksik Backlog

> Claude'un tespit ettiği sorunlar. Tek tek düzeltilir; her düzeltmede `Durum` güncellenir.
> Durum: `açık` · `çalışılıyor` · `düzeltildi` · `ertelendi` · `iptal`
> Referans akış: 1 provision → 2 OPR ata → 3 etkinlik+activity_id → 4 PAF → 5 yayınla → 6 kayıt → 7 onay → 8 My Event

---

## A. TEKRARLAR (aynı işi yapan rakip sayfalar — omurga için netleşmeli)

| # | Sorun | Nerede | Öneri | Öncelik | Durum |
|---|---|---|---|---|---|
| S1 | İki kayıt sayfası | `register-conventus.html` (gerçek PAF) ↔ `register.html` (eski) | register.html'i register-conventus'a yönlendir/arşivle; tüm linkleri tek hedefe çevir | Yüksek | düzeltildi |
| S2 | İki katılımcı görünümü | `my-event.html` (yeni) ↔ `my-event.dc.html` (eski) | my-event.dc → my-event.html redirect; index/settings linklerini çevir | Yüksek | düzeltildi |
| S3 | İki etkinlik oluşturma yolu | `new-event.html` (RPC+topluluk) ↔ `event-studio` sihirbazı | event-studio create'i de RPC'ye bağla; tek "oluştur" mantığı | Kritik | düzeltildi |
| S4 | Etkinlik yönetimi dağınık | `event-manage` ↔ `event-studio` Manage ↔ `Admin.dc` ↔ `event-_mvp` | event-manage'i tek yönetim yüzeyi yap; diğerleri redirect/arşiv | Yüksek | düzeltildi |
| S5 | Ölü MVP sayfası | `event-_mvp.html` (çıkışsız) | event-studio'ya redirect, arşivle | Orta | düzeltildi |

## B. ORPHAN (hiçbir yerden linklenmiyor)

| # | Sorun | Nerede | Öneri | Öncelik | Durum |
|---|---|---|---|---|---|
| S6 | Orphan | `announcements.html` | event-manage Duyurular sekmesine göm / linkle | Orta | düzeltildi |
| S7 | Orphan | `product-studio.html` | Faz B (Go & Meet) — o zaman bağla | Düşük | ertelendi |
| S8 | Orphan | `settings.html` (conventus-yerel) | index/nav'a bağla veya arşivle | Düşük | düzeltildi |

## C. KOPUK / ESKİ GEÇİŞLER (yanlış hedefe giden linkler)

| # | Sorun | Nerede | Öneri | Öncelik | Durum |
|---|---|---|---|---|---|
| S9  | index eski önizlemeye gidiyor | `index.html` → `event-_mvp.html` | → event-studio veya new-event | Yüksek | düzeltildi |
| S10 | index eski katılımcı sayfasına | `index.html` → `my-event.dc.html` | → my-event.html / my-events | Yüksek | düzeltildi |
| S11 | new-event listesi eski panellere | `new-event.html` → `agenda/applications` | → event-manage.html?e= | Orta | düzeltildi |
| S12 | eski etkinlik akışı | `go-and-test`, `Admin.dc` → `event-studio` | akış netleşince tek hedefe | Orta | düzeltildi |
| S13 | çıkışsız sayfalar | `programme.html`, `event-studio` (statik) | geri/ileri nav ekle | Düşük | düzeltildi |
| S14 | settings eski hedefler | `settings.html` → `my-event.dc`, `Admin.dc` | yeni sayfalara çevir | Düşük | düzeltildi |

## D. VERİ / AKTARIM EKSİKLERİ (omurga tutarlılığı)

| # | Sorun | Nerede | Öneri | Öncelik | Durum |
|---|---|---|---|---|---|
| S15 | event-studio create RPC kullanmıyor | `event-studio` saveEvent (yeni etkinlik) | community seçimi + `conventus_create_managed_event` RPC'ye bağla (community_id/activity_id boş kalmasın) | Kritik | düzeltildi |
| S16 | event-studio.da topluluk seçimi yok | `event-studio` Adım 1/0 | brief §5.3 "Adım 0 Topluluk" ekle | Yüksek | düzeltildi |
| S17 | Duyuru audience RLS yok (T14) | `conventus_announcements` | audience'a göre görünürlük RLS (approved/members_only) | Orta | düzeltildi ✓ canlı (Supabase'de doğrulandı) |
| S18 | Kayıt penceresi RLS yok (T10) | `conventus_registrations` | self-insert → registration_open kapısı | Yüksek | düzeltildi ✓ canlı (Supabase'de doğrulandı) |
| S19 | Doküman tablosu yok | `conventus_documents` + My Event | tablo + RLS + event-manage editör | Orta | düzeltildi ✓ canlı (Supabase'de doğrulandı, policy_count=2) |
| S20 | Seating & precedence yok (protokol) | yeni | `conventus_seating(tier,rank)` + UI iskeleti | Orta | ertelendi (A2 sonu) |

## E. EKSİK EDİTÖRLER / UI

| # | Sorun | Nerede | Öneri | Öncelik | Durum |
|---|---|---|---|---|---|
| S21 | Yönetici editör sekmeleri stub | `event-manage` Ajanda/Duyuru/İdari&Lojistik | mevcut agenda/announcements'ı göm veya inline editör | Yüksek | düzeltildi |
| S22 | Fonksiyonel unvan UI yok | `community-admin` "Yönetici Ata" | atarken `title` seç (opr/poc/protocol/escort/dispatcher) | Yüksek | düzeltildi |
| S23 | Lojistik editörü yok | `event-manage` Lojistik | `managed_events.logistics` jsonb editörü (My Event bunu okuyor) | Orta | düzeltildi |
| S24 | Duyuru audience seçimi UI yok | `announcements` / event-manage | audience + pinned + publish_at UI | Orta | düzeltildi |

## F. TASARIM / KİMLİK / KURAL

| # | Sorun | Nerede | Öneri | Öncelik | Durum |
|---|---|---|---|---|---|
| S25 | Kanonik kimliğe göçmemiş sayfalar | `event-studio`(Barlow), diğer legacy | tokens.css/base.css'e taşı, TR/EN | Düşük | düzeltildi ✓ (tipografi kanonik + tam TR/EN i18n; her iki dil ekran görüntüsüyle doğrulandı) |
| S26 | Native date input (yasak) | `new-event`, `event-studio` | DD.MM.YYYY maskeli input | Düşük | düzeltildi |
| S27 | index "doors" eski akışı yansıtıyor | `index.html` | yeni akışa göre kapıları güncelle | Orta | düzeltildi |
| S28 | cv-event-card yolu | `/assets/cv-event-card.js` | brief `/assets/js/` diyordu (kozmetik) | Düşük | iptal (mevcut yol kanonik — tüm JS `/assets/` altında düz; `js/` alt-dizin yok) |

---

## G. KONSOLİDASYON — ÖLÜ KATMAN TEMİZLİĞİ (temel sağlamlaştırma, dilim 1)

> Redirect stub'lara/arşive alınmış (S2/S4/S5/S12) sayfalar artık tümüyle **silindi**; canlı gelen linkler `event-studio.html`'e çevrildi. Amaç: yarım kalan EFDI→Supabase göçünün eski katmanını repodan kaldırmak.

| # | İş | Nerede | Durum |
|---|---|---|---|
| S29 | Ölü redirect stub'ları sil | `Admin.dc.html`, `my-event.dc.html`, `event-_mvp.html` | silindi |
| S30 | Ölü seed/stub JS sil | `services-data.js` (ölü seed), `auth.js` (stub), `booklet-data.js` | silindi |
| S31 | `Admin.dc.html` gelen linklerini çevir | `index.html`×3, `handbook.html`, `go-and-meet.html`×2, `product-studio.html`, `core.html` launcher, `routes.js` (event-mvp kaydı) → `event-studio.html` | düzeltildi |
| S32 | `overview.html` sil | routes.js'de 5 rotanın nav ebeveyni — **routes/nav dilimi**nde reparent edilip silinecek | ertelendi |
| S33 | `go-and-meet.html` + `support.js` emekliye ayır | canlı Events girişi; `gm-plan`'e göç et, sonra sil | ertelendi |
| S34 | `product-studio.html` (S7 park) | Faz B'de bağlanacak; şimdilik korunuyor | ertelendi |
| S35 | conventus/index.html EFDIAuth "Loading secure access…" ölü paneli | tanımsız `window.EFDIAuth`; `#csAccess` HTML'de yok → IIFE zaten erken return (görünmez ölü kod). Script IIFE + panel CSS (`.cs-grid`/`.cs-access`/`.cs-acct` vb.) + uydurma `super` rolü silindi. Canlı "Conventus Studio" kart bölümü ve `.cs-cards` korundu | düzeltildi |

---

## H. KONSOLİDASYON — cv-core.js (auth+client+rol çekirdeği, dilim 2)

> Amaç: ~40 dosyaya kopyalanmış Supabase client bootstrap'ı, 4 kopya üyelik guard'ı ve dağınık rol/scope listelerini tek modüle (`/assets/cv-core.js`) indirmek. Eklemeli ilerler.

| # | İş | Nerede | Durum |
|---|---|---|---|
| S36 | Paylaşılan çekirdek modülü oluştur | `/assets/cv-core.js` — `cvClient/cvIsMember/cvGuardMember` + `CV.roles/scopes/partRoles/homeFor` | düzeltildi |
| S37 | 4 kopya üyelik guard'ını çekirdeğe indir | `login.html` (inline hata → `cvIsMember`), `index.html`/`settings.html`/`dashboard/index.html` (redirect → `cvGuardMember`) | düzeltildi |
| S38 | Rol/scope TEK KAYNAK'ı çekirdeğe koy | `CV.roles/scopes/partRoles` + bağlam alt-kümeleri `CV.platformScopes` (rol konsolu; convergens drift'i düzeltildi) ve `CV.communityRoles` (community-admin; event_manager drift'i düzeltildi). `core.html` editörü + `community-admin.html` CV'ye bağlandı; core.html'e `role_owner`/`role_event_manager` i18n eklendi. (`conventus/index` `super` → ölü EFDIAuth paneli, S35'te silinecek; `settings.html` `cv_admins` → ayrı yetki-kaynağı işi) | düzeltildi |
| S39 | ~40 dosyanın client bootstrap'ını cv-core'a geçir | tüm platform sayfaları — `window.__cvSb` kopyaları yerine `cvClient()` | düzeltildi |
| S39.1 | Batch 1: izole-global Conventus sayfaları | `applications/announcements/my-events/agenda/gm-plan.html` — sayfa-özel global (`__cvAppSb` vb.) + hardcoded ESKİ JWT anon anahtarı kaldırıldı → `cvClient()` (kanonik publishable anahtar). Not: bu 5 sayfa eski JWT anahtarını kullanıyordu, artık tek anahtar | düzeltildi |
| S39.2 | Batch 2: kalan tüm client-kuran sayfalar | Conventus (communities/community/community-admin/event-manage/my-event/gm-provider/go-and-test/new-event/register-conventus/register/settings/event-studio), Convexus (index/new/settings/engagement/engagement-triage), Connectus ×7 (lazy `sb()`→`cvClient()`), root (forgot-password/register/verified/verified-directory/admin), selection sayfaları ×5. Toplam ~30 dosya → `cvClient()`; izole global + hardcoded anahtar kopyaları silindi | düzeltildi |
| S39-not | Kapsam dışı bırakılanlar | **bare-REST sayfaları** (`conventus/index`, `programme`, `go-and-meet`, `product-studio`) JS client kurmuyor — `fetch` apikey header'ı kullanıyor; bootstrap swap değil veri-katmanı işi. **reset-password**: `detectSessionInUrl:true` özel client seçeneği (cvClient'te yok) → kendi bootstrap'ı korundu. **login/core/index(root)/settings(root)**: kanonik client kuranlar, kendi bootstrap'ları bırakıldı (drift değil, kanonik anahtar) | ertelendi/kapsam-dışı |
| S40 | Çekirdek yetki fonksiyonlarını repoya al | `conventity_is_admin` / `is_convexus_admin` / `is_cv_admin` (şu an yalnız canlı DB'de) → `sql/` | ertelendi |

## I. İKİ-TARAFLI GİRİŞ (Faz 2 — arz+talep, ağ etkisi) — Cvent Vendor Marketplace deseninden

> Cvent'in "For Planners / For Suppliers" iki-kapılı girişi referans. Conventus'un fiili 3 rolüne uyarlandı.

| # | İş | Nerede | Durum |
|---|---|---|---|
| S41 | 3-kapılı giriş ekranı | `platforms/conventus/start.html` (yeni) — Organizatör→event-studio · Katılımcı→my-events/go-and-test · Sağlayıcı→gm-provider. Her kapıda Log in + Sign up. Tam TR/EN i18n, tema, sürüm rozeti, cv-core. Girişliyse `CV.homeFor(role)` ile "workspace'ini aç" iyileştirmesi | düzeltildi |
| S42 | Giriş noktası bağlandı | `conventus/index.html` hero "Get started" → start.html; `core.html` launcher'a "Get Started" | düzeltildi |
| S43 | Rol/niyet-tabanlı post-login yönlendirme | `login.html`: (1) güvenli `?next=` (start.html kapı seçimi) öncelikli; (2) yoksa rol→`CV.homeFor` yalnız organizer/event_manager/vendor için, admin/owner ekosistem konsolunda kalır. Her dal fail-safe `/index.html`. `next` sıkı iç-yol regex'inden geçer (açık-redirect kapalı). start.html kapıları `?next=<workspace>` taşır. OAuth yolu değişmedi | düzeltildi |
| S44 | Sağlayıcı → ekosistem vendor rolü | **Bulgu:** gm-provider onboarding zaten derin (çok-alanlı başvuru→akreditasyon→rıza→kategori kapısı). Gerçek boşluk: akredite sağlayıcıya `conventity_roles`'ta `vendor` rolü verilmiyordu → S43 routing'i onlar için ölüydü, matching/rol-konsolu onları arz aktörü görmüyordu. **Çözüm:** `sql/2026-08-04_conventus_provider_vendor_role.sql` — `gm_providers.accredited=true`→`conventity_roles` vendor grant (SECURITY DEFINER trigger), de-akreditasyonda yalnız otomatik rol revoke, mevcut firmalar için NOT EXISTS backfill. +ROLLBACK. **SQL Editor'de manuel çalıştırılmalı** (canlı DB; önce introspect) | hazır — uygulama bekliyor |

## Çalışma yöntemi
Tek tek: bir madde seç → düzelt → `node --check` + bütünlük → commit → Durum=düzeltildi → sıradaki.
Kullanıcının kendi bulduğu sorunlar bu listeye S29+ olarak eklenir.
