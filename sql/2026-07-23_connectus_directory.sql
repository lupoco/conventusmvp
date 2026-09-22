-- ============================================================
-- Connectus — profil directory + kendi profil RPC'leri (+ demo seed)
-- 2026-07-23  ·  Step 1: profil bölümünü gerçek veriye bağla
--
-- Tasarım Connectus sayfasının "Profiles" bölümünü besler:
--   • connectus_my_profile()  → oturum açan kullanıcının profili + provenans
--   • connectus_directory(n)  → ekosistem profilleri (kişi + kurum) + provenans
-- İkisi de SECURITY DEFINER: temel tablo RLS'lerine takılmadan GÜVENLİ alanları
-- döner (kişisel/gizli alan sızdırmaz). anon+authenticated çağırabilir.
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent.
--   Geri alma: *_ROLLBACK.sql
--   ALTER yok; yeni fonksiyon/insert. Sonda notify pgrst.
--
-- VARSAYIMLAR (canlı şemaya göre doğrulandı):
--   • conventity_people(id, full_name, email, role_title, home_org_id, auth_user_id, source, source_ref)
--   • conventity_orgs(id, legal_name, short_name, org_type, nation, source, source_ref)  · org_type='institution' geçerli
--   • conventity_participation(person_id, activity_id)
--   • conventity_evidence(activity_id, org_id, proof_slug, evidence_type, issued_at)  · person_id YOK
--     → kişinin "certs"i katılımları üzerinden: person → participation.activity_id → evidence.activity_id
--   • conventity_cn_expertise(person_id, tag, kind)  (Faz-1 tablosu; canlıda mevcut)
-- ============================================================

-- ── Kendi profilim ─────────────────────────────────────────────────────────
create or replace function public.connectus_my_profile()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id',      p.id,
    'name',    coalesce(p.full_name, p.email, 'Member'),
    'tagline', coalesce(p.role_title, ''),
    'org',     coalesce(o.short_name, o.legal_name),
    'email',   p.email,
    'events',  (select count(*) from public.conventity_participation pa where pa.person_id = p.id),
    'certs',   (select count(*) from public.conventity_evidence ev
                where ev.activity_id in (select pa.activity_id from public.conventity_participation pa where pa.person_id = p.id)),
    'tags',    coalesce((select array_agg(distinct e.tag order by e.tag)
                         from public.conventity_cn_expertise e where e.person_id = p.id), array[]::text[])
  )
  from public.conventity_people p
  left join public.conventity_orgs o on o.id = p.home_org_id
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

-- ── Ekosistem directory (kişi + kurum) ─────────────────────────────────────
create or replace function public.connectus_directory(p_limit int default 48)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with ppl as (
    select p.id,
           coalesce(p.full_name, p.email, 'Member') as name,
           coalesce(p.role_title, '') as tagline,
           coalesce(o.short_name, o.legal_name) as org,
           (select count(*) from public.conventity_participation pa where pa.person_id = p.id) as events,
           (select count(*) from public.conventity_evidence ev
            where ev.activity_id in (select pa.activity_id from public.conventity_participation pa where pa.person_id = p.id)) as certs,
           coalesce((select array_agg(distinct e.tag order by e.tag)
                     from public.conventity_cn_expertise e where e.person_id = p.id), array[]::text[]) as tags
    from public.conventity_people p
    left join public.conventity_orgs o on o.id = p.home_org_id
    where coalesce(p.full_name, p.email) is not null
    order by (select count(*) from public.conventity_participation pa where pa.person_id = p.id) desc,
             p.full_name asc nulls last
    limit p_limit
  ),
  org as (
    select o.id,
           coalesce(o.legal_name, o.short_name, 'Organisation') as name,
           trim(both ' ·' from coalesce(o.org_type, 'organisation') || coalesce(' · ' || o.nation, '')) as tagline,
           o.nation
    from public.conventity_orgs o
    where coalesce(o.legal_name, o.short_name) is not null
    order by o.legal_name asc nulls last
    limit greatest(p_limit / 3, 12)
  )
  select jsonb_build_object(
    'people', coalesce((select jsonb_agg(jsonb_build_object(
                'id', ppl.id, 'kind', 'person', 'name', ppl.name, 'tagline', ppl.tagline,
                'org', ppl.org, 'events', ppl.events, 'certs', ppl.certs, 'tags', ppl.tags)) from ppl), '[]'::jsonb),
    'orgs',   coalesce((select jsonb_agg(jsonb_build_object(
                'id', org.id, 'kind', 'org', 'name', org.name, 'tagline', org.tagline)) from org), '[]'::jsonb)
  );
$$;

grant execute on function public.connectus_my_profile()        to authenticated, anon;
grant execute on function public.connectus_directory(int)      to authenticated, anon;

-- ── Demo seed: birkaç birey + uzmanlık (canlı hissettirmek için) ───────────
-- Düşük riskli: yalnız conventity_people (basit kolonlar) + cn_expertise.
-- source_ref ile NOT EXISTS guard'lı — tekrar çalıştırılabilir, kopya olmaz.
insert into public.conventity_people (full_name, role_title, source, source_ref)
select v.full_name, v.role_title, 'seed', v.sref
from (values
  ('Dr. Elina Korhonen',   'Resilience Lead · National MoD',        'seed:cn:elina'),
  ('Maj. Marco Rossi',     'Interoperability · Multinational Corps','seed:cn:marco'),
  ('Ana Duarte',           'C-UAS Programme Lead',                  'seed:cn:ana'),
  ('Kaan Yılmaz',          'OSINT & CIMIC Analyst',                 'seed:cn:kaan'),
  ('Sofia Lindqvist',      'Edge ISR Engineer · Industry',          'seed:cn:sofia'),
  ('Tomas Novak',          'Logistics & Sustainment Officer',       'seed:cn:tomas'),
  ('Dr. Amara Okoye',      'AI / Autonomy Researcher',              'seed:cn:amara'),
  ('Lena Fischer',         'Cyber Resilience Lead',                 'seed:cn:lena')
) as v(full_name, role_title, sref)
where not exists (select 1 from public.conventity_people p where p.source_ref = v.sref);

insert into public.conventity_cn_expertise (person_id, tag, kind)
select p.id, t.tag, 'sme'
from public.conventity_people p
join (values
  ('seed:cn:elina','cimic'), ('seed:cn:elina','critical-infra'), ('seed:cn:elina','osint'),
  ('seed:cn:marco','c2-interop'), ('seed:cn:marco','cwix'), ('seed:cn:marco','tide'),
  ('seed:cn:ana','c-uas'), ('seed:cn:ana','counter-drone'), ('seed:cn:ana','sensors'),
  ('seed:cn:kaan','osint'), ('seed:cn:kaan','cimic'), ('seed:cn:kaan','analysis'),
  ('seed:cn:sofia','edge-isr'), ('seed:cn:sofia','mesh-comms'), ('seed:cn:sofia','sensors'),
  ('seed:cn:tomas','logistics'), ('seed:cn:tomas','sustainment'),
  ('seed:cn:amara','ai'), ('seed:cn:amara','autonomy'), ('seed:cn:amara','c-uas'),
  ('seed:cn:lena','cyber'), ('seed:cn:lena','resilience')
) as t(sref, tag) on t.sref = p.source_ref
where not exists (
  select 1 from public.conventity_cn_expertise e
  where e.person_id = p.id and e.tag = t.tag and e.kind = 'sme'
);

notify pgrst, 'reload schema';
