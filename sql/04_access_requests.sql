-- ============================================================================
-- 04_access_requests.sql  ·  Erişim talepleri
--
-- "Yakında" sayfasındaki form buraya yazar. Form, site parolasının ÖNÜNDE
-- (401 ekranında) çalışır; yani talebi gönderen kişi henüz siteye giremiyor.
-- Dolayısıyla yazma yetkisi `anon` rolünde olmak ZORUNDA — sınırı RLS çiziyor:
--   · anon YALNIZCA insert edebilir, hiçbir şey okuyamaz
--   · insert'te status/handled_* alanları zorla varsayılanda tutulur
--   · okuma/güncelleme/silme yalnız ekosistem admin'inde
--
-- NEREDE ÇALIŞIR: conventity-prod → SQL Editor. Tekrar çalıştırılabilir.
-- ============================================================================

-- ---- 0) yanlış proje / eksik şema koruması --------------------------------
do $cvguard$
declare n_prof bigint := 0;
begin
  if to_regclass('public.conventity_roles') is null then
    raise exception E'\n\n  Bu projede sema yok — once 02_clean_install.sql calistir.\n';
  end if;
  if to_regclass('public.convexus_profiles') is not null then
    select count(*) into n_prof from public.convexus_profiles;
  end if;
  if n_prof >= 100 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) tablo --------------------------------------------------------------
create table if not exists public.conventity_access_requests (
  id          uuid primary key default gen_random_uuid(),
  full_name   text not null,
  email       text not null,
  org_name    text,
  purpose     text,
  lang        text default 'tr',
  source      text not null default 'coming_soon',
  status      text not null default 'new',
  note        text,
  handled_by  uuid,
  handled_at  timestamptz,
  created_at  timestamptz not null default now()
);

do $cvblock$
declare r record;
begin
  for r in select * from (values
    ('car_status_ck',  $q$check (status = any (array['new','contacted','invited','declined','spam']))$q$),
    ('car_source_ck',  $q$check (source = any (array['coming_soon','site','manual']))$q$),
    ('car_lang_ck',    $q$check (lang is null or lang = any (array['tr','en']))$q$),
    ('car_name_len',   $q$check (char_length(btrim(full_name)) between 2 and 120)$q$),
    ('car_email_fmt',  $q$check (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' and char_length(email) <= 254)$q$),
    ('car_org_len',    $q$check (org_name is null or char_length(org_name) <= 160)$q$),
    ('car_purpose_len',$q$check (purpose is null or char_length(purpose) <= 1000)$q$),
    ('car_note_len',   $q$check (note is null or char_length(note) <= 2000)$q$)
  ) v(con, def) loop
    if not exists (select 1 from pg_constraint c
                   join pg_class rel on rel.oid = c.conrelid
                   join pg_namespace n on n.oid = rel.relnamespace
                   where n.nspname = 'public'
                     and rel.relname = 'conventity_access_requests'
                     and c.conname = r.con) then
      execute format('alter table public.conventity_access_requests add constraint %I %s',
                     r.con, r.def);
    end if;
  end loop;
end $cvblock$;

-- Aynı e-posta ile açık talep tekrarlanmasın (kaba spam freni + temiz kuyruk).
create unique index if not exists uq_car_open_email
  on public.conventity_access_requests (lower(email))
  where status = 'new';

create index if not exists idx_car_created on public.conventity_access_requests (created_at desc);
create index if not exists idx_car_status  on public.conventity_access_requests (status);

-- ---- 2) RLS ----------------------------------------------------------------
alter table public.conventity_access_requests enable row level security;

-- anon/authenticated: YALNIZCA yeni talep bırakabilir.
-- status/handled_*/note alanları zorla varsayılanda — kimse kendini "invited"
-- yazamaz, başkasının talebine not düşemez.
drop policy if exists car_public_insert on public.conventity_access_requests;
create policy car_public_insert on public.conventity_access_requests
  as permissive for insert to anon, authenticated
  with check (
    status = 'new'
    and source = 'coming_soon'
    and note is null
    and handled_by is null
    and handled_at is null
  );

-- Okuma/güncelleme/silme: yalnız ekosistem admin.
drop policy if exists car_admin_all on public.conventity_access_requests;
create policy car_admin_all on public.conventity_access_requests
  as permissive for all to authenticated
  using (conventity_is_admin('ecosystem'))
  with check (conventity_is_admin('ecosystem'));

-- ---- 3) PostgREST yetkileri ------------------------------------------------
-- DİKKAT: 02_clean_install.sql, .org'un yapılandırmasını birebir taşıdığı için
-- public'teki tüm tablolara anon dahil üç role de tam yetki veriyor; üstelik
-- `alter default privileges` yüzünden SONRADAN yaratılan tablolar da aynı
-- yetkiyi otomatik alıyor. Yani bu tablo yaratıldığı anda anon'un select/
-- update/delete yetkisi VAR. RLS yine de veriyi göstermezdi (okuma politikası
-- yok), ama tek savunma hattına yaslanmak yanlış — yetkiyi de geri al.
revoke all on public.conventity_access_requests from anon;
grant insert on public.conventity_access_requests to anon;
grant all    on public.conventity_access_requests to authenticated, service_role;

-- ---- 4) doğrulama ----------------------------------------------------------
select 'tablo kuruldu' as sonuc,
       (select count(*) from pg_policies
         where schemaname='public' and tablename='conventity_access_requests') as politika,
       (select count(*) from pg_constraint c join pg_class r on r.oid=c.conrelid
         join pg_namespace n on n.oid=r.relnamespace
        where n.nspname='public' and r.relname='conventity_access_requests') as kisit;
