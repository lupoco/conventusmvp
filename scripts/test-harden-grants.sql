-- Probe: anon rolüyle bir dizi işlem dener, her biri için IZIN VAR / REDDEDILDI
-- yazar. 05'ten ÖNCE ve SONRA aynı dosya çalıştırılıp çıktı karşılaştırılır.
-- Yalnızca yerel doğrulama harness'ında kullanılır; canlıda çalıştırma.

create schema if not exists cvtest;
grant usage on schema cvtest to anon, authenticated;

create or replace function cvtest.probe(p_ad text, p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return rpad(p_ad, 46) || ' IZIN VAR';
exception
  when insufficient_privilege then return rpad(p_ad, 46) || ' REDDEDILDI (yetki)';
  when others                 then return rpad(p_ad, 46) || ' REDDEDILDI (' || sqlstate || ')';
end $$;

grant execute on function cvtest.probe(text, text) to anon, authenticated;

-- ---- fixture (postgres olarak) ---------------------------------------------
insert into public.gm_providers (id, name, type, accredited)
  values ('11111111-1111-1111-1111-111111111111', 'AKREDITE SAGLAYICI', 'hotel', true)
  on conflict (id) do update set name = 'AKREDITE SAGLAYICI', accredited = true;

-- ---- anon ------------------------------------------------------------------
set role anon;

select '========== ANON OKUMA (calismaya devam etmeli) ==========' as bolum;
select cvtest.probe('view: gm_providers_public SELECT',
  'select count(*) from public.gm_providers_public');
select cvtest.probe('view: convexus_demand_signals_public SELECT',
  'select count(*) from public.convexus_demand_signals_public');
select cvtest.probe('tablo: conventus_managed_events SELECT',
  'select count(*) from public.conventus_managed_events');
select cvtest.probe('tablo: conventus_announcements SELECT',
  'select count(*) from public.conventus_announcements');
select cvtest.probe('tablo: gm_inventory SELECT',
  'select count(*) from public.gm_inventory');

select '========== ANON YAZMA · IZINLI FORM (calismali) ==========' as bolum;
select cvtest.probe('conventity_access_requests INSERT (gercek kayit)',
  $q$insert into public.conventity_access_requests (full_name, email, purpose)
     values ('Test Kisi', 'probe' || floor(random()*1e9)::text || '@example.com', 'deneme')$q$);

select '========== ANON YAZMA · KAPALI OLMALI ==========' as bolum;
select cvtest.probe('VIEW gm_providers_public UPDATE  (RLS ATLAR!)',
  $q$update public.gm_providers_public set name = 'ELE GECIRILDI'
     where id = '11111111-1111-1111-1111-111111111111'$q$);
select cvtest.probe('VIEW gm_providers_public DELETE  (RLS ATLAR!)',
  $q$delete from public.gm_providers_public
     where id = '11111111-1111-1111-1111-111111111111'$q$);
-- NOT: tablo yazmalarinda RLS reddi de 42501 verir; grant ile RLS'i ayirt
-- etmek icin asagidaki yetki matrisine bak. Burada yalnizca RLS'in HIC
-- devreye girmedigi view yazmalarini calistiriyoruz.

reset role;

select '========== TABAN TABLO DURUMU ==========' as bolum;
select coalesce(
  (select 'gm_providers satiri: ' || name from public.gm_providers
    where id = '11111111-1111-1111-1111-111111111111'),
  'gm_providers satiri: SILINMIS') as sonuc;

select '========== ANON YETKI MATRISI (grant duzeyi) ==========' as bolum;
select rapor, privilege_type, count(*)::text as adet from (
  select 'tablo' as rapor, g.privilege_type
    from information_schema.role_table_grants g
    join pg_tables t on t.schemaname = g.table_schema and t.tablename = g.table_name
   where g.grantee = 'anon' and g.table_schema = 'public'
  union all
  select 'view', g.privilege_type
    from information_schema.role_table_grants g
    join pg_views v on v.schemaname = g.table_schema and v.viewname = g.table_name
   where g.grantee = 'anon' and g.table_schema = 'public'
) x group by 1, 2 order by 1, 2;

select 'anon INSERT yetkisi olan tablolar' as bolum, g.table_name as ad
from information_schema.role_table_grants g
join pg_tables t on t.schemaname = g.table_schema and t.tablename = g.table_name
where g.grantee = 'anon' and g.table_schema = 'public' and g.privilege_type = 'INSERT'
order by 2;
