-- 19_audit_access_requests_ROLLBACK.sql  ·  19'u geri alır.
-- Yalnız tetikleyiciyi kaldırır; conventity_audit içindeki satırlar kalır (append-only).
drop trigger if exists trg_audit_conventity_access_requests on public.conventity_access_requests;
