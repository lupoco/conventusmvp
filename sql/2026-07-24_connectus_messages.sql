-- ============================================================
-- Connectus — Mesajlaşma (messages.html)  ·  1:1 doğrudan mesaj
-- 2026-07-24
--
-- Yeni tablo conventity_cn_messages + RLS + security-definer RPC katmanı.
-- Okuma RLS (yalnız iki taraf + admin); yazımlar RPC'lerden.
-- "Thread" = iki kişi (sıralı olmayan çift). Amaç-kilitli: yalnız ekosistem üyeleri.
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. *_ROLLBACK.sql
-- VARSAYIM: conventity_cn_my_person_id() · conventity_is_admin('ecosystem') mevcut.
-- ============================================================

create table if not exists public.conventity_cn_messages (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.conventity_people(id) on delete cascade,
  recipient_id uuid not null references public.conventity_people(id) on delete cascade,
  body         text not null,
  created_at   timestamptz not null default now(),
  read_at      timestamptz
);
create index if not exists idx_cn_msg_sender    on public.conventity_cn_messages(sender_id);
create index if not exists idx_cn_msg_recipient on public.conventity_cn_messages(recipient_id);
create index if not exists idx_cn_msg_created    on public.conventity_cn_messages(created_at);

alter table public.conventity_cn_messages enable row level security;
-- Okuma: yalnız iki taraf (+ admin). Yazım/güncelleme: RPC'lerden (security definer).
drop policy if exists cn_msg_read on public.conventity_cn_messages;
create policy cn_msg_read on public.conventity_cn_messages for select using (
  conventity_is_admin('ecosystem')
  or sender_id    = public.conventity_cn_my_person_id()
  or recipient_id = public.conventity_cn_my_person_id()
);

-- ── Mesaj gönder ───────────────────────────────────────────────────────────
create or replace function public.connectus_send_message(p_to uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  if p_to is null or p_to = me then return jsonb_build_object('ok',false,'error','invalid'); end if;
  if not exists (select 1 from public.conventity_people p where p.id = p_to)
    then return jsonb_build_object('ok',false,'error','no_recipient'); end if;
  if coalesce(trim(p_body),'') = '' then return jsonb_build_object('ok',false,'error','empty'); end if;
  insert into public.conventity_cn_messages (sender_id, recipient_id, body)
    values (me, p_to, trim(p_body));
  return jsonb_build_object('ok',true);
end $$;

-- ── Thread listesi (her muhatap için son mesaj + okunmamış sayısı) ──────────
create or replace function public.connectus_threads()
returns jsonb language sql stable security definer set search_path = public as $$
  with me as (select public.conventity_cn_my_person_id() as id),
  conv as (
    select case when m.sender_id = (select id from me) then m.recipient_id else m.sender_id end as other,
           m.body, m.created_at, m.sender_id, m.recipient_id, m.read_at
    from public.conventity_cn_messages m
    where (select id from me) in (m.sender_id, m.recipient_id)
  ),
  last as (
    select distinct on (other) other, body, created_at, sender_id
    from conv order by other, created_at desc
  ),
  un as (
    select other, count(*) filter (where recipient_id = (select id from me) and read_at is null) as unread
    from conv group by other
  )
  select coalesce((select jsonb_agg(row order by created_at desc) from (
    select jsonb_build_object(
      'person_id', l.other,
      'name', coalesce(p.full_name, p.email, 'Member'),
      'tagline', coalesce(p.role_title, ''),
      'last', l.body,
      'last_at', l.created_at,
      'from_me', l.sender_id = (select id from me),
      'unread', coalesce(u.unread, 0)) as row,
      l.created_at as created_at
    from last l
    join public.conventity_people p on p.id = l.other
    left join un u on u.other = l.other
  ) t), '[]'::jsonb);
$$;

-- ── Tek thread (mesajlar) + okundu işaretle ────────────────────────────────
create or replace function public.connectus_thread(p_with uuid, p_limit int default 200)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid; result jsonb;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  -- gelen okunmamışları okundu yap
  update public.conventity_cn_messages
    set read_at = now()
    where recipient_id = me and sender_id = p_with and read_at is null;
  select jsonb_build_object(
    'ok', true,
    'person', (select jsonb_build_object(
                 'id', p.id, 'name', coalesce(p.full_name,p.email,'Member'), 'tagline', coalesce(p.role_title,''))
               from public.conventity_people p where p.id = p_with),
    'messages', coalesce((select jsonb_agg(row order by created_at asc) from (
        select jsonb_build_object('id', m.id, 'body', m.body, 'created_at', m.created_at,
                 'from_me', m.sender_id = me) as row, m.created_at as created_at
        from public.conventity_cn_messages m
        where (m.sender_id = me and m.recipient_id = p_with)
           or (m.sender_id = p_with and m.recipient_id = me)
        order by m.created_at desc
        limit p_limit
      ) s), '[]'::jsonb)
  ) into result;
  return result;
end $$;

grant execute on function public.connectus_send_message(uuid, text) to authenticated;
grant execute on function public.connectus_threads()               to authenticated;
grant execute on function public.connectus_thread(uuid, int)        to authenticated;

notify pgrst, 'reload schema';
