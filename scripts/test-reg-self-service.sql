-- test-reg-self-service.sql
-- Kayit sahibinin kendi satirinda ne yapip ne yapamadigini kaniter.
-- Kalici guard: sql/18_reg_self_service.sql geri alinirsa bu test kirmizi olur.
--
-- IKI TUZAK (ikisine de dusuldu, ikisi de burada kapali):
--  1) Yerel auth.uid() govdesi
--       select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
--     yani TEKIL 'claim.sub'. Cogul 'request.jwt.claims' yazilirsa auth.uid()
--     NULL doner, her UPDATE 0 satir gunceller -> YANLIS NEGATIF.
--  2) Test kimligi fiksturde ekosistem admini olmamali. Admin zaten onaylayabilir;
--     onunla olculen "acik" YANLIS POZITIFTIR. Asagida once rol yoklugu dogrulanir.
--
--  KATILIMCI : 22222222-... (hicbir rolu yok)
--  ORGANIZATOR: 11111111-... (ecosystem admin)

\pset format aligned
\pset border 2
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------- fikstur
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111','org@test.local'),
  ('22222222-2222-2222-2222-222222222222','katilimci@test.local')
on conflict (id) do nothing;

insert into public.conventity_roles (auth_user_id, scope, role, status)
select '11111111-1111-1111-1111-111111111111','ecosystem','admin','active'
 where not exists (select 1 from public.conventity_roles
                    where auth_user_id='11111111-1111-1111-1111-111111111111'
                      and scope='ecosystem' and role='admin');

insert into public.conventity_activities (id, title, source_ref)
values ('77777777-7777-7777-7777-777777777777','Kanit','kanit:test')
on conflict (id) do nothing;

delete from public.conventus_registrations where email='katilimci@test.local';
delete from public.conventus_managed_events where code='KANIT-TEST';

insert into public.conventus_managed_events (code,title,published,visibility,created_by,activity_id)
values ('KANIT-TEST','Kanit',true,'public',
        '11111111-1111-1111-1111-111111111111','77777777-7777-7777-7777-777777777777');

insert into public.conventus_registrations
       (event_id,activity_id,user_id,email,first_name,status)
select id,'77777777-7777-7777-7777-777777777777',
       '22222222-2222-2222-2222-222222222222','katilimci@test.local','Katilimci','submitted'
  from public.conventus_managed_events where code='KANIT-TEST';

-- ------------------------------------------------ 0) duzenek saglamasi
do $$
declare v_uid uuid; v_admin boolean; v_yon boolean;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  v_uid   := auth.uid();
  v_admin := public.conventity_is_admin('ecosystem');
  v_yon   := public.conventity_can_manage_event('77777777-7777-7777-7777-777777777777');
  reset role;
  if v_uid is distinct from '22222222-2222-2222-2222-222222222222'::uuid then
    raise exception 'KIRMIZI 0a: auth.uid() kurulmadi (% ) — GUC adi yanlis olabilir', v_uid;
  end if;
  if v_admin or v_yon then
    raise exception 'KIRMIZI 0b: test kimligi yetkili (admin=%, yonetici=%) — olcum gecersiz', v_admin, v_yon;
  end if;
  raise notice 'YESIL 0: uid kuruldu ve katilimcinin hicbir yetkisi yok';
end $$;

-- ------------------------------------- 1) kendini onaylayabiliyor mu? (HAYIR)
do $$
declare v_hata text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    update public.conventus_registrations
       set status='approved' where email='katilimci@test.local';
  exception when others then v_hata := sqlerrm;
  end;
  reset role;
  if v_hata is null then
    raise exception 'KIRMIZI 1: katilimci kendini onaylayabildi';
  end if;
  raise notice 'YESIL 1: kendini onaylama engellendi';
end $$;

do $$
declare v_d text;
begin
  select status into v_d from public.conventus_registrations where email='katilimci@test.local';
  if v_d <> 'submitted' then raise exception 'KIRMIZI 1b: durum % oldu', v_d; end if;
  raise notice 'YESIL 1b: durum submitted kaldi';
end $$;

-- ---------------------------------- 2) kimlik kolonunu degistirebilir mi? (HAYIR)
do $$
declare v_hata text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    update public.conventus_registrations
       set confirmation_code='HACK-0001' where email='katilimci@test.local';
  exception when others then v_hata := sqlerrm;
  end;
  reset role;
  if v_hata is null then raise exception 'KIRMIZI 2: confirmation_code degistirilebildi'; end if;
  raise notice 'YESIL 2: kimlik kolonu korunuyor';
end $$;

-- ------------------------------- 3) onur konugu isareti koyabilir mi? (HAYIR)
do $$
declare v_hata text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    update public.conventus_registrations
       set is_guest_of_honour=true where email='katilimci@test.local';
  exception when others then v_hata := sqlerrm;
  end;
  reset role;
  if v_hata is null then raise exception 'KIRMIZI 3: katilimci kendini onur konugu yapabildi'; end if;
  raise notice 'YESIL 3: protokol isareti korunuyor';
end $$;

-- ------------------- 4) acik kayitta kendi bilgisini duzenleyebilir mi? (EVET)
do $$
declare v_kurum text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  update public.conventus_registrations
     set institution='LANDCOM', phone='+90 555 000 0000'
   where email='katilimci@test.local';
  reset role;
  select institution into v_kurum from public.conventus_registrations where email='katilimci@test.local';
  if v_kurum is distinct from 'LANDCOM' then raise exception 'KIRMIZI 4: duzenleme engellendi'; end if;
  raise notice 'YESIL 4: acik kayitta duzenleme calisiyor';
end $$;

-- ------------------------------------------ 5) kendi kaydini iptal edebilir mi? (EVET)
do $$
declare v_d text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  update public.conventus_registrations set status='cancelled' where email='katilimci@test.local';
  reset role;
  select status into v_d from public.conventus_registrations where email='katilimci@test.local';
  if v_d <> 'cancelled' then raise exception 'KIRMIZI 5: iptal engellendi (%)', v_d; end if;
  raise notice 'YESIL 5: kendi kaydini iptal edebiliyor';
end $$;

-- ---------------------- 6) iptalden sonra kendini geri acabilir mi? (HAYIR)
do $$
declare v_hata text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    update public.conventus_registrations set status='submitted' where email='katilimci@test.local';
  exception when others then v_hata := sqlerrm;
  end;
  reset role;
  if v_hata is null then raise exception 'KIRMIZI 6: iptal edilmis kayit katilimci tarafindan geri acildi'; end if;
  raise notice 'YESIL 6: iptal geri alinamiyor (organizator isi)';
end $$;

-- --------------------------- 7) ORGANIZATOR hala tam yetkili mi? (EVET)
do $$
declare v_d text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  update public.conventus_registrations set status='submitted' where email='katilimci@test.local';
  update public.conventus_registrations set status='approved'  where email='katilimci@test.local';
  reset role;
  select status into v_d from public.conventus_registrations where email='katilimci@test.local';
  if v_d <> 'approved' then raise exception 'KIRMIZI 7: organizator onayi bozuldu (%)', v_d; end if;
  raise notice 'YESIL 7: organizator onay/geri-acma yetkisi bozulmadi';
end $$;

-- ------------------- 8) onaylanmis kayitta katilimci icerik duzenleyemez (HAYIR)
do $$
declare v_hata text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    update public.conventus_registrations set passport_no='X1234567' where email='katilimci@test.local';
  exception when others then v_hata := sqlerrm;
  end;
  reset role;
  if v_hata is null then raise exception 'KIRMIZI 8: onaylanmis kayitta pasaport degistirilebildi'; end if;
  raise notice 'YESIL 8: onay sonrasi icerik kilitli';
end $$;

-- ------------------- 9) onaylanmis kaydi katilimci yine de iptal edebilir (EVET)
do $$
declare v_d text;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  update public.conventus_registrations set status='cancelled' where email='katilimci@test.local';
  reset role;
  select status into v_d from public.conventus_registrations where email='katilimci@test.local';
  if v_d <> 'cancelled' then raise exception 'KIRMIZI 9: onayli kayit iptal edilemedi (%)', v_d; end if;
  raise notice 'YESIL 9: onayli kayit iptal edilebiliyor';
end $$;

-- ---------------- 10) baskasinin kaydina erisim yok (gorunum bunu gostermez)
do $$
declare v_sayi int;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  select count(*) into v_sayi from public.conventus_my_registrations_v;
  reset role;
  if v_sayi <> 1 then raise exception 'KIRMIZI 10: gorunum % satir dondu (1 olmali)', v_sayi; end if;
  raise notice 'YESIL 10: gorunum yalnizca kendi kaydini gosteriyor';
end $$;

-- ===========================================================================
-- 11-14) GERCEK ORGANIZATOR (ecosystem admin DEGIL, activity scope'unda
--        event_manager). Guard'i yalnizca adminle test etmek yeterli degil:
--        adminin yolu ile normal organizatorun yolu conventity_can_manage_event
--        icinde AYRI dallar. Organizatorun onay yetkisi kirilirsa bu kirmizi olur.
-- ===========================================================================
insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333','yonetici@test.local'),
  ('44444444-4444-4444-4444-444444444444','katilimci2@test.local')
on conflict (id) do nothing;

insert into public.conventity_activities (id, title, source_ref)
values ('88888888-8888-8888-8888-888888888888','Kontrol','kontrol:test')
on conflict (id) do nothing;

delete from public.conventity_roles where auth_user_id='33333333-3333-3333-3333-333333333333';
insert into public.conventity_roles (auth_user_id, scope, scope_id, role, status)
values ('33333333-3333-3333-3333-333333333333','activity',
        '88888888-8888-8888-8888-888888888888','event_manager','active');

delete from public.conventus_registrations where email='katilimci2@test.local';
delete from public.conventus_managed_events where code='KONTROL-TEST';
insert into public.conventus_managed_events (code,title,published,visibility,created_by,activity_id)
values ('KONTROL-TEST','Kontrol',true,'public',
        '33333333-3333-3333-3333-333333333333','88888888-8888-8888-8888-888888888888');
insert into public.conventus_registrations (event_id,activity_id,user_id,email,first_name,status)
select id,'88888888-8888-8888-8888-888888888888',
       '44444444-4444-4444-4444-444444444444','katilimci2@test.local','K2','submitted'
  from public.conventus_managed_events where code='KONTROL-TEST';

do $$
declare v_admin boolean; v_yon boolean;
begin
  set local role authenticated;
  set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  v_admin := public.conventity_is_admin('ecosystem');
  v_yon   := public.conventity_can_manage_event('88888888-8888-8888-8888-888888888888');
  reset role;
  if v_admin then raise exception 'KIRMIZI 11a: kurgu bozuk — organizator ayni zamanda admin'; end if;
  if not v_yon then raise exception 'KIRMIZI 11b: event_manager rolu etkisiz'; end if;
  raise notice 'YESIL 11: organizator admin degil ama etkinligi yonetiyor';
end $$;

do $$
declare v_d text; v_h text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
    update public.conventus_registrations set status='approved' where email='katilimci2@test.local';
  exception when others then v_h := sqlerrm;
  end;
  reset role;
  select status into v_d from public.conventus_registrations where email='katilimci2@test.local';
  if v_h is not null or v_d <> 'approved' then
    raise exception 'KIRMIZI 12: gercek organizator onaylayamadi (durum=%, hata=%)', v_d, coalesce(v_h,'-');
  end if;
  raise notice 'YESIL 12: gercek event_manager onaylayabiliyor';
end $$;

do $$
declare v_h text := null;
begin
  begin
    set local role authenticated;
    set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
    -- katilimciya onay sonrasi KAPALI olan alan; organizatore acik olmali
    update public.conventus_registrations set passport_no='U1234567' where email='katilimci2@test.local';
  exception when others then v_h := sqlerrm;
  end;
  reset role;
  if v_h is not null then raise exception 'KIRMIZI 13: organizator onay sonrasi duzenleyemedi: %', v_h; end if;
  raise notice 'YESIL 13: organizator onay sonrasi duzenleyebiliyor';
end $$;

-- 14) BASKA etkinligin organizatoru bu kayda dokunamaz (yalitim).
--     Guard'in degil RLS'in isi, ama birlikte tutmazlarsa acik kalir.
insert into public.conventity_activities (id, title, source_ref)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','Yabanci','yabanci:test')
on conflict (id) do nothing;
delete from public.conventus_managed_events where code='YABANCI-TEST';
insert into public.conventus_managed_events (code,title,published,visibility,created_by,activity_id)
values ('YABANCI-TEST','Yabanci',true,'public',
        '11111111-1111-1111-1111-111111111111','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
delete from public.conventity_roles where auth_user_id='55555555-5555-5555-5555-555555555555';
insert into auth.users (id,email) values
  ('55555555-5555-5555-5555-555555555555','yabanci@test.local') on conflict (id) do nothing;
insert into public.conventity_roles (auth_user_id, scope, scope_id, role, status)
values ('55555555-5555-5555-5555-555555555555','activity',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','event_manager','active');

do $$
declare v_d text;
begin
  update public.conventus_registrations set status='submitted' where email='katilimci2@test.local';
  set local role authenticated;
  set local request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  update public.conventus_registrations set status='rejected' where email='katilimci2@test.local';
  reset role;
  select status into v_d from public.conventus_registrations where email='katilimci2@test.local';
  if v_d <> 'submitted' then
    raise exception 'KIRMIZI 14: BASKA etkinligin yoneticisi kaydi degistirdi (durum=%)', v_d;
  end if;
  raise notice 'YESIL 14: etkinlikler arasi yalitim korunuyor';
end $$;

delete from public.conventus_registrations where email='katilimci2@test.local';
delete from public.conventus_managed_events where code in ('KONTROL-TEST','YABANCI-TEST');
delete from public.conventity_roles where auth_user_id in
  ('33333333-3333-3333-3333-333333333333','55555555-5555-5555-5555-555555555555');

-- ---------------------------------------------------------------- temizlik
delete from public.conventity_outbox
 where event_id in (select id from public.conventus_managed_events
                     where code in ('KANIT-TEST','KONTROL-TEST','YABANCI-TEST'));
delete from public.conventus_registrations where email='katilimci@test.local';
delete from public.conventus_managed_events where code='KANIT-TEST';

select 'TEST-REG-SELF-SERVICE: HEPSI YESIL' as sonuc;
