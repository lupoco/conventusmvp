-- ============================================================
-- Connectus — Gruplar + Feed (Step 3)  ·  amaç-kilitli çalışma alanları
-- 2026-07-23
--
-- Faz-1 tabloları üzerine security-definer RPC katmanı:
--   conventity_cn_groups · _memberships · _posts (canlıda mevcut).
-- Yazımlar RPC'lerden (kilitli grupta INSERT...RETURNING RLS sorunu olmaz).
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. *_ROLLBACK.sql
-- VARSAYIM: conventity_cn_my_person_id() (Faz-1) mevcut.
-- ============================================================

-- purpose_kind'e 'topic'/'community' ekle (LinkedIn-tarzı topluluk için)
alter table public.conventity_cn_groups
  drop constraint if exists conventity_cn_groups_purpose_kind_check;
alter table public.conventity_cn_groups
  add constraint conventity_cn_groups_purpose_kind_check
  check (purpose_kind in ('problem','activity','challenge_area','event','org','topic','community'));

-- ── Grup listesi (görünür: ecosystem + üyesi olduğum kilitli) ───────────────
create or replace function public.connectus_groups()
returns jsonb language sql stable security definer set search_path = public as $$
  with me as (select public.conventity_cn_my_person_id() as id)
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', g.id, 'name', g.name, 'purpose_kind', g.purpose_kind, 'visibility', g.visibility,
    'members', (select count(*) from public.conventity_cn_memberships m where m.group_id = g.id),
    'my_role', (select m.role from public.conventity_cn_memberships m
                where m.group_id = g.id and m.person_id = (select id from me) limit 1)
  ) order by g.created_at desc), '[]'::jsonb)
  from public.conventity_cn_groups g
  where g.visibility = 'ecosystem'
     or exists (select 1 from public.conventity_cn_memberships m
                where m.group_id = g.id and m.person_id = (select id from me));
$$;

-- ── Grup kur (kurucu otomatik moderatör) ───────────────────────────────────
create or replace function public.connectus_create_group(p_name text, p_kind text default 'topic', p_visibility text default 'ecosystem')
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid; gid uuid;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  if coalesce(trim(p_name),'') = '' then return jsonb_build_object('ok',false,'error','name_required'); end if;
  insert into public.conventity_cn_groups (name, purpose_kind, visibility, created_by)
    values (trim(p_name),
            case when p_kind in ('problem','activity','challenge_area','event','org','topic','community') then p_kind else 'topic' end,
            case when p_visibility in ('locked','ecosystem') then p_visibility else 'ecosystem' end,
            me)
    returning id into gid;
  insert into public.conventity_cn_memberships (group_id, person_id, role) values (gid, me, 'moderator');
  return jsonb_build_object('ok',true,'id',gid);
end $$;

-- ── Katıl / Ayrıl ──────────────────────────────────────────────────────────
create or replace function public.connectus_join_group(p_group uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  insert into public.conventity_cn_memberships (group_id, person_id, role)
    values (p_group, me, 'member')
    on conflict (group_id, person_id) do nothing;
  return jsonb_build_object('ok',true);
end $$;

create or replace function public.connectus_leave_group(p_group uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
  delete from public.conventity_cn_memberships where group_id = p_group and person_id = me;
  return jsonb_build_object('ok',true);
end $$;

-- ── Feed (üyesi olduğum grupların gönderileri; ops. tek grup) ───────────────
create or replace function public.connectus_feed(p_group uuid default null, p_limit int default 30)
returns jsonb language sql stable security definer set search_path = public as $$
  with me as (select public.conventity_cn_my_person_id() as id),
  mine as (select group_id from public.conventity_cn_memberships where person_id = (select id from me))
  select coalesce((select jsonb_agg(row order by created_at desc) from (
    select jsonb_build_object(
      'id', po.id, 'group_id', po.group_id, 'group_name', g.name,
      'body', po.body, 'kind', po.kind, 'created_at', po.created_at,
      'author', coalesce(a.full_name, a.email, 'Member')) as row,
      po.created_at as created_at
    from public.conventity_cn_posts po
    join public.conventity_cn_groups g on g.id = po.group_id
    left join public.conventity_people a on a.id = po.author_id
    where po.group_id in (select group_id from mine)
      and (p_group is null or po.group_id = p_group)
    order by po.created_at desc
    limit p_limit
  ) s), '[]'::jsonb);
$$;

-- ── Gönderi oluştur (yalnız grup üyesi) ────────────────────────────────────
create or replace function public.connectus_post(p_group uuid, p_body text, p_kind text default 'note')
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  if not exists (select 1 from public.conventity_cn_memberships where group_id = p_group and person_id = me)
    then return jsonb_build_object('ok',false,'error','not_member'); end if;
  if coalesce(trim(p_body),'') = '' then return jsonb_build_object('ok',false,'error','empty'); end if;
  insert into public.conventity_cn_posts (group_id, author_id, body, kind)
    values (p_group, me, trim(p_body),
            case when p_kind in ('note','ask','offer','announce') then p_kind else 'note' end);
  return jsonb_build_object('ok',true);
end $$;

grant execute on function public.connectus_groups()                          to authenticated, anon;
grant execute on function public.connectus_feed(uuid, int)                   to authenticated;
grant execute on function public.connectus_create_group(text, text, text)    to authenticated;
grant execute on function public.connectus_join_group(uuid)                  to authenticated;
grant execute on function public.connectus_leave_group(uuid)                 to authenticated;
grant execute on function public.connectus_post(uuid, text, text)            to authenticated;

notify pgrst, 'reload schema';
