-- ============================================================================
-- 14_event_logistics.sql  ·  Organizator kendi etkinliginin lojistigini girebilsin
--
-- SORUN: gm_inventory'ye yalniz SAGLAYICI SAHIBI yazabiliyor (gmi_owner_all).
--   Organizator kendi etkinligine otel/arac/tur ekleyemiyor. Ustelik
--   provider_id NOT NULL, yani "Hotel Kordon" yazmak icin once bir saglayici
--   kaydi acmak, onu akredite etmek gerekiyor. Saglayici portali hazir
--   olmadan LANDCOM'un lojistigi girilemiyor.
--
-- COZUM — en kucuk degisiklik:
--   1) provider_id opsiyonel olsun + provider_name serbest metin alani.
--      Organizator oteli adiyla girer; ileride gercek saglayici sisteme
--      girerse provider_id baglanir. Boylece "once saglayici kaydi ac,
--      sonra akredite et" zinciri tamamen ortadan kalkiyor.
--   2) Organizatore kendi etkinliginin envanterinde tam yetki.
--   3) Okuma politikalarina "gorunur bir etkinlige bagli" dali eklendi.
--      Gorunurluk karari conventus_managed_events'in KENDI RLS'ine birakiliyor
--      (09'daki desenin ayni) — kural tek yerde kaliyor, burada kopyalanmiyor.
--
-- NEDEN accredited BAYRAGINA DOKUNMUYORUZ: o ekosistem admininin karari ve
--   kamusal saglayici vitrinini (gm_providers_public) besliyor. Organizatorun
--   kendi etkinligi icin girdigi otel, ekosistem capinda "akredite saglayici"
--   anlamina gelmemeli. Iki kavram ayri kalsin.
--
-- 07 NOTU: yeni politikalar conventity_can_manage_event ve
--   gm_provider_accredited cagiriyor; ikisi de mevcut politikalarda kullanildigi
--   icin turetilmis beyaz listede. 07'yi tekrar calistirmak GEREKMIYOR.
--
-- KULLANIM: 13'ten sonra. Tekrar calistirilabilir.
-- ============================================================================

do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.gm_inventory') is null then
    raise exception E'\n\n  gm_inventory yok — once 02_clean_install.sql calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) SAGLAYICI OPSIYONEL -------------------------------------------------
alter table public.gm_inventory alter column provider_id drop not null;
alter table public.gm_inventory add column if not exists provider_name text;

comment on column public.gm_inventory.provider_name is
  'Saglayici sisteme kayitli degilse adi. provider_id doluysa o kazanir.';

-- ---- 2) ORGANIZATOR YETKISI -------------------------------------------------
drop policy if exists gmi_organizer_all on public.gm_inventory;
create policy gmi_organizer_all on public.gm_inventory
  as permissive for all to authenticated
  using (exists (select 1 from public.conventus_managed_events e
                  where e.id = gm_inventory.event_id
                    and public.conventity_can_manage_event(e.activity_id)))
  with check (exists (select 1 from public.conventus_managed_events e
                  where e.id = gm_inventory.event_id
                    and public.conventity_can_manage_event(e.activity_id)));

-- ---- 3) OKUMA: etkinlige bagli kalemler de gorunsun -------------------------
-- Alt sorgu conventus_managed_events'in kendi RLS'ine tabi; etkinlik
-- gorunmuyorsa kalem de gorunmez. Gorunurluk kurali tek yerde.
drop policy if exists gmi_anon_showcase on public.gm_inventory;
create policy gmi_anon_showcase on public.gm_inventory
  as permissive for select to anon
  using (
    is_active = true
    and (
      coalesce(public.gm_provider_accredited(provider_id), false)
      or exists (select 1 from public.conventus_managed_events e where e.id = gm_inventory.event_id)
    )
  );

drop policy if exists gmi_auth_read_active on public.gm_inventory;
create policy gmi_auth_read_active on public.gm_inventory
  as permissive for select to authenticated
  using (
    is_active = true
    and (
      exists (select 1 from public.gm_providers p
               where p.id = gm_inventory.provider_id and p.accredited = true)
      or exists (select 1 from public.conventus_managed_events e where e.id = gm_inventory.event_id)
    )
  );

notify pgrst, 'reload schema';

-- ---- 4) DOGRULAMA -----------------------------------------------------------
select
  (select count(*) from information_schema.columns where table_schema='public'
     and table_name='gm_inventory' and column_name='provider_name')            as "provider_name (1)",
  (select (is_nullable='YES')::text from information_schema.columns where table_schema='public'
     and table_name='gm_inventory' and column_name='provider_id')              as "provider_id opsiyonel",
  (select count(*) from pg_policies where schemaname='public'
     and tablename='gm_inventory' and policyname='gmi_organizer_all')          as "organizator yetkisi (1)",
  (select count(*) from pg_policies where schemaname='public'
     and tablename='gm_inventory' and policyname='gmi_anon_showcase'
     and qual like '%conventus_managed_events%')                               as "anon etkinlik dali (1)",
  (select count(*) from pg_policies where schemaname='public'
     and tablename='gm_inventory')                                             as "toplam politika (4)";
