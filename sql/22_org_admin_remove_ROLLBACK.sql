-- 22_org_admin_remove_ROLLBACK.sql  ·  22'yi geri alır. Veri silmez.
drop function if exists public.conventity_org_admin_remove(uuid);
notify pgrst, 'reload schema';
