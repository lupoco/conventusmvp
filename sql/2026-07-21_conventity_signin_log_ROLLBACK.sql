-- ============================================================
-- GERİ ALMA — Conventity giriş kaydı (sign-in log)
-- 2026-07-21
-- 2026-07-21_conventity_signin_log.sql'i tamamen geri alır.
-- ============================================================

drop policy if exists conv_signin_insert_self on public.conventity_signin_log;
drop policy if exists conv_signin_select      on public.conventity_signin_log;

drop table if exists public.conventity_signin_log;

notify pgrst, 'reload schema';
