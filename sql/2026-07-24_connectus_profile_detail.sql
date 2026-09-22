-- ============================================================
-- Connectus — Profil detay RPC'si (kişisel sayfa: profile.html)
-- 2026-07-24
--
-- connectus_profile_detail(p_person_id):
--   • p_person_id NULL  → oturum açan kullanıcının profili (auth.uid())
--   • p_person_id dolu   → o kişinin GÜVENLİ (kamuya uygun) profili
-- Döner: base + expertise tags + provenance/credentials[] + track record[].
--
-- Provenans modeli (mevcut, doğrulanmış join'ler):
--   kişi → participation.activity_id → activities(title,type)
--   kişi'nin "credentials"ı: o katıldığı activity'lere bağlı evidence
--     (evidence.activity_id in <kişinin activity'leri>) · proof_slug varsa
--     verified.html?s=<slug> ile taşınabilir doğrulama.
--   NOT: bu bir kişisel "validated" sertifika DEĞİL — faaliyet provenansı.
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. *_ROLLBACK.sql
-- Yeni fonksiyon, ALTER yok. Sonda notify pgrst.
-- ============================================================

create or replace function public.connectus_profile_detail(p_person_id uuid default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with tgt as (
    select p.*
    from public.conventity_people p
    where (p_person_id is not null and p.id = p_person_id)
       or (p_person_id is null and p.auth_user_id = auth.uid())
    limit 1
  ),
  acts as (
    select pa.activity_id
    from public.conventity_participation pa
    where pa.person_id = (select id from tgt)
  )
  select case when (select id from tgt) is null then null else jsonb_build_object(
    'id',      (select id from tgt),
    'is_me',   (select auth_user_id from tgt) is not distinct from auth.uid(),
    'name',    coalesce((select full_name from tgt), (select email from tgt), 'Member'),
    'tagline', coalesce((select role_title from tgt), ''),
    'org',     (select coalesce(o.short_name, o.legal_name)
                from public.conventity_orgs o where o.id = (select home_org_id from tgt)),
    'events',  (select count(*) from acts),
    'certs',   (select count(*) from public.conventity_evidence ev where ev.activity_id in (select activity_id from acts)),
    'connections', (
      select count(*) from public.conventity_cn_connections c
      where c.status = 'accepted'
        and (select id from tgt) in (c.requester_id, c.addressee_id)),
    'tags', coalesce((select array_agg(distinct e.tag order by e.tag)
                      from public.conventity_cn_expertise e where e.person_id = (select id from tgt)),
                     array[]::text[]),
    'credentials', coalesce((
      select jsonb_agg(row order by ord)
      from (
        select jsonb_build_object(
                 'type', coalesce(ev.evidence_type, 'evidence'),
                 'activity', coalesce(a.title, 'Activity'),
                 'issued_at', ev.issued_at,
                 'proof_slug', ev.proof_slug) as row,
               ev.issued_at as ord
        from public.conventity_evidence ev
        left join public.conventity_activities a on a.id = ev.activity_id
        where ev.activity_id in (select activity_id from acts)
        order by ev.issued_at desc nulls last
        limit 24
      ) s), '[]'::jsonb),
    'track', coalesce((
      select jsonb_agg(jsonb_build_object('title', coalesce(a.title,'Activity'), 'kind', a.activity_type))
      from public.conventity_activities a
      where a.id in (select activity_id from acts)
      limit 24), '[]'::jsonb)
  ) end;
$$;

grant execute on function public.connectus_profile_detail(uuid) to authenticated, anon;

notify pgrst, 'reload schema';
