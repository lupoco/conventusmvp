-- ============================================================================
-- conventity_capabilities — ŞEMA + RLS (Core "Yetenek" UI için)  ·  2026-07-23
--
-- Bağlam: backbone tablo, canlıda 0 kayıt, repoda şema tanımı yoktu. Core'a
-- CRUD sekmesi eklemek için temiz bir yetenek modeli TANIMLANIR.
-- Tamamen ADDITIVE + idempotent: mevcut kolon varsa korunur (0 satır → güvenli).
-- CLAUDE.md kuralları: IF NOT EXISTS · text+CHECK · source_ref idempotency ·
-- RLS gerçek sınır · notify pgrst. Geri alma: *_ROLLBACK.sql
-- ============================================================================

-- 1) Tablo + kolonlar (additive) --------------------------------------------
create table if not exists public.conventity_capabilities(
  id uuid primary key default gen_random_uuid()
);
alter table public.conventity_capabilities add column if not exists code        text;
alter table public.conventity_capabilities add column if not exists name        text;
alter table public.conventity_capabilities add column if not exists domain      text;
alter table public.conventity_capabilities add column if not exists description text;
alter table public.conventity_capabilities add column if not exists status      text;
alter table public.conventity_capabilities add column if not exists source      text;
alter table public.conventity_capabilities add column if not exists source_ref  text;
alter table public.conventity_capabilities add column if not exists created_at  timestamptz default now();

-- 2) status: text + CHECK (enum yok) ----------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname='conventity_capabilities_status_chk') then
    alter table public.conventity_capabilities
      add constraint conventity_capabilities_status_chk
      check (status is null or status in ('active','draft','retired'));
  end if;
end
$$;

-- 3) source_ref evrensel idempotency anahtarı (unique, null'lar hariç) -------
create unique index if not exists uq_conv_caps_source_ref
  on public.conventity_capabilities(source_ref) where source_ref is not null;

create index if not exists idx_conv_caps_domain on public.conventity_capabilities(domain);

-- 4) RLS — herkes okur, yalnız ecosystem admin yazar ------------------------
alter table public.conventity_capabilities enable row level security;

drop policy if exists conv_caps_read on public.conventity_capabilities;
create policy conv_caps_read on public.conventity_capabilities
  for select using (true);

drop policy if exists conv_caps_write on public.conventity_capabilities;
create policy conv_caps_write on public.conventity_capabilities
  for all to authenticated
  using      (conventity_is_admin('ecosystem'))
  with check (conventity_is_admin('ecosystem'));

-- 5) PostgREST şema önbelleğini tazele --------------------------------------
notify pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   • Core → Yetenek sekmesi → Ekle → kaydet → satır görünür.
--   • admin OLMAYAN hesap yazamaz (RLS); herkes okuyabilir (vitrin/eşleştirme).
-- ============================================================================
