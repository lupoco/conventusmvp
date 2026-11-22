-- 22_org_admin_remove_ROLLBACK.sql  ·  22'yi geri alır. Veri silmez. pg_cron uzantısını kaldırmaz.
do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'conventity_org_purge';
  end if;
end $cron$;
drop function if exists public.conventity_org_purge();
drop function if exists public.conventity_org_admin_remove(uuid);
drop function if exists public.conventity_org__drop_account(text, uuid);
notify pgrst, 'reload schema';
