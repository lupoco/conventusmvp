-- ============================================================================
-- 15_event_services.sql  ·  Hizmet anahtarlari tek yerden yonetilsin
--
-- NEDEN: hangi Go & Meet bolumunun katilimciya gosterilecegi
--   conventus_managed_events.gm_services'te duruyor ama organizator onu
--   ancak Genel sekmesinden degistirebiliyordu. Envanteri girdigi yerde
--   anahtari gorememek "kalem girdim ama gorunmuyor" tuzagini uretiyordu.
--
-- NEDEN RPC: 12'deki gerekcenin ayni — conventus_managed_events'te UPDATE
--   politikasi yalniz created_by ve is_cv_admin. Etkinligi yoneten ama
--   olusturmamis biri dogrudan update calistirirsa 0 satir gunceller ve
--   HICBIR HATA ALMAZ. Sessiz basarisizlik yerine yetkiyi kendi kontrol eden
--   bir fonksiyon.
--
-- KULTUR TURU ve ES PROGRAMI TEK BAYRAK PAYLASIR (culture_spouse). Arayuzde
--   dort anahtar gosterip birini kapatinca digerinin de kapanmasi sinsi
--   olurdu; bu yuzden UC anahtar gosteriliyor ve kalemi olmayan bolum
--   katilimciya hic cizilmiyor. Ayri bir 'spouse' degeri eklemek CHECK'i ve
--   mevcut satirlarin anlamini degistirecegi icin tercih edilmedi.
--
-- KULLANIM: 14'ten sonra. Tekrar calistirilabilir.
-- ============================================================================

do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.conventus_managed_events') is null then
    raise exception E'\n\n  Sema yok — once 02_clean_install.sql calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n', n_prof;
  end if;
end $cvguard$;

create or replace function public.conventus_set_event_services(
  p_activity_id uuid,
  p_services    text[]
) returns void
language plpgsql
volatile
security definer
set search_path to 'public'
as $fn$
declare
  allowed constant text[] := array['accommodation','transfer_car','culture_spouse','offers'];
  bad text;
begin
  if not coalesce(public.conventity_can_manage_event(p_activity_id), false) then
    raise exception 'yetki yok: bu etkinligi yonetemezsiniz' using errcode = '42501';
  end if;
  if p_services is null then
    raise exception 'hizmet listesi bos olamaz (bos dizi gonderin)' using errcode = '22004';
  end if;

  -- CHECK kisiti zaten var ama hata mesaji anlasilir olsun: hangi deger yanlis?
  select x into bad from unnest(p_services) x where x <> all(allowed) limit 1;
  if bad is not null then
    raise exception 'gecersiz hizmet: % (izinli: %)', bad, array_to_string(allowed,', ')
      using errcode = '23514';
  end if;

  update public.conventus_managed_events
     set gm_services = (select coalesce(array_agg(distinct x), '{}'::text[]) from unnest(p_services) x)
   where activity_id = p_activity_id;

  if not found then
    raise exception 'etkinlik bulunamadi: %', p_activity_id using errcode = 'P0002';
  end if;
end
$fn$;

revoke all on function public.conventus_set_event_services(uuid,text[]) from public, anon;
grant execute on function public.conventus_set_event_services(uuid,text[]) to authenticated, service_role;

notify pgrst, 'reload schema';

select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='conventus_set_event_services')    as "RPC (1)",
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='conventus_set_event_services'
       and has_function_privilege('anon', p.oid, 'execute'))                   as "anon cagirabilir (0)",
  (select array_to_string(gm_services,', ') from public.conventus_managed_events
     where code='LANDCOM-CONF-2026')                                           as "LANDCOM hizmetleri";
