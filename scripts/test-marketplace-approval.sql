-- test-marketplace-approval.sql
-- Pazar yeri onay kuyrugu: saglayici -> yonetici karari -> katilimci.
--
-- Kalici guard: 23_marketplace_approval.sql geri alinirsa kirmizi olur.
-- Kritik iddialar:
--   * saglayici kendi teklifini ONAYLAYAMAZ
--   * yonetici bekleyen teklifi GORUR ve karara BAGLAR
--   * yonetici teklifin ICERIGINI degistiremez (onay, saglayicinin sozudur)
--   * BASKA etkinligin yoneticisi karisamaz
--   * katilimci yalnizca ONAYLI teklifi gorur
--   * her adim bildirim uretir

\pset format aligned
\pset border 2
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------- fikstur
insert into auth.users (id,email) values
  ('aa000000-0000-0000-0000-0000000000a1','saglayici@test.local'),
  ('aa000000-0000-0000-0000-0000000000a2','pazaryonetici@test.local'),
  ('aa000000-0000-0000-0000-0000000000a3','pazarkatilimci@test.local'),
  ('aa000000-0000-0000-0000-0000000000a4','yabancıyonetici@test.local')
on conflict (id) do nothing;

insert into public.conventity_activities (id,title,source_ref) values
  ('bb000000-0000-0000-0000-0000000000b1','PazarTest','pazar:test'),
  ('bb000000-0000-0000-0000-0000000000b2','PazarYabanci','pazar:yabanci')
on conflict (id) do nothing;

delete from public.conventity_roles
 where auth_user_id in ('aa000000-0000-0000-0000-0000000000a2','aa000000-0000-0000-0000-0000000000a4');
insert into public.conventity_roles (auth_user_id,scope,scope_id,role,status) values
  ('aa000000-0000-0000-0000-0000000000a2','activity','bb000000-0000-0000-0000-0000000000b1','event_manager','active'),
  ('aa000000-0000-0000-0000-0000000000a4','activity','bb000000-0000-0000-0000-0000000000b2','event_manager','active');

delete from public.conventity_outbox where dedupe_key like '%offer%';
delete from public.gm_offers where title in ('Konferans tarifesi','Ikinci teklif');
delete from public.gm_providers where contact_email='saglayici@test.local';
delete from public.conventus_managed_events where code='PAZAR-TEST';

insert into public.conventus_managed_events
  (code,title,published,visibility,created_by,activity_id,poc_email,poc_name)
values ('PAZAR-TEST','Pazar Etkinligi',true,'public',
        'aa000000-0000-0000-0000-0000000000a2','bb000000-0000-0000-0000-0000000000b1',
        'pazaryonetici@test.local','Pazar Yoneticisi');

insert into public.gm_providers (name,type,owner_user_id,contact_email,accredited)
values ('Test Otel','hotel','aa000000-0000-0000-0000-0000000000a1','saglayici@test.local',true);

-- ---------------------------------------- 0) kurgu saglamasi
do $$
declare v_s boolean; v_y boolean;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a1';
  v_s := public.conventity_can_manage_event('bb000000-0000-0000-0000-0000000000b1');
  reset role;
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a2';
  v_y := public.conventity_can_manage_event('bb000000-0000-0000-0000-0000000000b1');
  reset role;
  if v_s then raise exception 'KIRMIZI 0a: saglayici etkinligi yonetiyor — kurgu bozuk'; end if;
  if not v_y then raise exception 'KIRMIZI 0b: yonetici rolu etkisiz'; end if;
  raise notice 'YESIL 0: saglayici yonetici degil, yonetici yetkili';
end $$;

-- ------------------------------- 1) saglayici teklifi 'pending' olarak sunar
do $$
declare v_n int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a1';
  insert into public.gm_offers (provider_id,event_id,tag,title,body,status)
  select p.id, e.id, 'city','Konferans tarifesi','Tek kisilik oda, kahvalti dahil.','pending'
    from public.gm_providers p, public.conventus_managed_events e
   where p.contact_email='saglayici@test.local' and e.code='PAZAR-TEST';
  reset role;
  select count(*) into v_n from public.gm_offers where title='Konferans tarifesi';
  if v_n <> 1 then raise exception 'KIRMIZI 1: teklif olusturulamadi'; end if;
  raise notice 'YESIL 1: saglayici teklifi sundu (pending)';
end $$;

-- ------------------------------- 2) saglayici KENDINI onaylayamaz
do $$
declare v_d text; v_h text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a1';
    update public.gm_offers set status='approved' where title='Konferans tarifesi';
  exception when others then v_h := sqlerrm;
  end;
  reset role;
  select status into v_d from public.gm_offers where title='Konferans tarifesi';
  if v_d = 'approved' then raise exception 'KIRMIZI 2: saglayici kendi teklifini onayladi'; end if;
  raise notice 'YESIL 2: saglayici kendini onaylayamiyor (durum=%)', v_d;
end $$;

-- ------------------------------- 3) katilimci ONAYSIZ teklifi goremez
do $$
declare v_n int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a3';
  select count(*) into v_n from public.gm_offers where title='Konferans tarifesi';
  reset role;
  if v_n <> 0 then raise exception 'KIRMIZI 3: katilimci onaysiz teklifi gordu (% satir)', v_n; end if;
  raise notice 'YESIL 3: onaysiz teklif katilimciya gorunmuyor';
end $$;

-- ------------------------------- 4) YONETICI bekleyen teklifi GORUR
do $$
declare v_n int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a2';
  select count(*) into v_n from public.gm_offers where title='Konferans tarifesi';
  reset role;
  if v_n <> 1 then raise exception 'KIRMIZI 4: yonetici bekleyen teklifi goremiyor (% satir)', v_n; end if;
  raise notice 'YESIL 4: yonetici onay kuyrugunu goruyor';
end $$;

-- ------------------------------- 5) yonetici ICERIGI degistiremez
do $$
declare v_h text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a2';
    update public.gm_offers set status='approved', body='Ben degistirdim.'
     where title='Konferans tarifesi';
  exception when others then v_h := sqlerrm;
  end;
  reset role;
  if v_h is null then raise exception 'KIRMIZI 5: yonetici teklif metnini degistirebildi'; end if;
  raise notice 'YESIL 5: teklif icerigi yoneticiye kapali';
end $$;

-- ------------------------------- 6) yonetici ONAYLAR
do $$
declare v_d text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a2';
  update public.gm_offers set status='approved' where title='Konferans tarifesi';
  reset role;
  select status into v_d from public.gm_offers where title='Konferans tarifesi';
  if v_d <> 'approved' then raise exception 'KIRMIZI 6: yonetici onaylayamadi (durum=%)', v_d; end if;
  raise notice 'YESIL 6: yonetici teklifi onayladi';
end $$;

-- ------------------------------- 7) onaydan SONRA katilimci gorur
do $$
declare v_n int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a3';
  select count(*) into v_n from public.gm_offers where title='Konferans tarifesi';
  reset role;
  if v_n <> 1 then raise exception 'KIRMIZI 7: onayli teklif katilimciya gorunmuyor'; end if;
  raise notice 'YESIL 7: onayli teklif katilimciya gorunuyor';
end $$;

-- ------------------------------- 8) onaydan sonra saglayici metni degistiremez
do $$
declare v_h text := null; v_b text;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a1';
    update public.gm_offers set body='Sessizce degistirdim.' where title='Konferans tarifesi';
  exception when others then v_h := sqlerrm;
  end;
  reset role;
  select body into v_b from public.gm_offers where title='Konferans tarifesi';
  if v_b like 'Sessizce%' then
    raise exception 'KIRMIZI 8: onaydan sonra saglayici metni degistirdi — katilimci baska bir sey gordu';
  end if;
  raise notice 'YESIL 8: onaydan sonra metin kilitli';
end $$;

-- ------------------------------- 9) BASKA etkinligin yoneticisi karisamaz
do $$
declare v_n int; v_d text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a4';
  select count(*) into v_n from public.gm_offers where title='Konferans tarifesi' and status='pending';
  update public.gm_offers set status='rejected' where title='Konferans tarifesi';
  reset role;
  select status into v_d from public.gm_offers where title='Konferans tarifesi';
  if v_d <> 'approved' then
    raise exception 'KIRMIZI 9: baska etkinligin yoneticisi karari degistirdi (durum=%)', v_d;
  end if;
  raise notice 'YESIL 9: etkinlikler arasi yalitim korunuyor';
end $$;

-- ------------------------------- 10) bildirimler uretildi mi
do $$
declare v_g int; v_o int;
begin
  select count(*) into v_g from public.conventity_outbox
   where kind='mgr_offer_submitted' and to_email='pazaryonetici@test.local';
  select count(*) into v_o from public.conventity_outbox
   where kind='offer_approved' and to_email='saglayici@test.local';
  if v_g <> 1 then raise exception 'KIRMIZI 10a: yoneticiye teklif bildirimi % adet', v_g; end if;
  if v_o <> 1 then raise exception 'KIRMIZI 10b: saglayiciya onay bildirimi % adet', v_o; end if;
  raise notice 'YESIL 10: her iki tarafa da bildirim uretildi';
end $$;

-- ------------------------------- 11) RED yolu da calisir ve bildirilir
do $$
declare v_d text; v_r int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a1';
  insert into public.gm_offers (provider_id,event_id,tag,title,body,status)
  select p.id, e.id, 'city','Ikinci teklif','Ikinci gövde.','pending'
    from public.gm_providers p, public.conventus_managed_events e
   where p.contact_email='saglayici@test.local' and e.code='PAZAR-TEST';
  reset role;

  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a2';
  update public.gm_offers set status='rejected' where title='Ikinci teklif';
  reset role;

  select status into v_d from public.gm_offers where title='Ikinci teklif';
  select count(*) into v_r from public.conventity_outbox
   where kind='offer_rejected' and to_email='saglayici@test.local';
  if v_d <> 'rejected' then raise exception 'KIRMIZI 11a: red yolu calismadi (%)', v_d; end if;
  if v_r <> 1 then raise exception 'KIRMIZI 11b: red bildirimi % adet', v_r; end if;
  raise notice 'YESIL 11: red yolu calisiyor ve bildiriliyor';
end $$;

-- ------------------------------- 12) reddedilen teklif duzeltilip yeniden sunulur
do $$
declare v_d text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = 'aa000000-0000-0000-0000-0000000000a1';
  update public.gm_offers set body='Duzeltilmis gövde.', status='pending' where title='Ikinci teklif';
  reset role;
  select status into v_d from public.gm_offers where title='Ikinci teklif';
  if v_d <> 'pending' then
    raise exception 'KIRMIZI 12: reddedilen teklif yeniden sunulamadi (%)', v_d;
  end if;
  raise notice 'YESIL 12: reddedilen teklif duzeltilip yeniden sunulabiliyor';
end $$;

-- ---------------------------------------------------------------- temizlik
delete from public.conventity_outbox
 where event_id in (select id from public.conventus_managed_events where code='PAZAR-TEST');
delete from public.gm_offers where title in ('Konferans tarifesi','Ikinci teklif');
delete from public.gm_providers where contact_email='saglayici@test.local';
delete from public.conventus_managed_events where code='PAZAR-TEST';
delete from public.conventity_roles
 where auth_user_id in ('aa000000-0000-0000-0000-0000000000a2','aa000000-0000-0000-0000-0000000000a4');

select 'TEST-MARKETPLACE-APPROVAL: HEPSI YESIL' as sonuc;
