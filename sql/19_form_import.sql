-- 19_form_import.sql
-- PDF/Word kayit formunun yapay zeka ile dijital forma cevrilmesi — denetim kaydi.
--
-- Edge Function (supabase/functions/form-import) her cagrida buraya BIR satir
-- yazar: hangi belge, kac karakter, hangi model, ne onerildi. Yonetici oneriyi
-- ekranda duzenleyip uyguladiginda applied_at/applied_defs doldurulur.
--
-- NEDEN DENETIM: form tanimi kimin neyi sordugunu belirler. "Bu alani kim
-- ekledi?" sorusunun cevabi kalici olmali. Ayrica modelin ne onerdigi ile
-- yoneticinin ne kabul ettigi ARASINDAKI FARK gorulebilmeli — Orion FIT
-- ciktisini "validated" diye sunmama kuralinin ayni mantigi.
--
-- Idempotent.

begin;

create table if not exists public.conventus_form_imports (
  id            bigint generated always as identity primary key,
  activity_id   uuid not null,
  imported_by   uuid not null,
  source_name   text,
  source_chars  int,
  model         text,
  proposal      jsonb not null default '{}'::jsonb,   -- modelin onerisi (degismez)
  applied_defs  jsonb,                                -- yoneticinin kabul ettigi
  applied_at    timestamptz,
  applied_by    uuid,
  created_at    timestamptz not null default now()
);

create index if not exists cfi_activity_idx
  on public.conventus_form_imports (activity_id, created_at desc);

alter table public.conventus_form_imports enable row level security;

-- Okuma: yalnizca o etkinligi yonetebilenler.
drop policy if exists cfi_manager_read on public.conventus_form_imports;
create policy cfi_manager_read on public.conventus_form_imports
  for select to authenticated
  using (public.conventity_can_manage_event(activity_id));

-- "Uygulandi" isaretini yalnizca yonetici koyar; oneri satirinin kendisi
-- (proposal, model, imported_by, created_at) DEGISTIRILEMEZ.
drop policy if exists cfi_manager_apply on public.conventus_form_imports;
create policy cfi_manager_apply on public.conventus_form_imports
  for update to authenticated
  using (public.conventity_can_manage_event(activity_id))
  with check (public.conventity_can_manage_event(activity_id));

-- INSERT politikasi YOK: satiri yalnizca Edge Function (service_role) yazar.
-- DELETE politikasi YOK: oneri gecmisi silinemez.

create or replace function public.conventus_form_import_immutable()
returns trigger language plpgsql as $fn$
begin
  if new.proposal    is distinct from old.proposal
  or new.model       is distinct from old.model
  or new.imported_by is distinct from old.imported_by
  or new.activity_id is distinct from old.activity_id
  or new.source_name is distinct from old.source_name
  or new.created_at  is distinct from old.created_at then
    raise exception 'Oneri kaydi degistirilemez; yalnizca uygulama isareti yazilabilir.'
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_cfi_immutable on public.conventus_form_imports;
create trigger trg_cfi_immutable
  before update on public.conventus_form_imports
  for each row execute function public.conventus_form_import_immutable();

commit;

-- ---------------------------------------------------------------------------
-- DOGRULAMA
-- ---------------------------------------------------------------------------
select
  (select count(*) from information_schema.tables
    where table_name='conventus_form_imports')                    as "tablo (1)",
  (select count(*) from pg_policies
    where tablename='conventus_form_imports')                     as "politika (2)",
  (select count(*) from pg_policies
    where tablename='conventus_form_imports' and cmd='INSERT')    as "insert politikasi (0 olmali)",
  (select count(*) from pg_trigger
    where tgrelid='public.conventus_form_imports'::regclass
      and tgname='trg_cfi_immutable')                             as "degismezlik (1)",
  (select relrowsecurity from pg_class
    where oid='public.conventus_form_imports'::regclass)          as "rls acik";
