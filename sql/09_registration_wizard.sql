-- ============================================================================
-- 09_registration_wizard.sql  ·  Dilim 1 — kayıt sihirbazının veri katmanı
--
-- NE EKLER (hepsi ETKİNLİK BAZINDA ayarlanabilir — koda gömülü liste yok):
--   conventus_event_reg_types        kayıt tipleri + uygunluk notu
--   conventus_event_tracks           gün/parkur blokları (tarih·saat·kontenjan)
--   conventus_registration_tracks    kayıt ↔ parkur seçimi
--   conventus_event_consents         onay metinleri (sürümlü)
--   conventus_registration_consents  verilen onaylar — APPEND-ONLY
--   conventus_registrations'a: reg_type · reg_type_other · confirmation_code
--                              agreement_version · agreement_accepted_at
--
-- NEDEN AYARLANABİLİR: LANDCOM'un katılımcı tipleri ve parkurları henüz
--   kesin değil. Tahmin edip koda gömmek yerine organizatörün tanımladığı
--   veri yaptık; sihirbaz tanımlı olmayan adımı atlıyor (parkur yoksa o
--   adım hiç çıkmıyor).
--
-- PASAPORT/DOĞUM TARİHİ İÇİN YENİ ALAN GEREKMEDİ: `registration_field_defs`
--   çekirdek alanları da etkinlik bazında gizleyip zorunluluktan çıkarabiliyor
--   (register-conventus.html · applyFieldConfig). Toplanmasın isteniyorsa
--   ilgili çekirdek tanımına `"visible": false` yazmak yeterli.
--
-- ONAYLAR NEDEN AYRI TABLO: kutu işaretlemek değil, **hangi metne, hangi
--   sürümüne, ne zaman, kim** onay verdiği saklanmalı. Bu yüzden metin
--   sürümlü (`conventus_event_consents`), cevap append-only
--   (`conventus_registration_consents` — UPDATE/DELETE politikası YOK).
--
-- KULLANIM: 08'den sonra. Tekrar çalıştırılabilir.
-- ============================================================================

-- ---- 0) YANLIŞ PROJE KORUMASI ----------------------------------------------
do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.conventus_managed_events') is null then
    raise exception E'\n\n  Bu projede sema yok — once 02_clean_install.sql calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n'
      '  Hicbir sey yazilmadi.\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) KAYIT TİPLERİ -------------------------------------------------------
create table if not exists public.conventus_event_reg_types (
  id           bigserial primary key,
  event_id     bigint not null references public.conventus_managed_events(id) on delete cascade,
  key          text   not null,
  label        text   not null,
  note         text,                      -- "yalnızca ... iseniz seçin"
  allow_other  boolean not null default false,
  sort         int     not null default 0,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);
create unique index if not exists uq_cert_event_key
  on public.conventus_event_reg_types (event_id, key);
create index if not exists ix_cert_event on public.conventus_event_reg_types (event_id, sort);

-- ---- 2) PARKURLAR / GÜN BLOKLARI --------------------------------------------
create table if not exists public.conventus_event_tracks (
  id            bigserial primary key,
  event_id      bigint not null references public.conventus_managed_events(id) on delete cascade,
  key           text   not null,
  title         text   not null,
  description   text,
  starts_on     date,
  ends_on       date,
  time_from     text,                     -- '08:00' — saat dilimi etkinlikte
  time_to       text,
  capacity      int,                      -- null = sınırsız
  external_note text,                     -- "ayrıca X üzerinden kayıt gerekir"
  sort          int     not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);
create unique index if not exists uq_cetr_event_key
  on public.conventus_event_tracks (event_id, key);
create index if not exists ix_cetr_event on public.conventus_event_tracks (event_id, sort);

do $cv$ begin
  if not exists (select 1 from pg_constraint where conname='conventus_event_tracks_dates_check') then
    alter table public.conventus_event_tracks
      add constraint conventus_event_tracks_dates_check
      check (ends_on is null or starts_on is null or ends_on >= starts_on);
  end if;
  if not exists (select 1 from pg_constraint where conname='conventus_event_tracks_capacity_check') then
    alter table public.conventus_event_tracks
      add constraint conventus_event_tracks_capacity_check
      check (capacity is null or capacity > 0);
  end if;
end $cv$;

-- ---- 3) KAYIT ↔ PARKUR ------------------------------------------------------
create table if not exists public.conventus_registration_tracks (
  registration_id bigint not null references public.conventus_registrations(id) on delete cascade,
  track_id        bigint not null references public.conventus_event_tracks(id) on delete cascade,
  created_at      timestamptz not null default now(),
  primary key (registration_id, track_id)
);
create index if not exists ix_crt_track on public.conventus_registration_tracks (track_id);

-- ---- 4) ONAY METİNLERİ (sürümlü) --------------------------------------------
create table if not exists public.conventus_event_consents (
  id          bigserial primary key,
  event_id    bigint not null references public.conventus_managed_events(id) on delete cascade,
  key         text   not null,
  version     int    not null default 1,
  body        text   not null,
  is_required boolean not null default true,   -- "HAYIR ⇒ kayıt onaylanamaz"
  sort        int    not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);
create unique index if not exists uq_cec_event_key_ver
  on public.conventus_event_consents (event_id, key, version);
create index if not exists ix_cec_event on public.conventus_event_consents (event_id, sort);

-- ---- 5) VERİLEN ONAYLAR — APPEND-ONLY ---------------------------------------
-- Hukuken anlamlı olan kutunun işaretlenmesi değil, kaydın kendisi:
-- hangi metne (key+version), ne cevap, ne zaman, kim. Bu yüzden düzeltilemez.
create table if not exists public.conventus_registration_consents (
  id              bigserial primary key,
  registration_id bigint  not null references public.conventus_registrations(id) on delete cascade,
  consent_key     text    not null,
  consent_version int     not null,
  answer          boolean not null,
  answered_at     timestamptz not null default now(),
  answered_by     uuid default auth.uid()
);
create index if not exists ix_crc_reg on public.conventus_registration_consents (registration_id);

-- ---- 6) KAYIT TABLOSUNA EK ALANLAR ------------------------------------------
alter table public.conventus_registrations
  add column if not exists reg_type              text,
  add column if not exists reg_type_other        text,
  add column if not exists confirmation_code     text,
  add column if not exists agreement_version     text,
  add column if not exists agreement_accepted_at timestamptz;

create unique index if not exists uq_creg_confirmation_code
  on public.conventus_registrations (confirmation_code)
  where confirmation_code is not null;

-- ---- 7) ONAY KODU -----------------------------------------------------------
-- İnsan tarafından telefonda söylenebilir olmalı: karışan karakterler yok
-- (0/O, 1/I/L). Çakışırsa yeniden dener; 10 denemede olmazsa hata verir —
-- sessizce kodsuz kayıt açmaktansa patlaması iyidir.
create or replace function public.conventus_gen_confirmation_code()
returns text
language plpgsql
volatile
as $fn$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
  i    int;
  try  int := 0;
begin
  loop
    code := '';
    for i in 1..10 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (
      select 1 from public.conventus_registrations r where r.confirmation_code = code);
    try := try + 1;
    if try >= 10 then
      raise exception 'onay kodu uretilemedi (10 denemede benzersiz kod bulunamadi)';
    end if;
  end loop;
  return code;
end
$fn$;

create or replace function public.conventus_set_confirmation_code()
returns trigger
language plpgsql
volatile
security definer
set search_path to 'public'
as $fn$
begin
  if new.confirmation_code is null then
    new.confirmation_code := public.conventus_gen_confirmation_code();
  end if;
  return new;
end
$fn$;

drop trigger if exists trg_conventus_reg_confirmation_code on public.conventus_registrations;
create trigger trg_conventus_reg_confirmation_code
  before insert on public.conventus_registrations
  for each row execute function public.conventus_set_confirmation_code();

-- mevcut kayıtlara da kod ver (idempotent)
update public.conventus_registrations
   set confirmation_code = public.conventus_gen_confirmation_code()
 where confirmation_code is null;

-- ---- 8) RLS -----------------------------------------------------------------
alter table public.conventus_event_reg_types         enable row level security;
alter table public.conventus_event_tracks            enable row level security;
alter table public.conventus_registration_tracks     enable row level security;
alter table public.conventus_event_consents          enable row level security;
alter table public.conventus_registration_consents   enable row level security;

-- Etkinlik yapılandırması (tip · parkur · onay metni):
-- OKUMA — etkinliği görebilen görür. Alt sorgu `conventus_managed_events`in
--         kendi RLS'ine tabi olduğu için görünürlük kuralı tek yerde kalıyor,
--         burada kopyalanmıyor.
-- YAZMA — yalnız etkinliği yönetebilen.
do $cv$
declare t text;
begin
  foreach t in array array['conventus_event_reg_types',
                           'conventus_event_tracks',
                           'conventus_event_consents'] loop
    execute format('drop policy if exists %I on public.%I', t || '_read',  t);
    execute format('drop policy if exists %I on public.%I', t || '_write', t);
    execute format($p$
      create policy %I on public.%I for select to anon, authenticated
      using (exists (select 1 from public.conventus_managed_events e where e.id = event_id))
    $p$, t || '_read', t);
    execute format($p$
      create policy %I on public.%I for all to authenticated
      using (exists (select 1 from public.conventus_managed_events e
                      where e.id = event_id and public.conventity_can_manage_event(e.activity_id)))
      with check (exists (select 1 from public.conventus_managed_events e
                      where e.id = event_id and public.conventity_can_manage_event(e.activity_id)))
    $p$, t || '_write', t);
  end loop;
end $cv$;

-- Kayıt ↔ parkur: kendi kaydı ya da etkinlik yöneticisi.
drop policy if exists crt_own    on public.conventus_registration_tracks;
drop policy if exists crt_manage on public.conventus_registration_tracks;
create policy crt_own on public.conventus_registration_tracks for all to authenticated
  using (exists (select 1 from public.conventus_registrations r
                  where r.id = registration_id and r.user_id = auth.uid()))
  with check (exists (select 1 from public.conventus_registrations r
                  where r.id = registration_id and r.user_id = auth.uid()));
create policy crt_manage on public.conventus_registration_tracks for all to authenticated
  using (exists (select 1 from public.conventus_registrations r
                  join public.conventus_managed_events e on e.id = r.event_id
                  where r.id = registration_id and public.conventity_can_manage_event(e.activity_id)))
  with check (exists (select 1 from public.conventus_registrations r
                  join public.conventus_managed_events e on e.id = r.event_id
                  where r.id = registration_id and public.conventity_can_manage_event(e.activity_id)));

-- Verilen onaylar: YAZ ve OKU var, GÜNCELLE/SİL YOK — append-only.
drop policy if exists crc_insert_own    on public.conventus_registration_consents;
drop policy if exists crc_insert_manage on public.conventus_registration_consents;
drop policy if exists crc_read_own      on public.conventus_registration_consents;
drop policy if exists crc_read_manage   on public.conventus_registration_consents;
create policy crc_insert_own on public.conventus_registration_consents for insert to authenticated
  with check (exists (select 1 from public.conventus_registrations r
                       where r.id = registration_id and r.user_id = auth.uid()));
create policy crc_insert_manage on public.conventus_registration_consents for insert to authenticated
  with check (exists (select 1 from public.conventus_registrations r
                       join public.conventus_managed_events e on e.id = r.event_id
                       where r.id = registration_id and public.conventity_can_manage_event(e.activity_id)));
create policy crc_read_own on public.conventus_registration_consents for select to authenticated
  using (exists (select 1 from public.conventus_registrations r
                  where r.id = registration_id and r.user_id = auth.uid()));
create policy crc_read_manage on public.conventus_registration_consents for select to authenticated
  using (exists (select 1 from public.conventus_registrations r
                  join public.conventus_managed_events e on e.id = r.event_id
                  where r.id = registration_id and public.conventity_can_manage_event(e.activity_id)));

-- ---- 9) YETKİLER — 05 ve 07'deki kurallarla tutarlı -------------------------
-- anon: yapılandırmayı OKUR (kamusal etkinlik sayfası için), hiçbir şey yazmaz.
-- authenticated/service_role: tam (sınırı RLS çiziyor).
do $cv$
declare t text;
begin
  foreach t in array array['conventus_event_reg_types','conventus_event_tracks',
                           'conventus_event_consents','conventus_registration_tracks',
                           'conventus_registration_consents'] loop
    execute format('revoke all on public.%I from public, anon', t);
    execute format('grant all on public.%I to authenticated, service_role', t);
  end loop;
  -- yalnız yapılandırma tabloları anon'a okunur
  foreach t in array array['conventus_event_reg_types','conventus_event_tracks',
                           'conventus_event_consents'] loop
    execute format('grant select on public.%I to anon', t);
  end loop;
end $cv$;

do $cv$
declare s text;
begin
  for s in select sequencename from pg_sequences where schemaname='public'
            and sequencename like 'conventus_%' loop
    execute format('revoke all on sequence public.%I from public, anon', s);
    execute format('grant usage, select on sequence public.%I to authenticated, service_role', s);
  end loop;
end $cv$;

revoke all on function public.conventus_gen_confirmation_code()  from public, anon;
revoke all on function public.conventus_set_confirmation_code()  from public, anon;
grant execute on function public.conventus_gen_confirmation_code() to authenticated, service_role;

notify pgrst, 'reload schema';

-- ---- 10) DOĞRULAMA — tek sorgu ----------------------------------------------
select
  (select count(*) from pg_tables where schemaname='public'
     and tablename in ('conventus_event_reg_types','conventus_event_tracks',
                       'conventus_registration_tracks','conventus_event_consents',
                       'conventus_registration_consents'))                    as "yeni tablo (5)",
  (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relrowsecurity
     and c.relname in ('conventus_event_reg_types','conventus_event_tracks',
                       'conventus_registration_tracks','conventus_event_consents',
                       'conventus_registration_consents'))                    as "RLS acik (5)",
  (select count(*) from pg_policies where schemaname='public'
     and tablename='conventus_registration_consents'
     and cmd in ('UPDATE','DELETE'))                                          as "onay guncelleme/silme (0)",
  (select count(*) from information_schema.columns where table_schema='public'
     and table_name='conventus_registrations'
     and column_name in ('reg_type','reg_type_other','confirmation_code',
                         'agreement_version','agreement_accepted_at'))        as "yeni kolon (5)",
  (select count(*) from public.conventus_registrations where confirmation_code is null)
                                                                              as "kodsuz kayit (0)";
