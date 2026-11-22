-- ============================================================================
-- 22_org_admin_remove.sql  ·  Yönetici bir .org üyeliğini SİLER
--
-- /yonetim/ → Üyeler → "Sil". Üyelik satırı silinir; adresle açılmış hesap da,
-- yalnız bu iş için açıldıysa ve başka hiçbir izi yoksa, silinir (org-invite
-- işlevi tanımlama anında parolasız hesap açar; satır silinince adres ortak
-- hesap tablosunda kalmasın). Koruma conventity_org_forget ile aynıdır:
-- parolası, e-posta dışında giriş sağlayıcısı, rolü, profili ya da (hesaba ya da
-- aynı e-postaya bağlı) kişi kaydı varsa hesap KALIR.
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

create or replace function public.conventity_org_admin_remove(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth as $fn$
declare
  v_email text;
  v_uid   uuid;
  v_gone  boolean := false;
begin
  if not conventity_is_admin('ecosystem') then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  delete from conventity_org_members where id = p_id returning email, auth_user_id into v_email, v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_uid is null then
    select u.id into v_uid from auth.users u where lower(u.email::text) = v_email limit 1;
  end if;
  if v_uid is not null and v_uid <> auth.uid()
     and not exists (select 1 from auth.users u where u.id = v_uid and coalesce(u.encrypted_password, '') <> '')
     and not exists (select 1 from auth.identities i where i.user_id = v_uid and i.provider <> 'email')
     and not exists (select 1 from conventity_roles r where r.auth_user_id = v_uid)
     and not exists (select 1 from conventity_people p where p.auth_user_id = v_uid or lower(p.email) = v_email)
     and not exists (select 1 from profiles p where p.id = v_uid) then
    begin
      delete from auth.users where id = v_uid;
      v_gone := true;
    exception when others then
      v_gone := false;
    end;
  end if;
  return jsonb_build_object('ok', true, 'account_removed', v_gone);
end
$fn$;

revoke all on function public.conventity_org_admin_remove(uuid) from public;
revoke all on function public.conventity_org_admin_remove(uuid) from anon;
grant execute on function public.conventity_org_admin_remove(uuid) to authenticated;

notify pgrst, 'reload schema';

select proname as islev, prosecdef as security_definer from pg_proc where proname = 'conventity_org_admin_remove';
