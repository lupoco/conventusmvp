-- ============================================================================
-- conventity_capabilities — KEŞİF (salt-okunur)  ·  AÇIK İŞLER #3 (yetenek UI)
-- 2026-07-23
--
-- Amaç: Core'a "Yetenek" CRUD sekmesi eklemeden önce tablonun GERÇEK kolonlarını
-- ve ilişki tablolarını görmek (repoda şema yok, canlıda 0 kayıt). Form buna
-- göre kurulacak — guessed schema → PostgREST 0 satır hatasını önlemek için.
-- Supabase SQL Editor'de çalıştır, HER sorgunun çıktısını geri yapıştır.
-- ============================================================================

-- 1) Kolonlar (form alanları buradan çıkacak) --------------------------------
select ordinal_position, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public' and table_name='conventity_capabilities'
order by ordinal_position;

-- 2) PK / CHECK / UNIQUE kısıtları (enum benzeri text+CHECK alanlar için) -----
select con.conname, con.contype, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid=con.conrelid
join pg_namespace ns on ns.oid=rel.relnamespace
where ns.nspname='public' and rel.relname='conventity_capabilities'
  and con.contype in ('p','c','u')
order by con.contype, con.conname;

-- 3) DIŞ ANAHTARLAR — capabilities HANGİ tabloları işaret ediyor? ------------
select con.conname, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid=con.conrelid
join pg_namespace ns on ns.oid=rel.relnamespace
where ns.nspname='public' and rel.relname='conventity_capabilities' and con.contype='f';

-- 4) İLİŞKİ TABLOLARI — HANGİ tablolar conventity_capabilities'i işaret ediyor?
--    (problem↔capability, solution↔capability gibi junction tablolar burada çıkar)
select rel.relname as referencing_table, con.conname, pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid=con.conrelid
join pg_namespace ns on ns.oid=rel.relnamespace
where ns.nspname='public' and con.contype='f'
  and con.confrelid = 'public.conventity_capabilities'::regclass
order by rel.relname;

-- 5) RLS: politikalar + etkin mi (yazma yetkisi kimde?) ---------------------
select policyname, cmd, roles, qual, with_check
from pg_policies where schemaname='public' and tablename='conventity_capabilities'
order by cmd, policyname;
select relrowsecurity as rls_enabled from pg_class where oid='public.conventity_capabilities'::regclass;

-- 6) Kayıt sayısı (beklenen 0) + varsa örnek satır --------------------------
select count(*) as toplam from public.conventity_capabilities;
select * from public.conventity_capabilities limit 3;

-- ============================================================================
-- ÇIKTIYI YAPIŞTIR → Core'a tam uyumlu "Yetenek" CRUD sekmesi (liste + ekle/
-- düzenle/sil + arama + i18n) kurulacak; gerekiyorsa ilişki tabloları da.
-- ============================================================================
