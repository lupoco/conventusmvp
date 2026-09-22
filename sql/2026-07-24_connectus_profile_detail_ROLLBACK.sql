-- ROLLBACK — Connectus profil detay RPC'si (2026-07-24)
-- Yalnız yeni fonksiyonu düşürür. Başka nesneye dokunmaz.
drop function if exists public.connectus_profile_detail(uuid);
notify pgrst, 'reload schema';
