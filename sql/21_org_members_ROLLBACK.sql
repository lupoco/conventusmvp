-- 21_org_members_ROLLBACK.sql  ·  21'i geri alır.
-- DİKKAT: üye tablosunu ve içindeki bütün üyelikleri SİLER. Hesaplar (auth.users) kalır.
drop function if exists public.conventity_org_leave();
drop function if exists public.conventity_org_set_bulletin(boolean);
drop function if exists public.conventity_org_join(text, boolean, text);
drop function if exists public.conventity_org_me();
drop function if exists public.conventity_org_open();
drop table if exists public.conventity_org_members;
drop table if exists public.conventity_org_settings;
notify pgrst, 'reload schema';
