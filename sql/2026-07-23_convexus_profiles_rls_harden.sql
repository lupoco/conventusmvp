-- ============================================================================
-- convexus_profiles RLS — SERTLEŞTİRME (cerrahi)  ·  AÇIK İŞLER #2  ·  2026-07-23
--
-- Keşif (#3) ile doğrulandı — canlı politikalar:
--   ⚠ "manage ownerless profiles (interim)"  UPDATE  qual=(owner_id IS NULL)
--   ⚠ "delete ownerless profiles (interim)"  DELETE  qual=(owner_id IS NULL)
--   → giriş yapmış HERKES 147 seed profilini (owner_id NULL) düzenler/siler.
-- Geri kalan politikalar zaten doğru (owner insert/update/delete, public read).
--
-- ÇÖZÜM: yalnız iki zafiyetli interim politikayı kaldır + admin politikaları
-- ekle. Diğer politikalara DOKUNMA (minimal blast-radius, birebir rollback).
-- Sonuç yetki modeli:
--   SELECT herkese açık · INSERT kendi owner_id · UPDATE/DELETE sahibi VEYA
--   convexus admin · seed (owner_id NULL) → YALNIZ admin.
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. Geri alma: *_ROLLBACK.sql
-- ============================================================================

alter table public.convexus_profiles enable row level security;

-- 0) Admin fonksiyonu gerçekten var mı? Yoksa hiçbir şey değiştirmeden dur. --
--    (Keşif #4 çıktısı gönderilmediyse bu guard güvenlik ağıdır.)
do $$
begin
  if to_regprocedure('public.is_convexus_admin()') is null then
    raise exception
      'is_convexus_admin() bulunamadi — kesif #4 ciktisina gore dogru admin fonksiyon adini kullan (or. is_cv_admin()).';
  end if;
end
$$;

-- 1) Zafiyetli interim politikaları kaldır ----------------------------------
drop policy if exists "manage ownerless profiles (interim)" on public.convexus_profiles;
drop policy if exists "delete ownerless profiles (interim)" on public.convexus_profiles;

-- 2) Admin politikaları: seed dahil her profili yönet -----------------------
-- (owner politikaları zaten mevcut; permissive OR ile "sahip VEYA admin" olur)
drop policy if exists "profiles admin update" on public.convexus_profiles;
create policy "profiles admin update" on public.convexus_profiles
  for update to authenticated
  using      (public.is_convexus_admin())
  with check (public.is_convexus_admin());

drop policy if exists "profiles admin delete" on public.convexus_profiles;
create policy "profiles admin delete" on public.convexus_profiles
  for delete to authenticated
  using (public.is_convexus_admin());

-- 3) PostgREST şema önbelleğini tazele --------------------------------------
notify pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   • admin OLMAYAN hesap → seed profili (owner_id NULL) düzenle/sil → 0 satır.
--   • convexus/index.html vitrini (SELECT) → hâlâ dolu.
--   • admin hesabı → her profili düzenleyip silebilmeli.
--   • firma kendi profilini oluştur/düzenle → çalışmalı (owner politikaları).
-- ============================================================================
