-- 18_signin_events_ROLLBACK.sql — event kolonunu ve CHECK'i kaldırır.
-- DİKKAT: 'signout' satırları da silinir (kolonla birlikte bilgi gider).
alter table public.conventity_signin_log drop constraint if exists conventity_signin_log_event_check;
drop index if exists public.idx_conv_signin_event;
alter table public.conventity_signin_log drop column if exists event;
notify pgrst, 'reload schema';
