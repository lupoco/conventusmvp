-- ============================================================================
-- 12_protocol_ui.sql  ·  Dilim 2B — protokol arayuzunun veri tarafi
--
-- 10/11 verinin ve motorun tamamini kurdu ama arayuz iki yerde duvara carpiyor.
-- Etkinligi YONETEBILEN ama OLUSTURMAMIS bir kullanici (activity/event_manager):
--
--   1) Etkinligi GUNCELLEYEMIYOR. conventus_managed_events'te UPDATE politikasi
--      yalniz created_by ve is_cv_admin. Protokol ayarini dogrudan update ile
--      yazmak bu kullanicida 0 satir gunceller ve SESSIZCE basarili gorunur.
--      Cozum: logistics'teki desenin ayni — SECURITY DEFINER RPC, ilk is guard.
--
--   2) Etkinligi GOREMIYOR. SELECT icin tek genel politika
--      "events: public read open" (registration_open = true). Kayit kapaninca
--      yonetici kendi etkinligini kaybediyor; conventus_precedence_v de
--      managed_events'e join yaptigi icin BOS DONUYOR.
--      Cozum: yoneticiye acik bir SELECT politikasi + RESTRICTIVE gorunurluk
--      kapisina yonetici sarti.
--
-- 07 NOTU: eklenen politikalar yalniz conventity_can_manage_event cagiriyor;
--   o zaten turetilmis beyaz listede (anon=true dogrulandi). 07'yi tekrar
--   calistirmak GEREKMIYOR.
--
-- KULLANIM: 11'den sonra. Tekrar calistirilabilir.
-- ============================================================================

do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.conventity_ref_nation') is null then
    raise exception E'\n\n  Referans katmani yok — once 10 ve 11 calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) YONETICI ETKINLIGINI GORSUN ----------------------------------------
-- coalesce: activity_id bos olan eski satirlarda fonksiyon NULL donebilir;
-- RESTRICTIVE politikada NULL satiri eler ama niyeti acik yazmak daha iyi.
drop policy if exists cme_manager_read on public.conventus_managed_events;
create policy cme_manager_read on public.conventus_managed_events
  as permissive for select to authenticated
  using (coalesce(public.conventity_can_manage_event(activity_id), false));

-- RESTRICTIVE kapi: mevcut sartlara yoneticiyi EKLE (daraltma yok, genisletme var).
drop policy if exists cme_visibility_gate on public.conventus_managed_events;
create policy cme_visibility_gate on public.conventus_managed_events
  as restrictive for select to public
  using (
    visibility = 'public'
    or created_by = auth.uid()
    or public.is_cv_admin()
    or public.cv_event_access(id)
    or coalesce(public.conventity_can_manage_event(activity_id), false)
  );

-- ---- 2) PROTOKOL AYARINI KAYDET --------------------------------------------
-- Dogrudan UPDATE yerine RPC: yetkiyi tek yerde kontrol eder ve degerleri
-- referans tablolarina karsi DOGRULAR. Gecersiz deger sessizce yazilmaz —
-- 10'da bu kolonlara FK koymadik (referans verisi degisince etkinlik
-- kirilmasin diye), dogrulama bu yuzden burada.
create or replace function public.conventus_set_event_protocol(
  p_activity_id     uuid,
  p_precedence_list text default null,
  p_alpha_language  text default null,
  p_host_nation     text default null,
  p_partner_placement text default null,
  p_dress_code_key  text default null,
  p_dress_season    text default null
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
     set precedence_list   = coalesce(p_precedence_list,   precedence_list),
         alpha_language    = coalesce(p_alpha_language,    alpha_language),
         host_nation       = p_host_nation,          -- bosaltilabilmeli
         partner_placement = coalesce(p_partner_placement, partner_placement),
         dress_code_key    = p_dress_code_key,       -- bosaltilabilmeli
         dress_season      = p_dress_season          -- bosaltilabilmeli
   where activity_id = p_activity_id;

  if not found then
    raise exception 'etkinlik bulunamadi: %', p_activity_id using errcode = 'P0002';
  end if;
end
$fn$;

revoke all on function public.conventus_set_event_protocol(uuid,text,text,text,text,text,text) from public, anon;
grant execute on function public.conventus_set_event_protocol(uuid,text,text,text,text,text,text) to authenticated, service_role;

notify pgrst, 'reload schema';

-- ---- 3) DOGRULAMA -----------------------------------------------------------
select
  (select count(*) from pg_policies where schemaname='public'
     and tablename='conventus_managed_events' and policyname='cme_manager_read')      as "yonetici okuma (1)",
  (select count(*) from pg_policies where schemaname='public'
     and tablename='conventus_managed_events' and policyname='cme_visibility_gate'
     and qual like '%can_manage_event%')                                              as "kapi yoneticiyi taniyor (1)",
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='conventus_set_event_protocol')           as "RPC (1)",
  (select has_function_privilege('anon', p.oid, 'execute')::int
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='conventus_set_event_protocol')           as "anon cagirabilir (0)";
