-- ROLLBACK — Connectus kurumsal sayfa detay RPC'si (2026-07-24)
drop function if exists public.connectus_org_detail(uuid);
notify pgrst, 'reload schema';
