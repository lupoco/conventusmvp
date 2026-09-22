-- Connectus gruplar+feed GERİ ALMA · 2026-07-23  (tablolar Faz-1'de; yalnız RPC katmanı)
drop function if exists public.connectus_post(uuid, text, text);
drop function if exists public.connectus_feed(uuid, int);
drop function if exists public.connectus_leave_group(uuid);
drop function if exists public.connectus_join_group(uuid);
drop function if exists public.connectus_create_group(text, text, text);
drop function if exists public.connectus_groups();
-- purpose_kind CHECK'i Faz-1 haline döndür (topic/community çıkar)
alter table public.conventity_cn_groups drop constraint if exists conventity_cn_groups_purpose_kind_check;
alter table public.conventity_cn_groups add constraint conventity_cn_groups_purpose_kind_check
  check (purpose_kind in ('problem','activity','challenge_area','event','org'));
notify pgrst, 'reload schema';
