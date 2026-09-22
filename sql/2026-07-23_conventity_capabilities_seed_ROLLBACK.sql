-- ============================================================================
-- ROLLBACK — conventity_capabilities taksonomi seed'i  ·  2026-07-23
--
-- Yalnız seed ile eklenen (source='convexus_focus') kayıtları siler.
-- Elle eklenen veya import edilen yetenekler KORUNUR.
-- ============================================================================

delete from public.conventity_capabilities
where source = 'convexus_focus'
  and source_ref like 'cap_focus:%';

notify pgrst, 'reload schema';
