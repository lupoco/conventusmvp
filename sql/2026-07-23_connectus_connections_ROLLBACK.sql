-- Connectus bağlantılar GERİ ALMA · 2026-07-23
drop function if exists public.connectus_connections();
drop function if exists public.connectus_respond(uuid, boolean);
drop function if exists public.connectus_connect(uuid, text);
drop table if exists public.conventity_cn_connections cascade;
notify pgrst, 'reload schema';
