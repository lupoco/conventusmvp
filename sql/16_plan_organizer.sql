-- ============================================================================
-- 16_plan_organizer.sql  ·  Organizator rezervasyon taleplerini gorsun ve karara baglasin
--
-- DONGU YARIMDI: katilimci go-and-meet'ten talep gonderiyor (gm_plan satiri,
--   status='requested') ama organizatorun tarafinda karsiligi yoktu.
--
-- IKI ENGEL:
--   1) gmpl_organizer_read yalnizca `e.created_by = auth.uid()` diyor.
--      Etkinligi YONETEN ama OLUSTURMAMIS biri (activity/event_manager)
--      talepleri hic goremiyor. 12'de conventus_managed_events icin
--      duzeltilen ayni hata, burada gm_plan tarafinda duruyordu.
--   2) Organizator icin UPDATE politikasi YOK. Yalniz saglayici ve
--      katilimcinin kendisi durumu degistirebiliyor; organizator onaylayamiyor.
--
-- NEDEN POLITIKA, NEDEN RPC DEGIL: gm_plan'de yazma zaten politikayla
--   yonetiliyor (gmpl_user_*, gmpl_provider_update). Burada RPC eklemek ayni
--   tabloda iki farkli yetki mekanizmasi olustururdu. conventus_managed_events
--   tarafinda RPC gerekmisti cunku orada UPDATE politikasi sahibe kilitliydi
--   ve gevsetmek butun alanlari acardi; gm_plan'de boyle bir risk yok.
--
-- KATILIMCI ONAYLANMIS TALEBI GERI ALAMAZ: gmpl_user_delete zaten
--   status='requested' sarti koyuyor. Bu KASITLI ve dokunulmadi — onaydan
--   sonra iptal organizatorun karari olmali.
--
-- KULLANIM: 15'ten sonra. Tekrar calistirilabilir.
-- ============================================================================

do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.gm_plan') is null then
    raise exception E'\n\n  gm_plan yok — once 02_clean_install.sql calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) OKUMA: yoneten gorsun (olusturan sarti yetersizdi) -----------------
drop policy if exists gmpl_organizer_read on public.gm_plan;
create policy gmpl_organizer_read on public.gm_plan
  as permissive for select to authenticated
  using (exists (select 1 from public.conventus_managed_events e
                  where e.id = gm_plan.event_id
                    and (e.created_by = auth.uid()
                         or coalesce(public.conventity_can_manage_event(e.activity_id), false))));

-- ---- 2) KARAR: organizator onaylasin / iptal etsin --------------------------
-- WITH CHECK yalnizca CHECK kisitindaki uc degere izin veriyor; organizator
-- satiri baska bir etkinlige tasiyamasin diye USING sarti WITH CHECK'te de var.
drop policy if exists gmpl_organizer_update on public.gm_plan;
create policy gmpl_organizer_update on public.gm_plan
  as permissive for update to authenticated
  using (exists (select 1 from public.conventus_managed_events e
                  where e.id = gm_plan.event_id
                    and (e.created_by = auth.uid()
                         or coalesce(public.conventity_can_manage_event(e.activity_id), false))))
  with check (
    status = any (array['requested','confirmed','cancelled'])
    and exists (select 1 from public.conventus_managed_events e
                 where e.id = gm_plan.event_id
                   and (e.created_by = auth.uid()
                        or coalesce(public.conventity_can_manage_event(e.activity_id), false)))
  );

notify pgrst, 'reload schema';

-- ---- 3) DOGRULAMA -----------------------------------------------------------
select
  (select count(*) from pg_policies where schemaname='public' and tablename='gm_plan'
     and policyname='gmpl_organizer_read' and qual like '%can_manage_event%')   as "okuma yoneticiyi taniyor (1)",
  (select count(*) from pg_policies where schemaname='public' and tablename='gm_plan'
     and policyname='gmpl_organizer_update')                                    as "organizator karar yetkisi (1)",
  (select count(*) from pg_policies where schemaname='public' and tablename='gm_plan'
     and cmd='DELETE' and qual like '%requested%')                              as "onaylanmis talep silinemez (1)",
  (select count(*) from pg_policies where schemaname='public' and tablename='gm_plan')
                                                                                as "toplam politika (8)";
