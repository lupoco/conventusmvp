-- ============================================================================
-- 10_protocol_reference.sql  ·  NATO protokol referans katmani — SEMA
--
-- KAYNAK: NATO Protocol guide book (NON-SENSITIVE / RELEASABLE TO THE PUBLIC)
--   §2.1  STANAG 1059 Ed.8 ulke kodlari (askeri + sivil AYRI)
--   §2.2  NATO ic oncelik sirasi (22 madde) + oncelik doktrini
--   §3.1  NATO Dress Code (6 kademe · kislik/yazlik/sivil)
--   App 2-1  Askeri VIP + sivil erkan oncelik listesi (41 madde)
--   App 3-3  Unvanlar ve hitap bicimleri (ulus x rol)
--   PLCC WEBSITE REQUIREMENTS V23 (sifat · kurulus · unvan · rutbe)
--   PLCC WEBSITE REQUIREMENTS V25 (7 adimli oncelik karar agaci)
--
-- NEDEN VERI, NEDEN KOD DEGIL: bu listeler bugun
--   platforms/conventus/register-conventus.html icine GOMULU (RANKS, NATIONS).
--   Gomulu liste: tek sayfadan kullanilir, cevrilemez, degisince kod duzenlenir.
--   Referans tablosu: her sayfa okur, TR/EN tasir, admin gunceller.
--
-- ONCELIK NEDEN TEK SAYI DEGIL: V25 "tek sayiya indirgenmeli" diyor ve
--   adim 1-4 icin dogru — conventity_precedence_score() onu veriyor.
--   Ama adim 5-7 (rutbe tarihi · ulus alfabetik · soyadi) bir tarih ve iki
--   metin; float'a gomulurse bilgi kaybolur ve hata ayiklanamaz. Onlar
--   ORDER BY kolonu olarak kaliyor — conventus_precedence_v bu siralamayi
--   eksiksiz yapiyor. Skor kaba sira, view kesin sira.
--
-- SKOR SAKLANMIYOR: kolon degil, view. Rutbe/sifat degisince kendiliginden
--   guncellenir; bayat skor diye bir sey olmaz.
--
-- BAKIM KURALI (09'dan devam): bu dosyanin OKUMA politikalari hicbir fonksiyon
--   cagirmiyor (using(true) — referans verisi zaten kamusal). YAZMA politikalari
--   yalniz conventity_is_admin cagiriyor; o mevcut politikalarda kullanildigi
--   icin 07'nin turetilmis beyaz listesinde zaten var. 07'yi tekrar calistirmak
--   GEREKMIYOR.
--
-- KULLANIM: 09'dan sonra. Tekrar calistirilabilir. Veri icin 11'i calistir.
-- ============================================================================

-- ---- 0) YANLIS PROJE KORUMASI ----------------------------------------------
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

-- ---- 1) ULUSLAR — STANAG 1059 Ed.8 ------------------------------------------
-- Askeri kod 3 harf, sivil kod AYRI: NATO uyelerinde 2 harf (TUR->TU),
-- partnerlerde 3 harf ama sapmali (IRL->IRE, KGZ->KYR, KOR->ROK).
-- Tek kolonda tutulamaz.
-- name_fr: §2.2 siralamanin "English or French" olabilecegini soyluyor.
create table if not exists public.conventity_ref_nation (
  code_mil     text primary key,
  code_civ     text,
  name_en      text not null,
  name_fr      text,
  name_tr      text,
  bloc         text not null check (bloc in ('nato','pfp','md','ici','patg')),
  is_accession boolean not null default false,
  is_active    boolean not null default true,
  source_note  text,
  updated_at   timestamptz not null default now()
);
create index if not exists ix_ref_nation_bloc on public.conventity_ref_nation (bloc, name_en);

-- ---- 2) NATO KADEME OLCEGI --------------------------------------------------
-- ordinal ayni zamanda oncelik agirligidir (adim 4). Sivil karsilik bire bir
-- DEGIL: OR-6 ve OR-5'in ikisi de B2; OF-9/OF-8'in sivil karsiligi yok.
-- Bu yuzden civ_equiv join anahtari degil, bilgi alanidir.
create table if not exists public.conventity_ref_nato_grade (
  code          text primary key,
  kind          text not null check (kind in ('OF','OR')),
  ordinal       int  not null,
  civ_equiv     text,
  is_selectable boolean not null default true,
  note          text
);

-- ---- 3) RUTBELER ------------------------------------------------------------
create table if not exists public.conventity_ref_rank (
  id         bigserial primary key,
  grade_code text not null references public.conventity_ref_nato_grade(code) on delete cascade,
  service    text not null check (service in ('A','F','N')),   -- Army/Marine · Air · Navy
  name_en    text not null,
  acronym    text not null,
  sort       int  not null default 0,
  is_active  boolean not null default true
);
-- (grade_code, service) TEKIL DEGIL: kaynak bir kademede birden fazla rutbe
-- listeliyor — OF-1 hem "First Lieutenant" hem "Second Lieutenant", Deniz'de
-- ayrica "Midshipman". Tekillik kisaltma uzerinden.
create unique index if not exists uq_ref_rank on public.conventity_ref_rank (service, acronym);
create index if not exists ix_ref_rank_grade on public.conventity_ref_rank (grade_code, sort);

-- ---- 4) ETKINLIK SIFATI (Event Capacity / Role) -----------------------------
-- precedence_weight NEDEN RUTBEDEN BUYUK OLABILIR: §2.2 "Positional Authority"
-- — bir CHOD, sahsi rutbesi Albay da olsa CHOD onceligi alir. Sifat rutbeyi
-- ezmeli; bu yuzden principal sifatlarin agirligi OF-9'un (700) ustunde.
create table if not exists public.conventity_ref_capacity (
  key               text primary key,
  group_key         text not null,
  label_en          text not null,
  label_tr          text,
  precedence_weight int  not null default 0,
  sort              int  not null default 0,
  is_active         boolean not null default true
);

-- ---- 5) UNVAN (Title) -------------------------------------------------------
-- V25 adim 1 ve 2: stratejik ve diplomatik unvanlar her seyi ezer.
create table if not exists public.conventity_ref_title (
  key                    text primary key,
  group_key              text not null,
  label_en               text not null,
  label_tr               text,
  is_strategic_override  boolean not null default false,
  is_diplomatic_override boolean not null default false,
  precedence_weight      int  not null default 0,
  sort                   int  not null default 0,
  is_active              boolean not null default true
);

-- ---- 6) KURULUS -------------------------------------------------------------
create table if not exists public.conventity_ref_organization (
  key        text primary key,
  group_key  text not null,
  label_en   text not null,
  label_tr   text,
  parent_key text,
  sort       int not null default 0,
  is_active  boolean not null default true
);

-- ---- 7) ONCELIK LISTELERI — IKI TANE, ETKINLIK SECER ------------------------
-- nato_internal (22) : salt NATO toplantilari
-- vip_civil     (41) : sivil erkan / yerel yetkili karisik etkinlikler
create table if not exists public.conventity_ref_precedence_list (
  key            text primary key,
  label_en       text not null,
  label_tr       text,
  description_en text,
  description_tr text,
  source_ref     text
);
create table if not exists public.conventity_ref_precedence_item (
  list_key     text not null references public.conventity_ref_precedence_list(key) on delete cascade,
  position     int  not null,                 -- 1 = en ust
  label_en     text not null,
  label_tr     text,
  capacity_key text references public.conventity_ref_capacity(key),
  primary key (list_key, position)
);

-- ---- 8) KIYAFET KODU --------------------------------------------------------
-- §3.1: askeri (kislik/yazlik) ve sivil sutunlar PARALEL. Etkinlik kademeyi
-- secer; katilimci askeri/sivil oldugu ve mevsime gore karsiligini gorur.
create table if not exists public.conventity_ref_dress_code (
  key             text primary key,
  ordinal         int  not null,              -- 1 = en resmi
  label_en        text not null,
  label_tr        text,
  winter_uniform  text,
  summer_uniform  text,
  civilian        text,
  occasions       text,                       -- kaynak ekran goruntusunde kesik
  note            text
);

-- ---- 9) HITAP BICIMLERI (App 3-3) -------------------------------------------
-- Davet mektubu · masa karti · yaka karti · takdim metni bundan uretilir.
-- Sozlu ve yazili AYRI: GBR MOD sozlu "Sir", yazili "Dear Secretary of State".
create table if not exists public.conventity_ref_address_form (
  nation_code    text not null references public.conventity_ref_nation(code_mil) on delete cascade,
  role           text not null check (role in ('mod','chod','monarch','ambassador','knighted')),
  official_title text,
  personal_form  text,
  written_form   text,
  source_note    text,
  primary key (nation_code, role)
);

-- ---- 10) ETKINLIK PROTOKOL AYARI --------------------------------------------
-- §2.2 bunlarin hepsini etkinlige birakiyor: hangi liste, alfabetik sira hangi
-- dilde, ev sahibi ulus kim, partnerler araya mi girer sona mi eklenir.
alter table public.conventus_managed_events
  add column if not exists precedence_list   text default 'nato_internal',
  add column if not exists alpha_language    text default 'en',
  add column if not exists host_nation       text,
  add column if not exists partner_placement text default 'after',
  add column if not exists dress_code_key    text,
  add column if not exists dress_season      text;

do $cv$
begin
  if not exists (select 1 from pg_constraint where conname='ck_cme_alpha_language') then
    alter table public.conventus_managed_events
      add constraint ck_cme_alpha_language check (alpha_language in ('en','fr'));
  end if;
  if not exists (select 1 from pg_constraint where conname='ck_cme_partner_placement') then
    alter table public.conventus_managed_events
      add constraint ck_cme_partner_placement check (partner_placement in ('interleave','after'));
  end if;
  if not exists (select 1 from pg_constraint where conname='ck_cme_dress_season') then
    alter table public.conventus_managed_events
      add constraint ck_cme_dress_season check (dress_season is null or dress_season in ('winter','summer'));
  end if;
end $cv$;

-- ---- 11) KAYIT PROTOKOL ALANLARI --------------------------------------------
-- country/rank_title serbest metin olarak KALIYOR (eski kayitlar bozulmasin);
-- yeni alanlar referans tablolarina baglanir. Gecis 12'de yapilir.
--
-- represents_capacity_key NEDEN AYRI ALAN: §2.2 — bir Principal'i mektupla
-- temsil eden kisi onun tum hak ve onceligini alir, "oturma duzeni dahil".
-- Bu bir not degil, skoru degistiren bir kural; acik alan olmali.
alter table public.conventus_registrations
  add column if not exists nation_code             text,
  add column if not exists rank_id                 bigint,
  add column if not exists grade_code              text,
  add column if not exists capacity_key            text,
  add column if not exists title_key               text,
  add column if not exists organization_key        text,
  add column if not exists date_of_rank            date,
  add column if not exists represents_capacity_key text,
  add column if not exists representation_ref      text,
  add column if not exists is_guest_of_honour      boolean not null default false;

-- ---- 12) ONCELIK SKORU — V25 adim 1-4 ---------------------------------------
-- Saf fonksiyon: ayni girdi -> ayni cikti, tabloya bakmaz disinda referanslar.
-- greatest() NEDEN DOGRU: adimlar birbirini EZER, toplamaz. Bir tugeneralin
-- (450) "Head of Delegation" (800) olmasi onu 800 yapar, 1250 degil.
create or replace function public.conventity_precedence_score(
  p_title_key       text,
  p_capacity_key    text,
  p_represents_key  text,
  p_grade_code      text
) returns int
language sql
stable
set search_path to 'public'
as $fn$
  select greatest(
    -- Adim 1-2: stratejik / diplomatik unvan ezmesi
    coalesce((select t.precedence_weight from public.conventity_ref_title t
               where t.key = p_title_key
                 and (t.is_strategic_override or t.is_diplomatic_override)), 0),
    -- Adim 3: etkinlik sifati — temsil varsa TEMSIL EDILEN sifat gecerli
    coalesce((select c.precedence_weight from public.conventity_ref_capacity c
               where c.key = coalesce(p_represents_key, p_capacity_key)), 0),
    -- Adim 4: NATO kademesi (MASTER)
    coalesce((select g.ordinal from public.conventity_ref_nato_grade g
               where g.code = p_grade_code), 0)
  );
$fn$;

create or replace function public.conventus_registration_precedence(p_registration_id bigint)
returns int
language sql
stable
set search_path to 'public'
as $fn$
  select public.conventity_precedence_score(r.title_key, r.capacity_key,
                                            r.represents_capacity_key, r.grade_code)
    from public.conventus_registrations r
   where r.id = p_registration_id;
$fn$;

-- ---- 13) KIMLIK DIZESI — §2.1 -----------------------------------------------
-- Bicim: RUTBE "Soyadi" ULKEKODU KUVVET   ornek: GEN "Doe" TUR A
-- Noktalama YOK (kaynak acikca soyluyor).
create or replace function public.conventity_identity_string(
  p_acronym text, p_last_name text, p_nation_code text, p_service text
) returns text
language sql
immutable
as $fn$
  select nullif(trim(both ' ' from
    coalesce(p_acronym,'') || ' ' ||
    case when p_last_name is null or p_last_name = '' then ''
         else '"' || p_last_name || '" ' end ||
    coalesce(p_nation_code,'') || ' ' || coalesce(p_service,'')
  ), '');
$fn$;

-- ---- 14) HITAP --------------------------------------------------------------
create or replace function public.conventity_salutation(
  p_nation_code text, p_role text, p_mode text default 'written'
) returns text
language sql
stable
set search_path to 'public'
as $fn$
  select case when p_mode = 'personal' then a.personal_form else a.written_form end
    from public.conventity_ref_address_form a
   where a.nation_code = p_nation_code and a.role = p_role;
$fn$;

-- ---- 15) TAM SIRALAMA — V25 adim 1-7 ----------------------------------------
-- security_invoker = true ZORUNLU: aksi halde view, conventus_registrations'in
-- RLS'ini bypass eden bir okuma kanali olur.
-- Adim 5 rutbe tarihi (eski kazanir) · 6 ulus alfabetik (etkinligin sectigi
-- dilde) · 7 soyadi — bunlar ORDER BY kolonu, skora gomulmuyor.
drop view if exists public.conventus_precedence_v;
create view public.conventus_precedence_v
with (security_invoker = true) as
select
  r.id                as registration_id,
  r.event_id,
  r.first_name,
  r.last_name,
  r.nation_code,
  r.grade_code,
  r.capacity_key,
  r.represents_capacity_key,
  r.date_of_rank,
  r.is_guest_of_honour,
  public.conventity_precedence_score(r.title_key, r.capacity_key,
                                     r.represents_capacity_key, r.grade_code) as precedence_score,
  public.conventity_identity_string(rk.acronym, r.last_name, r.nation_code, rk.service) as identity_string,
  case when e.alpha_language = 'fr' then coalesce(n.name_fr, n.name_en) else n.name_en end as nation_sort,
  -- ev sahibi ulus ve onur konugu §2.2'ye gore ayri tutulur
  (r.nation_code is not distinct from e.host_nation) as is_host_nation,
  -- partnerler: 'after' ise NATO disi uluslar sona
  case when e.partner_placement = 'after' and n.bloc <> 'nato' then 1 else 0 end as partner_bucket
from public.conventus_registrations r
join public.conventus_managed_events e on e.id = r.event_id
left join public.conventity_ref_nation n on n.code_mil = r.nation_code
left join public.conventity_ref_rank   rk on rk.id     = r.rank_id;

comment on view public.conventus_precedence_v is
  'Protokol sirasi. Kullanim: order by precedence_score desc, date_of_rank asc nulls last, partner_bucket, nation_sort, last_name';

-- ---- 16) RLS ----------------------------------------------------------------
-- Referans verisi kaynagin kendi ifadesiyle "NON-SENSITIVE INFORMATION
-- RELEASABLE TO THE PUBLIC" — okuma herkese acik, yazma yalniz ekosistem admini.
do $cv$
declare t text;
begin
  foreach t in array array['conventity_ref_nation','conventity_ref_nato_grade',
                           'conventity_ref_rank','conventity_ref_capacity',
                           'conventity_ref_title','conventity_ref_organization',
                           'conventity_ref_precedence_list','conventity_ref_precedence_item',
                           'conventity_ref_dress_code','conventity_ref_address_form'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_read',  t);
    execute format('drop policy if exists %I on public.%I', t || '_write', t);
    execute format('create policy %I on public.%I for select to anon, authenticated using (true)',
                   t || '_read', t);
    execute format($p$
      create policy %I on public.%I for all to authenticated
      using (coalesce(public.conventity_is_admin('ecosystem'), false))
      with check (coalesce(public.conventity_is_admin('ecosystem'), false))
    $p$, t || '_write', t);
  end loop;
end $cv$;

-- ---- 17) YETKILER — 05 ve 07'deki kurallarla tutarli ------------------------
do $cv$
declare t text;
begin
  foreach t in array array['conventity_ref_nation','conventity_ref_nato_grade',
                           'conventity_ref_rank','conventity_ref_capacity',
                           'conventity_ref_title','conventity_ref_organization',
                           'conventity_ref_precedence_list','conventity_ref_precedence_item',
                           'conventity_ref_dress_code','conventity_ref_address_form'] loop
    execute format('revoke all on public.%I from public, anon', t);
    execute format('grant all    on public.%I to authenticated, service_role', t);
    execute format('grant select on public.%I to anon', t);
  end loop;
end $cv$;

-- View: 05'in kurali — anon/authenticated'a YAZMA yetkisi verilmez.
revoke all    on public.conventus_precedence_v from public, anon, authenticated;
grant  select on public.conventus_precedence_v to anon, authenticated, service_role;

do $cv$
declare s text;
begin
  for s in select sequencename from pg_sequences where schemaname='public'
            and sequencename like 'conventity_ref_%' loop
    execute format('revoke all on sequence public.%I from public, anon', s);
    execute format('grant usage, select on sequence public.%I to authenticated, service_role', s);
  end loop;
end $cv$;

revoke all on function public.conventity_precedence_score(text,text,text,text)   from public, anon;
revoke all on function public.conventus_registration_precedence(bigint)          from public, anon;
revoke all on function public.conventity_identity_string(text,text,text,text)    from public, anon;
revoke all on function public.conventity_salutation(text,text,text)              from public, anon;
grant execute on function public.conventity_precedence_score(text,text,text,text) to authenticated, service_role;
grant execute on function public.conventus_registration_precedence(bigint)        to authenticated, service_role;
grant execute on function public.conventity_identity_string(text,text,text,text)  to authenticated, service_role;
grant execute on function public.conventity_salutation(text,text,text)            to authenticated, service_role;

notify pgrst, 'reload schema';

-- ---- 18) DOGRULAMA — tek sorgu ----------------------------------------------
select
  (select count(*) from pg_tables where schemaname='public'
     and tablename like 'conventity_ref_%')                                   as "referans tablo (10)",
  (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relrowsecurity
     and c.relname like 'conventity_ref_%')                                   as "RLS acik (10)",
  (select count(*) from information_schema.columns where table_schema='public'
     and table_name='conventus_managed_events'
     and column_name in ('precedence_list','alpha_language','host_nation',
                         'partner_placement','dress_code_key','dress_season')) as "etkinlik kolonu (6)",
  (select count(*) from information_schema.columns where table_schema='public'
     and table_name='conventus_registrations'
     and column_name in ('nation_code','rank_id','grade_code','capacity_key','title_key',
                         'organization_key','date_of_rank','represents_capacity_key',
                         'representation_ref','is_guest_of_honour'))          as "kayit kolonu (10)",
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname in ('conventity_precedence_score',
       'conventus_registration_precedence','conventity_identity_string',
       'conventity_salutation'))                                              as "fonksiyon (4)",
  (select count(*) from pg_views v where v.schemaname='public'
     and v.viewname='conventus_precedence_v')                                 as "view (1)",
  -- view RLS'i bypass etmemeli
  (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relname='conventus_precedence_v'
     and coalesce(c.reloptions::text,'') like '%security_invoker=true%')      as "view guvenli (1)";
