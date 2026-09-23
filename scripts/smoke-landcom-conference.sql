-- LANDCOM Konferansı — uçtan uca duman testi (yerel harness).
-- Davet ve başvuru yollarının ikisini de RLS altında dener.
-- Ön koşul: sql/08_landcom_conference.sql çalıştırıldı.
\set ON_ERROR_STOP on

-- ---- temiz baslangic -------------------------------------------------------
-- Test 7 kayit penceresini kapatiyor; yarida kalan bir kosu onu acik
-- birakmayabilir. Her kosu kendi baslangicini garanti etsin.
delete from public.conventus_registrations
 where event_id in (select id from public.conventus_managed_events where code='LANDCOM-CONF-2026');
update public.conventus_managed_events set registration_open = true where code='LANDCOM-CONF-2026';

-- ---- aktorler --------------------------------------------------------------
insert into auth.users (id,email,created_at,email_confirmed_at) values
 ('f0000000-0000-0000-0000-00000000000a','aday@example.org',  now(), now()),
 ('f0000000-0000-0000-0000-00000000000b','yabanci@example.org',now(), now())
on conflict (id) do nothing;

\echo '=== 1) BASVURU: aday kendi kaydini olusturur (izinli olmali) ==='
set role authenticated;
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000a';
insert into public.conventus_registrations
  (event_id, user_id, first_name, last_name, email, institution, country, status)
select e.id, 'f0000000-0000-0000-0000-00000000000a','Aday','Katilimci',
       'aday@example.org','Ornek Kurum','TR','submitted'
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';
select '   kayit olusturuldu: '||count(*) from public.conventus_registrations;

\echo '=== 2) aday yalniz KENDI kaydini gorur ==='
select '   aday goruyor: '||count(*) from public.conventus_registrations;

\echo '=== 3) ilgisiz kullanici hicbir sey gormemeli ==='
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000b';
select '   yabanci goruyor: '||count(*)||' (0 olmali)' from public.conventus_registrations;

\echo '=== 4) yabanci baskasinin kaydini onaylamaya calisir (REDDEDILMELI) ==='
do $$ declare n int; begin
  update public.conventus_registrations set status='approved' where status='submitted';
  get diagnostics n = row_count;
  if n > 0 then raise exception 'GUVENLIK HATASI: yabanci % kaydi onayladi', n; end if;
  raise notice '   yabanci onaylayamadi (dogru)';
end $$;

\echo '=== 5) ORGANIZATOR (topluluk sahibi) kaydi gorur ve onaylar ==='
set request.jwt.claim.sub = 'e0000000-0000-0000-0000-000000000009';
select '   organizator goruyor: '||count(*) from public.conventus_registrations;
update public.conventus_registrations set status='approved' where status='submitted';
select '   onaylanan: '||count(*) from public.conventus_registrations where status='approved';

\echo '=== 6) DAVET: organizator baskasi adina kayit acar ==='
insert into public.conventus_registrations
  (event_id, user_id, registered_by, is_delegated, first_name, last_name, email, status)
select e.id, null, 'e0000000-0000-0000-0000-000000000009', true,
       'Davetli','Konusmaci','davetli@example.org','approved'
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';
select '   toplam kayit: '||count(*) from public.conventus_registrations;

\echo '=== 7) kayit kapaninca: etkinlik disariya gorunmez ve basvuru alinmaz ==='
reset role;
update public.conventus_managed_events set registration_open=false where code='LANDCOM-CONF-2026';
set role authenticated;
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000b';
-- 7a) gorunurluk: cme_visibility_gate RESTRICTIVE (visibility='public' gecer) ama
--     permissive taraftan yalniz "public read open" var ve o registration_open
--     istiyor -> kayit kapaninca etkinlik ilgisiz kullaniciya HIC gorunmuyor.
select '   disaridan gorunen etkinlik: '||count(*)||' (0 olmali)'
  from public.conventus_managed_events where code='LANDCOM-CONF-2026';
-- 7b) event_id elle verilse bile RLS insert'i reddetmeli
do $$
declare v_id bigint;
begin
  select id into v_id from public.conventus_managed_events where code='LANDCOM-CONF-2026';
  if v_id is null then
    -- gorunmuyor; id'yi harness disindan alip yine de deneyelim
    select e.id into v_id from public.conventus_managed_events e where true limit 1;
  end if;
  insert into public.conventus_registrations (event_id, user_id, first_name, email)
  values (coalesce(v_id, 1), 'f0000000-0000-0000-0000-00000000000b','Gec','gec@example.org');
  raise exception 'GUVENLIK HATASI: kayit kapaliyken basvuru kabul edildi';
exception
  when insufficient_privilege then raise notice '   kayit kapali: basvuru REDDEDILDI (dogru)';
  when foreign_key_violation  then raise notice '   kayit kapali: etkinlik gorunmuyor, basvuru acilamadi (dogru)';
end $$;
reset role;
update public.conventus_managed_events set registration_open=true where code='LANDCOM-CONF-2026';
set role authenticated;

\echo '=== 8) omurga bagi ==='
select '   conventity_activities kaydi: '||count(*) from public.conventity_activities
 where source_ref='conventus_event_code:LANDCOM-CONF-2026';
