-- ============================================================
-- Connectus — Kurumsal sayfa detay RPC'si (org.html)
-- 2026-07-24
--
-- connectus_org_detail(p_org_id):
--   base kimlik + üyeler (people.home_org_id) + kolektif uzmanlık
--   (üyelerin cn_expertise etiketleri) + kurum kanıtları (evidence.org_id).
-- SECURITY DEFINER: yalnız GÜVENLİ/kamuya uygun alanlar. anon+authenticated.
--
-- SADECE DOĞRULANMIŞ KOLONLAR (discovery before DDL — solutions şeması
--   repoda referanslı değil, bu yüzden dahil edilmedi):
--   conventity_orgs(id, legal_name, short_name, org_type, nation)
--   conventity_people(id, full_name, email, role_title, home_org_id)
--   conventity_cn_expertise(person_id, tag)
--   conventity_evidence(org_id, activity_id, proof_slug, evidence_type, issued_at)
--   conventity_activities(id, title)
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. *_ROLLBACK.sql
-- ============================================================

create or replace function public.connectus_org_detail(p_org_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with o as (
    select * from public.conventity_orgs where id = p_org_id limit 1
  ),
  mem as (
    select p.id,
           coalesce(p.full_name, p.email, 'Member') as name,
           coalesce(p.role_title, '') as tagline,
           (select count(*) from public.conventity_participation pa where pa.person_id = p.id) as events
    from public.conventity_people p
    where p.home_org_id = p_org_id
      and coalesce(p.full_name, p.email) is not null
    order by (select count(*) from public.conventity_participation pa where pa.person_id = p.id) desc,
             p.full_name asc nulls last
    limit 60
  )
  select case when (select id from o) is null then null else jsonb_build_object(
    'id',       (select id from o),
    'name',     coalesce((select legal_name from o), (select short_name from o), 'Organisation'),
    'short',    (select short_name from o),
    'org_type', coalesce((select org_type from o), 'organisation'),
    'nation',   (select nation from o),
    'members_count', (select count(*) from public.conventity_people p where p.home_org_id = p_org_id),
    'members', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', id, 'name', name, 'tagline', tagline, 'events', events)) from mem), '[]'::jsonb),
    'expertise', coalesce((
      select array_agg(tag order by tag) from (
        select distinct e.tag
        from public.conventity_cn_expertise e
        where e.person_id in (select id from mem)
        limit 40
      ) t), array[]::text[]),
    'credentials', coalesce((
      select jsonb_agg(row order by ord) from (
        select jsonb_build_object(
                 'type', coalesce(ev.evidence_type,'evidence'),
                 'activity', coalesce(a.title,'Activity'),
                 'issued_at', ev.issued_at,
                 'proof_slug', ev.proof_slug) as row,
               ev.issued_at as ord
        from public.conventity_evidence ev
        left join public.conventity_activities a on a.id = ev.activity_id
        where ev.org_id = p_org_id
        order by ev.issued_at desc nulls last
        limit 24
      ) s), '[]'::jsonb)
  ) end;
$$;

grant execute on function public.connectus_org_detail(uuid) to authenticated, anon;

notify pgrst, 'reload schema';
