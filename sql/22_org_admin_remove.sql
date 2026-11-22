-- ============================================================================
-- 22_org_admin_remove.sql  ·  .org üyeliğinde SİLME ve 30 GÜN kuralı
--
-- 1) conventity_org_admin_remove(id): /yonetim/ → Üyeler → "Sil". Üyelik satırı
--    silinir; adres için açılmış hesap da, yalnız bu iş için açıldıysa ve başka
--    hiçbir izi yoksa, silinir (org-invite işlevi tanımlama anında parolasız hesap
--    açar; satır silinince adres ortak hesap tablosunda kalmasın).
-- 2) conventity_org_purge(): 30 günde kabul edilmeyen tanımı VE onun için açılan
--    hesabı siler. Sunucuda, her gün kendiliğinden çalışır (pg_cron); yöneticinin
--    uygulamayı açmasına bağlı değildir. Üyelik sayfasındaki gizlilik özeti bunu
--    vaat eder; zamanlama kurulamadıysa bu dosya AÇIKÇA uyarır.
--
-- Hesap koruması üç yerde de aynıdır (conventity_org_forget ile birlikte):
-- parolası, e-posta dışında giriş sağlayıcısı, rolü, profili, başka bir .org üyelik
-- satırı ya da (hesaba ya da aynı e-postaya bağlı) kişi kaydı varsa hesap KALIR.
--
-- NEREDE ÇALIŞIR: conventity-prod → SQL Editor. Tekrar çalıştırılabilir.
-- Önce: 21_org_members.sql.  Geri alma: 22_org_admin_remove_ROLLBACK.sql
-- ============================================================================

do $cvguard$
declare n_prof bigint := 0;
begin
  if to_regclass('public.conventity_org_members') is null then
    raise exception E'\n\n  conventity_org_members yok — once 21_org_members.sql calistir.\n';
  end if;
  if to_regclass('public.convexus_profiles') is not null then
    select count(*) into n_prof from public.convexus_profiles;
  end if;
  if n_prof >= 100 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- ---- iç yardımcı: izsiz hesabı sil (kimseye çalıştırma izni verilmez) -------
create or replace function public.conventity_org__drop_account(p_email text, p_uid uuid)
returns boolean language plpgsql security definer set search_path = public, auth as $fn$
declare v_uid uuid := p_uid; v_email text := lower(p_email);
begin
  if v_uid is null then
    select u.id into v_uid from auth.users u where lower(u.email::text) = v_email limit 1;
  end if;
  if v_uid is null or v_uid = auth.uid() then return false; end if;
  if exists (select 1 from auth.users u where u.id = v_uid and coalesce(u.encrypted_password, '') <> '')
     or exists (select 1 from auth.identities i where i.user_id = v_uid and i.provider <> 'email')
     or exists (select 1 from conventity_org_members m where m.auth_user_id = v_uid or m.email = v_email)
     or exists (select 1 from conventity_roles r where r.auth_user_id = v_uid)
     or exists (select 1 from conventity_people p where p.auth_user_id = v_uid or lower(p.email) = v_email)
     or exists (select 1 from profiles p where p.id = v_uid) then
    return false;
  end if;
  begin
    delete from auth.users where id = v_uid;
  exception when others then
    return false;
  end;
  return true;
end
$fn$;

-- ---- 1) yönetici siler ------------------------------------------------------
create or replace function public.conventity_org_admin_remove(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth as $fn$
declare v_email text; v_uid uuid;
begin
  if not conventity_is_admin('ecosystem') then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  delete from conventity_org_members where id = p_id returning email, auth_user_id into v_email, v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'account_removed', conventity_org__drop_account(v_email, v_uid));
end
$fn$;

-- ---- 2) 30 gün: kabul edilmeyen tanım ve hesabı ------------------------------
create or replace function public.conventity_org_purge()
returns integer language plpgsql security definer set search_path = public, auth as $fn$
declare r record; n integer := 0;
begin
  for r in delete from conventity_org_members
            where status = 'invited' and auth_user_id is null and created_at < now() - interval '30 days'
            returning email
  loop
    perform conventity_org__drop_account(r.email, null);
    n := n + 1;
  end loop;
  return n;
end
$fn$;

revoke all on function public.conventity_org__drop_account(text, uuid) from public, anon, authenticated;
revoke all on function public.conventity_org_purge() from public, anon, authenticated;
revoke all on function public.conventity_org_admin_remove(uuid) from public, anon;
grant execute on function public.conventity_org_admin_remove(uuid) to authenticated;

-- ---- 3) günlük zamanlama (pg_cron) ----------------------------------------
do $cron$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise warning 'pg_cron kurulamadi: %', sqlerrm;
  end;
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'conventity_org_purge';
    perform cron.schedule('conventity_org_purge', '17 3 * * *', 'select public.conventity_org_purge()');
  else
    raise warning E'\n\n  ZAMANLAMA KURULAMADI: 30 gun kurali kendiliginden calismayacak.\n'
      '  Dashboard -> Database -> Extensions -> pg_cron acilip bu dosya yeniden calistirilmali;\n'
      '  yoksa uyelik ACILMAMALI (gizlilik ozeti 30 gun silmeyi vaat ediyor).\n';
  end if;
end $cron$;

notify pgrst, 'reload schema';

-- ---- 4) doğrulama: islev 3, pg_cron true olmalı ---------------------------
select (select count(*) from pg_proc where proname in ('conventity_org_admin_remove', 'conventity_org_purge', 'conventity_org__drop_account')) as islev,
       exists (select 1 from pg_extension where extname = 'pg_cron') as pg_cron;
