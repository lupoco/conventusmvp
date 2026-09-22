-- ============================================================
-- GERİ ALMA — Conventus sağlayıcı → vendor rolü (S44)  ·  2026-08-04
--
-- Trigger + fonksiyonu kaldırır ve OTOMATİK verilen vendor rollerini siler.
-- Elle verilmiş vendor rolleri (note 'auto:%' DEĞİL) KORUNUR.
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent.
-- ============================================================

drop trigger  if exists trg_provider_role_sync on public.gm_providers;
drop function if exists public.conventus_provider_role_sync();

-- Otomatik verilen vendor rollerini geri al (audit izini korumak istersen
-- bu DELETE yerine: update ... set status='revoked' ... kullan).
delete from conventity_roles
 where scope = 'conventus' and scope_id is null and role = 'vendor'
   and note like 'auto:%';
