-- ════════════════════════════════════════════════════════════════════════
-- conventus_documents_s19.sql   (S19)
-- Etkinlik dokümanları: başlık + URL link modeli (dosya yükleme YOK).
-- Yönetici yazar; katılımcı audience'a göre okur (S17 deseniyle aynı).
--
-- İdempotent: create table if not exists · add column if not exists ·
-- drop policy if exists → create policy. text+CHECK (enum yok).
-- ════════════════════════════════════════════════════════════════════════

create table if not exists conventus_documents (
  id           uuid primary key default gen_random_uuid(),
  event_id     bigint not null,   -- conventus_managed_events.id ile aynı tip (bigint)
  title        text not null,
  url          text,
  category     text not null default 'general',
  audience     text not null default 'approved',
  is_published boolean not null default true,
  sort_order   integer not null default 0,
  created_by   uuid default auth.uid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- İzinli değerler (CHECK — mevcut satır varsa kırmadan ekle)
do $$ begin
  if not exists (select 1 from pg_constraint where conname='conventus_documents_category_chk') then
    alter table conventus_documents add constraint conventus_documents_category_chk
      check (category in ('general','agenda','venue','travel','security','forms','other'));
  end if;
  if not exists (select 1 from pg_constraint where conname='conventus_documents_audience_chk') then
    alter table conventus_documents add constraint conventus_documents_audience_chk
      check (audience in ('all','approved','pending','community_members','organizers'));
  end if;
end $$;

create index if not exists conventus_documents_event_idx on conventus_documents(event_id, sort_order);

alter table conventus_documents enable row level security;

-- ── Yönetim: etkinlik sahibi VEYA can_manage_event → tam erişim ──────────
drop policy if exists doc_manager_all on conventus_documents;
create policy doc_manager_all on conventus_documents
  for all to authenticated
  using (
    exists (
      select 1 from conventus_managed_events e
      where e.id = conventus_documents.event_id
        and (e.created_by = auth.uid() or conventity_can_manage_event(e.activity_id))
    )
  )
  with check (
    exists (
      select 1 from conventus_managed_events e
      where e.id = conventus_documents.event_id
        and (e.created_by = auth.uid() or conventity_can_manage_event(e.activity_id))
    )
  );

-- ── Okuma: yayınlanmış + audience kapısı (S17 ile aynı mantık) ───────────
drop policy if exists doc_audience_read on conventus_documents;
create policy doc_audience_read on conventus_documents
  for select to anon, authenticated
  using (
    is_published = true
    and (
      audience = 'all'
      or (audience = 'approved' and exists (
        select 1 from conventus_registrations r
        where r.event_id = conventus_documents.event_id
          and r.user_id = auth.uid() and r.status in ('approved','checked_in')))
      or (audience = 'pending' and exists (
        select 1 from conventus_registrations r
        where r.event_id = conventus_documents.event_id
          and r.user_id = auth.uid()))
      or (audience = 'community_members' and exists (
        select 1 from conventus_managed_events e
        where e.id = conventus_documents.event_id
          and e.community_id is not null and conventity_in_community(e.community_id)))
      or (audience = 'organizers' and exists (
        select 1 from conventus_managed_events e
        where e.id = conventus_documents.event_id
          and conventity_can_manage_event(e.activity_id)))
    )
  );

-- PostgREST şema önbelleğini tazele (yeni tablo görünsün)
notify pgrst, 'reload schema';

-- Doğrulama
select 'conventus_documents' as tbl,
       (select count(*) from pg_policies
         where schemaname='public' and tablename='conventus_documents') as policy_count;
-- Beklenen: policy_count = 2 (doc_manager_all + doc_audience_read).
