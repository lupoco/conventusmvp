-- ============================================================================
-- ROLLBACK — conventity_capabilities şema + RLS  ·  2026-07-23
--
-- DİKKAT: Bu dosya tabloyu KOMPLE DÜŞÜRÜR (tüm yetenek kayıtları silinir).
-- Yalnız tablo bu migration'la SIFIRDAN oluşturulduysa ve içi boşsa kullan.
-- Tablo migration'dan ÖNCE de vardıysa, aşağıdaki "SADECE POLİTİKA" bloğunu
-- kullan (tabloyu koru).
-- ============================================================================

-- --- SADECE POLİTİKA + eklenen kısıt/indeksleri geri al (tabloyu koru) ------
drop policy if exists conv_caps_read  on public.conventity_capabilities;
drop policy if exists conv_caps_write on public.conventity_capabilities;
drop index  if exists public.uq_conv_caps_source_ref;
drop index  if exists public.idx_conv_caps_domain;
alter table public.conventity_capabilities
  drop constraint if exists conventity_capabilities_status_chk;
notify pgrst, 'reload schema';

-- --- KOMPLE DÜŞÜR (yalnız tablo bu migration'la oluştuysa; yorumdan çıkar) --
-- drop table if exists public.conventity_capabilities cascade;
-- notify pgrst, 'reload schema';
