-- ============================================================================
-- 19_audit_access_requests.sql  ·  Talep güncellemeleri denetim kaydına
--
-- conventity_audit ve conventity_audit_trg() zaten kurulu (02_clean_install);
-- rol işlemleri (conventity_roles) şimdiden kayda geçiyor. Bu dosya aynı
-- tetikleyiciyi conventity_access_requests tablosuna bağlar: bir talebin
-- durumu ya da notu değişince (UPDATE) ve talep silinince (DELETE) kim,
-- ne zaman, neyi değiştirdi kayda geçer.
--
-- INSERT bilerek kapsam dışı: "Yakında" sayfasından gelen her talebi
-- (ad, e-posta) ikinci kez denetim tablosuna kopyalamamak için.
--
-- NEREDE ÇALIŞIR: conventity-prod → SQL Editor. Tekrar çalıştırılabilir.
-- Geri alma: 19_audit_access_requests_ROLLBACK.sql
-- ============================================================================

-- ---- 0) yanlış proje / eksik şema koruması --------------------------------
do $cvguard$
declare n_prof bigint := 0;
begin
  if to_regclass('public.conventity_access_requests') is null then
    raise exception E'\n\n  conventity_access_requests yok — once 04_access_requests.sql calistir.\n';
  end if;
  if to_regclass('public.conventity_audit') is null
     or to_regprocedure('public.conventity_audit_trg()') is null then
    raise exception E'\n\n  conventity_audit / conventity_audit_trg() yok — once 02_clean_install.sql calistir.\n';
  end if;
  if to_regclass('public.convexus_profiles') is not null then
    select count(*) into n_prof from public.convexus_profiles;
  end if;
  if n_prof >= 100 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) tetikleyici --------------------------------------------------------
drop trigger if exists trg_audit_conventity_access_requests on public.conventity_access_requests;
create trigger trg_audit_conventity_access_requests
  after update or delete on public.conventity_access_requests
  for each row execute function public.conventity_audit_trg();

-- ---- 2) doğrulama ----------------------------------------------------------
select tgname as tetikleyici, tgrelid::regclass as tablo
  from pg_trigger
 where tgname = 'trg_audit_conventity_access_requests' and not tgisinternal;
