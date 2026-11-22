-- 20_admin_users_ROLLBACK.sql  ·  20'yi geri alır. Veri silmez.
drop function if exists public.conventity_admin_users();
notify pgrst, 'reload schema';
