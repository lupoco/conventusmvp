-- ============================================================================
-- 03_bootstrap_owner.sql  ·  §4 — İLK ADMİN (chicken-egg çözümü)
--
-- ÖN KOŞUL: 02_clean_install.sql çalıştırıldı VE hesabın Supabase'de açıldı
--           (Dashboard → Authentication → Users → Add user, ya da uygulamadan
--            sign up).
--
-- KULLANIM: tamamını conventity-prod SQL Editor'üne yapıştır → Run.
--           E-posta aşağıda tek yerde; başka hesap için orayı değiştir.
--           Tekrar çalıştırılabilir — ikinci kez hiçbir şey değiştirmez.
-- ============================================================================

-- ---- 1) Kurulum sağlam mı ---------------------------------------------------
select 'tablo'     as nesne, count(*)::text as adet from pg_tables    where schemaname='public'
union all select 'view',      count(*)::text from pg_views     where schemaname='public'
union all select 'politika',  count(*)::text from pg_policies  where schemaname='public'
union all select 'RLS kapalı tablo (0 olmalı)', count(*)::text
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and not c.relrowsecurity;

-- ---- 2) Rolü ver — uid'i e-postadan bulur, elle kopyalama yok --------------
with owner as (
  select id from auth.users
  where lower(email) = lower('serkancopul@gmail.com')   -- <<< TEK DEĞİŞTİRİLECEK YER
  order by created_at limit 1
)
insert into conventity_roles (auth_user_id, scope, role, status, note)
select o.id, 'ecosystem', 'admin', 'active', 'bootstrap owner'
from owner o
where not exists (
  select 1 from conventity_roles r
  where r.auth_user_id = o.id and r.scope = 'ecosystem' and r.role = 'admin'
);

-- ---- 3) Doğrula -------------------------------------------------------------
-- auth_user_id DOLU olmalı; boşsa rol RLS'te etkisizdir.
select u.email,
       r.scope, r.role, r.status,
       r.auth_user_id is not null as rls_de_etkili,
       r.granted_at
from conventity_roles r
join auth.users u on u.id = r.auth_user_id
where r.scope = 'ecosystem' and r.role = 'admin';

-- Hiç satır dönmediyse: o e-postayla kayıtlı kullanıcı yok.
-- Kontrol:  select id, email, created_at from auth.users order by created_at desc;
