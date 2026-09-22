-- ============================================================================
-- conventus_go_and_test_v2.sql · Conventus v2 — FAZ A2 · SQL dilimi 1
-- Rol&Akış mimarisi kararları D1–D4'ün şema tarafı. Idempotent · tek transaction.
-- Faz A1 (conventus_community_v2.sql) çalıştırılmış olmalı.
--
-- Kapsam:
--   D1  conventity_roles.title            (fonksiyonel etkinlik-ekibi unvanı: OPR/POC/…)
--   D2  managed_events.registration_field_defs jsonb  (PAF form tanımı)
--       registrations.answers jsonb                    (PAF cevapları)
--   D3  registrations.status makinesi + 'invited'      (durum genişletme, veri-kayıpsız)
--       conventus_registration_events (append-only geçiş izi) + trigger  (T11)
--   §5.3 announcements.audience / publish_at           (hedef kitle görünürlüğü — T14)
--
-- ⚠ RLS NOTU: registrations UPDATE (onay/red) politikasını topluluk modeline çekmek
--   introspection #6 (managed_events + registrations mevcut policy) gerektiriyor —
--   o ayrı adımda. Bu dosya SADECE şema + append-only denetim ekler (güvenli/additive).
-- ============================================================================

begin;

-- ── D1 · Fonksiyonel unvan (yalnız activity kapsamında dolu; serbest metin) ──
alter table conventity_roles add column if not exists title text;
comment on column conventity_roles.title is
  'Etkinlik ekibi fonksiyonel unvanı (activity kapsamı): opr·poc·protocol·escort·dispatcher·registration… Serbest metin.';

-- ── D2 · PAF: kayıt formu tanımı + cevaplar ─────────────────────────────────
alter table conventus_managed_events
  add column if not exists registration_field_defs jsonb not null default '[]'::jsonb;
-- Beklenen biçim: [{"key":"rank","label":"Rütbe","type":"text","required":true}, …]
-- type ∈ text·textarea·select·checkbox·date(DD.MM.YYYY maskeli)·file

alter table conventus_registrations
  add column if not exists answers jsonb not null default '{}'::jsonb;
-- Beklenen biçim: {"rank":"OF-4","nation":"TUR", …} (registration_field_defs.key → değer)

-- ── D3 · Kayıt durum makinesi (veri-kayıpsız genişletme) ────────────────────
-- Mevcut status CHECK adı/değerleri bilinmiyor → mevcut değerleri KORUYARAK
-- makine değerlerini ekle, eski status-CHECK'i (adı ne olursa) kaldır.
do $$
declare drops text; extra text; vals text;
begin
  -- 1) mevcut kullanılan status değerlerini topla (kaybetme)
  select string_agg(distinct quote_literal(status), ',') into extra
    from conventus_registrations where status is not null;
  -- 2) hedef makine değerleri (D3: 'invited' dahil)
  vals := $q$'invited','draft','submitted','under_review','approved','rejected','waitlisted','checked_in','cancelled','no_show'$q$;
  if extra is not null then vals := vals || ',' || extra; end if;   -- birleşim (yinelenen zararsız)
  -- 3) 'status' geçen mevcut CHECK'leri kaldır
  select string_agg('alter table conventus_registrations drop constraint '||quote_ident(conname)||';', ' ')
    into drops from pg_constraint
    where conrelid = 'public.conventus_registrations'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%status%';
  if drops is not null then execute drops; end if;
  -- 4) genişletilmiş CHECK'i ekle
  execute 'alter table conventus_registrations add constraint conventus_registrations_status_chk '||
          'check (status in ('||vals||'))';
end $$;

-- Geçiş izi (append-only) — silme/düzenleme UI'ı YOK
create table if not exists conventus_registration_events (
  id            bigserial primary key,
  event_id      bigint,
  registrant_uid uuid,
  from_status   text,
  to_status     text not null,
  actor_user_id uuid,
  note          text,
  created_at    timestamptz not null default now()
);
create index if not exists idx_reg_events_event on conventus_registration_events(event_id);

create or replace function conventus_log_registration_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into conventus_registration_events(event_id, registrant_uid, to_status, actor_user_id)
    values (new.event_id, new.user_id, coalesce(new.status,'submitted'), auth.uid());
    return new;
  elsif tg_op = 'UPDATE' then
    if new.status is distinct from old.status then
      insert into conventus_registration_events(event_id, registrant_uid, from_status, to_status, actor_user_id)
      values (new.event_id, new.user_id, old.status, new.status, auth.uid());
    end if;
    return new;
  end if;
  return null;
end $$;
drop trigger if exists trg_registration_audit on conventus_registrations;
create trigger trg_registration_audit after insert or update on conventus_registrations
  for each row execute function conventus_log_registration_event();

alter table conventus_registration_events enable row level security;
drop policy if exists crege_select on conventus_registration_events;
create policy crege_select on conventus_registration_events for select using (
  registrant_uid = auth.uid()
  or exists (select 1 from conventus_managed_events e
              where e.id = conventus_registration_events.event_id
                and conventity_can_manage_event(e.activity_id))
);
-- (insert/update/delete policy YOK — append-only; trigger security definer yazar.)

-- ── §5.3 · Duyuru hedef kitle (görünürlük RLS ile; JS filtresi değil) ────────
alter table conventus_announcements
  add column if not exists audience text not null default 'all'
      check (audience in ('all','approved','pending','organizers','community_members')),
  add column if not exists publish_at timestamptz;
-- not: 'pinned' kolonu zaten var (announcements arayüzü kullanıyor) → eklenmez.

notify pgrst, 'reload schema';

commit;

-- ── DOĞRULAMA (commit sonrası — çıktıyı raporla) ────────────────────────────
select 'roles_title' as check,
       count(*) filter (where title is not null) as with_title from conventity_roles;
select 'paf_cols' as check,
       (select count(*) from information_schema.columns
         where table_name='conventus_managed_events' and column_name='registration_field_defs') as has_field_defs,
       (select count(*) from information_schema.columns
         where table_name='conventus_registrations' and column_name='answers') as has_answers;
select 'status_check' as check, pg_get_constraintdef(oid) as def
  from pg_constraint where conrelid='public.conventus_registrations'::regclass
   and conname='conventus_registrations_status_chk';
select 'reg_events' as check, count(*) from conventus_registration_events;
select 'ann_audience' as check,
       (select count(*) from information_schema.columns
         where table_name='conventus_announcements' and column_name='audience') as has_audience;
-- Beklenen: has_field_defs=1 · has_answers=1 · status_check 'invited' içerir · has_audience=1.
