-- ============================================================================
-- conventus_delegation.sql · Conventus v2 — FAZ A2 · Vekaleten & toplu kayıt
-- POC / asistan / delegasyon lideri, başkası adına (veya grup olarak) kayıt
-- oluşturabilsin. Bir bakan/komutan başvuru sayfasını kendi kullanmaz —
-- yerine yetkili biri (etkinliği yöneten) kaydı açar.
-- Idempotent. Faz A1 + A2 dilim 1/1b çalıştırılmış olmalı.
-- ============================================================================

begin;

-- Kaydı gerçekte kim gönderdi (özneden farklı olabilir) + delegasyon işareti.
alter table conventus_registrations
  add column if not exists registered_by uuid,
  add column if not exists is_delegated  boolean not null default false;

-- Vekaleten kayıtta özne (user_id) bir hesaba sahip olmayabilir → NULL'a izin ver.
-- (own-satır RLS'i user_id=auth.uid() kontrol eder; NULL satırlar ona takılmaz,
--  yönetici politikaları üzerinden yönetilir — tutarlı.)
alter table conventus_registrations alter column user_id drop not null;

-- Etkinliği yönetenler (OPR/POC/organizer) başkası adına kayıt EKLEYEBİLİR.
-- registered_by = auth.uid() (kimin eklediği denetlenebilir); own-insert'e DOKUNULMAZ.
drop policy if exists reg_manager_insert on conventus_registrations;
create policy reg_manager_insert on conventus_registrations for insert with check (
  registered_by = auth.uid()
  and exists (select 1 from conventus_managed_events e
               where e.id = conventus_registrations.event_id
                 and conventity_can_manage_event(e.activity_id))
);

notify pgrst, 'reload schema';
commit;

-- doğrulama
select 'cols' as check,
  (select count(*) from information_schema.columns where table_name='conventus_registrations' and column_name='registered_by') as registered_by,
  (select count(*) from information_schema.columns where table_name='conventus_registrations' and column_name='is_delegated') as is_delegated,
  (select is_nullable from information_schema.columns where table_name='conventus_registrations' and column_name='user_id') as user_id_nullable;
select 'policy' as check, policyname from pg_policies
  where tablename='conventus_registrations' and policyname='reg_manager_insert';
