-- ============================================================================
-- 13_protocol_optional.sql  ·  Protokol her etkinlikte zorunlu DEGIL
--
-- NEDEN: her etkinlik VIP degil. Cogunlukla OF-5 ve alti katilimcilarla
--   ilerlenen etkinliklerde rutbe/sifat/rutbe tarihi sormak gereksiz surtunme
--   yaratiyor. Protokol motoru kalsin ama ETKINLIK BAZINDA acilip kapansin.
--
-- TASARIM — NEDEN YENI BIR ALAN SISTEMI KURMUYORUZ:
--   Hangi alanin sorulacagi zaten `registration_field_defs` ile yonetiliyor
--   (core alanlar: visible/required). Protokol alanlari icin ikinci bir
--   yapilandirma sistemi kurmak ayni seyi iki yerde tutmak olurdu. Bu dosya
--   yalniz ANA ANAHTARI ekliyor; alan bazinda gorunurluk/zorunluluk yine
--   registration_field_defs'ten geliyor.
--
--   protocol_enabled = false  -> sihirbaz rutbe/sifat/rutbe tarihi SORMAZ,
--                                protokol sekmesi "kapali" der, sira uretilmez
--   protocol_enabled = true   -> alanlar sorulur; hangisi zorunlu,
--                                registration_field_defs'e bakar
--
-- VARSAYILAN NEDEN false: cogunluk sade etkinlik. Protokol isteyen acar.
--   LANDCOM-CONF-2026 asagida acik olarak true yapiliyor.
--
-- ELLE DOLDURMA: referans listesi olsa bile katilimci "Diger (elle yazin)"
--   secebilir — bu arayuz tarafinda, rutbede zaten var, ulusa da eklendi.
--   Referans okunamazsa serbest metne dusme davranisi de korunuyor.
--
-- KULLANIM: 12'den sonra. Tekrar calistirilabilir.
-- ============================================================================

do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.conventity_ref_nation') is null then
    raise exception E'\n\n  Referans katmani yok — once 10, 11 ve 12 calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) ANA ANAHTAR ----------------------------------------------------------
alter table public.conventus_managed_events
  add column if not exists protocol_enabled boolean not null default false;

comment on column public.conventus_managed_events.protocol_enabled is
  'Protokol sirasi bu etkinlikte kullanilsin mi. false ise sihirbaz rutbe/sifat/rutbe tarihi sormaz.';

-- ---- 2) RPC'YE EKLE ----------------------------------------------------------
-- 12'deki imza degisiyor: once eskisini dusur, yoksa iki asiri yukleme kalir
-- ve PostgREST hangisini cagiracagini bilemez.
drop function if exists public.conventus_set_event_protocol(uuid,text,text,text,text,text,text);

create or replace function public.conventus_set_event_protocol(
  p_activity_id       uuid,
  p_protocol_enabled  boolean default null,
  p_precedence_list   text default null,
  p_alpha_language    text default null,
  p_host_nation       text default null,
  p_partner_placement text default null,
  p_dress_code_key    text default null,
  p_dress_season      text default null
) returns void
language plpgsql
volatile
security definer
set search_path to 'public'
as $fn$
begin
  if not coalesce(public.conventity_can_manage_event(p_activity_id), false) then
    raise exception 'yetki yok: bu etkinligi yonetemezsiniz' using errcode = '42501';
  end if;

  if p_precedence_list is not null and not exists (
       select 1 from public.conventity_ref_precedence_list where key = p_precedence_list) then
    raise exception 'gecersiz oncelik listesi: %', p_precedence_list using errcode = '23514';
  end if;
  if p_host_nation is not null and not exists (
       select 1 from public.conventity_ref_nation where code_mil = p_host_nation) then
    raise exception 'gecersiz ev sahibi ulus: %', p_host_nation using errcode = '23514';
  end if;
  if p_dress_code_key is not null and not exists (
       select 1 from public.conventity_ref_dress_code where key = p_dress_code_key) then
    raise exception 'gecersiz kiyafet kademesi: %', p_dress_code_key using errcode = '23514';
  end if;
  if p_alpha_language is not null and p_alpha_language not in ('en','fr') then
    raise exception 'alfabetik sira dili en veya fr olmali' using errcode = '23514';
  end if;
  if p_partner_placement is not null and p_partner_placement not in ('interleave','after') then
    raise exception 'partner yerlesimi interleave veya after olmali' using errcode = '23514';
  end if;
  if p_dress_season is not null and p_dress_season not in ('winter','summer') then
    raise exception 'mevsim winter veya summer olmali' using errcode = '23514';
  end if;

  update public.conventus_managed_events
     set protocol_enabled  = coalesce(p_protocol_enabled,  protocol_enabled),
         precedence_list   = coalesce(p_precedence_list,   precedence_list),
         alpha_language    = coalesce(p_alpha_language,    alpha_language),
         host_nation       = p_host_nation,
         partner_placement = coalesce(p_partner_placement, partner_placement),
         dress_code_key    = p_dress_code_key,
         dress_season      = p_dress_season
   where activity_id = p_activity_id;

  if not found then
    raise exception 'etkinlik bulunamadi: %', p_activity_id using errcode = 'P0002';
  end if;
end
$fn$;

revoke all on function public.conventus_set_event_protocol(uuid,boolean,text,text,text,text,text,text) from public, anon;
grant execute on function public.conventus_set_event_protocol(uuid,boolean,text,text,text,text,text,text) to authenticated, service_role;

-- ---- 3) LANDCOM: protokol acik ----------------------------------------------
update public.conventus_managed_events
   set protocol_enabled = true
 where code = 'LANDCOM-CONF-2026';

notify pgrst, 'reload schema';

-- ---- 4) DOGRULAMA -----------------------------------------------------------
select
  (select count(*) from information_schema.columns where table_schema='public'
     and table_name='conventus_managed_events' and column_name='protocol_enabled')  as "kolon (1)",
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='conventus_set_event_protocol')          as "RPC asiri yukleme (1 olmali)",
  (select coalesce(bool_or(protocol_enabled),false)::text from public.conventus_managed_events
     where code='LANDCOM-CONF-2026')                                                 as "LANDCOM acik",
  (select count(*) from public.conventus_managed_events where protocol_enabled)      as "protokollu etkinlik";
