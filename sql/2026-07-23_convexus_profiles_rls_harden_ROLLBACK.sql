-- ============================================================================
-- ROLLBACK — convexus_profiles RLS sertleştirme (cerrahi)  ·  2026-07-23
--
-- Sertleştirmeyi BİREBİR geri alır: admin politikalarını kaldırır, iki
-- "(interim)" politikayı keşif #3 çıktısındaki tanımlarıyla aynen geri kurar.
-- (İnterim GÜVENLİK GEVŞEKtir — giriş yapan herkes seed profillerini yönetir.
--  Yalnız acil geri dönüş için.)
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction.
-- ============================================================================

alter table public.convexus_profiles enable row level security;

-- 1) Sertleştirmeyle eklenen admin politikalarını kaldır --------------------
drop policy if exists "profiles admin update" on public.convexus_profiles;
drop policy if exists "profiles admin delete" on public.convexus_profiles;

-- 2) Interim politikaları birebir geri kur (keşif #3'ten) --------------------
drop policy if exists "manage ownerless profiles (interim)" on public.convexus_profiles;
create policy "manage ownerless profiles (interim)" on public.convexus_profiles
  for update to authenticated
  using      (owner_id IS NULL)
  with check (owner_id IS NULL);

drop policy if exists "delete ownerless profiles (interim)" on public.convexus_profiles;
create policy "delete ownerless profiles (interim)" on public.convexus_profiles
  for delete to authenticated
  using (owner_id IS NULL);

-- 3) Şema önbelleğini tazele -------------------------------------------------
notify pgrst, 'reload schema';
