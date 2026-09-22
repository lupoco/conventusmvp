-- ============================================================
-- Connectus — Bağlantılar (Step 2)  ·  amaç-kilitli connection isteği
-- 2026-07-23
--
-- "Connect" akışı: istek (neden'iyle) -> kabul/ret -> bağlantı.
-- Yazımlar security-definer RPC'lerden; okuma RLS ile (iki taraf görür).
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. *_ROLLBACK.sql
-- VARSAYIM: conventity_cn_my_person_id() (Faz-1) + conventity_is_admin('ecosystem') mevcut.
-- ============================================================

create table if not exists public.conventity_cn_connections (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.conventity_people(id) on delete cascade,
  addressee_id  uuid not null references public.conventity_people(id) on delete cascade,
  status        text not null default 'pending' check (status in ('pending','accepted','declined')),
  purpose       text,                 -- amaç-kilitli: neden bağlanıyorsun
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  unique (requester_id, addressee_id)
);
create index if not exists idx_cn_conn_req  on public.conventity_cn_connections(requester_id);
create index if not exists idx_cn_conn_addr on public.conventity_cn_connections(addressee_id);

alter table public.conventity_cn_connections enable row level security;
-- Okuma: yalnız iki taraf (+ admin). Yazımlar RPC'lerden (security definer).
drop policy if exists cn_conn_read on public.conventity_cn_connections;
create policy cn_conn_read on public.conventity_cn_connections for select using (
  conventity_is_admin('ecosystem')
  or requester_id = public.conventity_cn_my_person_id()
  or addressee_id = public.conventity_cn_my_person_id()
);

-- ── İstek gönder ───────────────────────────────────────────────────────────
create or replace function public.connectus_connect(p_addressee uuid, p_purpose text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid; ex record;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  if p_addressee is null or p_addressee = me then return jsonb_build_object('ok',false,'error','invalid'); end if;
  select * into ex from public.conventity_cn_connections
    where (requester_id=me and addressee_id=p_addressee)
       or (requester_id=p_addressee and addressee_id=me)
    limit 1;
  if found then return jsonb_build_object('ok',true,'status',ex.status,'existing',true); end if;
  insert into public.conventity_cn_connections (requester_id, addressee_id, purpose)
    values (me, p_addressee, nullif(trim(coalesce(p_purpose,'')),''));
  return jsonb_build_object('ok',true,'status','pending');
end $$;

-- ── Yanıtla (kabul/ret) — yalnız addressee ─────────────────────────────────
create or replace function public.connectus_respond(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid; r record;
begin
  me := public.conventity_cn_my_person_id();
  select * into r from public.conventity_cn_connections where id = p_id limit 1;
  if not found then return jsonb_build_object('ok',false,'error','not_found'); end if;
  if r.addressee_id <> me then return jsonb_build_object('ok',false,'error','forbidden'); end if;
  if r.status <> 'pending' then return jsonb_build_object('ok',true,'status',r.status); end if;
  update public.conventity_cn_connections
    set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
    where id = p_id;
  return jsonb_build_object('ok',true,'status', case when p_accept then 'accepted' else 'declined' end);
end $$;

-- ── Bağlantılarım + istekler (frontend durum haritası) ─────────────────────
create or replace function public.connectus_connections()
returns jsonb language sql stable security definer set search_path = public as $$
  with me as (select public.conventity_cn_my_person_id() as id)
  select jsonb_build_object(
    'accepted', coalesce((select jsonb_agg(jsonb_build_object(
        'connection_id', c.id,
        'person_id', case when c.requester_id=(select id from me) then c.addressee_id else c.requester_id end,
        'name', coalesce(p.full_name,p.email,'Member'),
        'tagline', coalesce(p.role_title,'')))
      from public.conventity_cn_connections c
      join public.conventity_people p on p.id = case when c.requester_id=(select id from me) then c.addressee_id else c.requester_id end
      where c.status='accepted' and (c.requester_id=(select id from me) or c.addressee_id=(select id from me))), '[]'::jsonb),
    'incoming', coalesce((select jsonb_agg(jsonb_build_object(
        'connection_id', c.id, 'person_id', c.requester_id,
        'name', coalesce(p.full_name,p.email,'Member'), 'tagline', coalesce(p.role_title,''), 'purpose', c.purpose))
      from public.conventity_cn_connections c
      join public.conventity_people p on p.id = c.requester_id
      where c.status='pending' and c.addressee_id=(select id from me)), '[]'::jsonb),
    'outgoing', coalesce((select jsonb_agg(c.addressee_id)
      from public.conventity_cn_connections c
      where c.status='pending' and c.requester_id=(select id from me)), '[]'::jsonb)
  );
$$;

grant execute on function public.connectus_connect(uuid, text)   to authenticated;
grant execute on function public.connectus_respond(uuid, boolean) to authenticated;
grant execute on function public.connectus_connections()          to authenticated;

notify pgrst, 'reload schema';
