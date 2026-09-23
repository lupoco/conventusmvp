-- harness: gercek Supabase auth.users'a sadik ek kolonlar
alter table auth.users add column if not exists email_confirmed_at timestamptz;
alter table auth.users add column if not exists last_sign_in_at timestamptz;
alter table auth.users add column if not exists raw_user_meta_data jsonb default '{}'::jsonb;

delete from public.conventity_roles;
delete from public.conventity_people;
delete from auth.users;

insert into auth.users (id, email, created_at, email_confirmed_at, raw_user_meta_data) values
 ('a0000000-0000-0000-0000-000000000001','admin@example.org', now()-interval '3 day', now(), '{}'),
 ('b0000000-0000-0000-0000-000000000002','yeni1@example.org', now()-interval '2 hour', now(),
    '{"account_type":"corporate","auth_person":"Ayse Yilmaz","company_name":"Ornek Kurum","country":"TR"}'),
 ('c0000000-0000-0000-0000-000000000003','yeni2@example.org', now()-interval '1 hour', null,
    '{"account_type":"personal","username":"mehmet","country":"NL"}'),
 ('d0000000-0000-0000-0000-000000000004','zatenuye@example.org', now()-interval '5 day', now(), '{}');

-- admin: rolu var
insert into public.conventity_people (id, full_name, email, auth_user_id, source)
 values ('11111111-0000-0000-0000-000000000001','Ekosistem Admin','admin@example.org','a0000000-0000-0000-0000-000000000001','manual');
insert into public.conventity_roles (person_id, auth_user_id, scope, role, status)
 values ('11111111-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','ecosystem','admin','active');
-- zatenuye: kisi kaydi var, rolu yok -> bekleyen DEGIL
insert into public.conventity_people (full_name, email, auth_user_id, source)
 values ('Zaten Uye','zatenuye@example.org','d0000000-0000-0000-0000-000000000004','manual');

\echo '=== 1) anon cagirabiliyor mu (REDDEDILMELI) ==='
set role anon;
do $$ begin
  perform * from public.conventity_pending_members();
  raise exception 'GUVENLIK HATASI: anon bekleyenleri listeledi';
exception when insufficient_privilege then raise notice '   anon: REDDEDILDI (dogru)'; end $$;
reset role;

\echo '=== 2) admin olmayan authenticated (REDDEDILMELI) ==='
set role authenticated;
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-000000000003';
do $$ begin
  perform * from public.conventity_pending_members();
  raise exception 'GUVENLIK HATASI: admin olmayan listeledi';
exception when insufficient_privilege then raise notice '   admin olmayan: REDDEDILDI (dogru)'; end $$;
do $$ begin
  perform public.conventity_approve_member('b0000000-0000-0000-0000-000000000002');
  raise exception 'GUVENLIK HATASI: admin olmayan onay verdi';
exception when insufficient_privilege then raise notice '   admin olmayan onay: REDDEDILDI (dogru)'; end $$;
reset role;

\echo '=== 3) admin listeler (yeni1 + yeni2 cikmali, admin ve zatenuye CIKMAMALI) ==='
set role authenticated;
set request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000001';
select email, email_confirmed, coalesce(full_name,'-') as ad, coalesce(org_name,'-') as kurum, coalesce(country,'-') as ulke
from public.conventity_pending_members();

\echo '=== 4) gecersiz rol / kapsam ==='
do $$ begin
  perform public.conventity_approve_member('b0000000-0000-0000-0000-000000000002','superuser');
  raise exception 'HATA: gecersiz rol kabul edildi';
exception when sqlstate '22023' then raise notice '   gecersiz rol: REDDEDILDI (dogru)'; end $$;
do $$ begin
  perform public.conventity_approve_member('b0000000-0000-0000-0000-000000000002','member','community');
  raise exception 'HATA: community kapsami kabul edildi';
exception when sqlstate '22023' then raise notice '   community kapsami: REDDEDILDI (dogru)'; end $$;

\echo '=== 5) onayla ==='
select public.conventity_approve_member('b0000000-0000-0000-0000-000000000002') as sonuc;
select public.conventity_approve_member('b0000000-0000-0000-0000-000000000002') as ikinci_kez;

\echo '=== 6) onaydan sonra listede kalmamali ==='
select email from public.conventity_pending_members();

\echo '=== 7) uyelik gecerli mi ==='
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-000000000002';
select public.conventity_is_member() as yeni1_uye_mi;
reset role;

\echo '=== 8) acilan kayitlar ==='
select 'kisi: '||full_name||' | '||coalesce(email,'-')||' | source='||source from public.conventity_people
 where auth_user_id='b0000000-0000-0000-0000-000000000002';
select 'rol : '||scope||'/'||role||' | status='||status||' | person_id dolu='||(person_id is not null)::text
 from public.conventity_roles where auth_user_id='b0000000-0000-0000-0000-000000000002';
select 'toplam rol satiri (1 olmali): '||count(*) from public.conventity_roles
 where auth_user_id='b0000000-0000-0000-0000-000000000002';
