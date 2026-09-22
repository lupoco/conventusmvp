-- ============================================================================
-- ROLLBACK — otorite seed/link  ·  2026-07-23
-- Seed ile üretilen bağları çözer ve seed org'larını siler.
-- originating_authority metnine ve elle bağlanmış kayıtlara dokunmaz.
-- ============================================================================

-- Kimlik: source_ref='authority:%' (seed'in ürettiği benzersiz anahtar).
-- 1) Seed org'larına bağlı problemlerin bağını çöz ---------------------------
update public.conventity_problems p
set authority_org_id = null
from public.conventity_orgs o
where p.authority_org_id = o.id
  and o.source_ref like 'authority:%';

-- 2) Seed ile üretilen org'ları sil ------------------------------------------
delete from public.conventity_orgs
where source_ref like 'authority:%';

notify pgrst, 'reload schema';
