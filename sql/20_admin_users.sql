-- ============================================================================
-- 20_admin_users.sql  ·  Yönetim uygulaması için hesap listesi
--
-- /yonetim/ → Kişiler sekmesi hesapları göstermeli; ama auth.users istemciden
-- okunamaz, profiles ve conventity_people ise her hesap için dolu değildir.
-- Bu dosya tek bir işlev ekler: conventity_admin_users(). Yalnız ekosistem
-- yöneticisi çağırınca satır döner; başkası için boş döner. Döndürdüğü alanlar:
-- hesap kimliği, e-posta, kayıt tarihi, son giriş. Parola özeti, telefon ve
-- diğer auth alanları döndürülmez. Veri değiştirmez (STABLE).
--
-- NEREDE ÇALIŞIR: conventity-prod → SQL Editor. Tekrar çalıştırılabilir.
-- Geri alma: 20_admin_users_ROLLBACK.sql
-- ============================================================================

-- ---- 0) yanlış proje / eksik şema koruması --------------------------------
do $cvguard$
declare n_prof bigint := 0;
begin
  if to_regprocedure('public.conventity_is_admin(text)') is null then
    raise exception E'\n\n  conventity_is_admin(text) yok — once 02_clean_install.sql calistir.\n';
  end if;
  if to_regclass('public.convexus_profiles') is not null then
    select count(*) into n_prof from public.convexus_profiles;
  end if;
  if n_prof >= 100 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) işlev --------------------------------------------------------------
create or replace function public.conventity_admin_users()
returns table (id uuid, email text, created_at timestamptz, last_sign_in_at timestamptz)
language sql
stable
security definer
set search_path = public, auth
as $fn$
  select u.id, u.email::text, u.created_at, u.last_sign_in_at
    from auth.users u
   where public.conventity_is_admin('ecosystem')
   order by u.created_at desc
   limit 2000;
$fn$;

revoke all on function public.conventity_admin_users() from public;
revoke all on function public.conventity_admin_users() from anon;
grant execute on function public.conventity_admin_users() to authenticated;

-- ---- 2) PostgREST şema önbelleği -----------------------------------------
notify pgrst, 'reload schema';

-- ---- 3) doğrulama ----------------------------------------------------------
select proname as islev, prosecdef as security_definer
  from pg_proc where proname = 'conventity_admin_users';
