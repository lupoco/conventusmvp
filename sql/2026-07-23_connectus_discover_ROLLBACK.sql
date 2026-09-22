-- Connectus keşif GERİ ALMA · 2026-07-23
drop function if exists public.connectus_discover(text, int);
notify pgrst, 'reload schema';
