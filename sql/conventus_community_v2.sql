-- ============================================================================
-- conventus_community_v2.sql · Conventus v2 — FAZ A1 (Hiyerarşi + Yetki şeması)
-- Idempotent · tek transaction · text+CHECK (enum yok) · RLS doğuştan açık.
-- TEK YETKİ KAYNAĞI: conventity_roles (yeni yetki/üyelik tablosu AÇILMAZ).
--
-- SIRA: şema → CHECK/index → managed_events bağı → miras trigger → yetki fn
--       → denetim → RLS (yeni tablolar) → doğrulama.  Frontend YOK.
--
-- ⚠ PART B (en altta): conventus_managed_events / conventus_registrations
--   ÜZERİNDEKİ MEVCUT RLS'i değiştirir. 00_introspect_v2.sql #6/#7 çıktısını
--   görmeden ÇALIŞTIRMA — kör politika silmiyoruz, orada bekliyor.
--
-- ⚠ VARSAYIM NOKTALARI (introspection ile doğrula):
--   A) conventus_managed_events.activity_id kolonu var mı? — yoksa aşağıda EKLENİR.
--   B) conventity_activities.activity_type CHECK 'event' değerini kabul ediyor mu?
--      Etmiyorsa backfill 'challenge' kullanır (kod bunu kullanıyor, geçerli).
--   C) conventity_roles'ta RESTRICTIVE politika VARSA yeni izinler AND'lenir;
--      T16 regresyon testini çalıştır.
-- ============================================================================

begin;

-- ─────────────────────────────────────────────────────────────────────────
-- 1) TOPLULUK TABLOSU + İKİ SEVİYE KİLİDİ
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists conventus_communities (
  id             uuid primary key default gen_random_uuid(),
  parent_id      uuid references conventus_communities(id) on delete restrict,
  level          int  not null default 1 check (level in (1,2)),
  slug           text unique not null,
  name           text not null,
  short_name     text,
  tagline        text,
  about          text,
  logo_url       text,
  banner_url     text,
  org_id         uuid references conventity_orgs(id),
  country        text,
  contact_email  text,
  visibility     text not null default 'public'
                 check (visibility in ('public','unlisted','private')),
  join_policy    text not null default 'invite'
                 check (join_policy in ('open','request','invite')),
  domain         text[] default '{}',
  focus_area     text[] default '{}',
  is_active      boolean not null default true,
  provisioned_by uuid,
  provisioned_at timestamptz default now(),
  source_ref     text unique,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists idx_cc_parent on conventus_communities(parent_id);
create index if not exists idx_cc_slug   on conventus_communities(slug);

-- Derinlik = 2 SABİT (karar #1): parent_id olan topluluk parent olamaz.
create or replace function conventus_cc_depth_guard()
returns trigger language plpgsql as $$
declare p_level int;
begin
  if new.parent_id is null then
    new.level := 1;
  else
    select level into p_level from conventus_communities where id = new.parent_id;
    if p_level is null then raise exception 'parent community not found'; end if;
    if p_level <> 1 then
      raise exception 'Only two levels are allowed: a sub-community cannot have children';
    end if;
    new.level := 2;
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_cc_depth on conventus_communities;
create trigger trg_cc_depth before insert or update on conventus_communities
  for each row execute function conventus_cc_depth_guard();

-- ─────────────────────────────────────────────────────────────────────────
-- 2) conventity_roles GENİŞLETMESİ (tek yetki kaynağı)
-- ─────────────────────────────────────────────────────────────────────────
alter table conventity_roles
  add column if not exists scope_id    uuid,
  add column if not exists status      text default 'active',
  add column if not exists granted_via uuid,
  add column if not exists expires_at  timestamptz,
  add column if not exists note        text;

-- CHECK'leri genişlet (idempotent: drop + add). Mevcut değerler alt kümedir.
alter table conventity_roles drop constraint if exists conventity_roles_scope_check;
alter table conventity_roles add  constraint conventity_roles_scope_check
  check (scope in ('ecosystem','convexus','conventus','conventlab','connectus',
                   'consultus','convergens','community','activity'));

alter table conventity_roles drop constraint if exists conventity_roles_role_check;
alter table conventity_roles add  constraint conventity_roles_role_check
  check (role in ('admin','organizer','vendor','member','owner','event_manager'));

alter table conventity_roles drop constraint if exists conventity_roles_status_check;
alter table conventity_roles add  constraint conventity_roles_status_check
  check (status in ('pending','active','suspended','revoked'));

-- scope_id tutarlılığı: community/activity'de ZORUNLU, diğerlerinde NULL.
alter table conventity_roles drop constraint if exists conventity_roles_scopeid_check;
alter table conventity_roles add  constraint conventity_roles_scopeid_check
  check ( (scope in ('community','activity') and scope_id is not null)
       or (scope not in ('community','activity') and scope_id is null) );

create unique index if not exists uq_roles_user_scope
  on conventity_roles(auth_user_id, scope, scope_id, role)
  where auth_user_id is not null;
create index if not exists idx_roles_scope on conventity_roles(scope, scope_id, status);

-- ─────────────────────────────────────────────────────────────────────────
-- 3) conventus_managed_events BAĞLANTISI + activity_id güvencesi
-- ─────────────────────────────────────────────────────────────────────────
alter table conventus_managed_events
  add column if not exists activity_id       uuid,   -- (A) yoksa ekler; §3 kararı
  add column if not exists community_id       uuid references conventus_communities(id),
  add column if not exists visibility         text default 'public'
      check (visibility in ('public','unlisted','members_only')),
  add column if not exists reg_opens_at       timestamptz,
  add column if not exists reg_closes_at      timestamptz,
  add column if not exists capacity           int,
  add column if not exists requires_approval  boolean default true,
  add column if not exists waitlist_enabled   boolean default false,
  add column if not exists logistics          jsonb  default '{}'::jsonb;
create index if not exists idx_cme_community on conventus_managed_events(community_id);
create index if not exists idx_cme_activity  on conventus_managed_events(activity_id);

-- ─────────────────────────────────────────────────────────────────────────
-- 4) ÜYELİK MİRASI (karar #2) — trigger'lar. scope<>'community' ERKEN return.
--    (conventity_roles tüm ekosistemin kaynağı — platform rolleri BOZULMAZ.)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function conventus_membership_cascade()
returns trigger language plpgsql security definer set search_path = public as $$
declare p_id uuid;
begin
  if new.scope <> 'community' then return new; end if;         -- KORUMA
  select parent_id into p_id from conventus_communities where id = new.scope_id;
  if p_id is not null then
    insert into conventity_roles (person_id, auth_user_id, scope, scope_id, role,
                                  status, granted_by, granted_via, note)
    values (new.person_id, new.auth_user_id, 'community', p_id, 'member',
            new.status, new.granted_by, new.id, 'inherited from sub-community')
    on conflict do nothing;
  end if;
  return new;
end $$;
drop trigger if exists trg_membership_cascade on conventity_roles;
create trigger trg_membership_cascade after insert on conventity_roles
  for each row execute function conventus_membership_cascade();

create or replace function conventus_membership_revoke_cascade()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.scope <> 'community' then return old; end if;          -- KORUMA
  delete from conventity_roles r
   where r.scope = 'community'
     and r.auth_user_id = old.auth_user_id
     and r.scope_id in (select id from conventus_communities where parent_id = old.scope_id);
  return old;
end $$;
drop trigger if exists trg_membership_revoke on conventity_roles;
create trigger trg_membership_revoke after delete on conventity_roles
  for each row execute function conventus_membership_revoke_cascade();

-- ─────────────────────────────────────────────────────────────────────────
-- 5) YETKİ FONKSİYONLARI (RLS'in tek arayüzü)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function conventity_community_role(p_cid uuid)
returns text language sql stable security definer set search_path = public as $$
  with me as (select auth.uid() u)
  select r.role from conventity_roles r, me
   where r.scope='community' and r.status='active' and r.auth_user_id = me.u
     and ( r.scope_id = p_cid
        or r.scope_id = (select parent_id from conventus_communities where id = p_cid) )
   order by case r.role when 'owner' then 1 when 'admin' then 2
                        when 'organizer' then 3 else 4 end
   limit 1;
$$;

create or replace function conventity_in_community(p_cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select conventity_community_role(p_cid) is not null;
$$;

-- Belirli bir kullanıcının bir topluluğun AKTİF üyesi olup olmadığı (karar #3 için).
create or replace function conventity_uid_in_community(p_uid uuid, p_cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from conventity_roles r
                  where r.scope='community' and r.status='active'
                    and r.auth_user_id = p_uid and r.scope_id = p_cid);
$$;

create or replace function conventity_can_manage_community(p_cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select conventity_is_admin('ecosystem')
      or coalesce(conventity_community_role(p_cid) in ('owner','admin'), false);
$$;

-- ⚠ KARAR #3'ÜN TEK NOKTASI — Faz B'de "dış organizatör" için SADECE burası değişir.
create or replace function conventity_can_manage_event(p_activity_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select conventity_is_admin('ecosystem')
      or exists (
           select 1 from conventity_roles r
            where r.scope='activity' and r.scope_id = p_activity_id
              and r.auth_user_id = auth.uid() and r.status='active'
              and r.role in ('event_manager','organizer')
              and (r.expires_at is null or r.expires_at > now())
         )
      or exists (
           select 1 from conventus_managed_events e
            where e.activity_id = p_activity_id
              and conventity_can_manage_community(e.community_id)
         );
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 6) DENETİM İZİ (append-only) + otomatik yazan trigger
-- ─────────────────────────────────────────────────────────────────────────
create table if not exists conventus_role_events (
  id            bigserial primary key,
  role_id       uuid,
  auth_user_id  uuid,
  scope         text,
  scope_id      uuid,
  action        text not null check (action in
                 ('granted','revoked','role_changed','status_changed','inherited')),
  from_value    text,
  to_value      text,
  actor_user_id uuid,
  note          text,
  created_at    timestamptz not null default now()
);
create index if not exists idx_role_events_scope on conventus_role_events(scope, scope_id);

create or replace function conventus_log_role_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                      to_value,actor_user_id,note)
    values (new.id,new.auth_user_id,new.scope,new.scope_id,
            case when new.note like 'inherited%' then 'inherited' else 'granted' end,
            new.role,auth.uid(),new.note);
    return new;
  elsif tg_op = 'UPDATE' then
    if new.role is distinct from old.role then
      insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                        from_value,to_value,actor_user_id)
      values (new.id,new.auth_user_id,new.scope,new.scope_id,'role_changed',
              old.role,new.role,auth.uid());
    end if;
    if new.status is distinct from old.status then
      insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                        from_value,to_value,actor_user_id)
      values (new.id,new.auth_user_id,new.scope,new.scope_id,'status_changed',
              old.status,new.status,auth.uid());
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                      from_value,actor_user_id)
    values (old.id,old.auth_user_id,old.scope,old.scope_id,'revoked',old.role,auth.uid());
    return old;
  end if;
  return null;
end $$;
drop trigger if exists trg_role_audit on conventity_roles;
create trigger trg_role_audit after insert or update or delete on conventity_roles
  for each row execute function conventus_log_role_event();

-- ─────────────────────────────────────────────────────────────────────────
-- 7) RLS — YENİ TABLOLAR (doğuştan açık)
-- ─────────────────────────────────────────────────────────────────────────
alter table conventus_communities enable row level security;

drop policy if exists cc_select on conventus_communities;
create policy cc_select on conventus_communities for select using (
  visibility = 'public' or conventity_in_community(id) or conventity_is_admin('ecosystem')
);

-- INSERT: level 1 → SADECE ekosistem admin; level 2 → üst topluluk admini.
drop policy if exists cc_insert on conventus_communities;
create policy cc_insert on conventus_communities for insert with check (
  (parent_id is null and conventity_is_admin('ecosystem'))
  or (parent_id is not null and conventity_can_manage_community(parent_id))
);

drop policy if exists cc_update on conventus_communities;
create policy cc_update on conventus_communities for update using (
  conventity_can_manage_community(id)
) with check (
  conventity_can_manage_community(id)
);

drop policy if exists cc_delete on conventus_communities;
create policy cc_delete on conventus_communities for delete using (
  conventity_is_admin('ecosystem')
  or (parent_id is not null and conventity_can_manage_community(parent_id))
);

-- Denetim izi: yönetenler OKUR; insert yalnız trigger (security definer); UPDATE/DELETE YOK.
alter table conventus_role_events enable row level security;
drop policy if exists cre_select on conventus_role_events;
create policy cre_select on conventus_role_events for select using (
  conventity_is_admin('ecosystem')
  or (scope='community' and conventity_can_manage_community(scope_id))
  or (scope='activity'  and exists (
        select 1 from conventus_managed_events e
         where e.activity_id = conventus_role_events.scope_id
           and conventity_can_manage_community(e.community_id)))
);
-- (insert/update/delete policy YOK — append-only. Trigger definer olarak yazar.)

-- ─────────────────────────────────────────────────────────────────────────
-- 8) RLS — conventity_roles'a EK community/activity politikaları (additive)
--    Mevcut 22 politikaya DOKUNULMAZ; bunlar ayrı adlarla eklenir.
-- ─────────────────────────────────────────────────────────────────────────
-- community kapsamı
drop policy if exists roles_community_select on conventity_roles;
create policy roles_community_select on conventity_roles for select using (
  scope='community' and (auth_user_id = auth.uid() or conventity_can_manage_community(scope_id))
);
drop policy if exists roles_community_insert on conventity_roles;
create policy roles_community_insert on conventity_roles for insert with check (
  scope='community' and (
    conventity_can_manage_community(scope_id)
    or ( auth_user_id = auth.uid() and role='member'
         and exists (select 1 from conventus_communities c
                      where c.id = scope_id and c.join_policy in ('open','request')) )
  )
);
drop policy if exists roles_community_update on conventity_roles;
create policy roles_community_update on conventity_roles for update using (
  scope='community' and conventity_can_manage_community(scope_id)
) with check (
  scope='community' and conventity_can_manage_community(scope_id)
);
drop policy if exists roles_community_delete on conventity_roles;
create policy roles_community_delete on conventity_roles for delete using (
  scope='community' and (auth_user_id = auth.uid() or conventity_can_manage_community(scope_id))
);

-- activity kapsamı — atanan kişi hedef etkinliğin topluluğunun AKTİF üyesi olmalı (karar #3)
drop policy if exists roles_activity_select on conventity_roles;
create policy roles_activity_select on conventity_roles for select using (
  scope='activity' and (
    auth_user_id = auth.uid()
    or exists (select 1 from conventus_managed_events e
                where e.activity_id = scope_id
                  and conventity_can_manage_community(e.community_id))
  )
);
drop policy if exists roles_activity_insert on conventity_roles;
create policy roles_activity_insert on conventity_roles for insert with check (
  scope='activity' and role in ('event_manager','organizer')
  and exists (
    select 1 from conventus_managed_events e
     where e.activity_id = scope_id                                  -- scope_id = yeni satır
       and conventity_can_manage_community(e.community_id)           -- atayan yetkili mi
       and conventity_uid_in_community(auth_user_id, e.community_id) -- atanan aktif üye mi (karar #3)
  )
);
drop policy if exists roles_activity_update on conventity_roles;
create policy roles_activity_update on conventity_roles for update using (
  scope='activity' and exists (select 1 from conventus_managed_events e
    where e.activity_id = scope_id and conventity_can_manage_community(e.community_id))
);
drop policy if exists roles_activity_delete on conventity_roles;
create policy roles_activity_delete on conventity_roles for delete using (
  scope='activity' and (
    auth_user_id = auth.uid()
    or exists (select 1 from conventus_managed_events e
                where e.activity_id = scope_id
                  and conventity_can_manage_community(e.community_id))
  )
);

-- ─────────────────────────────────────────────────────────────────────────
-- 9) BACKFILL — her yönetilen etkinlik için conventity_activities satırı (§3)
--    Idempotent: source_ref guard. (B) activity_type: önce 'event' dene, CHECK
--    reddederse 'challenge'a düş (kod bunu kullanıyor → geçerli).
-- ─────────────────────────────────────────────────────────────────────────
do $$
declare e record; act uuid; ref text;
begin
  for e in select id, code, title from conventus_managed_events where activity_id is null loop
    ref := 'conventus_event:'||e.id;
    -- NOT EXISTS guard (source_ref'te unique kısıt varsaymadan idempotent)
    if not exists (select 1 from conventity_activities where source_ref = ref) then
      begin
        insert into conventity_activities (title, activity_type, source, origin_ref, source_ref)
        values (coalesce(e.title, e.code, 'Event '||e.id), 'event', 'conventus',
                coalesce(e.code, e.id::text), ref);
      exception when check_violation then          -- activity_type 'event' CHECK'te yoksa
        insert into conventity_activities (title, activity_type, source, origin_ref, source_ref)
        values (coalesce(e.title, e.code, 'Event '||e.id), 'challenge', 'conventus',
                coalesce(e.code, e.id::text), ref);
      end;
    end if;
    select id into act from conventity_activities where source_ref = ref limit 1;
    if act is not null then
      update conventus_managed_events set activity_id = act where id = e.id and activity_id is null;
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';

commit;

-- ─────────────────────────────────────────────────────────────────────────
-- DOĞRULAMA SELECT'LERİ (commit sonrası — çıktıyı raporla)
-- ─────────────────────────────────────────────────────────────────────────
select 'communities'      as check, count(*) from conventus_communities;
select 'roles_new_cols'   as check,
       count(*) filter (where scope_id is not null) as scoped_rows,
       count(*) as total_roles from conventity_roles;
select 'events_backfill'  as check,
       count(*) filter (where activity_id is null) as still_null,
       count(*) as total from conventus_managed_events;
select 'role_events'      as check, count(*) from conventus_role_events;
select 'auth_fns'         as check, string_agg(routine_name, ', ') as fns
  from information_schema.routines
 where routine_schema='public'
   and routine_name in ('conventity_community_role','conventity_in_community',
                        'conventity_can_manage_community','conventity_can_manage_event');
-- Beklenen: still_null = 0 · 4 fonksiyon listelenir · communities 0 (henüz provision yok).


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PART B — MEVCUT TABLO RLS'İ (⚠ introspection #6/#7 GÖRMEDEN ÇALIŞTIRMA)  ║
-- ║  conventus_managed_events + conventus_registrations üzerindeki görünürlük  ║
-- ║  ve kayıt-penceresi politikaları. Kör politika SİLMİYORUZ. Aşağıdaki       ║
-- ║  bloğu, mevcut politikaları gördükten ve hangilerinin kaldırılacağını      ║
-- ║  onayladıktan SONRA ayrı çalıştır. §4.6.                                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
/*
begin;
alter table conventus_managed_events enable row level security;

-- ⚠ Mevcut CHECK yalnız ('public','invite') idi → members_only/unlisted için GENİŞLET.
--    (mevcut değerler alt küme; süper küme güvenli.)
alter table conventus_managed_events drop constraint if exists cme_visibility_chk;
alter table conventus_managed_events add  constraint cme_visibility_chk
  check (visibility in ('public','invite','unlisted','members_only'));

-- Görünürlük: public/unlisted+yayında herkese; members_only/invite topluluk üyesine;
--            taslak yalnız yönetenlere.
drop policy if exists cme_select_v2 on conventus_managed_events;
create policy cme_select_v2 on conventus_managed_events for select using (
  (published and visibility in ('public','unlisted'))
  or (visibility in ('members_only','invite') and conventity_in_community(community_id))
  or conventity_can_manage_community(community_id)
  or conventity_can_manage_event(activity_id)
);
drop policy if exists cme_insert_v2 on conventus_managed_events;
create policy cme_insert_v2 on conventus_managed_events for insert with check (
  conventity_can_manage_community(community_id)
);
drop policy if exists cme_update_v2 on conventus_managed_events;
create policy cme_update_v2 on conventus_managed_events for update using (
  conventity_can_manage_event(activity_id)
) with check (
  conventity_can_manage_event(activity_id)
);
drop policy if exists cme_delete_v2 on conventus_managed_events;
create policy cme_delete_v2 on conventus_managed_events for delete using (
  conventity_can_manage_community(community_id)
);

-- Kayıt penceresi RLS'te (UI'a güvenme). event_id → managed_events.
-- ⚠ Mevcut "reg: own insert" (auth.uid()=user_id) pencere ZORLAMIYORDU. PERMISSIVE
--   olduğu için yanına eklenen politika işe yaramaz → o politikayı DEĞİŞTİR (T10).
alter table conventus_registrations enable row level security;
drop policy if exists "reg: own insert" on conventus_registrations;
drop policy if exists cvreg_insert       on conventus_registrations;
create policy cvreg_insert on conventus_registrations for insert with check (
  auth.uid() = user_id
  and exists (select 1 from conventus_managed_events e
               where e.id = event_id and e.published
                 and (e.reg_opens_at  is null or now() >= e.reg_opens_at)
                 and (e.reg_closes_at is null or now() <= e.reg_closes_at))
);
-- Mevcut select/update politikaları (reg: own read / reg: organiser *) KORUNUR —
-- organiser tanımını topluluk modeline çekmek istersek ayrı adımda genişletiriz.

notify pgrst, 'reload schema';
commit;
*/
