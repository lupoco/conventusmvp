\set ON_ERROR_STOP on
-- Bu betik BOS bir semada yazildi; 08_landcom_conference.sql artik LANDCOM
-- toplulugunu aciyor. Ikisi ayni slug'i kullanir ve betik cakisirdi. Kendi
-- izole slug'ini kullaniyor ve her kosuda kendi izlerini temizliyor.
delete from conventus_registrations where event_id in
  (select id from conventus_managed_events where code='SMOKE-MVP-26');
delete from conventus_managed_events where code='SMOKE-MVP-26';
delete from conventity_activities where source_ref='conventus_event_code:SMOKE-MVP-26';
delete from conventity_roles where scope='community' and scope_id in
  (select id from conventus_communities where slug='smoke-mvp');
delete from conventus_communities where slug='smoke-mvp';

-- 1) Sahte kullanici (Supabase'de sign up'a karsilik gelir)
insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111','serkan@example.test')
  on conflict do nothing;

-- 2) §4 bootstrap owner: ekosistem admin rolu
insert into conventity_roles (auth_user_id, scope, role, status, note)
select '11111111-1111-1111-1111-111111111111','ecosystem','admin','active','bootstrap owner'
where not exists (select 1 from conventity_roles
  where auth_user_id='11111111-1111-1111-1111-111111111111' and scope='ecosystem' and role='admin');

-- 3) Bundan sonrasi GERCEK kullanici gibi: authenticated rolu + RLS acik
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set role authenticated;

select 'admin mi          : '||conventity_is_admin('ecosystem')::text as kontrol;
select 'uye mi            : '||conventity_is_member()::text;

-- 4) Topluluk kur (cc_insert politikasi: parent_id null + ekosistem admin)
insert into conventus_communities (slug, name, short_name, visibility, join_policy)
values ('smoke-mvp','Duman Testi Toplulugu','SMOKE','public','invite')
returning 'topluluk kuruldu  : '||slug;

select 'topluluk yonetebilir: '||conventity_can_manage_community(
        (select id from conventus_communities where slug='smoke-mvp'))::text;

-- 5) Etkinlik olustur — RPC omurgaya activity satirini da yazar
select 'etkinlik kodu     : '||(conventus_create_managed_event(
         (select id from conventus_communities where slug='smoke-mvp'),
         'SMOKE-MVP-26','Duman Testi Etkinligi',
         current_date + 30, current_date + 31,'Izmir','LANDCOM',
         'MVP dogrulama etkinligi', true, false)).code;

select 'omurga activity   : '||count(*)::text from conventity_activities
 where source_ref = 'conventus_event_code:SMOKE-MVP-26';

-- 6) Kayit ol (reg_self_insert_open politikasi: registration_open = true)
insert into conventus_registrations (event_id, user_id, first_name, last_name, email, status)
select id, auth.uid(), 'Serkan','Copul','serkan@example.test','submitted'
from conventus_managed_events where code = 'SMOKE-MVP-26'
returning 'kayit olusturuldu : '||status;

-- 7) Trigger'lar calisti mi
reset role;
select 'kayit olay kaydi  : '||count(*)::text from conventus_registration_events;
select 'rol olay kaydi    : '||count(*)::text from conventus_role_events;
select 'denetim kaydi     : '||count(*)::text from conventity_audit;

-- 8) RLS gercekten siniri tutuyor mu: YETKISIZ kullanici topluluk kuramamali
insert into auth.users (id, email) values ('22222222-2222-2222-2222-222222222222','yabanci@example.test')
  on conflict do nothing;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set role authenticated;
do $$
begin
  insert into conventus_communities (slug, name) values ('sahte','Sahte Topluluk');
  raise exception 'GUVENLIK HATASI: yetkisiz kullanici topluluk kurabildi';
exception when insufficient_privilege then
  raise notice 'RLS engelledi     : yetkisiz kullanici topluluk kuramadi (dogru)';
end $$;
reset role;
