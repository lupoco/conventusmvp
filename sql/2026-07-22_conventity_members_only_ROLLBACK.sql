-- ============================================================
-- Conventity — Üyelik kapısı GERİ ALMA
-- 2026-07-22
--
-- Bu, conventity_is_member() RPC'sini kaldırır. Kaldırdıktan SONRA
-- login.html / index.html'deki üyelik denetimini de geri al (yoksa arayüz
-- fail-closed davranıp herkesi kilitleyebilir).
-- ============================================================
drop function if exists public.conventity_is_member();
notify pgrst, 'reload schema';
