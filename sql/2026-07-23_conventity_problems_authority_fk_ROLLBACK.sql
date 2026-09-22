-- ============================================================================
-- ROLLBACK — conventity_problems otorite bağı (FK)  ·  2026-07-23
-- authority_org_id kolonunu, FK'yı ve indeksi kaldırır. originating_authority
-- metnine dokunmaz. (Önce seed rollback'i çalıştırmak temiz olur.)
-- ============================================================================

alter table public.conventity_problems
  drop constraint if exists conventity_problems_authority_org_fk;
drop index if exists public.idx_conv_problems_authority_org;
alter table public.conventity_problems
  drop column if exists authority_org_id;

notify pgrst, 'reload schema';
