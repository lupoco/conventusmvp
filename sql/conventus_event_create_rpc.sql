-- ============================================================================
-- conventus_event_create_rpc.sql · Conventus v2 — FAZ A2 · SQL dilimi 1b
-- T9: etkinlik oluşturulunca activity_id OTOMATİK açılsın. + kayıt yönetici RLS.
-- Idempotent. Faz A1 + go_and_test_v2 (dilim 1) çalıştırılmış olmalı.
--
-- Neden RPC: conventity_activities'e yazmak normal kullanıcıya RLS'te kapalı
-- olabilir. SECURITY DEFINER fonksiyon, can_manage_community kontrolünü İÇERDE
-- yaparak (RLS gerçek sınır) activity + event'i atomik açar. new-event.html bunu çağırır.
-- ============================================================================

begin;

create or replace function conventus_create_managed_event(
  p_community_id      uuid,
  p_code              text,
  p_title             text,
  p_start_date        date,
  p_end_date          date,
  p_location          text,
  p_host_org          text,
  p_description       text,
  p_registration_open boolean,
  p_invite_only       boolean
) returns conventus_managed_events
language plpgsql security definer set search_path = public as $$
declare v_act uuid; v_row conventus_managed_events;
begin
  if p_title is null or length(btrim(p_title)) = 0 then
    raise exception 'title required';
  end if;
  if p_community_id is null or not conventity_can_manage_community(p_community_id) then
    raise exception 'not authorized to create events for this community';
  end if;

  -- Etkinliğin activity satırı (idempotent: source_ref = event kodu).
  -- source 'internal' (canlıda geçerli: internal/external; 'conventus' CHECK'te YOK).
  -- activity_type 'event' CHECK'te yoksa 'challenge'a düş.
  select id into v_act from conventity_activities
    where source_ref = 'conventus_event_code:'||p_code limit 1;
  if v_act is null then
    begin
      insert into conventity_activities (title, activity_type, source, origin_ref, source_ref)
      values (p_title, 'event', 'internal', 'conventus', 'conventus_event_code:'||p_code)
      returning id into v_act;
    exception when check_violation then
      insert into conventity_activities (title, activity_type, source, origin_ref, source_ref)
      values (p_title, 'challenge', 'internal', 'conventus', 'conventus_event_code:'||p_code)
      returning id into v_act;
    end;
  end if;

  insert into conventus_managed_events (
    code, title, start_date, end_date, location, host_org, description,
    registration_open, invite_only, community_id, activity_id, created_by)
  values (
    p_code, p_title, p_start_date, p_end_date, p_location, p_host_org, p_description,
    coalesce(p_registration_open, true), coalesce(p_invite_only, false),
    p_community_id, v_act, auth.uid())
  returning * into v_row;

  return v_row;
end $$;

grant execute on function conventus_create_managed_event(
  uuid,text,text,date,date,text,text,text,boolean,boolean) to anon, authenticated;

-- ── Kayıt yönetimi RLS (additive) — etkinlik yöneticisi kayıtları görür+günceller ──
-- Mevcut "reg: own *" / "reg: organiser *" politikalarına DOKUNULMAZ; bunlar OR'lanır.
drop policy if exists reg_manager_read on conventus_registrations;
create policy reg_manager_read on conventus_registrations for select using (
  exists (select 1 from conventus_managed_events e
           where e.id = conventus_registrations.event_id
             and conventity_can_manage_event(e.activity_id))
);
drop policy if exists reg_manager_update on conventus_registrations;
create policy reg_manager_update on conventus_registrations for update using (
  exists (select 1 from conventus_managed_events e
           where e.id = conventus_registrations.event_id
             and conventity_can_manage_event(e.activity_id))
) with check (
  exists (select 1 from conventus_managed_events e
           where e.id = conventus_registrations.event_id
             and conventity_can_manage_event(e.activity_id))
);

notify pgrst, 'reload schema';
commit;

-- doğrulama
select 'rpc' as check, proname from pg_proc where proname='conventus_create_managed_event';
select 'reg_policies' as check, policyname from pg_policies
  where tablename='conventus_registrations' and policyname in ('reg_manager_read','reg_manager_update');
