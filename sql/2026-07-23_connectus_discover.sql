-- ============================================================
-- Connectus — Keşif / Eşleştirme (Step 4)
-- 2026-07-23
--
-- connectus_discover(query):
--   • query doluysa: kişi arama (ad/rol/uzmanlık ILIKE) — gerekçeli.
--   • query boşsa: sıcak öneri — ortak uzmanlık + ortak bağlantı ile skorlu, gerekçeli.
-- Açıklanabilir/deterministik (AI değil): her sonuçta bir "why".
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. *_ROLLBACK.sql
-- VARSAYIM: conventity_cn_my_person_id() · cn_expertise · cn_connections mevcut.
-- ============================================================

create or replace function public.connectus_discover(p_query text default null, p_limit int default 12)
returns jsonb language sql stable security definer set search_path = public as $$
  with me as (select public.conventity_cn_my_person_id() as id),
  q as (select nullif(trim(coalesce(p_query,'')),'') as term),
  mytags as (select tag from public.conventity_cn_expertise where person_id = (select id from me)),
  myconns as (
    select case when requester_id = (select id from me) then addressee_id else requester_id end as pid
    from public.conventity_cn_connections
    where status = 'accepted' and (select id from me) in (requester_id, addressee_id)
  ),
  cand as (
    select p.id,
           coalesce(p.full_name, p.email, 'Member') as name,
           coalesce(p.role_title, '') as tagline,
           (select array_agg(distinct e.tag) from public.conventity_cn_expertise e
              where e.person_id = p.id and e.tag in (select tag from mytags)) as shared,
           (select count(*) from (
              select pid from myconns
              intersect
              select case when c.requester_id = p.id then c.addressee_id else c.requester_id end
              from public.conventity_cn_connections c
              where c.status = 'accepted' and p.id in (c.requester_id, c.addressee_id)
            ) mm) as mutuals,
           (select e.tag from public.conventity_cn_expertise e
              where e.person_id = p.id and (select term from q) is not null
                and e.tag ilike '%' || (select term from q) || '%' limit 1) as qtag
    from public.conventity_people p
    where p.id is distinct from (select id from me)
      and coalesce(p.full_name, p.email) is not null
  ),
  scored as (
    select c.*,
      coalesce(array_length(c.shared,1),0)*2 + c.mutuals*3 + case when c.qtag is not null then 5 else 0 end as score,
      case
        when (select term from q) is not null and c.qtag is not null then 'expertise “' || c.qtag || '”'
        when (select term from q) is not null then 'name / role match'
        when coalesce(array_length(c.shared,1),0) > 0 and c.mutuals > 0
          then 'shared expertise ' || array_to_string(c.shared, ', ') || ' · ' || c.mutuals || ' mutual'
        when coalesce(array_length(c.shared,1),0) > 0 then 'shared expertise ' || array_to_string(c.shared, ', ')
        when c.mutuals > 0 then c.mutuals || ' mutual connection' || case when c.mutuals = 1 then '' else 's' end
        else 'in the ecosystem'
      end as why
    from cand c
    where case when (select term from q) is not null
      then (c.name ilike '%'||(select term from q)||'%' or c.tagline ilike '%'||(select term from q)||'%' or c.qtag is not null)
      else (coalesce(array_length(c.shared,1),0) > 0 or c.mutuals > 0)
    end
  )
  select coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'tagline',tagline,'why',why))
                   from (select * from scored order by score desc, name asc limit p_limit) t), '[]'::jsonb);
$$;

grant execute on function public.connectus_discover(text, int) to authenticated, anon;

notify pgrst, 'reload schema';
