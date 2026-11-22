-- ============================================================================
-- 18_signin_events.sql  ·  Giriş kaydına çıkış olayı
--
-- conventity_signin_log şu an yalnız başarılı girişi tutuyor. Bu dosya bir
-- "event" kolonu ekler: 'signin' (varsayılan; eski satırlar böyle kalır) ya da
-- 'signout'. Yönetim uygulaması (/yonetim/) çıkıştan hemen önce 'signout'
-- satırı yazar. Tablo append-only kalır: update/delete politikası yok.
--
-- NEREDE ÇALIŞIR: conventity-prod → SQL Editor. Tekrar çalıştırılabilir.
-- Geri alma: 18_signin_events_ROLLBACK.sql
-- ============================================================================

-- ---- 0) yanlış proje / eksik şema koruması --------------------------------
do $cvguard$
declare n_prof bigint := 0;
begin
  if to_regclass('public.conventity_signin_log') is null then
    raise exception E'\n\n  conventity_signin_log yok — once 02_clean_install.sql calistir.\n';
  end if;
  if to_regclass('public.convexus_profiles') is not null then
    select count(*) into n_prof from public.convexus_profiles;
  end if;
  if n_prof >= 100 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) kolon + CHECK ------------------------------------------------------
alter table public.conventity_signin_log
  add column if not exists event text not null default 'signin';

do $ck$
begin
  if not exists (select 1 from pg_constraint where conname = 'conventity_signin_log_event_check') then
    alter table public.conventity_signin_log
      add constraint conventity_signin_log_event_check check (event in ('signin','signout'));
  end if;
end $ck$;

create index if not exists idx_conv_signin_event on public.conventity_signin_log(event);

-- ---- 2) PostgREST şema önbelleği -----------------------------------------
notify pgrst, 'reload schema';

-- ---- 3) doğrulama ----------------------------------------------------------
select event, count(*) as satir from public.conventity_signin_log group by event order by event;
