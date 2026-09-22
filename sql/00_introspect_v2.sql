-- ============================================================================
-- 00_introspect_v2.sql  ·  Conventus v2 — Faz A1 KEŞİF
-- Amaç: DDL yazmadan önce gerçek şemayı görmek. Salt-okunur, hiçbir şeyi değiştirmez.
-- Kullanım: Supabase SQL Editor'de çalıştır, HER sorgunun çıktısını Claude'a yapıştır.
-- (Claude bu ortamdan Supabase'e ulaşamıyor — proxy allowlist dışı.)
-- ============================================================================

-- 1) conventity_roles — gerçek kolonlar --------------------------------------
select ordinal_position, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public' and table_name='conventity_roles'
order by ordinal_position;

-- 2) conventity_roles — CHECK kısıtları (scope/role vb.) ----------------------
select con.conname, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid=con.conrelid
join pg_namespace ns on ns.oid=rel.relnamespace
where ns.nspname='public' and rel.relname='conventity_roles' and con.contype in ('c','u','p')
order by con.contype, con.conname;

-- 3) conventity_roles — mevcut RLS politikaları (22 canlı politika — DOKUNMA) --
select policyname, cmd, permissive, roles, qual, with_check
from pg_policies
where schemaname='public' and tablename='conventity_roles'
order by cmd, policyname;

-- 4) conventus_managed_events — kolonlar (⚠ activity_id VAR MI?) --------------
select ordinal_position, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public' and table_name='conventus_managed_events'
order by ordinal_position;

-- 5) conventus_managed_events — CHECK/UNIQUE/PK ------------------------------
select con.conname, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid=con.conrelid
join pg_namespace ns on ns.oid=rel.relnamespace
where ns.nspname='public' and rel.relname='conventus_managed_events' and con.contype in ('c','u','p')
order by con.contype, con.conname;

-- 6) conventus_managed_events — mevcut RLS politikaları -----------------------
--    (§4.6'daki görünürlük/kayıt-penceresi politikalarını GÜVENLE yazmak için gerekli)
select policyname, cmd, permissive, roles, qual, with_check
from pg_policies
where schemaname='public' and tablename='conventus_managed_events'
order by cmd, policyname;

-- 7) conventus_registrations — kolonlar + policy (kayıt penceresi RLS için) ---
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public' and table_name='conventus_registrations'
order by ordinal_position;
select policyname, cmd, qual, with_check
from pg_policies
where schemaname='public' and tablename='conventus_registrations'
order by cmd, policyname;

-- 8) conventity_activities — activity_type CHECK (backfill 'event' geçerli mi?)
select con.conname, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid=con.conrelid
join pg_namespace ns on ns.oid=rel.relnamespace
where ns.nspname='public' and rel.relname='conventity_activities' and con.contype='c'
order by con.conname;

-- 9) activity_id NULL olan yönetilen etkinlik sayısı (backfill kapsamı) -------
--    (Eğer 4. sorguda activity_id kolonu YOKSA bu sorgu hata verir — o da bir cevaptır.)
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='conventus_managed_events'
               and column_name='activity_id') then
    raise notice 'activity_id kolonu VAR.';
  else
    raise notice 'activity_id kolonu YOK — migration ADD COLUMN yapacak.';
  end if;
end $$;
-- Kolon varsa sayıyı da al:
-- select count(*) filter (where activity_id is null) as null_activity,
--        count(*) as total
-- from conventus_managed_events;

-- 10) gm_* tabloların gerçek şeması (Faz B için — şimdi sadece envanter) ------
select table_name, count(*) as col_count
from information_schema.columns
where table_schema='public' and table_name like 'gm\_%'
group by table_name order by table_name;

-- 11) Omurga sağlığı: is_admin RPC ve activities kolonları --------------------
select routine_name from information_schema.routines
where routine_schema='public'
  and routine_name in ('conventity_is_admin','conventity_community_role',
                       'conventity_can_manage_community','conventity_can_manage_event');
select column_name, data_type from information_schema.columns
where table_schema='public' and table_name='conventity_activities'
order by ordinal_position;
