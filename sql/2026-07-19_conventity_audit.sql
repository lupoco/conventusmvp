-- ============================================================
-- Conventity — Denetim kaydı (audit log)  ·  AÇIK İŞLER #1
-- 2026-07-19  ·  rev 2026-07-23: tablo-varlık guard (rollback güvenliği)
--
-- ÇALIŞTIRMA: Supabase SQL Editor'de tek transaction olarak çalıştır.
-- Idempotent — tekrar çalıştırılabilir. Geri alma: *_ROLLBACK.sql
--
-- VARSAYIMLAR (canlı şemaya göre doğrula):
--   • Denetlenen tabloların PK kolonu adı: id (uuid)
--   • conventity_people.auth_user_id, auth.uid() ile eşleşir
--   • conventity_is_admin(text) mevcut (Core'un ecosystem kapısı)
--   • gen_random_uuid() kullanılabilir (Supabase varsayılan)
-- ============================================================

-- 1) Append-only denetim tablosu -------------------------------
create table if not exists public.conventity_audit (
  id              uuid primary key default gen_random_uuid(),
  actor_auth_uid  uuid,
  actor_person_id uuid,
  table_name      text not null,
  record_id       uuid,
  action          text not null check (action in ('insert','update','delete')),
  diff            jsonb,
  at              timestamptz not null default now()
);

create index if not exists idx_conv_audit_at    on public.conventity_audit(at desc);
create index if not exists idx_conv_audit_tbl   on public.conventity_audit(table_name);
create index if not exists idx_conv_audit_rec   on public.conventity_audit(record_id);

-- 2) Generic trigger fonksiyonu --------------------------------
-- security definer: RLS'e takılmadan audit satırı yazabilsin.
create or replace function public.conventity_audit_trg()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_person uuid;
  v_rec    uuid;
  v_diff   jsonb;
begin
  select id into v_person
    from conventity_people
   where auth_user_id = v_uid
   limit 1;

  if tg_op = 'DELETE' then
    v_rec  := (to_jsonb(old)->>'id')::uuid;
    v_diff := jsonb_build_object('old', to_jsonb(old));
  elsif tg_op = 'UPDATE' then
    v_rec  := (to_jsonb(new)->>'id')::uuid;
    v_diff := jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new));
  else -- INSERT
    v_rec  := (to_jsonb(new)->>'id')::uuid;
    v_diff := jsonb_build_object('new', to_jsonb(new));
  end if;

  insert into conventity_audit(actor_auth_uid, actor_person_id, table_name, record_id, action, diff)
  values (v_uid, v_person, tg_table_name, v_rec, lower(tg_op), v_diff);

  if tg_op = 'DELETE' then return old; else return new; end if;
end
$$;

-- 3) Kritik tablolara trigger bağla (idempotent) ---------------
-- Tablo-varlık guard: 5 tablodan biri canlıda yoksa/yeniden
-- adlandırılmışsa TÜM migration rollback olmasın (CLAUDE.md tuzağı).
do $$
declare t text;
begin
  foreach t in array array[
    'conventity_roles',
    'conventity_matches',
    'conventity_evidence',
    'conventity_orgs',
    'conventity_solutions'
  ] loop
    if to_regclass('public.'||t) is null then
      raise notice 'audit: tablo bulunamadı, trigger atlandı: %', t;
      continue;
    end if;
    execute format('drop trigger if exists trg_audit_%1$s on public.%1$s', t);
    execute format(
      'create trigger trg_audit_%1$s after insert or update or delete on public.%1$s '
      'for each row execute function public.conventity_audit_trg()', t);
  end loop;
end
$$;

-- 4) RLS — append-only, yalnız ecosystem admin okur ------------
alter table public.conventity_audit enable row level security;

drop policy if exists conv_audit_select on public.conventity_audit;
create policy conv_audit_select
  on public.conventity_audit
  for select
  using (conventity_is_admin('ecosystem'));

-- Bilerek YOK: insert/update/delete politikası.
--   • insert yalnızca security-definer trigger üzerinden olur.
--   • update/delete politikası olmadığı için tablo append-only'dir.

-- 5) PostgREST şema önbelleğini tazele --------------------------
notify pgrst, 'reload schema';

-- ============================================================
-- DOĞRULAMA (çalıştırdıktan sonra):
--   -- admin oturumuyla:
--   select set_config('request.jwt.claims',
--     '{"sub":"<uid>","role":"authenticated"}', true);
--   -- bir rol ver / kanıt ekle, sonra:
--   select action, table_name, at from conventity_audit order by at desc limit 5;
--   -- admin olmayan hesap 0 satır görmeli; kimse delete edememeli.
-- ============================================================
