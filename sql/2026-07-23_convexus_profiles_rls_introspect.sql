-- ============================================================================
-- convexus_profiles RLS — KEŞİF (salt-okunur)  ·  AÇIK İŞLER #2
-- 2026-07-23
--
-- Amaç: DDL yazmadan önce convexus_profiles'in GERÇEK canlı RLS durumunu görmek.
-- Hiçbir şeyi değiştirmez. Supabase SQL Editor'de çalıştır, HER sorgunun
-- çıktısını geri yapıştır — sertleştirme + doğru rollback buna göre kesinleşir.
-- (Claude bu ortamdan Supabase'e ulaşamıyor — proxy allowlist dışı.)
-- ============================================================================

-- 1) convexus_profiles — kolonlar (owner_id tipi/nullable doğrula) -----------
select ordinal_position, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public' and table_name='convexus_profiles'
order by ordinal_position;

-- 2) RLS etkin mi? (relrowsecurity=true olmalı; forcerowsecurity de not al) ---
select c.relname, c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname in ('convexus_profiles','convexus_profile_domains','convexus_profile_focus_areas')
order by c.relname;

-- 3) ⭐ MEVCUT POLİTİKALAR — interim'i burada göreceğiz -----------------------
--    (owner_id IS NULL / using(true) / cmd=ALL olan permissive politika şüpheli)
select policyname, cmd, permissive, roles, qual, with_check
from pg_policies
where schemaname='public'
  and tablename in ('convexus_profiles','convexus_profile_domains','convexus_profile_focus_areas')
order by tablename, cmd, policyname;

-- 4) Admin fonksiyon gövdeleri — conventity_roles'tan mı okuyor? -------------
--    (CLAUDE.md: is_convexus_admin/is_cv_admin gövdeleri roles'a çevrildi)
select p.proname, pg_get_functiondef(p.oid) as body
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('is_convexus_admin','is_cv_admin');

-- 5) Tablo grant'leri — anon/authenticated hangi DML'e sahip? ---------------
--    (grant genişse gerçek koruma yalnız RLS'ten gelir)
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema='public' and table_name='convexus_profiles'
  and grantee in ('anon','authenticated','public')
order by grantee, privilege_type;

-- 6) Seed profilleri — kaç kayıt owner_id IS NULL? (beklenen ~147) ----------
select count(*) filter (where owner_id is null)  as seed_owner_null,
       count(*) filter (where owner_id is not null) as owned,
       count(*) as toplam
from public.convexus_profiles;

-- ============================================================================
-- ÇIKTIYI YAPIŞTIR. Sonra kesinleşecek:
--   • 2026-07-23_convexus_profiles_rls_harden.sql         (rol-tabanlı)
--   • 2026-07-23_convexus_profiles_rls_harden_ROLLBACK.sql (interim'e dönüş)
-- ============================================================================
