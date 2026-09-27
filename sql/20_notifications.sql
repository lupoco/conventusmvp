-- 20_notifications.sql
-- E-posta bildirim katmani — "transactional outbox" deseni.
--
-- NEDEN BU DESEN: bildirimi durum degisikligiyle AYNI transaction'da kuyruga
-- yaziyoruz. Kayit onaylandi ama e-posta kaybolmus olamaz; ikisi birlikte olur
-- ya da birlikte olmaz. Gonderim ayri bir surecte (Edge Function) yapilir,
-- basarisizlik satirda GORUNUR kalir — sessizce yutulmaz.
--
-- NE YAZILIR: yalnizca VERI (kime, hangi olay, hangi etkinlik). Metin burada
-- degil Edge Function'da uretilir. Sebep: merkezi bakim — musteriye ozel
-- sablon kopyasi olmaz, dil/metin tek yerden degisir.
--
-- KIM BILGILENDIRILIR
--   kayit alindi    -> katilimci (tesekkur) + organizator (yeni basvuru)
--   onaylandi       -> katilimci
--   reddedildi      -> katilimci
--   beklemeye alindi-> katilimci
--   iptal edildi    -> katilimci (teyit) + organizator (yer bosaldi)
--
-- Idempotent.

begin;

-- ---------------------------------------------------------------------------
-- 1) Kuyruk
-- ---------------------------------------------------------------------------
create table if not exists public.conventity_outbox (
  id            bigint generated always as identity primary key,
  kind          text not null,
  to_email      text not null,
  to_name       text,
  lang          text not null default 'tr',
  community_id  uuid,        -- kiraci: markalama + kapsam
  activity_id   uuid,        -- etkinlik: yonetici RLS'i buradan
  event_id      bigint,
  payload       jsonb not null default '{}'::jsonb,
  dedupe_key    text not null,
  status        text not null default 'pending',
  attempts      int  not null default 0,
  last_error    text,
  scheduled_at  timestamptz not null default now(),
  sent_at       timestamptz,
  created_at    timestamptz not null default now(),
  constraint outbox_status_ck check (status in ('pending','sent','failed','skipped')),
  constraint outbox_email_ck  check (position('@' in to_email) > 1)
);

-- Ayni olay iki kez kuyruga girmez. Tek gercek cift-gonderim korumasi budur.
create unique index if not exists outbox_dedupe_uidx
  on public.conventity_outbox (dedupe_key);

-- Drenaj sorgusu: bekleyen ve zamani gelmis, eski once.
create index if not exists outbox_pending_idx
  on public.conventity_outbox (status, scheduled_at)
  where status = 'pending';

create index if not exists outbox_activity_idx
  on public.conventity_outbox (activity_id, created_at desc);

alter table public.conventity_outbox enable row level security;

-- Okuma: etkinligi yoneten gorur (kendi kuyrugunu izleyebilsin diye).
drop policy if exists outbox_manager_read on public.conventity_outbox;
create policy outbox_manager_read on public.conventity_outbox
  for select to authenticated
  using (public.conventity_can_manage_event(activity_id));

-- INSERT/UPDATE/DELETE politikasi YOK: kuyruga yalnizca trigger (tanimlayici
-- haklariyla) yazar, yalnizca drenaj (service_role) gunceller. Istemci
-- kuyruga eleman ekleyemez -> uzerimizden spam gonderilemez.

-- ---------------------------------------------------------------------------
-- 2) Kuyruga ekleme yardimcisi (ileride pazar yeri de bunu kullanacak)
-- ---------------------------------------------------------------------------
create or replace function public.conventity_enqueue_mail(
  p_kind text, p_to_email text, p_to_name text, p_lang text,
  p_community_id uuid, p_activity_id uuid, p_event_id bigint,
  p_payload jsonb, p_dedupe_key text, p_scheduled_at timestamptz default now()
) returns bigint
language plpgsql security definer set search_path to 'public' as $fn$
declare v_id bigint;
begin
  -- Adres yoksa kuyruga hic girmez; sessiz bir "basarisiz" satir uretmeyiz.
  if p_to_email is null or position('@' in p_to_email) < 2 then
    return null;
  end if;
  insert into public.conventity_outbox
    (kind, to_email, to_name, lang, community_id, activity_id, event_id,
     payload, dedupe_key, scheduled_at)
  values
    (p_kind, lower(trim(p_to_email)), p_to_name, coalesce(p_lang,'tr'),
     p_community_id, p_activity_id, p_event_id,
     coalesce(p_payload,'{}'::jsonb), p_dedupe_key, coalesce(p_scheduled_at, now()))
  on conflict (dedupe_key) do nothing
  returning id into v_id;
  return v_id;
end;
$fn$;

revoke execute on function public.conventity_enqueue_mail(
  text,text,text,text,uuid,uuid,bigint,jsonb,text,timestamptz) from public, anon;

-- ---------------------------------------------------------------------------
-- 3) Kayit olaylarini kuyruga bagla
-- ---------------------------------------------------------------------------
create or replace function public.conventus_reg_notify()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_ev      record;
  v_kind    text;
  v_ad      text;
  v_yonkind text;
  v_payload jsonb;
begin
  select e.id, e.code, e.title, e.start_date, e.end_date, e.location,
         e.community_id, e.activity_id, e.poc_email, e.poc_name
    into v_ev
    from public.conventus_managed_events e
   where e.id = new.event_id;
  if not found then
    return new;   -- etkinlik yoksa bildirilecek bir sey de yok
  end if;

  if tg_op = 'INSERT' then
    if coalesce(new.status,'submitted') not in ('submitted','under_review') then
      return new;
    end if;
    v_kind := 'reg_submitted';
  else
    if new.status is not distinct from old.status then
      return new;
    end if;
    v_kind := case new.status
      when 'approved'  then 'reg_approved'
      when 'rejected'  then 'reg_rejected'
      when 'waitlisted' then 'reg_waitlisted'
      when 'cancelled' then 'reg_cancelled'
      else null end;
    if v_kind is null then
      return new;   -- draft/under_review/checked_in: e-posta gerekmiyor
    end if;
  end if;

  v_ad := nullif(trim(coalesce(new.first_name,'') || ' ' || coalesce(new.last_name,'')), '');

  v_payload := jsonb_build_object(
    'registration_id', new.id,
    'event_code',      v_ev.code,
    'event_title',     v_ev.title,
    'start_date',      v_ev.start_date,
    'end_date',        v_ev.end_date,
    'location',        v_ev.location,
    'status',          new.status,
    'confirmation_code', new.confirmation_code,
    'participant_name',  v_ad,
    'participant_email', new.email,
    'institution',     new.institution
  );

  -- katilimciya
  perform public.conventity_enqueue_mail(
    v_kind, new.email, v_ad, 'tr',
    v_ev.community_id, v_ev.activity_id, v_ev.id, v_payload,
    v_kind || ':' || new.id::text || ':' || coalesce(new.status,'-'));

  -- organizatore: yalnizca yeni basvuru ve iptal ilgilendirir
  v_yonkind := case v_kind
    when 'reg_submitted' then 'mgr_new_registration'
    when 'reg_cancelled' then 'mgr_cancellation'
    else null end;

  if v_yonkind is not null and v_ev.poc_email is not null then
    perform public.conventity_enqueue_mail(
      v_yonkind, v_ev.poc_email, v_ev.poc_name, 'tr',
      v_ev.community_id, v_ev.activity_id, v_ev.id, v_payload,
      v_yonkind || ':' || new.id::text || ':' || coalesce(new.status,'-'));
  end if;

  return new;
end;
$fn$;

comment on function public.conventus_reg_notify() is
  'Kayit durumu degisince conventity_outbox''a bildirim satiri yazar (ayni transaction).';

drop trigger if exists trg_conventus_reg_notify on public.conventus_registrations;
create trigger trg_conventus_reg_notify
  after insert or update on public.conventus_registrations
  for each row execute function public.conventus_reg_notify();

-- ---------------------------------------------------------------------------
-- 4) Drenaj yardimcilari (service_role tarafindan cagrilir)
-- ---------------------------------------------------------------------------
create or replace function public.conventity_outbox_claim(p_limit int default 25)
returns setof public.conventity_outbox
language sql volatile set search_path to 'public' as $fn$
  update public.conventity_outbox o
     set attempts = o.attempts + 1
   where o.id in (
     select id from public.conventity_outbox
      where status = 'pending' and scheduled_at <= now() and attempts < 5
      order by scheduled_at
      limit greatest(1, least(coalesce(p_limit,25), 100))
      for update skip locked
   )
  returning o.*;
$fn$;

revoke execute on function public.conventity_outbox_claim(int) from public, anon, authenticated;

-- 5 denemeden sonra pes eder ve GORUNUR sekilde 'failed' olur.
create or replace function public.conventity_outbox_finish(
  p_id bigint, p_ok boolean, p_error text default null
) returns void
language sql volatile set search_path to 'public' as $fn$
  update public.conventity_outbox
     set status = case when p_ok then 'sent'
                       when attempts >= 5 then 'failed'
                       else 'pending' end,
         sent_at = case when p_ok then now() else null end,
         last_error = case when p_ok then null else left(coalesce(p_error,'?'), 500) end,
         scheduled_at = case when p_ok or attempts >= 5 then scheduled_at
                             else now() + (attempts * interval '2 minutes') end
   where id = p_id;
$fn$;

revoke execute on function public.conventity_outbox_finish(bigint, boolean, text) from public, anon, authenticated;

commit;

-- ---------------------------------------------------------------------------
-- DOGRULAMA
-- ---------------------------------------------------------------------------
select
  (select count(*) from information_schema.tables
    where table_name='conventity_outbox')                          as "kuyruk (1)",
  (select count(*) from pg_policies
    where tablename='conventity_outbox')                           as "politika (1)",
  (select count(*) from pg_policies
    where tablename='conventity_outbox' and cmd<>'SELECT')         as "yazma politikasi (0)",
  (select count(*) from pg_trigger
    where tgrelid='public.conventus_registrations'::regclass
      and tgname='trg_conventus_reg_notify')                       as "tetikleyici (1)",
  (select count(*) from pg_indexes
    where indexname='outbox_dedupe_uidx')                          as "cift-gonderim kilidi (1)";
