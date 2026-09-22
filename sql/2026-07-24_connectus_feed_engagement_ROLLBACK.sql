-- ROLLBACK — Connectus feed etkileşimi (2026-07-24)
-- DİKKAT: tablo drop'ları reaction/comment verisini SİLER.
-- connectus_feed'i etkileşim-öncesi haline döndürmek için
-- 2026-07-23_connectus_groups_feed.sql içindeki connectus_feed'i yeniden çalıştır.
drop function if exists public.connectus_post_comments(uuid, int);
drop function if exists public.connectus_comment(uuid, text);
drop function if exists public.connectus_react(uuid, boolean);
drop policy if exists cn_comment_read on public.conventity_cn_post_comments;
drop policy if exists cn_react_read on public.conventity_cn_post_reactions;
drop table if exists public.conventity_cn_post_comments;
drop table if exists public.conventity_cn_post_reactions;
notify pgrst, 'reload schema';
