-- ============================================================================
-- conventus_logistics_rpc.sql · Conventus v2 — FAZ A2 · İdari & Lojistik (S23)
-- Etkinlik yöneticisi (yaratıcı olmasa da) logistics jsonb'yi yazabilsin.
-- managed_events UPDATE RLS'i (PART B) beklemeden, can_manage_event içeriden
-- denetleyen SECURITY DEFINER RPC ile (create RPC deseni). Idempotent.
-- ============================================================================

begin;

create or replace function conventus_set_event_logistics(p_activity_id uuid, p_logistics jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not conventity_can_manage_event(p_activity_id) then
    raise exception 'not authorized to manage this event';
  end if;
  update conventus_managed_events
     set logistics = coalesce(p_logistics, '{}'::jsonb)
   where activity_id = p_activity_id;
end $$;

grant execute on function conventus_set_event_logistics(uuid, jsonb) to anon, authenticated;

notify pgrst, 'reload schema';
commit;

select 'rpc' as check, proname from pg_proc where proname='conventus_set_event_logistics';
