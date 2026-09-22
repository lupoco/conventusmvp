-- ============================================================================
-- conventity_problems — otorite bağı (authority_org_id FK)  ·  C-fazı 1/2
-- 2026-07-23
--
-- Talep otoritesini (NATO/ulus/kurum) birinci sınıf yap: serbest metin
-- originating_authority KALIR (etiket/fallback), yanına conventity_orgs'a
-- nullable FK eklenir. Tamamen ADDITIVE + idempotent — hiçbir şey kırılmaz.
-- Sonra: *_authority_seed.sql (metinden org üretip bağlar). Geri: *_ROLLBACK.
-- ============================================================================

alter table public.conventity_problems
  add column if not exists authority_org_id uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='conventity_problems_authority_org_fk') then
    alter table public.conventity_problems
      add constraint conventity_problems_authority_org_fk
      foreign key (authority_org_id) references public.conventity_orgs(id) on delete set null;
  end if;
end
$$;

create index if not exists idx_conv_problems_authority_org
  on public.conventity_problems(authority_org_id);

notify pgrst, 'reload schema';
