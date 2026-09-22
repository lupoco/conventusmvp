-- ============================================================
-- ROLLBACK — Conventity denetim kaydı (audit log)
-- 2026-07-19  ·  rev 2026-07-23: tablo-varlık guard
--
-- 2026-07-19_conventity_audit.sql'i geri alır.
-- Supabase SQL Editor'de tek transaction olarak çalıştır.
-- DİKKAT: conventity_audit tablosunu ve içindeki tüm denetim
-- kayıtlarını KALICI olarak siler.
-- ============================================================

-- 1) Trigger'ları kaldır ---------------------------------------
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
      continue;   -- tablo yoksa "drop trigger ... on <tablo>" de hata verir, atla
    end if;
    execute format('drop trigger if exists trg_audit_%1$s on public.%1$s', t);
  end loop;
end
$$;

-- 2) Trigger fonksiyonunu kaldır -------------------------------
drop function if exists public.conventity_audit_trg();

-- 3) Politika + tabloyu kaldır ---------------------------------
drop policy if exists conv_audit_select on public.conventity_audit;
drop table if exists public.conventity_audit;

-- 4) Şema önbelleğini tazele -----------------------------------
notify pgrst, 'reload schema';
