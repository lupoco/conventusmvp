\set ON_ERROR_STOP on
delete from conventity_access_requests;

-- ============ anon rolu (form ziyaretcisi) ============
set role anon;

-- 1) gecerli talep -> KABUL
insert into conventity_access_requests (full_name, email, org_name, purpose, lang)
values ('Ayse Yilmaz','ayse@example.org','Ornek Kurum','Conventus MVP''yi gormek istiyorum','tr');
select '1 gecerli talep       : KABUL' as t;

-- 2) kendini davetli yazmaya calis -> RED
do $$ begin
  insert into conventity_access_requests (full_name,email,status) values ('Kotu','k@e.com','invited');
  raise exception 'GUVENLIK HATASI: anon status yazabildi';
exception when insufficient_privilege then raise notice '2 status=invited denemesi: RED (dogru)'; end $$;

-- 3) baskasinin talebine not dusmeye calis -> RED
do $$ begin
  insert into conventity_access_requests (full_name,email,note) values ('Kotu','k2@e.com','not');
  raise exception 'GUVENLIK HATASI: anon note yazabildi';
exception when insufficient_privilege then raise notice '3 note denemesi       : RED (dogru)'; end $$;

-- 4) talepleri okumaya calis -> RED (yetki yok)
do $$ begin
  perform count(*) from conventity_access_requests;
  raise exception 'GUVENLIK HATASI: anon talepleri okuyabildi';
exception when insufficient_privilege then raise notice '4 okuma denemesi      : RED (dogru)'; end $$;

-- 5) bozuk e-posta -> RED (CHECK)
do $$ begin
  insert into conventity_access_requests (full_name,email) values ('Test','bozuk-eposta');
  raise exception 'GUVENLIK HATASI: bozuk e-posta kabul edildi';
exception when check_violation then raise notice '5 bozuk e-posta       : RED (dogru)'; end $$;

-- 6) ayni e-posta ile ikinci acik talep -> RED (tekil indeks)
do $$ begin
  insert into conventity_access_requests (full_name,email) values ('Ayse Y','AYSE@example.org');
  raise exception 'GUVENLIK HATASI: mukerrer acik talep kabul edildi';
exception when unique_violation then raise notice '6 mukerrer talep      : RED (dogru)'; end $$;

-- 7) 1000 karakteri asan aciklama -> RED
do $$ begin
  insert into conventity_access_requests (full_name,email,purpose)
  values ('Uzun','uzun@e.com', repeat('x',1001));
  raise exception 'GUVENLIK HATASI: 1000+ karakter kabul edildi';
exception when check_violation then raise notice '7 cok uzun aciklama   : RED (dogru)'; end $$;

reset role;

-- ============ ekosistem admin ============
insert into auth.users (id,email) values ('33333333-3333-3333-3333-333333333333','admin@e.com') on conflict do nothing;
delete from conventity_roles where auth_user_id='33333333-3333-3333-3333-333333333333';
insert into conventity_roles (auth_user_id, scope, role, status) values ('33333333-3333-3333-3333-333333333333','ecosystem','admin','active');
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set role authenticated;
select '8 admin okuyabiliyor  : '||count(*)::text||' talep' from conventity_access_requests;
update conventity_access_requests set status='contacted', note='arandi' where email='ayse@example.org';
select '9 admin guncelledi    : '||status||' / '||note from conventity_access_requests;

-- ============ admin OLMAYAN giris yapmis kullanici ============
reset role;
insert into auth.users (id,email) values ('44444444-4444-4444-4444-444444444444','normal@e.com') on conflict do nothing;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
set role authenticated;
select '10 admin olmayan gorur: '||count(*)::text||' talep (0 olmali)' from conventity_access_requests;
reset role;
