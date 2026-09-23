-- sql/09_registration_wizard.sql — güvenlik ve davranış testi (yerel harness).
-- Ön koşul: 08_landcom_conference.sql çalıştırıldı.
\set ON_ERROR_STOP on

-- ---- temiz başlangıç + yapılandırma ----------------------------------------
delete from public.conventus_registration_consents;
delete from public.conventus_registration_tracks;
delete from public.conventus_registrations
 where event_id in (select id from public.conventus_managed_events where code='LANDCOM-CONF-2026');
delete from public.conventus_event_reg_types
 where event_id in (select id from public.conventus_managed_events where code='LANDCOM-CONF-2026');
delete from public.conventus_event_tracks
 where event_id in (select id from public.conventus_managed_events where code='LANDCOM-CONF-2026');
delete from public.conventus_event_consents
 where event_id in (select id from public.conventus_managed_events where code='LANDCOM-CONF-2026');
update public.conventus_managed_events set registration_open=true where code='LANDCOM-CONF-2026';

insert into public.conventus_event_reg_types (event_id, key, label, note, sort)
select e.id, 'delegate', 'Katılımcı', 'Konferansa katılacaksanız bunu seçin.', 1
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';
insert into public.conventus_event_reg_types (event_id, key, label, note, allow_other, sort)
select e.id, 'other', 'Diğer', 'Yukarıdakilere uymuyorsa açıklayın.', true, 9
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';

insert into public.conventus_event_tracks (event_id, key, title, starts_on, ends_on, time_from, time_to, capacity, sort)
select e.id, 'main', 'Ana program', date '2026-11-17', date '2026-11-19', '09:00', '17:00', null, 1
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';
insert into public.conventus_event_tracks (event_id, key, title, starts_on, ends_on, capacity, sort)
select e.id, 'site', 'Saha ziyareti', date '2026-11-18', date '2026-11-18', 20, 2
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';

insert into public.conventus_event_consents (event_id, key, version, body, is_required, sort)
select e.id, 'participant_list', 1,
  'İletişim bilgilerimin katılımcı listesinde paylaşılmasına onay veriyorum.', true, 1
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';
insert into public.conventus_event_consents (event_id, key, version, body, is_required, sort)
select e.id, 'media', 1,
  'Etkinlikte çekilen görüntülerin yayımlanmasına onay veriyorum.', false, 2
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';

insert into auth.users (id,email,created_at,email_confirmed_at) values
 ('f0000000-0000-0000-0000-00000000000a','aday@example.org',   now(), now()),
 ('f0000000-0000-0000-0000-00000000000b','yabanci@example.org', now(), now())
on conflict (id) do nothing;

\echo '=== 1) ANON: yapilandirmayi okuyabilmeli (kamusal etkinlik sayfasi icin) ==='
set role anon;
select '   anon kayit tipi goruyor : '||count(*) from public.conventus_event_reg_types;
select '   anon parkur goruyor     : '||count(*) from public.conventus_event_tracks;
select '   anon onay metni goruyor : '||count(*) from public.conventus_event_consents;

\echo '=== 2) ANON: yapilandirmayi YAZAMAMALI ==='
do $$ begin
  insert into public.conventus_event_tracks (event_id, key, title)
  select e.id,'hack','Korsan' from public.conventus_managed_events e limit 1;
  raise exception 'GUVENLIK HATASI: anon parkur ekledi';
exception when insufficient_privilege then raise notice '   anon yazma: REDDEDILDI (dogru)'; end $$;

\echo '=== 3) ANON: verilen onaylari gormemeli ==='
do $$ begin
  perform * from public.conventus_registration_consents;
  raise exception 'GUVENLIK HATASI: anon onaylari okudu';
exception when insufficient_privilege then raise notice '   anon onay okuma: REDDEDILDI (dogru)'; end $$;
reset role;

\echo '=== 4) ADAY: kayit acar, onay kodu otomatik uretilmeli ==='
set role authenticated;
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000a';
insert into public.conventus_registrations
  (event_id, user_id, first_name, last_name, email, reg_type, status)
select e.id,'f0000000-0000-0000-0000-00000000000a','Aday','Katilimci','aday@example.org','delegate','submitted'
from public.conventus_managed_events e where e.code='LANDCOM-CONF-2026';
select '   onay kodu uzunlugu: '||length(confirmation_code)||' (10 olmali)'
  from public.conventus_registrations where user_id='f0000000-0000-0000-0000-00000000000a';

\echo '=== 5) ADAY: parkur secer ve onay verir ==='
insert into public.conventus_registration_tracks (registration_id, track_id)
select r.id, t.id from public.conventus_registrations r, public.conventus_event_tracks t
where r.user_id='f0000000-0000-0000-0000-00000000000a' and t.key in ('main','site');
insert into public.conventus_registration_consents (registration_id, consent_key, consent_version, answer)
select r.id, c.key, c.version, true
from public.conventus_registrations r, public.conventus_event_consents c
where r.user_id='f0000000-0000-0000-0000-00000000000a';
select '   secilen parkur: '||count(*) from public.conventus_registration_tracks;
select '   verilen onay  : '||count(*) from public.conventus_registration_consents;

\echo '=== 6) ONAYLAR APPEND-ONLY: aday kendi onayini degistiremez/silemez ==='
do $$ declare n int; begin
  update public.conventus_registration_consents set answer=false;
  get diagnostics n = row_count;
  if n > 0 then raise exception 'GUVENLIK HATASI: onay guncellendi (% satir)', n; end if;
  raise notice '   onay guncelleme: ENGELLENDI (dogru)';
end $$;
do $$ declare n int; begin
  delete from public.conventus_registration_consents;
  get diagnostics n = row_count;
  if n > 0 then raise exception 'GUVENLIK HATASI: onay silindi (% satir)', n; end if;
  raise notice '   onay silme     : ENGELLENDI (dogru)';
end $$;

\echo '=== 7) YABANCI: baskasinin parkur/onay kayitlarini gormemeli ==='
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000b';
select '   yabanci parkur goruyor: '||count(*)||' (0 olmali)' from public.conventus_registration_tracks;
select '   yabanci onay goruyor  : '||count(*)||' (0 olmali)' from public.conventus_registration_consents;

\echo '=== 8) YABANCI: yapilandirmayi yazamamali ==='
do $$ declare n int; begin
  update public.conventus_event_tracks set capacity=999;
  get diagnostics n = row_count;
  if n > 0 then raise exception 'GUVENLIK HATASI: yabanci parkuru degistirdi'; end if;
  raise notice '   yabanci yapilandirma: ENGELLENDI (dogru)';
end $$;

\echo '=== 9) ORGANIZATOR: hepsini gorur, onaylari degistiremez ==='
set request.jwt.claim.sub = 'e0000000-0000-0000-0000-000000000009';
select '   organizator parkur goruyor: '||count(*) from public.conventus_registration_tracks;
select '   organizator onay goruyor  : '||count(*) from public.conventus_registration_consents;
do $$ declare n int; begin
  update public.conventus_registration_consents set answer=false;
  get diagnostics n = row_count;
  if n > 0 then raise exception 'GUVENLIK HATASI: organizator onayi degistirdi'; end if;
  raise notice '   organizator onay degistirme: ENGELLENDI (dogru)';
end $$;

\echo '=== 10) ORGANIZATOR: yapilandirmayi yonetebilmeli ==='
update public.conventus_event_tracks set capacity=25 where key='site';
select '   parkur kontenjani guncellendi: '||capacity from public.conventus_event_tracks where key='site';
reset role;

\echo '=== 11) onay kodu benzersiz mi ==='
select '   kayit: '||count(*)||' · benzersiz kod: '||count(distinct confirmation_code)
  from public.conventus_registrations;
