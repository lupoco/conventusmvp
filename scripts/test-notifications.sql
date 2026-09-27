-- test-notifications.sql
-- Bildirim kuyrugu (conventity_outbox) davranis testi.
--
-- Kalici guard: 20_notifications.sql geri alinirsa / trigger dusurulurse kirmizi.
-- Kritik iddialar:
--   * bildirim durum degisikligiyle AYNI transaction'da yazilir (kaybolmaz)
--   * ayni olay iki kez kuyruga girmez (cift e-posta yok)
--   * istemci kuyruga yazamaz (uzerimizden spam gonderilemez)
--   * basarisizlik GORUNUR kalir, sessizce yutulmaz

\pset format aligned
\pset border 2
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------- fikstur
-- Onceki kosu hatayla yarida kalmis olabilir: temizligi BASTA da yap.
-- (Geride kalan acik bir BILDIRIM-TEST etkinligi smoke testini yaniltiyordu.)
delete from public.conventity_outbox
 where event_id in (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
delete from public.conventus_registrations
 where event_id in (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
delete from public.conventus_managed_events where code='BILDIRIM-TEST';
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111','org@test.local'),
  ('66666666-6666-6666-6666-666666666666','bildirim-katilimci@test.local')
on conflict (id) do nothing;

insert into public.conventity_roles (auth_user_id, scope, role, status)
select '11111111-1111-1111-1111-111111111111','ecosystem','admin','active'
 where not exists (select 1 from public.conventity_roles
                    where auth_user_id='11111111-1111-1111-1111-111111111111'
                      and scope='ecosystem' and role='admin');

insert into public.conventity_activities (id, title, source_ref)
values ('77777777-7777-7777-7777-777777777777','Bildirim','bildirim:test')
on conflict (id) do nothing;

delete from public.conventity_outbox where dedupe_key like '%:BT:%' or event_id in
  (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
delete from public.conventus_registrations where email='bildirim-katilimci@test.local';
delete from public.conventus_managed_events where code='BILDIRIM-TEST';

insert into public.conventus_managed_events
  (code,title,published,visibility,created_by,activity_id,poc_email,poc_name,start_date,location)
values ('BILDIRIM-TEST','Bildirim Denemesi',true,'public',
        '11111111-1111-1111-1111-111111111111','77777777-7777-7777-7777-777777777777',
        'organizator@test.local','Organizator','2026-05-12','Izmir');

-- ---------------------------------------- 1) kayit alinca iki bildirim cikar
insert into public.conventus_registrations
       (event_id,activity_id,user_id,email,first_name,last_name,status)
select id,'77777777-7777-7777-7777-777777777777',
       '66666666-6666-6666-6666-666666666666','bildirim-katilimci@test.local','Elif','Demir','submitted'
  from public.conventus_managed_events where code='BILDIRIM-TEST';

do $$
declare v_kat int; v_yon int;
begin
  select count(*) into v_kat from public.conventity_outbox
   where kind='reg_submitted' and to_email='bildirim-katilimci@test.local'
     and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  select count(*) into v_yon from public.conventity_outbox
   where kind='mgr_new_registration' and to_email='organizator@test.local'
     and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  if v_kat <> 1 then raise exception 'KIRMIZI 1a: katilimci bildirimi % adet', v_kat; end if;
  if v_yon <> 1 then raise exception 'KIRMIZI 1b: organizator bildirimi % adet', v_yon; end if;
  raise notice 'YESIL 1: kayit alininca katilimci + organizator kuyruga girdi';
end $$;

-- ------------------------------------- 2) icerik gercekten dolu mu (bos mail yok)
do $$
declare v jsonb;
begin
  select payload into v from public.conventity_outbox
   where kind='reg_submitted' and to_email='bildirim-katilimci@test.local'
     and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  if v->>'event_title' is null or v->>'event_code' is null then
    raise exception 'KIRMIZI 2: payload eksik: %', v;
  end if;
  if v->>'participant_name' <> 'Elif Demir' then
    raise exception 'KIRMIZI 2b: isim yanlis: %', v->>'participant_name';
  end if;
  raise notice 'YESIL 2: bildirim icerigi dolu (% / %)', v->>'event_code', v->>'participant_name';
end $$;

-- --------------------------- 3) ONAY tek bildirim uretir, organizatore gitmez
do $$
declare v_kat int; v_yon int;
begin
  update public.conventus_registrations set status='approved' where email='bildirim-katilimci@test.local';
  select count(*) into v_kat from public.conventity_outbox where kind='reg_approved'
   and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  select count(*) into v_yon from public.conventity_outbox where kind like 'mgr_%'
   and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  if v_kat <> 1 then raise exception 'KIRMIZI 3a: onay bildirimi % adet', v_kat; end if;
  if v_yon <> 1 then raise exception 'KIRMIZI 3b: organizatore gereksiz bildirim (% adet)', v_yon; end if;
  raise notice 'YESIL 3: onay yalnizca katilimciya gitti';
end $$;

-- ------------------------------------------- 4) CIFT GONDERIM olmaz
do $$
declare v_once int; v_sonra int;
begin
  select count(*) into v_once from public.conventity_outbox
   where event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  -- ayni duruma tekrar yazmak (idempotent guncelleme) yeni mail uretmemeli
  update public.conventus_registrations set status='approved' where email='bildirim-katilimci@test.local';
  update public.conventus_registrations set institution='LANDCOM' where email='bildirim-katilimci@test.local';
  select count(*) into v_sonra from public.conventity_outbox
   where event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  if v_sonra <> v_once then
    raise exception 'KIRMIZI 4: cift bildirim uretildi (% -> %)', v_once, v_sonra;
  end if;
  raise notice 'YESIL 4: ayni olay iki kez kuyruga girmiyor';
end $$;

-- ------------------------- 5) ileri-geri gidis: her GERCEK gecis bir bildirim
do $$
declare v int;
begin
  update public.conventus_registrations set status='waitlisted' where email='bildirim-katilimci@test.local';
  update public.conventus_registrations set status='approved'   where email='bildirim-katilimci@test.local';
  select count(*) into v from public.conventity_outbox where kind='reg_waitlisted'
   and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  if v <> 1 then raise exception 'KIRMIZI 5: beklemeye alma bildirimi % adet', v; end if;
  raise notice 'YESIL 5: her gercek durum gecisi bildiriliyor';
end $$;

-- -------------------------- 6) IPTAL: katilimci + organizator bilgilendirilir
do $$
declare v_kat int; v_yon int;
begin
  update public.conventus_registrations set status='cancelled' where email='bildirim-katilimci@test.local';
  select count(*) into v_kat from public.conventity_outbox where kind='reg_cancelled'
   and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  select count(*) into v_yon from public.conventity_outbox where kind='mgr_cancellation'
   and event_id = (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
  if v_kat <> 1 or v_yon <> 1 then
    raise exception 'KIRMIZI 6: iptal bildirimleri (kat=%, yon=%)', v_kat, v_yon;
  end if;
  raise notice 'YESIL 6: iptalde iki taraf da bilgilendiriliyor';
end $$;

-- ------------------------- 7) ISTEMCI KUYRUGA YAZAMAZ (spam korumasi)
do $$
declare v_hata text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
    insert into public.conventity_outbox (kind,to_email,dedupe_key)
    values ('spam','kurban@example.com','spam:1');
  exception when others then v_hata := sqlerrm;
  end;
  reset role;
  if v_hata is null then raise exception 'KIRMIZI 7: istemci kuyruga eleman ekleyebildi'; end if;
  raise notice 'YESIL 7: istemci kuyruga yazamiyor';
end $$;

-- ------------------- 8) katilimci BASKASININ bildirimini okuyamaz
do $$
declare v int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  select count(*) into v from public.conventity_outbox;
  reset role;
  if v <> 0 then raise exception 'KIRMIZI 8: katilimci kuyrugu okuyabiliyor (% satir)', v; end if;
  raise notice 'YESIL 8: kuyruk katilimciya kapali';
end $$;

-- ------------------- 9) organizator KENDI etkinliginin kuyrugunu gorur
do $$
declare v int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  select count(*) into v from public.conventity_outbox;
  reset role;
  if v < 1 then raise exception 'KIRMIZI 9: organizator kendi kuyrugunu goremiyor'; end if;
  raise notice 'YESIL 9: organizator kuyrugu izleyebiliyor (% satir)', v;
end $$;

-- ------------------- 10) drenaj: claim -> finish(ok) -> tekrar claim etmez
do $$
declare v_id bigint; v_st text; v_ikinci int;
begin
  select id into v_id from public.conventity_outbox where status='pending' order by id limit 1;
  if v_id is null then raise exception 'KIRMIZI 10a: bekleyen bildirim yok'; end if;
  perform public.conventity_outbox_claim(1);
  perform public.conventity_outbox_finish(v_id, true, null);
  select status into v_st from public.conventity_outbox where id=v_id;
  if v_st <> 'sent' then raise exception 'KIRMIZI 10b: gonderim isaretlenmedi (%)', v_st; end if;
  select count(*) into v_ikinci from public.conventity_outbox_claim(50) where id = v_id;
  if v_ikinci <> 0 then raise exception 'KIRMIZI 10c: gonderilmis satir tekrar alindi'; end if;
  raise notice 'YESIL 10: gonderilen satir bir daha kuyruktan alinmiyor';
end $$;

-- ------------------- 11) BASARISIZLIK GORUNUR: 5 denemeden sonra 'failed'
do $$
declare v_id bigint; v_st text; v_hata text;
begin
  select id into v_id from public.conventity_outbox where status='pending' order by id limit 1;
  if v_id is null then raise exception 'KIRMIZI 11a: bekleyen bildirim yok'; end if;
  for i in 1..5 loop
    update public.conventity_outbox set attempts = i where id = v_id;
    perform public.conventity_outbox_finish(v_id, false, 'SMTP 550 kutu dolu');
  end loop;
  select status, last_error into v_st, v_hata from public.conventity_outbox where id=v_id;
  if v_st <> 'failed' then raise exception 'KIRMIZI 11b: basarisizlik failed olmadi (%)', v_st; end if;
  if v_hata is null then raise exception 'KIRMIZI 11c: hata sebebi kaydedilmedi'; end if;
  raise notice 'YESIL 11: basarisizlik gorunur kaliyor (% / %)', v_st, left(v_hata,20);
end $$;

-- ------------------- 12) adresi olmayan alici kuyruga hic girmez
do $$
declare v bigint;
begin
  v := public.conventity_enqueue_mail('x', null, null, 'tr', null, null, null, '{}'::jsonb, 'bos:1');
  if v is not null then raise exception 'KIRMIZI 12: adressiz satir kuyruga girdi'; end if;
  v := public.conventity_enqueue_mail('x', 'gecersiz', null, 'tr', null, null, null, '{}'::jsonb, 'bos:2');
  if v is not null then raise exception 'KIRMIZI 12b: gecersiz adres kuyruga girdi'; end if;
  raise notice 'YESIL 12: adressiz/gecersiz alici kuyruga girmiyor';
end $$;

-- ---------------------------------------------------------------- temizlik
delete from public.conventity_outbox
 where event_id in (select id from public.conventus_managed_events where code='BILDIRIM-TEST');
delete from public.conventus_registrations where email='bildirim-katilimci@test.local';
delete from public.conventus_managed_events where code='BILDIRIM-TEST';

select 'TEST-NOTIFICATIONS: HEPSI YESIL' as sonuc;
