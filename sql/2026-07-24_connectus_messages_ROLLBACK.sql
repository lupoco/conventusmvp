-- ROLLBACK — Connectus mesajlaşma (2026-07-24)
-- DİKKAT: tablo drop'u mesaj verisini SİLER. Önce yalnız fonksiyonları
-- kaldırmak istersen alttaki table drop'u yorumda bırak.
drop function if exists public.connectus_thread(uuid, int);
drop function if exists public.connectus_threads();
drop function if exists public.connectus_send_message(uuid, text);
drop policy if exists cn_msg_read on public.conventity_cn_messages;
drop table if exists public.conventity_cn_messages;
notify pgrst, 'reload schema';
