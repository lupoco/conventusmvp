-- ============================================================================
-- conventity_capabilities — TAKSONOMİDEN SEED  ·  2026-07-23
--
-- Yetenek havuzunu UYDURMADAN doldur: ekosistemin mevcut focus-area
-- taksonomisinden (convexus_focus_areas: code · name · sort_order) türet.
-- Idempotent: source_ref='cap_focus:<code>' + NOT EXISTS guard → tekrar
-- çalıştırılabilir, çift kayıt olmaz. Sadece INSERT (mevcut kayda dokunmaz).
-- ÖNCE: 2026-07-23_conventity_capabilities_schema.sql çalışmış olmalı.
-- Geri alma: *_seed_ROLLBACK.sql
-- ============================================================================

-- convexus_focus_areas VARSA seed et (yoksa sessizce atla — guard) ----------
do $$
begin
  if to_regclass('public.convexus_focus_areas') is null then
    raise notice 'seed: convexus_focus_areas bulunamadi — atlandi';
    return;
  end if;

  insert into public.conventity_capabilities (code, name, status, source, source_ref)
  select fa.code,
         coalesce(fa.name, fa.code),
         'active',
         'convexus_focus',
         'cap_focus:'||fa.code
  from public.convexus_focus_areas fa
  where fa.code is not null
    and not exists (
      select 1 from public.conventity_capabilities c
      where c.source_ref = 'cap_focus:'||fa.code
    );

  raise notice 'seed: conventity_capabilities focus-area taksonomisinden guncellendi';
end
$$;

notify pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   select count(*) from conventity_capabilities where source='convexus_focus';
--   -- Core → Yetenekler sekmesi artık taksonomiyle dolu; eşleştirmenin ortak
--   -- sözlüğü hazır. Admin gerekirse domain/description ekler.
-- ============================================================================
