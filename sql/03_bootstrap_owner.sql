-- ============================================================================
-- 03_bootstrap_owner.sql  ·  §4 — İLK ADMİN (chicken-egg çözümü)
--
-- SIRA:
--   1. 02_clean_install.sql çalıştırılmış olmalı.
--   2. Uygulamadan (local: http://localhost:8000/register.html) kendi
--      e-postanla sign up ol.
--   3. Aşağıdaki 1. sorguyu çalıştır, uid'ini al.
--   4. 2. bloktaki <SERKAN-UID> yerine yapıştır, çalıştır.
--
-- NOT: `auth_user_id` DOLU olmalı — boşsa rol RLS'te etkisizdir.
-- ============================================================================

-- 1) uid'i bul ---------------------------------------------------------------
select id as auth_user_id, email, created_at
from auth.users
order by created_at desc;

-- 2) ekosistem admin rolünü ver (uid'i yapıştırdıktan sonra çalıştır) --------
/*
insert into conventity_roles (auth_user_id, scope, role, status, note)
select '<SERKAN-UID>'::uuid, 'ecosystem', 'admin', 'active', 'bootstrap owner'
where not exists (
  select 1 from conventity_roles
  where auth_user_id = '<SERKAN-UID>'::uuid
    and scope = 'ecosystem' and role = 'admin'
);

-- 3) doğrula: üçü de true dönmeli
select conventity_is_admin('ecosystem') as ekosistem_admin,
       is_cv_admin()                    as cv_admin,
       is_convexus_admin()              as convexus_admin;
*/
