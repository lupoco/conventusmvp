-- ============================================================================
-- 17_rls_manager_gaps.sql  ·  "sahibi" / "yoneteni" karisikligi — toplu tarama sonucu
--
-- TARAMA: public semadaki 239 politika, event_id tasiyan tablolar uzerinde
--   (tablo, islem) basina "conventity_can_manage_event cagiran politika var mi"
--   diye tarandi. Yetkiyi yalniz `created_by = auth.uid()` ile tanimlayan ve
--   yonetici karsiligi OLMAYAN uc tablo bulundu.
--
-- YANLIS ALARMLAR (kontrol edildi, HATA DEGIL):
--   conventus_registrations : reg_manager_read / reg_manager_update zaten var.
--     Sahiplik politikalari gereksiz tekrar; politikalar OR'landigi icin
--     zarari yok.
--   gm_inventory · gm_offers · gm_plan(provider) : buradaki "sahiplik"
--     SAGLAYICI sahipligi (gm_providers.owner_user_id) ve KASITLI.
--   conventus_documents · conventus_event_* : yonetici politikalari mevcut.
--
-- BULUNAN UC ACIK — hicbirinde hata mesaji yok, sessizce bos liste
-- ya da sessiz basarisizlik olarak gorunurler:
--   1) conventus_sessions      INSERT/UPDATE/DELETE + yayimlanmamis SELECT
--      Etkinligi yoneten ama olusturmamis biri AJANDAYI duzenleyemiyor ve
--      kendi taslaklarini goremiyor (yalniz is_published=true olanlari).
--   2) conventus_announcements INSERT/UPDATE/DELETE
--      Duyurulari OKUYOR (ann_manager_read var) ama yazamiyor.
--   3) conventus_invitations   ALL
--      Yetki `created_by OR is_cv_admin`; yonetici davetleri yonetemiyor.
--
-- YAKLASIM: mevcut sahiplik politikalari SILINMIYOR, yaninа yonetici
--   politikasi ekleniyor. Permissive politikalar OR'lanir; silmek gereksiz
--   risk olurdu. Sonuc: olusturan da yoneten de yapabiliyor.
--
-- 07 NOTU: eklenen politikalar yalniz conventity_can_manage_event cagiriyor;
--   zaten turetilmis beyaz listede. 07'yi tekrar calistirmak GEREKMIYOR.
--
-- KULLANIM: 16'dan sonra. Tekrar calistirilabilir.
-- ============================================================================

do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.conventus_sessions') is null then
    raise exception E'\n\n  Sema yok — once 02_clean_install.sql calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- Uc tablo da ayni sekilde etkinlige bagli: event_id -> managed_events.activity_id
do $cv$
declare t text;
begin
  foreach t in array array['conventus_sessions','conventus_announcements','conventus_invitations'] loop
    execute format('drop policy if exists %I on public.%I', t || '_manager_all', t);
    execute format($p$
      create policy %I on public.%I as permissive for all to authenticated
      using (exists (select 1 from public.conventus_managed_events e
                      where e.id = %I.event_id
                        and coalesce(public.conventity_can_manage_event(e.activity_id), false)))
      with check (exists (select 1 from public.conventus_managed_events e
                      where e.id = %I.event_id
                        and coalesce(public.conventity_can_manage_event(e.activity_id), false)))
    $p$, t || '_manager_all', t, t, t);
  end loop;
end $cv$;

notify pgrst, 'reload schema';

-- ---- DOGRULAMA: acik kalan var mi? ------------------------------------------
-- DIKKAT: `for all` politikasi pg_policies'e cmd='ALL' olarak yazilir. Islem
-- basina gruplarken INSERT satiri kendi ALL kapsayicisini GORMEZ; ilk surumde
-- bu yuzden duzelttigimiz tablolar hala "acik" gorunuyordu. Asagidaki sorgu
-- ALL politikalarini her islemin kapsayicisi sayiyor.
with et as (
  select distinct c.relname tbl from pg_attribute a
   join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind='r' and a.attnum>0 and not a.attisdropped
     and a.attname='event_id'
), p as (
  select tablename, cmd, coalesce(qual,'')||' '||coalesce(with_check,'') g
    from pg_policies where schemaname='public'
), islem as (
  -- tabloda gecen her gercek islem
  select distinct tablename, cmd from p join et on et.tbl=p.tablename where cmd <> 'ALL'
), acik as (
  select i.tablename, i.cmd
    from islem i
   where exists (select 1 from p join et on et.tbl=p.tablename
                  where p.tablename=i.tablename and p.cmd=i.cmd
                    and p.g ~ 'created_by\s*=\s*auth\.uid')
     and not exists (select 1 from p
                      where p.tablename=i.tablename
                        and (p.cmd=i.cmd or p.cmd='ALL')
                        and p.g like '%can_manage_event%')
)
select
  (select count(*) from acik)                                                   as "acik kalan (0 olmali)",
  (select coalesce(string_agg(tablename||'.'||cmd, ', '), '—') from acik)       as "acik olanlar",
  (select count(*) from pg_policies where schemaname='public'
     and policyname in ('conventus_sessions_manager_all',
                        'conventus_announcements_manager_all',
                        'conventus_invitations_manager_all'))                    as "eklenen politika (3)";
