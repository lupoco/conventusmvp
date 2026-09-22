-- Connectus - feed engagement (reactions + comments) - 2026-07-24
-- Verified clean (libpg_query). Run once in Supabase SQL Editor.
create table if not exists public.conventity_cn_post_reactions (
  post_id uuid not null references public.conventity_cn_posts(id) on delete cascade,
  person_id uuid not null references public.conventity_people(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, person_id)
);
create index if not exists idx_cn_react_post on public.conventity_cn_post_reactions(post_id);

create table if not exists public.conventity_cn_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.conventity_cn_posts(id) on delete cascade,
  author_id uuid not null references public.conventity_people(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_cn_comment_post on public.conventity_cn_post_comments(post_id);

alter table public.conventity_cn_post_reactions enable row level security;
alter table public.conventity_cn_post_comments enable row level security;

drop policy if exists cn_react_read on public.conventity_cn_post_reactions;
create policy cn_react_read on public.conventity_cn_post_reactions for select using (
  conventity_is_admin('ecosystem')
  or exists (select 1 from public.conventity_cn_posts po
             join public.conventity_cn_memberships m on m.group_id = po.group_id
             where po.id = post_id and m.person_id = public.conventity_cn_my_person_id())
);
drop policy if exists cn_comment_read on public.conventity_cn_post_comments;
create policy cn_comment_read on public.conventity_cn_post_comments for select using (
  conventity_is_admin('ecosystem')
  or exists (select 1 from public.conventity_cn_posts po
             join public.conventity_cn_memberships m on m.group_id = po.group_id
             where po.id = post_id and m.person_id = public.conventity_cn_my_person_id())
);

create or replace function public.connectus_react(p_post uuid, p_on boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $func$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok', false, 'error', 'no_profile'); end if;
  if not exists (select 1 from public.conventity_cn_posts po
                 join public.conventity_cn_memberships m on m.group_id = po.group_id
                 where po.id = p_post and m.person_id = me)
    then return jsonb_build_object('ok', false, 'error', 'not_member'); end if;
  if p_on then
    insert into public.conventity_cn_post_reactions (post_id, person_id)
      values (p_post, me) on conflict (post_id, person_id) do nothing;
  else
    delete from public.conventity_cn_post_reactions where post_id = p_post and person_id = me;
  end if;
  return jsonb_build_object('ok', true, 'on', p_on);
end $func$;

create or replace function public.connectus_comment(p_post uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = public as $func$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok', false, 'error', 'no_profile'); end if;
  if not exists (select 1 from public.conventity_cn_posts po
                 join public.conventity_cn_memberships m on m.group_id = po.group_id
                 where po.id = p_post and m.person_id = me)
    then return jsonb_build_object('ok', false, 'error', 'not_member'); end if;
  if coalesce(trim(p_body), '') = '' then return jsonb_build_object('ok', false, 'error', 'empty'); end if;
  insert into public.conventity_cn_post_comments (post_id, author_id, body) values (p_post, me, trim(p_body));
  return jsonb_build_object('ok', true);
end $func$;

create or replace function public.connectus_post_comments(p_post uuid, p_limit int default 50)
returns jsonb language sql stable security definer set search_path = public as $func$
  select coalesce((select jsonb_agg(j order by j_at asc) from (
    select jsonb_build_object('id', c.id, 'body', c.body, 'created_at', c.created_at,
             'author', coalesce(a.full_name, a.email, 'Member'),
             'author_id', c.author_id) as j, c.created_at as j_at
    from public.conventity_cn_post_comments c
    left join public.conventity_people a on a.id = c.author_id
    where c.post_id = p_post
    order by c.created_at asc limit p_limit
  ) s), '[]'::jsonb);
$func$;

create or replace function public.connectus_feed(p_group uuid default null, p_limit int default 30)
returns jsonb language sql stable security definer set search_path = public as $func$
  with me as (select public.conventity_cn_my_person_id() as id),
  mine as (select group_id from public.conventity_cn_memberships where person_id = (select id from me))
  select coalesce((select jsonb_agg(j order by j_at desc) from (
    select jsonb_build_object(
      'id', po.id, 'group_id', po.group_id, 'group_name', g.name,
      'body', po.body, 'kind', po.kind, 'created_at', po.created_at,
      'author', coalesce(a.full_name, a.email, 'Member'),
      'author_id', po.author_id,
      'reactions', (select count(*) from public.conventity_cn_post_reactions r where r.post_id = po.id),
      'reacted', exists (select 1 from public.conventity_cn_post_reactions r where r.post_id = po.id and r.person_id = (select id from me)),
      'comments', (select count(*) from public.conventity_cn_post_comments c where c.post_id = po.id)
    ) as j, po.created_at as j_at
    from public.conventity_cn_posts po
    join public.conventity_cn_groups g on g.id = po.group_id
    left join public.conventity_people a on a.id = po.author_id
    where po.group_id in (select group_id from mine)
      and (p_group is null or po.group_id = p_group)
    order by po.created_at desc
    limit p_limit
  ) s), '[]'::jsonb);
$func$;

grant execute on function public.connectus_react(uuid, boolean) to authenticated;
grant execute on function public.connectus_comment(uuid, text) to authenticated;
grant execute on function public.connectus_post_comments(uuid, int) to authenticated;
grant execute on function public.connectus_feed(uuid, int) to authenticated;

notify pgrst, 'reload schema';
