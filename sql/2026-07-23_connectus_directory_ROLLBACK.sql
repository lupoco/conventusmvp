-- Connectus directory + demo seed GERİ ALMA · 2026-07-23
drop function if exists public.connectus_directory(int);
drop function if exists public.connectus_my_profile();
-- demo seed'i kaldır (yalnız seed kaynaklı kayıtlar)
delete from public.conventity_cn_expertise
  where person_id in (select id from public.conventity_people where source_ref like 'seed:cn:%');
delete from public.conventity_people where source_ref like 'seed:cn:%';
notify pgrst, 'reload schema';
