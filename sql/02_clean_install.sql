-- ============================================================================
-- 02_clean_install.sql  ·  conventity.com — TEMİZ KURULUM
--
-- Kaynak: conventity.org `public` şemasının salt-okunur DDL dökümü
--         (sql/01_dump_org_schema.sql ile alındı).
-- Üretim: scripts/dump-to-clean-install.py — elle düzenleme YAPMA,
--         döküm değişirse scripti yeniden çalıştır.
--
-- NE YAPAR: omurgayı + Conventus/Convexus/Connectus şemasını BOŞ kurar.
-- NE YAPMAZ: hiçbir INSERT yok. 147 org, convexus havuzu, form şablonları,
--            demo veri — hiçbiri taşınmaz. (Dosya sonundaki yorum bloğu
--            .org'da hangi tablonun kaç satır taşıdığını gösterir.)
--
-- NEREDE ÇALIŞIR: conventity-prod (tstlireeidnpchadgjly) → SQL Editor.
--                 .org'da ÇALIŞTIRMA.
--
-- İdempotent: tekrar çalıştırılabilir, ikinci çalıştırma hiçbir şey değiştirmez.
-- SQL Editor tek transaction çalıştırır: bir satır patlarsa hepsi geri alınır.
-- ============================================================================

-- ---- Ön koşul: Supabase rolleri ve auth şeması hazır olmalı ---------------
do $cvblock$
begin
  if to_regprocedure('auth.uid()') is null then
    raise exception 'auth.uid() yok — bu script Supabase projesinde calistirilmali.';
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    raise exception 'authenticated rolu yok — bu script Supabase projesinde calistirilmali.';
  end if;
end $cvblock$;

grant usage on schema public to anon, authenticated, service_role;

-- ---- .org'da kurulu eklentiler (bilgi; yeni proje kendi setiyle gelir) ----
--   pg_stat_statements           schema=extensions  v1.11
--   pgcrypto                     schema=extensions  v1.3
--   supabase_vault               schema=vault  v0.3.1
--   uuid-ossp                    schema=extensions  v1.1

-- ===================== 1 · DIZILER =====================
create sequence if not exists public.conventus_registration_events_id_seq;
create sequence if not exists public.conventus_role_events_id_seq;

-- ===================== 2 · TABLOLAR =====================
create table if not exists public.conventity_activities (
  id uuid default gen_random_uuid() not null,
  title text not null,
  activity_type text default 'event'::text,
  source text default 'internal'::text,
  origin_ref text,
  legacy_event_bigint bigint,
  legacy_selection_uuid uuid,
  start_date date,
  end_date date,
  status text default 'planned'::text,
  classification text default 'unclass'::text,
  source_ref text,
  owner_id uuid,
  created_at timestamp with time zone default now()
);
create table if not exists public.conventity_audit (
  id uuid default gen_random_uuid() not null,
  actor_auth_uid uuid,
  actor_person_id uuid,
  table_name text not null,
  record_id uuid,
  action text not null,
  diff jsonb,
  at timestamp with time zone default now() not null
);
create table if not exists public.conventity_capabilities (
  id uuid default gen_random_uuid() not null,
  code text not null,
  description text,
  taxonomy_branch text,
  source text default 'local'::text,
  validated boolean default false,
  source_ref text,
  created_at timestamp with time zone default now(),
  name text,
  domain text,
  status text
);
create table if not exists public.conventity_cn_connections (
  id uuid default gen_random_uuid() not null,
  requester_id uuid not null,
  addressee_id uuid not null,
  status text default 'pending'::text not null,
  purpose text,
  created_at timestamp with time zone default now() not null,
  responded_at timestamp with time zone
);
create table if not exists public.conventity_cn_expertise (
  id uuid default gen_random_uuid() not null,
  person_id uuid not null,
  tag text not null,
  kind text default 'sme'::text not null,
  self_rated integer,
  source_ref text
);
create table if not exists public.conventity_cn_groups (
  id uuid default gen_random_uuid() not null,
  name text not null,
  purpose_kind text not null,
  purpose_ref uuid,
  visibility text default 'locked'::text not null,
  created_by uuid,
  source_ref text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventity_cn_memberships (
  id uuid default gen_random_uuid() not null,
  group_id uuid not null,
  person_id uuid not null,
  role text default 'member'::text not null,
  link_participation_id uuid,
  source_ref text,
  joined_at timestamp with time zone default now() not null
);
create table if not exists public.conventity_cn_messages (
  id uuid default gen_random_uuid() not null,
  sender_id uuid not null,
  recipient_id uuid not null,
  body text not null,
  created_at timestamp with time zone default now() not null,
  read_at timestamp with time zone
);
create table if not exists public.conventity_cn_post_comments (
  id uuid default gen_random_uuid() not null,
  post_id uuid not null,
  author_id uuid not null,
  body text not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventity_cn_post_reactions (
  post_id uuid not null,
  person_id uuid not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventity_cn_posts (
  id uuid default gen_random_uuid() not null,
  group_id uuid not null,
  author_id uuid not null,
  body text not null,
  kind text default 'note'::text not null,
  source_ref text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventity_evidence (
  id uuid default gen_random_uuid() not null,
  activity_id uuid,
  org_id uuid,
  evidence_type text,
  verdict text,
  issuing_auth text default 'conventity'::text,
  proof_slug text,
  score_total integer,
  payload jsonb,
  source_ref text,
  issued_at timestamp with time zone default now(),
  created_at timestamp with time zone default now()
);
create table if not exists public.conventity_matches (
  id uuid default gen_random_uuid() not null,
  problem_id uuid not null,
  solution_id uuid not null,
  org_id uuid,
  score integer,
  reasons jsonb,
  status text default 'shortlisted'::text not null,
  note text,
  decided_by uuid,
  decided_at timestamp with time zone default now(),
  created_at timestamp with time zone default now()
);
create table if not exists public.conventity_orgs (
  id uuid default gen_random_uuid() not null,
  legal_name text not null,
  short_name text,
  nation text,
  org_type text,
  ecosystem_tags text[] default '{}'::text[],
  website text,
  membership_tier text default 'basic'::text,
  source text default 'seed'::text,
  classification text default 'unclass'::text,
  source_ref text,
  owner_id uuid,
  created_at timestamp with time zone default now()
);
create table if not exists public.conventity_participation (
  id uuid default gen_random_uuid() not null,
  activity_id uuid,
  org_id uuid,
  person_id uuid,
  part_role text default 'participant'::text,
  status text default 'confirmed'::text,
  source_ref text,
  joined_at timestamp with time zone default now()
);
create table if not exists public.conventity_people (
  id uuid default gen_random_uuid() not null,
  full_name text,
  home_org_id uuid,
  role_title text,
  is_poc boolean default false,
  email text,
  auth_user_id uuid,
  source text default 'seed'::text,
  source_ref text,
  owner_id uuid,
  created_at timestamp with time zone default now()
);
create table if not exists public.conventity_problem_capability (
  problem_id uuid not null,
  capability_id uuid not null
);
create table if not exists public.conventity_problem_solution (
  id uuid default gen_random_uuid() not null,
  problem_id uuid,
  solution_id uuid,
  status text default 'proposed'::text,
  score numeric,
  created_at timestamp with time zone default now()
);
create table if not exists public.conventity_problems (
  id uuid default gen_random_uuid() not null,
  title text not null,
  op_description text,
  desired_end_state text,
  originating_authority text,
  status text default 'draft'::text,
  classification text default 'unclass'::text,
  external_ref text,
  source_ref text,
  published_at timestamp with time zone,
  owner_id uuid,
  created_at timestamp with time zone default now(),
  focus_area text,
  authority_org_id uuid
);
create table if not exists public.conventity_relations (
  id uuid default gen_random_uuid() not null,
  from_type text,
  from_id uuid,
  rel_type text,
  to_type text,
  to_id uuid,
  provenance text default 'conventity'::text,
  created_at timestamp with time zone default now()
);
create table if not exists public.conventity_roles (
  id uuid default gen_random_uuid() not null,
  person_id uuid,
  auth_user_id uuid,
  scope text default 'convexus'::text,
  role text default 'member'::text,
  granted_by uuid,
  granted_at timestamp with time zone default now(),
  source_ref text,
  scope_id uuid,
  status text default 'active'::text,
  granted_via uuid,
  expires_at timestamp with time zone,
  note text,
  title text
);
create table if not exists public.conventity_signin_log (
  id uuid default gen_random_uuid() not null,
  auth_user_id uuid not null,
  email text,
  method text default 'password'::text not null,
  user_agent text,
  at timestamp with time zone default now() not null
);
create table if not exists public.conventity_solution_capability (
  solution_id uuid not null,
  capability_id uuid not null
);
create table if not exists public.conventity_solutions (
  id uuid default gen_random_uuid() not null,
  org_id uuid,
  name text not null,
  description text,
  trl integer,
  cost_class text,
  domain text,
  isc_pilot_area text,
  focus_area text,
  status text default 'active'::text,
  source text default 'seed'::text,
  source_ref text,
  owner_id uuid,
  created_at timestamp with time zone default now(),
  orion jsonb
);
create table if not exists public.conventus_announcements (
  id uuid default gen_random_uuid() not null,
  event_id bigint not null,
  title text not null,
  body text,
  pinned boolean default false not null,
  is_published boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  audience text default 'all'::text not null,
  publish_at timestamp with time zone
);
create table if not exists public.conventus_communities (
  id uuid default gen_random_uuid() not null,
  parent_id uuid,
  level integer default 1 not null,
  slug text not null,
  name text not null,
  short_name text,
  tagline text,
  about text,
  logo_url text,
  banner_url text,
  org_id uuid,
  country text,
  contact_email text,
  visibility text default 'public'::text not null,
  join_policy text default 'invite'::text not null,
  domain text[] default '{}'::text[],
  focus_area text[] default '{}'::text[],
  is_active boolean default true not null,
  provisioned_by uuid,
  provisioned_at timestamp with time zone default now(),
  source_ref text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_documents (
  id uuid default gen_random_uuid() not null,
  event_id bigint not null,
  title text not null,
  url text,
  category text default 'general'::text not null,
  audience text default 'approved'::text not null,
  is_published boolean default true not null,
  sort_order integer default 0 not null,
  created_by uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_events (
  id bigint generated always as identity not null,
  start_date date not null,
  end_date date,
  title text not null,
  category text default 'industry'::text not null,
  location text,
  description text,
  organiser text,
  poc text,
  url text,
  tbc boolean default false,
  created_at timestamp with time zone default now()
);
create table if not exists public.conventus_exercise_media (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  application_id uuid,
  observation_id uuid,
  need_id uuid,
  kind text default 'photo'::text not null,
  storage_path text not null,
  file_name text,
  mime_type text,
  size_bytes bigint,
  caption text,
  captured_at timestamp with time zone,
  uploaded_by uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_exercise_observations (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  application_id uuid,
  need_id uuid,
  obs_date date default CURRENT_DATE not null,
  obs_session text default 'closeout'::text,
  kind text not null,
  headline text not null,
  detail text,
  impact text default 'moderate'::text,
  evidence_url text,
  witnessed_by text,
  observer_id uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_exercise_ratings (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  application_id uuid not null,
  need_id uuid,
  dimension_code text not null,
  rating text not null,
  note text,
  rater_id uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_invitations (
  id bigint generated always as identity not null,
  event_id bigint not null,
  pattern text not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_managed_events (
  id bigint generated always as identity not null,
  code text not null,
  title text not null,
  start_date date,
  end_date date,
  location text,
  host_org text,
  description text,
  invite_only boolean default false not null,
  registration_open boolean default true not null,
  created_by uuid default auth.uid() not null,
  created_at timestamp with time zone default now() not null,
  agenda_field_defs jsonb default '[]'::jsonb not null,
  subtitle text,
  city text,
  country text,
  summary text,
  poc_name text,
  poc_email text,
  gm_services text[] default '{accommodation,transfer_car,culture_spouse,offers}'::text[] not null,
  published boolean default true not null,
  visibility text default 'public'::text not null,
  activity_id uuid,
  community_id uuid,
  reg_opens_at timestamp with time zone,
  reg_closes_at timestamp with time zone,
  capacity integer,
  requires_approval boolean default true,
  waitlist_enabled boolean default false,
  logistics jsonb default '{}'::jsonb,
  registration_field_defs jsonb default '[]'::jsonb not null
);
create table if not exists public.conventus_rating_dimensions (
  id uuid default gen_random_uuid() not null,
  event_id uuid,
  need_id uuid,
  code text not null,
  label_en text not null,
  label_tr text,
  label_fr text,
  label_de text,
  help_en text,
  help_tr text,
  weight numeric default 1.0 not null,
  sort_order integer default 0 not null,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_recognition_records (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  application_id uuid not null,
  level text not null,
  statement text not null,
  basis_observations uuid[] default '{}'::uuid[] not null,
  basis_needs uuid[] default '{}'::uuid[] not null,
  basis_note text,
  issued_by uuid,
  issuing_authority text,
  issued_at timestamp with time zone,
  reference_no text,
  status text default 'draft'::text not null,
  withdrawn_reason text,
  publishable boolean default false not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_registration_events (
  id bigint default nextval('conventus_registration_events_id_seq'::regclass) not null,
  event_id bigint,
  registrant_uid uuid,
  from_status text,
  to_status text not null,
  actor_user_id uuid,
  note text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_registrations (
  id bigint generated always as identity not null,
  event_id bigint not null,
  user_id uuid default auth.uid(),
  first_name text,
  last_name text,
  email text,
  institution text,
  country text,
  rank_title text,
  role text,
  note text,
  status text default 'pending'::text not null,
  created_at timestamp with time zone default now() not null,
  phone text,
  passport_no text,
  dob date,
  ns_email text,
  duty text,
  activity_id uuid,
  person_id uuid,
  org_id uuid,
  answers jsonb default '{}'::jsonb not null,
  registered_by uuid,
  is_delegated boolean default false not null
);
create table if not exists public.conventus_role_events (
  id bigint default nextval('conventus_role_events_id_seq'::regclass) not null,
  role_id uuid,
  auth_user_id uuid,
  scope text,
  scope_id uuid,
  action text not null,
  from_value text,
  to_value text,
  actor_user_id uuid,
  note text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_selection_app_criteria (
  application_id uuid not null,
  need_id uuid not null,
  key text not null,
  value_num numeric,
  value_bool boolean,
  value_text text,
  meets boolean
);
create table if not exists public.conventus_selection_app_needs (
  application_id uuid not null,
  need_id uuid not null,
  is_primary boolean default false not null,
  claim_detail text
);
create table if not exists public.conventus_selection_applications (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  convexus_profile_id uuid,
  submitted_by uuid,
  company_name text not null,
  country text,
  org_type text,
  contact_name text,
  contact_email text,
  contact_phone text,
  website text,
  trl_demo integer,
  trl_claimed_range text,
  artifact_class text default 'unknown'::text not null,
  domain_axis text default 'ground'::text,
  validation_tier text default 'none'::text not null,
  validation_detail text,
  integration_path boolean default false not null,
  integration_detail text,
  blockers text[] default '{}'::text[] not null,
  fit_flags text[] default '{}'::text[] not null,
  summary text,
  raw_intake jsonb,
  state text default 'submitted'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  registration_country text,
  foci_flag boolean,
  foci_detail text,
  integration_standards text[] default '{}'::text[] not null,
  spectrum_required boolean default false not null,
  spectrum_bands text[] default '{}'::text[] not null,
  spectrum_detail text,
  assets jsonb default '[]'::jsonb not null,
  personnel_count integer,
  personnel_nationalities text[] default '{}'::text[] not null,
  cost_coverage text,
  data_sharing_consent boolean default false not null,
  data_sharing_level text,
  certifications text[] default '{}'::text[] not null,
  system_name text,
  contact_role text,
  use_case text,
  nif_backed boolean default false not null,
  diana_backed boolean default false not null,
  interoperability_note text,
  isc_domain text,
  isc_pilot_area text,
  source_ref text,
  validation_tier_verified text,
  verified_by uuid,
  verified_at timestamp with time zone,
  verification_note text,
  trl_verified integer,
  pathway_status text default 'none'::text,
  pathway_type text,
  pathway_note text
);
create table if not exists public.conventus_selection_assessments (
  id uuid default gen_random_uuid() not null,
  run_id uuid,
  application_id uuid not null,
  source text default 'engine'::text not null,
  gate_passed boolean default false not null,
  gate_fails jsonb default '[]'::jsonb not null,
  score_total integer default 0 not null,
  score_breakdown jsonb default '{}'::jsonb not null,
  matched_needs text[] default '{}'::text[] not null,
  decision text not null,
  promoted boolean default false not null,
  promotion_reason text,
  badges jsonb default '[]'::jsonb not null,
  rationale text,
  assessor_id uuid,
  created_at timestamp with time zone default now() not null,
  primary_capability_code text,
  primary_capability_name text,
  primary_confidence numeric,
  primary_signal text,
  alternative_capabilities text[] default '{}'::text[] not null,
  fit_status text default 'generated'::text
);
create table if not exists public.conventus_selection_events (
  id uuid default gen_random_uuid() not null,
  event_code text not null,
  organizer_id uuid,
  title text not null,
  host_nation text,
  window_start date,
  window_end date,
  min_trl integer default 6 not null,
  absolute_trl_floor integer default 5 not null,
  domain_axis text default 'ground'::text not null,
  slots integer,
  min_specialists_per_need integer default 2 not null,
  engine_version text default '1.1'::text not null,
  weights jsonb,
  status text default 'draft'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  eligible_countries text[] default '{}'::text[] not null,
  excluded_countries text[] default '{}'::text[] not null,
  allow_partner_nations boolean default true not null,
  foci_check_required boolean default false not null,
  application_deadline timestamp with time zone,
  assessment_date date,
  invite_date date,
  confirm_deadline date,
  reserve_slots integer default 0 not null,
  multi_assessor boolean default false not null,
  assessor_ids uuid[] default '{}'::uuid[] not null,
  activity_id uuid,
  data_origin text default 'production'::text not null
);
create table if not exists public.conventus_selection_form_fields (
  id uuid default gen_random_uuid() not null,
  event_id uuid,
  field_key text not null,
  section text default 'custom'::text not null,
  label_en text not null,
  label_tr text,
  help_en text,
  help_tr text,
  input_type text default 'text'::text not null,
  options jsonb default '[]'::jsonb not null,
  is_core boolean default false not null,
  is_required boolean default true not null,
  is_scored boolean default false not null,
  score_weight integer default 0 not null,
  sort_order integer default 0 not null,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_selection_materials (
  id uuid default gen_random_uuid() not null,
  application_id uuid not null,
  kind text default 'other'::text not null,
  label text,
  url text,
  storage_path text,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_selection_needs (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  code text not null,
  label text not null,
  detail text,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  criteria jsonb default '[]'::jsonb not null,
  target_slots integer,
  max_slots integer,
  area_note text
);
create table if not exists public.conventus_selection_runs (
  id uuid default gen_random_uuid() not null,
  event_id uuid not null,
  engine_version text not null,
  weights jsonb not null,
  bands jsonb not null,
  run_by uuid,
  note text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_selection_transitions (
  id uuid default gen_random_uuid() not null,
  application_id uuid not null,
  from_state text,
  to_state text not null,
  actor_id uuid,
  note text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_selection_verifications (
  id uuid default gen_random_uuid() not null,
  application_id uuid not null,
  field_key text not null,
  claimed_value text,
  verified_value text,
  outcome text default 'confirmed'::text not null,
  evidence_url text,
  note text,
  verifier_id uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.conventus_sessions (
  id uuid default gen_random_uuid() not null,
  event_id bigint not null,
  title text not null,
  description text,
  session_date date not null,
  start_time time without time zone not null,
  end_time time without time zone,
  room text,
  speakers text,
  track text,
  sort_order integer default 0 not null,
  is_published boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  custom_fields jsonb default '{}'::jsonb not null,
  buttons jsonb default '[]'::jsonb not null,
  item_type text default 'session'::text not null
);
create table if not exists public.convexus_activity_records (
  id uuid default gen_random_uuid() not null,
  profile_id uuid,
  application_id uuid,
  activity_code text not null,
  activity_name text not null,
  activity_type text default 'other'::text not null,
  organiser text,
  organiser_tier text default 'national'::text not null,
  year integer,
  location text,
  engagement_level text default 'participated'::text not null,
  assessment_outcome text default 'unknown'::text not null,
  assessment_body text,
  assessment_ref text,
  assessment_note text,
  verified boolean default false not null,
  verified_by uuid,
  verified_at timestamp with time zone,
  evidence_url text,
  source_ref text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.convexus_admins (
  user_id uuid not null,
  note text,
  created_at timestamp with time zone default now()
);
create table if not exists public.convexus_demand_signals (
  id uuid default gen_random_uuid() not null,
  code text not null,
  title text not null,
  summary text,
  focus_area text[],
  source text default 'manual'::text not null,
  status text default 'candidate'::text not null,
  origin_request_id uuid,
  owner_id uuid,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  source_ref text,
  internal_notes text,
  domain text,
  problem_statement text,
  desired_end_state text,
  time_horizon integer,
  source_url text,
  sort_order integer,
  problem_id uuid
);
create table if not exists public.convexus_domains (
  code text not null,
  name text not null,
  sort_order integer not null,
  description text
);
create table if not exists public.convexus_engagement_events (
  id uuid default gen_random_uuid() not null,
  request_id uuid not null,
  from_status text,
  to_status text,
  action text not null,
  actor_id uuid,
  note text,
  created_at timestamp with time zone default now()
);
create table if not exists public.convexus_engagement_requests (
  id uuid default gen_random_uuid() not null,
  org_name text not null,
  org_country text,
  contact_name text,
  contact_email text,
  website text,
  capability_title text not null,
  capability_summary text,
  trl integer,
  focus_area text[],
  target_stakeholder text[],
  briefing_package_url text,
  profile_id uuid,
  demand_signal_id uuid,
  status text default 'received'::text not null,
  taxonomy_status text default 'untriaged'::text not null,
  demand_status text default 'untriaged'::text not null,
  proposed_capability_area text,
  routed_to text[],
  route_reasons text[],
  triage_notes text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);
create table if not exists public.convexus_focus_areas (
  code text not null,
  name text not null,
  sort_order integer not null,
  origin text default 'base'::text not null,
  description text
);
create table if not exists public.convexus_ndpp_codes (
  code text not null,
  name text not null,
  domain text,
  active boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.convexus_profile_domains (
  profile_id uuid not null,
  domain_code text not null
);
create table if not exists public.convexus_profile_focus_areas (
  profile_id uuid not null,
  focus_code text not null,
  is_primary boolean default false
);
create table if not exists public.convexus_profiles (
  id uuid default gen_random_uuid() not null,
  owner_id uuid,
  org_name text not null,
  org_country text,
  summary text,
  use_profile text,
  trl integer,
  trl_verified integer,
  ally_engaged boolean default false,
  visibility text default 'public'::text not null,
  status text default 'draft'::text not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  website text,
  contact_email text,
  cost_class text,
  membership_tier text default 'basic'::text,
  org_id uuid
);
create table if not exists public.convexus_reference_frameworks (
  code text not null,
  name text not null,
  scope_type text not null,
  granularity text not null,
  source_ref text,
  sort_order integer not null,
  description text
);
create table if not exists public.convexus_requirement_attributes (
  code text not null,
  label text not null,
  description text not null,
  supply_hint text,
  sort_order integer default 0 not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.convexus_signal_attributes (
  signal_id uuid not null,
  attribute_code text not null,
  centrality integer default 1 not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.convexus_use_profiles (
  code text not null,
  name text not null,
  sort_order integer not null,
  description text
);
create table if not exists public.cv_admins (
  user_id uuid not null,
  note text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.gm_inventory (
  id uuid default gen_random_uuid() not null,
  provider_id uuid not null,
  event_id bigint,
  category text not null,
  title text not null,
  description text,
  price_class text,
  date_from date,
  date_to date,
  capacity integer,
  details jsonb default '{}'::jsonb not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  price_amount numeric(12,2),
  currency text default 'EUR'::text
);
create table if not exists public.gm_offers (
  id uuid default gen_random_uuid() not null,
  provider_id uuid not null,
  event_id bigint,
  tag text default 'other'::text not null,
  title text not null,
  body text,
  price_note text,
  date_from date,
  date_to date,
  status text default 'draft'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  price_amount numeric(12,2),
  currency text default 'EUR'::text,
  tag_other text
);
create table if not exists public.gm_plan (
  id uuid default gen_random_uuid() not null,
  event_id bigint not null,
  user_id uuid not null,
  category text not null,
  inventory_id uuid,
  offer_id uuid,
  status text default 'requested'::text not null,
  note text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table if not exists public.gm_provider_ratings (
  id uuid default gen_random_uuid() not null,
  provider_id uuid not null,
  platform text not null,
  platform_other text,
  score numeric(3,1) not null,
  scale numeric(3,1) default 5 not null,
  url text not null,
  verified boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table if not exists public.gm_providers (
  id uuid default gen_random_uuid() not null,
  name text not null,
  type text default 'other'::text not null,
  owner_user_id uuid,
  contact_email text,
  phone text,
  accredited boolean default false not null,
  commission_rate numeric(5,2),
  contract_fee numeric(12,2),
  contract_date date,
  contract_note text,
  created_at timestamp with time zone default now() not null,
  terms_accepted_at timestamp with time zone,
  terms_version text,
  categories text[] default '{}'::text[] not null,
  type_other text,
  contact_person text,
  website text,
  city text,
  country text,
  description text,
  applied_at timestamp with time zone default now()
);
create table if not exists public.profiles (
  id uuid not null,
  full_name text,
  company text,
  bio text,
  created_at timestamp without time zone default now()
);
create table if not exists public.projects (
  id uuid default gen_random_uuid() not null,
  owner_id uuid,
  title text not null,
  description text,
  category text,
  created_at timestamp without time zone default now()
);

-- ===================== 3 · PK / UNIQUE / CHECK =====================
do $cvblock$
declare r record;
begin
  for r in select * from (values
    ('conventity_activities', 'conventity_activities_activity_type_check', $d$CHECK ((activity_type = ANY (ARRAY['event'::text, 'experiment'::text, 'ttx'::text, 'mapex'::text, 'range'::text, 'challenge'::text])))$d$),
    ('conventity_activities', 'conventity_activities_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_activities', 'conventity_activities_source_check', $d$CHECK ((source = ANY (ARRAY['internal'::text, 'external'::text])))$d$),
    ('conventity_activities', 'conventity_activities_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_activities', 'conventity_activities_status_check', $d$CHECK ((status = ANY (ARRAY['planned'::text, 'open'::text, 'running'::text, 'completed'::text, 'archived'::text])))$d$),
    ('conventity_audit', 'conventity_audit_action_check', $d$CHECK ((action = ANY (ARRAY['insert'::text, 'update'::text, 'delete'::text])))$d$),
    ('conventity_audit', 'conventity_audit_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_capabilities', 'conventity_capabilities_code_key', $d$UNIQUE (code)$d$),
    ('conventity_capabilities', 'conventity_capabilities_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_capabilities', 'conventity_capabilities_source_check', $d$CHECK ((source = ANY (ARRAY['ndpp'::text, 'crit'::text, 'orion'::text, 'local'::text])))$d$),
    ('conventity_capabilities', 'conventity_capabilities_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_capabilities', 'conventity_capabilities_status_chk', $d$CHECK (((status IS NULL) OR (status = ANY (ARRAY['active'::text, 'draft'::text, 'retired'::text]))))$d$),
    ('conventity_cn_connections', 'conventity_cn_connections_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_cn_connections', 'conventity_cn_connections_requester_id_addressee_id_key', $d$UNIQUE (requester_id, addressee_id)$d$),
    ('conventity_cn_connections', 'conventity_cn_connections_status_check', $d$CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text])))$d$),
    ('conventity_cn_expertise', 'conventity_cn_expertise_kind_check', $d$CHECK ((kind = ANY (ARRAY['sme'::text, 'speaker'::text])))$d$),
    ('conventity_cn_expertise', 'conventity_cn_expertise_person_id_tag_kind_key', $d$UNIQUE (person_id, tag, kind)$d$),
    ('conventity_cn_expertise', 'conventity_cn_expertise_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_cn_expertise', 'conventity_cn_expertise_self_rated_check', $d$CHECK (((self_rated >= 1) AND (self_rated <= 5)))$d$),
    ('conventity_cn_expertise', 'conventity_cn_expertise_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_cn_groups', 'conventity_cn_groups_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_cn_groups', 'conventity_cn_groups_purpose_kind_check', $d$CHECK ((purpose_kind = ANY (ARRAY['problem'::text, 'activity'::text, 'challenge_area'::text, 'event'::text, 'org'::text, 'topic'::text, 'community'::text])))$d$),
    ('conventity_cn_groups', 'conventity_cn_groups_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_cn_groups', 'conventity_cn_groups_visibility_check', $d$CHECK ((visibility = ANY (ARRAY['locked'::text, 'ecosystem'::text])))$d$),
    ('conventity_cn_memberships', 'conventity_cn_memberships_group_id_person_id_key', $d$UNIQUE (group_id, person_id)$d$),
    ('conventity_cn_memberships', 'conventity_cn_memberships_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_cn_memberships', 'conventity_cn_memberships_role_check', $d$CHECK ((role = ANY (ARRAY['member'::text, 'moderator'::text, 'sme'::text, 'speaker'::text])))$d$),
    ('conventity_cn_memberships', 'conventity_cn_memberships_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_cn_messages', 'conventity_cn_messages_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_cn_post_comments', 'conventity_cn_post_comments_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_cn_post_reactions', 'conventity_cn_post_reactions_pkey', $d$PRIMARY KEY (post_id, person_id)$d$),
    ('conventity_cn_posts', 'conventity_cn_posts_kind_check', $d$CHECK ((kind = ANY (ARRAY['note'::text, 'ask'::text, 'offer'::text, 'announce'::text])))$d$),
    ('conventity_cn_posts', 'conventity_cn_posts_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_cn_posts', 'conventity_cn_posts_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_evidence', 'conventity_evidence_evidence_type_check', $d$CHECK ((evidence_type = ANY (ARRAY['participation_seal'::text, 'assessment'::text, 'validated'::text, 'badge_ref'::text])))$d$),
    ('conventity_evidence', 'conventity_evidence_issuing_auth_check', $d$CHECK ((issuing_auth = ANY (ARRAY['conventity'::text, 'nato'::text])))$d$),
    ('conventity_evidence', 'conventity_evidence_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_evidence', 'conventity_evidence_proof_slug_key', $d$UNIQUE (proof_slug)$d$),
    ('conventity_evidence', 'conventity_evidence_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_matches', 'conventity_matches_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_matches', 'conventity_matches_status_chk', $d$CHECK ((status = ANY (ARRAY['shortlisted'::text, 'contacted'::text, 'rejected'::text, 'engaged'::text])))$d$),
    ('conventity_orgs', 'conventity_orgs_membership_tier_check', $d$CHECK ((membership_tier = ANY (ARRAY['basic'::text, 'bronze'::text, 'silver'::text, 'gold'::text])))$d$),
    ('conventity_orgs', 'conventity_orgs_org_type_check', $d$CHECK ((org_type = ANY (ARRAY['firm'::text, 'institution'::text, 'ecosystem'::text, 'nation'::text, 'provider'::text])))$d$),
    ('conventity_orgs', 'conventity_orgs_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_orgs', 'conventity_orgs_source_check', $d$CHECK ((source = ANY (ARRAY['seed'::text, 'frontdoor'::text, 'import'::text, 'manual'::text])))$d$),
    ('conventity_orgs', 'conventity_orgs_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_participation', 'conventity_participation_check', $d$CHECK (((org_id IS NOT NULL) OR (person_id IS NOT NULL)))$d$),
    ('conventity_participation', 'conventity_participation_part_role_check', $d$CHECK ((part_role = ANY (ARRAY['participant'::text, 'organizer'::text, 'evaluator'::text, 'observer'::text, 'vendor'::text])))$d$),
    ('conventity_participation', 'conventity_participation_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_participation', 'conventity_participation_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_participation', 'conventity_participation_status_check', $d$CHECK ((status = ANY (ARRAY['invited'::text, 'confirmed'::text, 'attended'::text, 'withdrawn'::text])))$d$),
    ('conventity_people', 'conventity_people_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_people', 'conventity_people_source_check', $d$CHECK ((source = ANY (ARRAY['seed'::text, 'frontdoor'::text, 'import'::text, 'manual'::text])))$d$),
    ('conventity_people', 'conventity_people_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_problem_capability', 'conventity_problem_capability_pkey', $d$PRIMARY KEY (problem_id, capability_id)$d$),
    ('conventity_problem_solution', 'conventity_problem_solution_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_problem_solution', 'conventity_problem_solution_problem_id_solution_id_key', $d$UNIQUE (problem_id, solution_id)$d$),
    ('conventity_problem_solution', 'conventity_problem_solution_status_check', $d$CHECK ((status = ANY (ARRAY['proposed'::text, 'shortlisted'::text, 'rejected'::text, 'matched'::text])))$d$),
    ('conventity_problems', 'conventity_problems_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_problems', 'conventity_problems_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_problems', 'conventity_problems_status_check', $d$CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'matched'::text, 'closed'::text])))$d$),
    ('conventity_relations', 'conventity_relations_from_type_check', $d$CHECK ((from_type = ANY (ARRAY['org'::text, 'person'::text, 'solution'::text, 'activity'::text, 'problem'::text])))$d$),
    ('conventity_relations', 'conventity_relations_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_relations', 'conventity_relations_provenance_check', $d$CHECK ((provenance = ANY (ARRAY['conventity'::text, 'nato_mirror'::text, 'inferred'::text])))$d$),
    ('conventity_relations', 'conventity_relations_rel_type_check', $d$CHECK ((rel_type = ANY (ARRAY['knows'::text, 'owns_relationship'::text, 'collaborated'::text, 'invested_in'::text, 'decided'::text, 'procured'::text, 'derived_from'::text])))$d$),
    ('conventity_relations', 'conventity_relations_to_type_check', $d$CHECK ((to_type = ANY (ARRAY['org'::text, 'person'::text, 'solution'::text, 'activity'::text, 'problem'::text])))$d$),
    ('conventity_roles', 'conventity_roles_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_roles', 'conventity_roles_role_check', $d$CHECK ((role = ANY (ARRAY['admin'::text, 'organizer'::text, 'vendor'::text, 'member'::text, 'owner'::text, 'event_manager'::text])))$d$),
    ('conventity_roles', 'conventity_roles_scope_check', $d$CHECK ((scope = ANY (ARRAY['ecosystem'::text, 'convexus'::text, 'conventus'::text, 'conventlab'::text, 'connectus'::text, 'consultus'::text, 'convergens'::text, 'community'::text, 'activity'::text])))$d$),
    ('conventity_roles', 'conventity_roles_scopeid_check', $d$CHECK ((((scope = ANY (ARRAY['community'::text, 'activity'::text])) AND (scope_id IS NOT NULL)) OR ((scope <> ALL (ARRAY['community'::text, 'activity'::text])) AND (scope_id IS NULL))))$d$),
    ('conventity_roles', 'conventity_roles_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_roles', 'conventity_roles_status_check', $d$CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'revoked'::text])))$d$),
    ('conventity_signin_log', 'conventity_signin_log_method_check', $d$CHECK ((method = ANY (ARRAY['password'::text, 'google'::text, 'linkedin_oidc'::text, 'other'::text])))$d$),
    ('conventity_signin_log', 'conventity_signin_log_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_solution_capability', 'conventity_solution_capability_pkey', $d$PRIMARY KEY (solution_id, capability_id)$d$),
    ('conventity_solutions', 'conventity_solutions_cost_class_check', $d$CHECK ((cost_class = ANY (ARRAY['survivable'::text, 'attritable'::text, 'consumable'::text])))$d$),
    ('conventity_solutions', 'conventity_solutions_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventity_solutions', 'conventity_solutions_source_check', $d$CHECK ((source = ANY (ARRAY['seed'::text, 'frontdoor'::text, 'import'::text, 'manual'::text])))$d$),
    ('conventity_solutions', 'conventity_solutions_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventity_solutions', 'conventity_solutions_status_check', $d$CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'active'::text, 'retired'::text])))$d$),
    ('conventity_solutions', 'conventity_solutions_trl_check', $d$CHECK (((trl >= 1) AND (trl <= 9)))$d$),
    ('conventus_announcements', 'conventus_announcements_audience_check', $d$CHECK ((audience = ANY (ARRAY['all'::text, 'approved'::text, 'pending'::text, 'organizers'::text, 'community_members'::text])))$d$),
    ('conventus_announcements', 'conventus_announcements_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_communities', 'conventus_communities_join_policy_check', $d$CHECK ((join_policy = ANY (ARRAY['open'::text, 'request'::text, 'invite'::text])))$d$),
    ('conventus_communities', 'conventus_communities_level_check', $d$CHECK ((level = ANY (ARRAY[1, 2])))$d$),
    ('conventus_communities', 'conventus_communities_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_communities', 'conventus_communities_slug_key', $d$UNIQUE (slug)$d$),
    ('conventus_communities', 'conventus_communities_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('conventus_communities', 'conventus_communities_visibility_check', $d$CHECK ((visibility = ANY (ARRAY['public'::text, 'unlisted'::text, 'private'::text])))$d$),
    ('conventus_documents', 'conventus_documents_audience_check', $d$CHECK ((audience = ANY (ARRAY['all'::text, 'approved'::text, 'pending'::text, 'community_members'::text, 'organizers'::text])))$d$),
    ('conventus_documents', 'conventus_documents_category_check', $d$CHECK ((category = ANY (ARRAY['general'::text, 'agenda'::text, 'venue'::text, 'travel'::text, 'security'::text, 'forms'::text, 'other'::text])))$d$),
    ('conventus_documents', 'conventus_documents_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_events', 'conventus_events_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_exercise_media', 'conventus_exercise_media_kind_check', $d$CHECK ((kind = ANY (ARRAY['photo'::text, 'video'::text, 'document'::text])))$d$),
    ('conventus_exercise_media', 'conventus_exercise_media_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_exercise_observations', 'conventus_exercise_observations_impact_check', $d$CHECK ((impact = ANY (ARRAY['minor'::text, 'moderate'::text, 'significant'::text, 'blocking'::text])))$d$),
    ('conventus_exercise_observations', 'conventus_exercise_observations_kind_check', $d$CHECK ((kind = ANY (ARRAY['achievement'::text, 'hurdle_jumped'::text, 'hurdle_hit'::text, 'observation'::text])))$d$),
    ('conventus_exercise_observations', 'conventus_exercise_observations_obs_session_check', $d$CHECK ((obs_session = ANY (ARRAY['standup'::text, 'closeout'::text, 'adhoc'::text, 'wash_up'::text])))$d$),
    ('conventus_exercise_observations', 'conventus_exercise_observations_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_exercise_ratings', 'conventus_exercise_ratings_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_exercise_ratings', 'conventus_exercise_ratings_rating_check', $d$CHECK ((rating = ANY (ARRAY['did_not_meet'::text, 'partial'::text, 'met'::text, 'excelled'::text, 'not_assessed'::text])))$d$),
    ('conventus_invitations', 'conventus_invitations_event_id_pattern_key', $d$UNIQUE (event_id, pattern)$d$),
    ('conventus_invitations', 'conventus_invitations_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_managed_events', 'cme_gm_services_chk', $d$CHECK ((gm_services <@ ARRAY['accommodation'::text, 'transfer_car'::text, 'culture_spouse'::text, 'offers'::text]))$d$),
    ('conventus_managed_events', 'cme_visibility_chk', $d$CHECK ((visibility = ANY (ARRAY['public'::text, 'invite'::text])))$d$),
    ('conventus_managed_events', 'conventus_managed_events_code_key', $d$UNIQUE (code)$d$),
    ('conventus_managed_events', 'conventus_managed_events_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_rating_dimensions', 'conventus_rating_dimensions_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_recognition_records', 'conventus_recognition_records_level_check', $d$CHECK ((level = ANY (ARRAY['participated'::text, 'demonstrated'::text, 'validated'::text, 'capability_proven'::text])))$d$),
    ('conventus_recognition_records', 'conventus_recognition_records_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_recognition_records', 'conventus_recognition_records_reference_no_key', $d$UNIQUE (reference_no)$d$),
    ('conventus_recognition_records', 'conventus_recognition_records_status_check', $d$CHECK ((status = ANY (ARRAY['draft'::text, 'issued'::text, 'withdrawn'::text])))$d$),
    ('conventus_registration_events', 'conventus_registration_events_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_registrations', 'conventus_registrations_event_id_user_id_key', $d$UNIQUE (event_id, user_id)$d$),
    ('conventus_registrations', 'conventus_registrations_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_registrations', 'conventus_registrations_status_chk', $d$CHECK ((status = ANY (ARRAY['invited'::text, 'draft'::text, 'submitted'::text, 'under_review'::text, 'approved'::text, 'rejected'::text, 'waitlisted'::text, 'checked_in'::text, 'cancelled'::text, 'no_show'::text, 'approved'::text])))$d$),
    ('conventus_role_events', 'conventus_role_events_action_check', $d$CHECK ((action = ANY (ARRAY['granted'::text, 'revoked'::text, 'role_changed'::text, 'status_changed'::text, 'inherited'::text])))$d$),
    ('conventus_role_events', 'conventus_role_events_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_app_criteria', 'conventus_selection_app_criteria_pkey', $d$PRIMARY KEY (application_id, need_id, key)$d$),
    ('conventus_selection_app_needs', 'conventus_selection_app_needs_pkey', $d$PRIMARY KEY (application_id, need_id)$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_artifact_class_check', $d$CHECK ((artifact_class = ANY (ARRAY['ugv_platform'::text, 'adjacent_platform'::text, 'mountable_subsystem'::text, 'embedded_software'::text, 'ops_enabler'::text, 'out_of_domain'::text, 'unknown'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_cost_coverage_check', $d$CHECK ((cost_coverage = ANY (ARRAY['self_funded'::text, 'partial_support'::text, 'support_requested'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_data_sharing_level_check', $d$CHECK ((data_sharing_level = ANY (ARRAY['none'::text, 'host_nation_only'::text, 'nato_internal'::text, 'public_summary'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_domain_axis_check', $d$CHECK ((domain_axis = ANY (ARRAY['ground'::text, 'aerial'::text, 'maritime'::text, 'space'::text, 'cyber'::text, 'other'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_isc_domain_check', $d$CHECK (((isc_domain IS NULL) OR (isc_domain = ANY (ARRAY['LAND'::text, 'MARITIME'::text, 'AIR'::text, 'CYBER'::text, 'SPACE'::text, 'JOINT_ENABLING'::text, 'SOF'::text]))))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_isc_pilot_area_check', $d$CHECK (((isc_pilot_area IS NULL) OR (isc_pilot_area = ANY (ARRAY['OTHER'::text, 'LAND_PLATFORMS'::text, 'JOINT_FIRES'::text, 'SEAD_SBAMD'::text, 'MARITIME_PLATFORMS'::text]))))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_org_type_check', $d$CHECK ((org_type = ANY (ARRAY['startup'::text, 'scaleup'::text, 'industry'::text, 'sme'::text, 'small_business'::text, 'spinoff'::text, 'academia'::text, 'other'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_pathway_status_check', $d$CHECK ((pathway_status = ANY (ARRAY['none'::text, 'identified'::text, 'in_progress'::text, 'awarded'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_pathway_type_check', $d$CHECK (((pathway_type IS NULL) OR (pathway_type = ANY (ARRAY['national'::text, 'nspa'::text, 'diana_rapid_adoption'::text, 'systems_integrator'::text, 'other'::text]))))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_state_check', $d$CHECK ((state = ANY (ARRAY['submitted'::text, 'screened'::text, 'assessed'::text, 'shortlisted'::text, 'invited'::text, 'confirmed'::text, 'declined'::text, 'withdrawn'::text, 'demonstrated'::text, 'evidence_captured'::text, 'recognised'::text, 'pathway_identified'::text, 'contracted'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_trl_demo_check', $d$CHECK (((trl_demo >= 1) AND (trl_demo <= 9)))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_trl_verified_check', $d$CHECK (((trl_verified IS NULL) OR ((trl_verified >= 1) AND (trl_verified <= 9))))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_validation_tier_check', $d$CHECK ((validation_tier = ANY (ARRAY['combat_fielded'::text, 'combat_tested'::text, 'allied_exercise'::text, 'national_trial'::text, 'none'::text])))$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_validation_tier_verified_check', $d$CHECK (((validation_tier_verified IS NULL) OR (validation_tier_verified = ANY (ARRAY['combat_fielded'::text, 'combat_tested'::text, 'allied_exercise'::text, 'national_trial'::text, 'none'::text]))))$d$),
    ('conventus_selection_assessments', 'conventus_selection_assessments_decision_check', $d$CHECK ((decision = ANY (ARRAY['MUST'::text, 'RESERVE'::text, 'MAYBE'::text, 'NO'::text])))$d$),
    ('conventus_selection_assessments', 'conventus_selection_assessments_fit_status_check', $d$CHECK ((fit_status = ANY (ARRAY['generated'::text, 'human_reviewed'::text, 'error'::text, 'pending'::text])))$d$),
    ('conventus_selection_assessments', 'conventus_selection_assessments_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_assessments', 'conventus_selection_assessments_source_check', $d$CHECK ((source = ANY (ARRAY['engine'::text, 'human_override'::text, 'committee'::text])))$d$),
    ('conventus_selection_assessments', 'csas_conf_range', $d$CHECK (((primary_confidence IS NULL) OR ((primary_confidence >= (0)::numeric) AND (primary_confidence <= (1)::numeric))))$d$),
    ('conventus_selection_events', 'conventus_selection_events_data_origin_check', $d$CHECK ((data_origin = ANY (ARRAY['production'::text, 'demo'::text, 'fixture'::text])))$d$),
    ('conventus_selection_events', 'conventus_selection_events_domain_axis_check', $d$CHECK ((domain_axis = ANY (ARRAY['ground'::text, 'aerial'::text, 'maritime'::text, 'space'::text, 'cyber'::text, 'other'::text])))$d$),
    ('conventus_selection_events', 'conventus_selection_events_event_code_key', $d$UNIQUE (event_code)$d$),
    ('conventus_selection_events', 'conventus_selection_events_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_events', 'conventus_selection_events_status_check', $d$CHECK ((status = ANY (ARRAY['draft'::text, 'open'::text, 'closed'::text, 'assessed'::text, 'published'::text])))$d$),
    ('conventus_selection_form_fields', 'conventus_selection_form_fields_input_type_check', $d$CHECK ((input_type = ANY (ARRAY['text'::text, 'textarea'::text, 'number'::text, 'select'::text, 'multiselect'::text, 'boolean'::text, 'date'::text, 'url'::text, 'file'::text, 'country'::text, 'trl'::text, 'criteria'::text])))$d$),
    ('conventus_selection_form_fields', 'conventus_selection_form_fields_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_form_fields', 'conventus_selection_form_fields_section_check', $d$CHECK ((section = ANY (ARRAY['identity'::text, 'system'::text, 'evidence'::text, 'logistics'::text, 'materials'::text, 'custom'::text])))$d$),
    ('conventus_selection_materials', 'conventus_selection_materials_kind_check', $d$CHECK ((kind = ANY (ARRAY['pitch_deck'::text, 'tech_doc'::text, 'demo_video'::text, 'brochure'::text, 'reference'::text, 'test_report'::text, 'other'::text])))$d$),
    ('conventus_selection_materials', 'conventus_selection_materials_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_needs', 'conventus_selection_needs_event_id_code_key', $d$UNIQUE (event_id, code)$d$),
    ('conventus_selection_needs', 'conventus_selection_needs_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_runs', 'conventus_selection_runs_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_transitions', 'conventus_selection_transitions_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_selection_verifications', 'conventus_selection_verifications_outcome_check', $d$CHECK ((outcome = ANY (ARRAY['confirmed'::text, 'downgraded'::text, 'upgraded'::text, 'rejected'::text, 'unverifiable'::text])))$d$),
    ('conventus_selection_verifications', 'conventus_selection_verifications_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_sessions', 'conventus_sessions_pkey', $d$PRIMARY KEY (id)$d$),
    ('conventus_sessions', 'conventus_sessions_time_chk', $d$CHECK (((end_time IS NULL) OR (end_time > start_time)))$d$),
    ('conventus_sessions', 'conventus_sessions_type_chk', $d$CHECK ((item_type = ANY (ARRAY['session'::text, 'meal'::text, 'transport'::text, 'social'::text, 'executive'::text, 'networking'::text])))$d$),
    ('convexus_activity_records', 'convexus_activity_records_activity_type_check', $d$CHECK ((activity_type = ANY (ARRAY['nato_exercise'::text, 'nato_innovation'::text, 'nato_accelerator'::text, 'nato_fund'::text, 'national_exercise'::text, 'allied_trial'::text, 'multinational_prog'::text, 'other'::text])))$d$),
    ('convexus_activity_records', 'convexus_activity_records_assessment_outcome_check', $d$CHECK ((assessment_outcome = ANY (ARRAY['excelled'::text, 'met'::text, 'partial'::text, 'did_not_meet'::text, 'not_assessed'::text, 'unknown'::text])))$d$),
    ('convexus_activity_records', 'convexus_activity_records_engagement_level_check', $d$CHECK ((engagement_level = ANY (ARRAY['demonstrated'::text, 'integrated'::text, 'participated'::text, 'selected_only'::text, 'applied'::text])))$d$),
    ('convexus_activity_records', 'convexus_activity_records_organiser_tier_check', $d$CHECK ((organiser_tier = ANY (ARRAY['nato_hq'::text, 'nato_command'::text, 'nato_agency'::text, 'multinational'::text, 'national'::text, 'other'::text])))$d$),
    ('convexus_activity_records', 'convexus_activity_records_pkey', $d$PRIMARY KEY (id)$d$),
    ('convexus_activity_records', 'convexus_activity_records_source_ref_key', $d$UNIQUE (source_ref)$d$),
    ('convexus_admins', 'convexus_admins_pkey', $d$PRIMARY KEY (user_id)$d$),
    ('convexus_demand_signals', 'convexus_demand_signals_code_key', $d$UNIQUE (code)$d$),
    ('convexus_demand_signals', 'convexus_demand_signals_domain_chk', $d$CHECK (((domain IS NULL) OR (domain = ANY (ARRAY['land'::text, 'air_missile_defence'::text, 'deep_strike'::text, 'medical'::text, 'logistics'::text]))))$d$),
    ('convexus_demand_signals', 'convexus_demand_signals_pkey', $d$PRIMARY KEY (id)$d$),
    ('convexus_demand_signals', 'convexus_demand_signals_source_check', $d$CHECK ((source = ANY (ARRAY['public_document'::text, 'engagement'::text, 'manual'::text])))$d$),
    ('convexus_demand_signals', 'convexus_demand_signals_status_check', $d$CHECK ((status = ANY (ARRAY['candidate'::text, 'active'::text, 'archived'::text])))$d$),
    ('convexus_domains', 'convexus_domains_pkey', $d$PRIMARY KEY (code)$d$),
    ('convexus_engagement_events', 'convexus_engagement_events_action_check', $d$CHECK ((action = ANY (ARRAY['submitted'::text, 'briefing_requested'::text, 'review_started'::text, 'routed'::text, 'experimentation_started'::text, 'closed'::text, 'reopened'::text, 'promoted_to_demand'::text, 'promoted_to_category'::text, 'note'::text])))$d$),
    ('convexus_engagement_events', 'convexus_engagement_events_pkey', $d$PRIMARY KEY (id)$d$),
    ('convexus_engagement_requests', 'convexus_engagement_requests_demand_status_check', $d$CHECK ((demand_status = ANY (ARRAY['untriaged'::text, 'matched'::text, 'no_match'::text, 'new_demand_candidate'::text])))$d$),
    ('convexus_engagement_requests', 'convexus_engagement_requests_pkey', $d$PRIMARY KEY (id)$d$),
    ('convexus_engagement_requests', 'convexus_engagement_requests_status_check', $d$CHECK ((status = ANY (ARRAY['received'::text, 'briefing_requested'::text, 'under_review'::text, 'routed'::text, 'experimentation'::text, 'closed'::text])))$d$),
    ('convexus_engagement_requests', 'convexus_engagement_requests_taxonomy_status_check', $d$CHECK ((taxonomy_status = ANY (ARRAY['untriaged'::text, 'mapped'::text, 'partial'::text, 'off_taxonomy'::text, 'new_category_candidate'::text])))$d$),
    ('convexus_engagement_requests', 'convexus_engagement_requests_trl_check', $d$CHECK (((trl IS NULL) OR ((trl >= 1) AND (trl <= 9))))$d$),
    ('convexus_focus_areas', 'convexus_focus_areas_pkey', $d$PRIMARY KEY (code)$d$),
    ('convexus_ndpp_codes', 'convexus_ndpp_codes_pkey', $d$PRIMARY KEY (code)$d$),
    ('convexus_profile_domains', 'convexus_profile_domains_pkey', $d$PRIMARY KEY (profile_id, domain_code)$d$),
    ('convexus_profile_focus_areas', 'convexus_profile_focus_areas_pkey', $d$PRIMARY KEY (profile_id, focus_code)$d$),
    ('convexus_profiles', 'convexus_profiles_cost_class_check', $d$CHECK (((cost_class IS NULL) OR (cost_class = ANY (ARRAY['survivable'::text, 'attritable'::text, 'consumable'::text]))))$d$),
    ('convexus_profiles', 'convexus_profiles_membership_tier_check', $d$CHECK ((membership_tier = ANY (ARRAY['basic'::text, 'bronze'::text, 'silver'::text, 'gold'::text])))$d$),
    ('convexus_profiles', 'convexus_profiles_pkey', $d$PRIMARY KEY (id)$d$),
    ('convexus_profiles', 'convexus_profiles_status_check', $d$CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'archived'::text])))$d$),
    ('convexus_profiles', 'convexus_profiles_trl_check', $d$CHECK (((trl >= 1) AND (trl <= 9)))$d$),
    ('convexus_profiles', 'convexus_profiles_trl_verified_check', $d$CHECK (((trl_verified >= 1) AND (trl_verified <= 9)))$d$),
    ('convexus_profiles', 'convexus_profiles_visibility_check', $d$CHECK ((visibility = ANY (ARRAY['public'::text, 'gated'::text, 'nda'::text])))$d$),
    ('convexus_reference_frameworks', 'convexus_reference_frameworks_pkey', $d$PRIMARY KEY (code)$d$),
    ('convexus_requirement_attributes', 'convexus_requirement_attributes_pkey', $d$PRIMARY KEY (code)$d$),
    ('convexus_signal_attributes', 'convexus_signal_attributes_centrality_chk', $d$CHECK ((centrality = ANY (ARRAY[1, 2])))$d$),
    ('convexus_signal_attributes', 'convexus_signal_attributes_pkey', $d$PRIMARY KEY (signal_id, attribute_code)$d$),
    ('convexus_use_profiles', 'convexus_use_profiles_pkey', $d$PRIMARY KEY (code)$d$),
    ('cv_admins', 'cv_admins_pkey', $d$PRIMARY KEY (user_id)$d$),
    ('gm_inventory', 'gm_inv_currency_chk', $d$CHECK (((currency IS NULL) OR (currency = ANY (ARRAY['EUR'::text, 'USD'::text, 'TRY'::text, 'GBP'::text, 'CHF'::text, 'AED'::text, 'SAR'::text, 'QAR'::text, 'KWD'::text, 'BHD'::text, 'OMR'::text, 'JPY'::text, 'CNY'::text, 'KRW'::text, 'CAD'::text, 'AUD'::text, 'NOK'::text, 'SEK'::text, 'DKK'::text, 'PLN'::text, 'CZK'::text, 'HUF'::text, 'RON'::text, 'BGN'::text]))))$d$),
    ('gm_inventory', 'gm_inventory_category_check', $d$CHECK ((category = ANY (ARRAY['accommodation'::text, 'transfer_car'::text, 'culture_spouse'::text])))$d$),
    ('gm_inventory', 'gm_inventory_pkey', $d$PRIMARY KEY (id)$d$),
    ('gm_offers', 'gm_off_currency_chk', $d$CHECK (((currency IS NULL) OR (currency = ANY (ARRAY['EUR'::text, 'USD'::text, 'TRY'::text, 'GBP'::text, 'CHF'::text, 'AED'::text, 'SAR'::text, 'QAR'::text, 'KWD'::text, 'BHD'::text, 'OMR'::text, 'JPY'::text, 'CNY'::text, 'KRW'::text, 'CAD'::text, 'AUD'::text, 'NOK'::text, 'SEK'::text, 'DKK'::text, 'PLN'::text, 'CZK'::text, 'HUF'::text, 'RON'::text, 'BGN'::text]))))$d$),
    ('gm_offers', 'gm_offers_pkey', $d$PRIMARY KEY (id)$d$),
    ('gm_offers', 'gm_offers_status_check', $d$CHECK ((status = ANY (ARRAY['draft'::text, 'pending'::text, 'approved'::text, 'rejected'::text])))$d$),
    ('gm_offers', 'gm_offers_tag_check', $d$CHECK ((tag = ANY (ARRAY['summer'::text, 'winter'::text, 'golf'::text, 'ski'::text, 'spa'::text, 'city'::text, 'other'::text])))$d$),
    ('gm_plan', 'gm_plan_category_check', $d$CHECK ((category = ANY (ARRAY['accommodation'::text, 'transfer_car'::text, 'culture_spouse'::text, 'offer'::text])))$d$),
    ('gm_plan', 'gm_plan_pkey', $d$PRIMARY KEY (id)$d$),
    ('gm_plan', 'gm_plan_status_check', $d$CHECK ((status = ANY (ARRAY['requested'::text, 'confirmed'::text, 'cancelled'::text])))$d$),
    ('gm_provider_ratings', 'gm_provider_ratings_pkey', $d$PRIMARY KEY (id)$d$),
    ('gm_provider_ratings', 'gm_provider_ratings_platform_check', $d$CHECK ((platform = ANY (ARRAY['google'::text, 'tripadvisor'::text, 'booking'::text, 'trustpilot'::text, 'expedia'::text, 'other'::text])))$d$),
    ('gm_provider_ratings', 'gm_provider_ratings_scale_check', $d$CHECK ((scale = ANY (ARRAY[(5)::numeric, (10)::numeric])))$d$),
    ('gm_provider_ratings', 'gm_rating_score_chk', $d$CHECK (((score >= (0)::numeric) AND (score <= scale)))$d$),
    ('gm_providers', 'gm_prov_categories_chk', $d$CHECK ((categories <@ ARRAY['accommodation'::text, 'transfer_car'::text, 'culture_spouse'::text, 'offers'::text]))$d$),
    ('gm_providers', 'gm_providers_pkey', $d$PRIMARY KEY (id)$d$),
    ('gm_providers', 'gm_providers_type_check', $d$CHECK ((type = ANY (ARRAY['hotel'::text, 'transfer_car'::text, 'tour_agency'::text, 'other'::text])))$d$),
    ('profiles', 'profiles_pkey', $d$PRIMARY KEY (id)$d$),
    ('projects', 'projects_pkey', $d$PRIMARY KEY (id)$d$)
  ) v(tbl, con, def) loop
    if not exists (
      select 1 from pg_constraint c
      join pg_class rel on rel.oid = c.conrelid
      join pg_namespace n on n.oid = rel.relnamespace
      where n.nspname = 'public' and rel.relname = r.tbl and c.conname = r.con
    ) then
      execute format('alter table public.%I add constraint %I %s', r.tbl, r.con, r.def);
    end if;
  end loop;
end $cvblock$;
-- -- (kısıt sonu)

-- ===================== 4 · INDEKSLER =====================
CREATE INDEX IF NOT EXISTS idx_conv_audit_at ON public.conventity_audit USING btree (at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_audit_rec ON public.conventity_audit USING btree (record_id);
CREATE INDEX IF NOT EXISTS idx_conv_audit_tbl ON public.conventity_audit USING btree (table_name);
CREATE INDEX IF NOT EXISTS idx_conv_caps_domain ON public.conventity_capabilities USING btree (domain);
CREATE UNIQUE INDEX IF NOT EXISTS uq_conv_caps_source_ref ON public.conventity_capabilities USING btree (source_ref) WHERE (source_ref IS NOT NULL);
CREATE INDEX IF NOT EXISTS idx_cn_conn_addr ON public.conventity_cn_connections USING btree (addressee_id);
CREATE INDEX IF NOT EXISTS idx_cn_conn_req ON public.conventity_cn_connections USING btree (requester_id);
CREATE INDEX IF NOT EXISTS idx_cn_exp_tag ON public.conventity_cn_expertise USING btree (tag);
CREATE INDEX IF NOT EXISTS idx_cn_memb_group ON public.conventity_cn_memberships USING btree (group_id);
CREATE INDEX IF NOT EXISTS idx_cn_memb_person ON public.conventity_cn_memberships USING btree (person_id);
CREATE INDEX IF NOT EXISTS idx_cn_msg_created ON public.conventity_cn_messages USING btree (created_at);
CREATE INDEX IF NOT EXISTS idx_cn_msg_recipient ON public.conventity_cn_messages USING btree (recipient_id);
CREATE INDEX IF NOT EXISTS idx_cn_msg_sender ON public.conventity_cn_messages USING btree (sender_id);
CREATE INDEX IF NOT EXISTS idx_cn_comment_post ON public.conventity_cn_post_comments USING btree (post_id);
CREATE INDEX IF NOT EXISTS idx_cn_react_post ON public.conventity_cn_post_reactions USING btree (post_id);
CREATE INDEX IF NOT EXISTS idx_cn_posts_group ON public.conventity_cn_posts USING btree (group_id);
CREATE INDEX IF NOT EXISTS conventity_matches_org_idx ON public.conventity_matches USING btree (org_id);
CREATE INDEX IF NOT EXISTS conventity_matches_problem_idx ON public.conventity_matches USING btree (problem_id);
CREATE UNIQUE INDEX IF NOT EXISTS conventity_matches_uniq ON public.conventity_matches USING btree (problem_id, solution_id);
CREATE INDEX IF NOT EXISTS idx_conv_problems_authority_org ON public.conventity_problems USING btree (authority_org_id);
CREATE INDEX IF NOT EXISTS idx_roles_scope ON public.conventity_roles USING btree (scope, scope_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_roles_user_scope ON public.conventity_roles USING btree (auth_user_id, scope, scope_id, role) WHERE (auth_user_id IS NOT NULL);
CREATE INDEX IF NOT EXISTS idx_conv_signin_at ON public.conventity_signin_log USING btree (at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_signin_method ON public.conventity_signin_log USING btree (method);
CREATE INDEX IF NOT EXISTS idx_conv_signin_user ON public.conventity_signin_log USING btree (auth_user_id);
CREATE INDEX IF NOT EXISTS conventus_ann_event_idx ON public.conventus_announcements USING btree (event_id, pinned DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cc_parent ON public.conventus_communities USING btree (parent_id);
CREATE INDEX IF NOT EXISTS idx_cc_slug ON public.conventus_communities USING btree (slug);
CREATE INDEX IF NOT EXISTS conventus_documents_event_idx ON public.conventus_documents USING btree (event_id, sort_order);
CREATE UNIQUE INDEX IF NOT EXISTS conventus_events_uq ON public.conventus_events USING btree (title, start_date);
CREATE INDEX IF NOT EXISTS idx_cem_app ON public.conventus_exercise_media USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_cem_event ON public.conventus_exercise_media USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_cem_obs ON public.conventus_exercise_media USING btree (observation_id);
CREATE INDEX IF NOT EXISTS idx_ceo_app ON public.conventus_exercise_observations USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_ceo_date ON public.conventus_exercise_observations USING btree (obs_date);
CREATE INDEX IF NOT EXISTS idx_ceo_event ON public.conventus_exercise_observations USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_cer_app ON public.conventus_exercise_ratings USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_cer_event ON public.conventus_exercise_ratings USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_cme_activity ON public.conventus_managed_events USING btree (activity_id);
CREATE INDEX IF NOT EXISTS idx_cme_community ON public.conventus_managed_events USING btree (community_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_crd_event_code ON public.conventus_rating_dimensions USING btree (event_id, code) WHERE (event_id IS NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS uq_crd_tpl_code ON public.conventus_rating_dimensions USING btree (code) WHERE (event_id IS NULL);
CREATE INDEX IF NOT EXISTS idx_crr_app ON public.conventus_recognition_records USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_crr_event ON public.conventus_recognition_records USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_reg_events_event ON public.conventus_registration_events USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_role_events_scope ON public.conventus_role_events USING btree (scope, scope_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_csan_one_primary ON public.conventus_selection_app_needs USING btree (application_id) WHERE is_primary;
CREATE INDEX IF NOT EXISTS idx_csa_event ON public.conventus_selection_applications USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_csa_profile ON public.conventus_selection_applications USING btree (convexus_profile_id);
CREATE INDEX IF NOT EXISTS idx_csa_state ON public.conventus_selection_applications USING btree (state);
CREATE UNIQUE INDEX IF NOT EXISTS uq_csa_source_ref ON public.conventus_selection_applications USING btree (source_ref) WHERE (source_ref IS NOT NULL);
CREATE INDEX IF NOT EXISTS idx_csas_app ON public.conventus_selection_assessments USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_csas_run ON public.conventus_selection_assessments USING btree (run_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_csff_event_key ON public.conventus_selection_form_fields USING btree (event_id, field_key) WHERE (event_id IS NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS uq_csff_template_key ON public.conventus_selection_form_fields USING btree (field_key) WHERE (event_id IS NULL);
CREATE INDEX IF NOT EXISTS idx_csm_app ON public.conventus_selection_materials USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_cst_app ON public.conventus_selection_transitions USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_csv_app ON public.conventus_selection_verifications USING btree (application_id);
CREATE INDEX IF NOT EXISTS conventus_sessions_event_idx ON public.conventus_sessions USING btree (event_id, session_date, start_time);
CREATE INDEX IF NOT EXISTS idx_car_app ON public.convexus_activity_records USING btree (application_id);
CREATE INDEX IF NOT EXISTS idx_car_code ON public.convexus_activity_records USING btree (activity_code);
CREATE INDEX IF NOT EXISTS idx_car_profile ON public.convexus_activity_records USING btree (profile_id);
CREATE INDEX IF NOT EXISTS convexus_demand_signals_domain_idx ON public.convexus_demand_signals USING btree (domain);
CREATE INDEX IF NOT EXISTS idx_cds_focus_gin ON public.convexus_demand_signals USING gin (focus_area);
CREATE INDEX IF NOT EXISTS idx_cds_origin ON public.convexus_demand_signals USING btree (origin_request_id);
CREATE INDEX IF NOT EXISTS idx_cds_source ON public.convexus_demand_signals USING btree (source);
CREATE INDEX IF NOT EXISTS idx_cds_status ON public.convexus_demand_signals USING btree (status);
CREATE INDEX IF NOT EXISTS idx_ceng_evt_created ON public.convexus_engagement_events USING btree (created_at);
CREATE INDEX IF NOT EXISTS idx_ceng_evt_request ON public.convexus_engagement_events USING btree (request_id);
CREATE INDEX IF NOT EXISTS idx_ceng_req_demand_status ON public.convexus_engagement_requests USING btree (demand_status);
CREATE INDEX IF NOT EXISTS idx_ceng_req_focus_gin ON public.convexus_engagement_requests USING gin (focus_area);
CREATE INDEX IF NOT EXISTS idx_ceng_req_profile ON public.convexus_engagement_requests USING btree (profile_id);
CREATE INDEX IF NOT EXISTS idx_ceng_req_status ON public.convexus_engagement_requests USING btree (status);
CREATE INDEX IF NOT EXISTS idx_ceng_req_taxonomy_status ON public.convexus_engagement_requests USING btree (taxonomy_status);
CREATE INDEX IF NOT EXISTS convexus_signal_attributes_attr_idx ON public.convexus_signal_attributes USING btree (attribute_code);
CREATE INDEX IF NOT EXISTS gm_inv_event_idx ON public.gm_inventory USING btree (event_id) WHERE (event_id IS NOT NULL);
CREATE INDEX IF NOT EXISTS gm_inv_provider_idx ON public.gm_inventory USING btree (provider_id, category);
CREATE INDEX IF NOT EXISTS gm_offers_status_idx ON public.gm_offers USING btree (status, tag);
CREATE INDEX IF NOT EXISTS gm_plan_user_idx ON public.gm_plan USING btree (event_id, user_id);
CREATE INDEX IF NOT EXISTS gm_ratings_provider_idx ON public.gm_provider_ratings USING btree (provider_id, verified);
CREATE UNIQUE INDEX IF NOT EXISTS gm_providers_owner_uq ON public.gm_providers USING btree (owner_user_id) WHERE (owner_user_id IS NOT NULL);

-- ===================== 5 · FONKSIYONLAR =====================
set check_function_bodies = off;
CREATE OR REPLACE FUNCTION public.connectus_comment(p_post uuid, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                  declare me uuid;
                                                                  begin
                                                                    me := public.conventity_cn_my_person_id();
                                                                      if me is null then return jsonb_build_object('ok', false, 'error', 'no_profile'); end if;
                                                                        if not exists (select 1 from public.conventity_cn_posts po
                                                                                         join public.conventity_cn_memberships m on m.group_id = po.group_id
                                                                                                          where po.id = p_post and m.person_id = me)
                                                                                                              then return jsonb_build_object('ok', false, 'error', 'not_member'); end if;
                                                                                                                if coalesce(trim(p_body), '') = '' then return jsonb_build_object('ok', false, 'error', 'empty'); end if;
                                                                                                                  insert into public.conventity_cn_post_comments (post_id, author_id, body) values (p_post, me, trim(p_body));
                                                                                                                    return jsonb_build_object('ok', true);
                                                                                                                    end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_connect(p_addressee uuid, p_purpose text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                      declare me uuid; ex record;
                      begin
                        me := public.conventity_cn_my_person_id();
                          if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
                            if p_addressee is null or p_addressee = me then return jsonb_build_object('ok',false,'error','invalid'); end if;
                              select * into ex from public.conventity_cn_connections
                                  where (requester_id=me and addressee_id=p_addressee) or (requester_id=p_addressee and addressee_id=me) limit 1;
                                    if found then return jsonb_build_object('ok',true,'status',ex.status,'existing',true); end if;
                                      insert into public.conventity_cn_connections (requester_id, addressee_id, purpose)
                                          values (me, p_addressee, nullif(trim(coalesce(p_purpose,'')),''));
                                            return jsonb_build_object('ok',true,'status','pending');
                                            end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_connections()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                with me as (select public.conventity_cn_my_person_id() as id)
                                                                  select jsonb_build_object(
                                                                      'accepted', coalesce((select jsonb_agg(jsonb_build_object('connection_id',c.id,
                                                                              'person_id', case when c.requester_id=(select id from me) then c.addressee_id else c.requester_id end,
                                                                                      'name', coalesce(p.full_name,p.email,'Member'), 'tagline', coalesce(p.role_title,'')))
                                                                                            from public.conventity_cn_connections c
                                                                                                  join public.conventity_people p on p.id = case when c.requester_id=(select id from me) then c.addressee_id else c.requester_id end
                                                                                                        where c.status='accepted' and (c.requester_id=(select id from me) or c.addressee_id=(select id from me))), '[]'::jsonb),
                                                                                                            'incoming', coalesce((select jsonb_agg(jsonb_build_object('connection_id',c.id,'person_id',c.requester_id,
                                                                                                                    'name', coalesce(p.full_name,p.email,'Member'), 'tagline', coalesce(p.role_title,''), 'purpose', c.purpose))
                                                                                                                          from public.conventity_cn_connections c join public.conventity_people p on p.id = c.requester_id
                                                                                                                                where c.status='pending' and c.addressee_id=(select id from me)), '[]'::jsonb),
                                                                                                                                    'outgoing', coalesce((select jsonb_agg(c.addressee_id)
                                                                                                                                          from public.conventity_cn_connections c where c.status='pending' and c.requester_id=(select id from me)), '[]'::jsonb));
                                                                                                                                          $function$
;
CREATE OR REPLACE FUNCTION public.connectus_create_group(p_name text, p_kind text DEFAULT 'topic'::text, p_visibility text DEFAULT 'ecosystem'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                           declare me uuid; gid uuid;
                           begin
                             me := public.conventity_cn_my_person_id();
                               if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
                                 if coalesce(trim(p_name),'')='' then return jsonb_build_object('ok',false,'error','name_required'); end if;
                                   insert into public.conventity_cn_groups (name, purpose_kind, visibility, created_by)
                                       values (trim(p_name),
                                             case when p_kind in ('problem','activity','challenge_area','event','org','topic','community') then p_kind else 'topic' end,
                                                   case when p_visibility in ('locked','ecosystem') then p_visibility else 'ecosystem' end, me)
                                                       returning id into gid;
                                                         insert into public.conventity_cn_memberships (group_id, person_id, role) values (gid, me, 'moderator');
                                                           return jsonb_build_object('ok',true,'id',gid);
                                                           end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_directory(p_limit integer DEFAULT 48)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with ppl as (
    select p.id, coalesce(p.full_name, p.email, 'Member') as name,
           coalesce(p.role_title, '') as tagline, coalesce(o.short_name, o.legal_name) as org,
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
    limit p_limit),
  org as (
    select o.id, coalesce(o.legal_name, o.short_name, 'Organisation') as name,
           trim(both ' ·' from coalesce(o.org_type,'organisation') || coalesce(' · '||o.nation,'')) as tagline
    from public.conventity_orgs o
    where coalesce(o.legal_name, o.short_name) is not null
    order by o.legal_name asc nulls last
    limit greatest(p_limit/3, 12))
  select jsonb_build_object(
    'people', coalesce((select jsonb_agg(jsonb_build_object('id',ppl.id,'kind','person','name',ppl.name,
               'tagline',ppl.tagline,'org',ppl.org,'events',ppl.events,'certs',ppl.certs,'tags',ppl.tags)) from ppl), '[]'::jsonb),
    'orgs',   coalesce((select jsonb_agg(jsonb_build_object('id',org.id,'kind','org','name',org.name,'tagline',org.tagline)) from org), '[]'::jsonb));
$function$
;
CREATE OR REPLACE FUNCTION public.connectus_discover(p_query text DEFAULT NULL::text, p_limit integer DEFAULT 12)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                            with me as (select public.conventity_cn_my_person_id() as id),
                                                                                                                                              q as (select nullif(trim(coalesce(p_query,'')),'') as term),
                                                                                                                                                mytags as (select tag from public.conventity_cn_expertise where person_id = (select id from me)),
                                                                                                                                                  myconns as (
                                                                                                                                                      select case when requester_id=(select id from me) then addressee_id else requester_id end as pid
                                                                                                                                                          from public.conventity_cn_connections
                                                                                                                                                              where status='accepted' and (select id from me) in (requester_id, addressee_id)),
                                                                                                                                                                cand as (
                                                                                                                                                                    select p.id, coalesce(p.full_name,p.email,'Member') as name, coalesce(p.role_title,'') as tagline,
                                                                                                                                                                          (select array_agg(distinct e.tag) from public.conventity_cn_expertise e
                                                                                                                                                                                   where e.person_id=p.id and e.tag in (select tag from mytags)) as shared,
                                                                                                                                                                                         (select count(*) from (
                                                                                                                                                                                                  select pid from myconns
                                                                                                                                                                                                           intersect
                                                                                                                                                                                                                    select case when c.requester_id=p.id then c.addressee_id else c.requester_id end
                                                                                                                                                                                                                             from public.conventity_cn_connections c
                                                                                                                                                                                                                                      where c.status='accepted' and p.id in (c.requester_id,c.addressee_id)) mm) as mutuals,
                                                                                                                                                                                                                                            (select e.tag from public.conventity_cn_expertise e
                                                                                                                                                                                                                                                     where e.person_id=p.id and (select term from q) is not null and e.tag ilike '%'||(select term from q)||'%' limit 1) as qtag
                                                                                                                                                                                                                                                         from public.conventity_people p
                                                                                                                                                                                                                                                             where p.id is distinct from (select id from me) and coalesce(p.full_name,p.email) is not null),
                                                                                                                                                                                                                                                               scored as (
                                                                                                                                                                                                                                                                   select c.*,
                                                                                                                                                                                                                                                                         coalesce(array_length(c.shared,1),0)*2 + c.mutuals*3 + case when c.qtag is not null then 5 else 0 end as score,
                                                                                                                                                                                                                                                                               case
                                                                                                                                                                                                                                                                                       when (select term from q) is not null and c.qtag is not null then 'expertise “'||c.qtag||'”'
                                                                                                                                                                                                                                                                                               when (select term from q) is not null then 'name / role match'
                                                                                                                                                                                                                                                                                                       when coalesce(array_length(c.shared,1),0)>0 and c.mutuals>0 then 'shared expertise '||array_to_string(c.shared,', ')||' · '||c.mutuals||' mutual'
                                                                                                                                                                                                                                                                                                               when coalesce(array_length(c.shared,1),0)>0 then 'shared expertise '||array_to_string(c.shared,', ')
                                                                                                                                                                                                                                                                                                                       when c.mutuals>0 then c.mutuals||' mutual connection'||case when c.mutuals=1 then '' else 's' end
                                                                                                                                                                                                                                                                                                                               else 'in the ecosystem'
                                                                                                                                                                                                                                                                                                                                     end as why
                                                                                                                                                                                                                                                                                                                                         from cand c
                                                                                                                                                                                                                                                                                                                                             where case when (select term from q) is not null
                                                                                                                                                                                                                                                                                                                                                   then (c.name ilike '%'||(select term from q)||'%' or c.tagline ilike '%'||(select term from q)||'%' or c.qtag is not null)
                                                                                                                                                                                                                                                                                                                                                         else (coalesce(array_length(c.shared,1),0)>0 or c.mutuals>0) end)
                                                                                                                                                                                                                                                                                                                                                           select coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'tagline',tagline,'why',why))
                                                                                                                                                                                                                                                                                                                                                               from (select * from scored order by score desc, name asc limit p_limit) t), '[]'::jsonb);
                                                                                                                                                                                                                                                                                                                                                               $function$
;
CREATE OR REPLACE FUNCTION public.connectus_feed(p_group uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                    with me as (select public.conventity_cn_my_person_id() as id),
                                                      mine as (select group_id from public.conventity_cn_memberships where person_id = (select id from me))
                                                        select coalesce((select jsonb_agg(j order by j_at desc) from (
                                                            select jsonb_build_object(
                                                                  'id', po.id, 'group_id', po.group_id, 'group_name', g.name,
                                                                        'body', po.body, 'kind', po.kind, 'created_at', po.created_at,
                                                                              'author', coalesce(a.full_name, a.email, 'Member'),
                                                                                    'author_id', po.author_id,
                                                                                          'reactions', (select count(*) from public.conventity_cn_post_reactions r where r.post_id = po.id),
                                                                                                'reacted', exists (select 1 from public.conventity_cn_post_reactions r where r.post_id = po.id and r.person_id = (select id from me)),
                                                                                                      'comments', (select count(*) from public.conventity_cn_post_comments c where c.post_id = po.id)
                                                                                                          ) as j, po.created_at as j_at
                                                                                                              from public.conventity_cn_posts po
                                                                                                                  join public.conventity_cn_groups g on g.id = po.group_id
                                                                                                                      left join public.conventity_people a on a.id = po.author_id
                                                                                                                          where po.group_id in (select group_id from mine)
                                                                                                                                and (p_group is null or po.group_id = p_group)
                                                                                                                                    order by po.created_at desc
                                                                                                                                        limit p_limit
                                                                                                                                          ) s), '[]'::jsonb);
                                                                                                                                          $function$
;
CREATE OR REPLACE FUNCTION public.connectus_groups()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    with me as (select public.conventity_cn_my_person_id() as id)
      select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'purpose_kind',g.purpose_kind,'visibility',g.visibility,
          'members',(select count(*) from public.conventity_cn_memberships m where m.group_id=g.id),
              'my_role',(select m.role from public.conventity_cn_memberships m where m.group_id=g.id and m.person_id=(select id from me) limit 1))
                  order by g.created_at desc), '[]'::jsonb)
                    from public.conventity_cn_groups g
                      where g.visibility='ecosystem'
                           or exists (select 1 from public.conventity_cn_memberships m where m.group_id=g.id and m.person_id=(select id from me));
                           $function$
;
CREATE OR REPLACE FUNCTION public.connectus_join_group(p_group uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                           declare me uuid;
                                                           begin
                                                             me := public.conventity_cn_my_person_id();
                                                               if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
                                                                 insert into public.conventity_cn_memberships (group_id, person_id, role) values (p_group, me, 'member')
                                                                     on conflict (group_id, person_id) do nothing;
                                                                       return jsonb_build_object('ok',true);
                                                                       end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_leave_group(p_group uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                       declare me uuid;
                                                                       begin
                                                                         me := public.conventity_cn_my_person_id();
                                                                           delete from public.conventity_cn_memberships where group_id=p_group and person_id=me;
                                                                             return jsonb_build_object('ok',true);
                                                                             end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_my_profile()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'id', p.id, 'name', coalesce(p.full_name, p.email, 'Member'),
    'tagline', coalesce(p.role_title, ''),
    'org', coalesce(o.short_name, o.legal_name), 'email', p.email,
    'events', (select count(*) from public.conventity_participation pa where pa.person_id = p.id),
    'certs',  (select count(*) from public.conventity_evidence ev
               where ev.activity_id in (select pa.activity_id from public.conventity_participation pa where pa.person_id = p.id)),
    'tags',   coalesce((select array_agg(distinct e.tag order by e.tag)
                        from public.conventity_cn_expertise e where e.person_id = p.id), array[]::text[]))
  from public.conventity_people p
  left join public.conventity_orgs o on o.id = p.home_org_id
  where p.auth_user_id = auth.uid() limit 1;
$function$
;
CREATE OR REPLACE FUNCTION public.connectus_org_detail(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with o as (select * from public.conventity_orgs where id = p_org_id limit 1),
  mem as (
    select p.id, coalesce(p.full_name, p.email, 'Member') as name,
           coalesce(p.role_title,'') as tagline,
           (select count(*) from public.conventity_participation pa where pa.person_id = p.id) as events
    from public.conventity_people p
    where p.home_org_id = p_org_id and coalesce(p.full_name, p.email) is not null
    order by (select count(*) from public.conventity_participation pa where pa.person_id = p.id) desc,
             p.full_name asc nulls last
    limit 60
  )
  select case when (select id from o) is null then null else jsonb_build_object(
    'id', (select id from o),
    'name', coalesce((select legal_name from o),(select short_name from o),'Organisation'),
    'short', (select short_name from o),
    'org_type', coalesce((select org_type from o),'organisation'),
    'nation', (select nation from o),
    'members_count', (select count(*) from public.conventity_people p where p.home_org_id = p_org_id),
    'members', coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'tagline',tagline,'events',events)) from mem), '[]'::jsonb),
    'expertise', coalesce((select array_agg(tag order by tag) from (
        select distinct e.tag from public.conventity_cn_expertise e where e.person_id in (select id from mem) limit 40) t), array[]::text[]),
    'credentials', coalesce((select jsonb_agg(row order by ord) from (
        select jsonb_build_object('type',coalesce(ev.evidence_type,'evidence'),'activity',coalesce(a.title,'Activity'),
                 'issued_at',ev.issued_at,'proof_slug',ev.proof_slug) as row, ev.issued_at as ord
        from public.conventity_evidence ev
        left join public.conventity_activities a on a.id = ev.activity_id
        where ev.org_id = p_org_id order by ev.issued_at desc nulls last limit 24) s), '[]'::jsonb)
  ) end;
$function$
;
CREATE OR REPLACE FUNCTION public.connectus_post(p_group uuid, p_body text, p_kind text DEFAULT 'note'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                 declare me uuid;
                                                                                                                 begin
                                                                                                                   me := public.conventity_cn_my_person_id();
                                                                                                                     if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
                                                                                                                       if not exists (select 1 from public.conventity_cn_memberships where group_id=p_group and person_id=me)
                                                                                                                           then return jsonb_build_object('ok',false,'error','not_member'); end if;
                                                                                                                             if coalesce(trim(p_body),'')='' then return jsonb_build_object('ok',false,'error','empty'); end if;
                                                                                                                               insert into public.conventity_cn_posts (group_id, author_id, body, kind)
                                                                                                                                   values (p_group, me, trim(p_body), case when p_kind in ('note','ask','offer','announce') then p_kind else 'note' end);
                                                                                                                                     return jsonb_build_object('ok',true);
                                                                                                                                     end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_post_comments(p_post uuid, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select jsonb_agg(j order by j_at asc) from (
      select jsonb_build_object('id', c.id, 'body', c.body, 'created_at', c.created_at,
                   'author', coalesce(a.full_name, a.email, 'Member'),
                                'author_id', c.author_id) as j, c.created_at as j_at
                                    from public.conventity_cn_post_comments c
                                        left join public.conventity_people a on a.id = c.author_id
                                            where c.post_id = p_post
                                                order by c.created_at asc limit p_limit
                                                  ) s), '[]'::jsonb);
                                                  $function$
;
CREATE OR REPLACE FUNCTION public.connectus_profile_detail(p_person_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with tgt as (
    select p.* from public.conventity_people p
    where (p_person_id is not null and p.id = p_person_id)
       or (p_person_id is null and p.auth_user_id = auth.uid())
    limit 1
  ),
  acts as (
    select pa.activity_id from public.conventity_participation pa
    where pa.person_id = (select id from tgt)
  )
  select case when (select id from tgt) is null then null else jsonb_build_object(
    'id', (select id from tgt),
    'is_me', (select auth_user_id from tgt) is not distinct from auth.uid(),
    'name', coalesce((select full_name from tgt), (select email from tgt), 'Member'),
    'tagline', coalesce((select role_title from tgt), ''),
    'org', (select coalesce(o.short_name, o.legal_name)
            from public.conventity_orgs o where o.id = (select home_org_id from tgt)),
    'events', (select count(*) from acts),
    'certs', (select count(*) from public.conventity_evidence ev where ev.activity_id in (select activity_id from acts)),
    'connections', (select count(*) from public.conventity_cn_connections c
      where c.status='accepted' and (select id from tgt) in (c.requester_id, c.addressee_id)),
    'tags', coalesce((select array_agg(distinct e.tag order by e.tag)
                      from public.conventity_cn_expertise e where e.person_id = (select id from tgt)), array[]::text[]),
    'credentials', coalesce((
      select jsonb_agg(row order by ord) from (
        select jsonb_build_object('type', coalesce(ev.evidence_type,'evidence'),
                 'activity', coalesce(a.title,'Activity'), 'issued_at', ev.issued_at, 'proof_slug', ev.proof_slug) as row,
               ev.issued_at as ord
        from public.conventity_evidence ev
        left join public.conventity_activities a on a.id = ev.activity_id
        where ev.activity_id in (select activity_id from acts)
        order by ev.issued_at desc nulls last limit 24
      ) s), '[]'::jsonb),
    'track', coalesce((
      select jsonb_agg(jsonb_build_object('title', coalesce(a.title,'Activity'), 'kind', a.activity_type))
      from public.conventity_activities a where a.id in (select activity_id from acts) limit 24), '[]'::jsonb)
  ) end;
$function$
;
CREATE OR REPLACE FUNCTION public.connectus_react(p_post uuid, p_on boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
    if me is null then return jsonb_build_object('ok', false, 'error', 'no_profile'); end if;
      if not exists (select 1 from public.conventity_cn_posts po
                       join public.conventity_cn_memberships m on m.group_id = po.group_id
                                        where po.id = p_post and m.person_id = me)
                                            then return jsonb_build_object('ok', false, 'error', 'not_member'); end if;
                                              if p_on then
                                                  insert into public.conventity_cn_post_reactions (post_id, person_id)
                                                        values (p_post, me) on conflict (post_id, person_id) do nothing;
                                                          else
                                                              delete from public.conventity_cn_post_reactions where post_id = p_post and person_id = me;
                                                                end if;
                                                                  return jsonb_build_object('ok', true, 'on', p_on);
                                                                  end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_respond(p_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                            declare me uuid; r record;
                                            begin
                                              me := public.conventity_cn_my_person_id();
                                                select * into r from public.conventity_cn_connections where id = p_id limit 1;
                                                  if not found then return jsonb_build_object('ok',false,'error','not_found'); end if;
                                                    if r.addressee_id <> me then return jsonb_build_object('ok',false,'error','forbidden'); end if;
                                                      if r.status <> 'pending' then return jsonb_build_object('ok',true,'status',r.status); end if;
                                                        update public.conventity_cn_connections
                                                            set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now() where id = p_id;
                                                              return jsonb_build_object('ok',true,'status', case when p_accept then 'accepted' else 'declined' end);
                                                              end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_send_message(p_to uuid, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  if p_to is null or p_to = me then return jsonb_build_object('ok',false,'error','invalid'); end if;
  if not exists (select 1 from public.conventity_people p where p.id = p_to)
    then return jsonb_build_object('ok',false,'error','no_recipient'); end if;
  if coalesce(trim(p_body),'')='' then return jsonb_build_object('ok',false,'error','empty'); end if;
  insert into public.conventity_cn_messages (sender_id, recipient_id, body) values (me, p_to, trim(p_body));
  return jsonb_build_object('ok',true);
end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_thread(p_with uuid, p_limit integer DEFAULT 200)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid; result jsonb;
begin
  me := public.conventity_cn_my_person_id();
  if me is null then return jsonb_build_object('ok',false,'error','no_profile'); end if;
  update public.conventity_cn_messages set read_at=now()
    where recipient_id=me and sender_id=p_with and read_at is null;
  select jsonb_build_object('ok',true,
    'person',(select jsonb_build_object('id',p.id,'name',coalesce(p.full_name,p.email,'Member'),'tagline',coalesce(p.role_title,''))
              from public.conventity_people p where p.id=p_with),
    'messages',coalesce((select jsonb_agg(row order by created_at asc) from (
        select jsonb_build_object('id',m.id,'body',m.body,'created_at',m.created_at,'from_me',m.sender_id=me) as row, m.created_at as created_at
        from public.conventity_cn_messages m
        where (m.sender_id=me and m.recipient_id=p_with) or (m.sender_id=p_with and m.recipient_id=me)
        order by m.created_at desc limit p_limit) s), '[]'::jsonb)
  ) into result;
  return result;
end $function$
;
CREATE OR REPLACE FUNCTION public.connectus_threads()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with me as (select public.conventity_cn_my_person_id() as id),
  conv as (
    select case when m.sender_id=(select id from me) then m.recipient_id else m.sender_id end as other,
           m.body, m.created_at, m.sender_id, m.recipient_id, m.read_at
    from public.conventity_cn_messages m
    where (select id from me) in (m.sender_id, m.recipient_id)),
  last as (select distinct on (other) other, body, created_at, sender_id from conv order by other, created_at desc),
  un as (select other, count(*) filter (where recipient_id=(select id from me) and read_at is null) as unread from conv group by other)
  select coalesce((select jsonb_agg(row order by created_at desc) from (
    select jsonb_build_object('person_id',l.other,'name',coalesce(p.full_name,p.email,'Member'),
      'tagline',coalesce(p.role_title,''),'last',l.body,'last_at',l.created_at,
      'from_me',l.sender_id=(select id from me),'unread',coalesce(u.unread,0)) as row, l.created_at as created_at
    from last l join public.conventity_people p on p.id=l.other left join un u on u.other=l.other) t), '[]'::jsonb);
$function$
;
CREATE OR REPLACE FUNCTION public.conventity_audit_trg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid    uuid := auth.uid();
  v_person uuid;
  v_rec    uuid;
  v_diff   jsonb;
begin
  select id into v_person
    from conventity_people
   where auth_user_id = v_uid
   limit 1;

  if tg_op = 'DELETE' then
    v_rec  := (to_jsonb(old)->>'id')::uuid;
    v_diff := jsonb_build_object('old', to_jsonb(old));
  elsif tg_op = 'UPDATE' then
    v_rec  := (to_jsonb(new)->>'id')::uuid;
    v_diff := jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new));
  else -- INSERT
    v_rec  := (to_jsonb(new)->>'id')::uuid;
    v_diff := jsonb_build_object('new', to_jsonb(new));
  end if;

  insert into conventity_audit(actor_auth_uid, actor_person_id, table_name, record_id, action, diff)
  values (v_uid, v_person, tg_table_name, v_rec, lower(tg_op), v_diff);

  if tg_op = 'DELETE' then return old; else return new; end if;
end
$function$
;
CREATE OR REPLACE FUNCTION public.conventity_can_manage_community(p_cid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                                                                                                                                                                                                           select conventity_is_admin('ecosystem')
                                                                                                                                                                                                                                                                                                                                                                                                 or coalesce(conventity_community_role(p_cid) in ('owner','admin'), false);
                                                                                                                                                                                                                                                                                                                                                                                                 $function$
;
CREATE OR REPLACE FUNCTION public.conventity_can_manage_event(p_activity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                                                                                                                                                                                                                   select conventity_is_admin('ecosystem')
                                                                                                                                                                                                                                                                                                                                                                                                         or exists (
                                                                                                                                                                                                                                                                                                                                                                                                                    select 1 from conventity_roles r
                                                                                                                                                                                                                                                                                                                                                                                                                                where r.scope='activity' and r.scope_id = p_activity_id
                                                                                                                                                                                                                                                                                                                                                                                                                                              and r.auth_user_id = auth.uid() and r.status='active'
                                                                                                                                                                                                                                                                                                                                                                                                                                                            and r.role in ('event_manager','organizer')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                          and (r.expires_at is null or r.expires_at > now())
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   )
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         or exists (
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    select 1 from conventus_managed_events e
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                where e.activity_id = p_activity_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              and conventity_can_manage_community(e.community_id)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       );
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       $function$
;
CREATE OR REPLACE FUNCTION public.conventity_cn_is_group_member(g uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                select exists (select 1 from public.conventity_cn_memberships m
                                                                                 where m.group_id = g and m.person_id = public.conventity_cn_my_person_id());
                                                                                 $function$
;
CREATE OR REPLACE FUNCTION public.conventity_cn_my_person_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id from public.conventity_people p where p.auth_user_id = auth.uid() limit 1;
  $function$
;
CREATE OR REPLACE FUNCTION public.conventity_community_role(p_cid uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                                                                                                               with me as (select auth.uid() u)
                                                                                                                                                                                                                                                                                                 select r.role from conventity_roles r, me
                                                                                                                                                                                                                                                                                                    where r.scope='community' and r.status='active' and r.auth_user_id = me.u
                                                                                                                                                                                                                                                                                                         and ( r.scope_id = p_cid
                                                                                                                                                                                                                                                                                                                 or r.scope_id = (select parent_id from conventus_communities where id = p_cid) )
                                                                                                                                                                                                                                                                                                                    order by case r.role when 'owner' then 1 when 'admin' then 2
                                                                                                                                                                                                                                                                                                                                            when 'organizer' then 3 else 4 end
                                                                                                                                                                                                                                                                                                                                               limit 1;
                                                                                                                                                                                                                                                                                                                                               $function$
;
CREATE OR REPLACE FUNCTION public.conventity_in_community(p_cid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                                                                                                                                                                 select conventity_community_role(p_cid) is not null;
                                                                                                                                                                                                                                                                                                                                                 $function$
;
CREATE OR REPLACE FUNCTION public.conventity_is_admin(p_scope text DEFAULT 'ecosystem'::text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from conventity_roles r
    where r.auth_user_id = auth.uid()
      and r.role = 'admin'
      and (r.scope = 'ecosystem' or r.scope = p_scope)
  );
$function$
;
CREATE OR REPLACE FUNCTION public.conventity_is_member()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
      coalesce(public.conventity_is_admin('ecosystem'), false)
          or exists (
                select 1 from public.conventity_roles r
                      where r.auth_user_id = auth.uid()
                          )
                              or exists (
                                    select 1 from public.conventity_people p
                                          where p.auth_user_id = auth.uid()
                                              )
                                                  or (
                                                        nullif(auth.jwt() ->> 'email', '') is not null
                                                              and exists (
                                                                      select 1 from public.conventity_people p
                                                                              where p.email is not null
                                                                                        and lower(p.email) = lower(auth.jwt() ->> 'email')
                                                                                              )
                                                                                                  );
                                                                                                  $function$
;
CREATE OR REPLACE FUNCTION public.conventity_uid_in_community(p_uid uuid, p_cid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                                                                                                                                                                   select exists (select 1 from conventity_roles r
                                                                                                                                                                                                                                                                                                                                                                     where r.scope='community' and r.status='active'
                                                                                                                                                                                                                                                                                                                                                                                         and r.auth_user_id = p_uid and r.scope_id = p_cid);
                                                                                                                                                                                                                                                                                                                                                                                         $function$
;
CREATE OR REPLACE FUNCTION public.conventus_cc_depth_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
                                                                                declare p_level int;
                                                                                begin
                                                                                  if new.parent_id is null then
                                                                                      new.level := 1;
                                                                                        else
                                                                                            select level into p_level from conventus_communities where id = new.parent_id;
                                                                                                if p_level is null then raise exception 'parent community not found'; end if;
                                                                                                    if p_level <> 1 then
                                                                                                          raise exception 'Only two levels are allowed: a sub-community cannot have children';
                                                                                                              end if;
                                                                                                                  new.level := 2;
                                                                                                                    end if;
                                                                                                                      new.updated_at := now();
                                                                                                                        return new;
                                                                                                                        end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_clone_rating_dims(p_event_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                            declare n int;
                                            begin
                                              insert into public.conventus_rating_dimensions
                                                  (event_id, code, label_en, label_tr, label_fr, label_de, help_en, help_tr, weight, sort_order, active)
                                                    select p_event_id, d.code, d.label_en, d.label_tr, d.label_fr, d.label_de,
                                                             d.help_en, d.help_tr, d.weight, d.sort_order, d.active
                                                               from public.conventus_rating_dimensions d
                                                                 where d.event_id is null
                                                                     and not exists (select 1 from public.conventus_rating_dimensions x
                                                                                         where x.event_id = p_event_id and x.code = d.code);
                                                                                           get diagnostics n = row_count;
                                                                                             return n;
                                                                                             end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_create_managed_event(p_community_id uuid, p_code text, p_title text, p_start_date date, p_end_date date, p_location text, p_host_org text, p_description text, p_registration_open boolean, p_invite_only boolean)
 RETURNS conventus_managed_events
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_act uuid; v_row conventus_managed_events;
begin
  if p_title is null or length(btrim(p_title)) = 0 then
    raise exception 'title required';
  end if;
  if p_community_id is null or not conventity_can_manage_community(p_community_id) then
    raise exception 'not authorized to create events for this community';
  end if;

  -- source 'internal' (canlıda geçerli: internal/external; 'conventus' CHECK'te YOK)
  -- idempotent: source_ref ile mevcut activity'yi tekrar kullan
  select id into v_act from conventity_activities
    where source_ref = 'conventus_event_code:'||p_code limit 1;
  if v_act is null then
    begin
      insert into conventity_activities (title, activity_type, source, origin_ref, source_ref)
      values (p_title, 'event', 'internal', 'conventus', 'conventus_event_code:'||p_code)
      returning id into v_act;
    exception when check_violation then
      insert into conventity_activities (title, activity_type, source, origin_ref, source_ref)
      values (p_title, 'challenge', 'internal', 'conventus', 'conventus_event_code:'||p_code)
      returning id into v_act;
    end;
  end if;

  insert into conventus_managed_events (
    code, title, start_date, end_date, location, host_org, description,
    registration_open, invite_only, community_id, activity_id, created_by)
  values (
    p_code, p_title, p_start_date, p_end_date, p_location, p_host_org, p_description,
    coalesce(p_registration_open, true), coalesce(p_invite_only, false),
    p_community_id, v_act, auth.uid())
  returning * into v_row;

  return v_row;
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_log_registration_event()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                  begin
                                                    if tg_op = 'INSERT' then
                                                        insert into conventus_registration_events(event_id, registrant_uid, to_status, actor_user_id)
                                                            values (new.event_id, new.user_id, coalesce(new.status,'submitted'), auth.uid());
                                                                return new;
                                                                  elsif tg_op = 'UPDATE' then
                                                                      if new.status is distinct from old.status then
                                                                            insert into conventus_registration_events(event_id, registrant_uid, from_status, to_status, actor_user_id)
                                                                                  values (new.event_id, new.user_id, old.status, new.status, auth.uid());
                                                                                      end if;
                                                                                          return new;
                                                                                            end if;
                                                                                              return null;
                                                                                              end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_log_role_event()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              begin
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                if tg_op = 'INSERT' then
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          to_value,actor_user_id,note)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              values (new.id,new.auth_user_id,new.scope,new.scope_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          case when new.note like 'inherited%' then 'inherited' else 'granted' end,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      new.role,auth.uid(),new.note);
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          return new;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            elsif tg_op = 'UPDATE' then
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                if new.role is distinct from old.role then
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              from_value,to_value,actor_user_id)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    values (new.id,new.auth_user_id,new.scope,new.scope_id,'role_changed',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  old.role,new.role,auth.uid());
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      end if;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          if new.status is distinct from old.status then
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        from_value,to_value,actor_user_id)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              values (new.id,new.auth_user_id,new.scope,new.scope_id,'status_changed',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            old.status,new.status,auth.uid());
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                end if;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    return new;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      elsif tg_op = 'DELETE' then
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          insert into conventus_role_events(role_id,auth_user_id,scope,scope_id,action,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                from_value,actor_user_id)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    values (old.id,old.auth_user_id,old.scope,old.scope_id,'revoked',old.role,auth.uid());
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        return old;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          end if;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            return null;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_membership_cascade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                  declare p_id uuid;
                                                                                                                                                                                                  begin
                                                                                                                                                                                                    if new.scope <> 'community' then return new; end if;         -- KORUMA
                                                                                                                                                                                                      select parent_id into p_id from conventus_communities where id = new.scope_id;
                                                                                                                                                                                                        if p_id is not null then
                                                                                                                                                                                                            insert into conventity_roles (person_id, auth_user_id, scope, scope_id, role,
                                                                                                                                                                                                                                              status, granted_by, granted_via, note)
                                                                                                                                                                                                                                                  values (new.person_id, new.auth_user_id, 'community', p_id, 'member',
                                                                                                                                                                                                                                                              new.status, new.granted_by, new.id, 'inherited from sub-community')
                                                                                                                                                                                                                                                                  on conflict do nothing;
                                                                                                                                                                                                                                                                    end if;
                                                                                                                                                                                                                                                                      return new;
                                                                                                                                                                                                                                                                      end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_membership_revoke_cascade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                                                                                                                                                                                                                                                                        begin
                                                                                                                                                                                                                                                                          if old.scope <> 'community' then return old; end if;          -- KORUMA
                                                                                                                                                                                                                                                                            delete from conventity_roles r
                                                                                                                                                                                                                                                                               where r.scope = 'community'
                                                                                                                                                                                                                                                                                    and r.auth_user_id = old.auth_user_id
                                                                                                                                                                                                                                                                                         and r.scope_id in (select id from conventus_communities where parent_id = old.scope_id);
                                                                                                                                                                                                                                                                                           return old;
                                                                                                                                                                                                                                                                                           end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_obs_block_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  raise exception 'conventus_exercise_observations append-only — gözlem değiştirilemez. Düzeltme için yeni gözlem ekleyin.';
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_provider_role_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- (A) Akreditasyon KAZANILDI (INSERT accredited=true, ya da false/null -> true)
  if new.accredited is true
     and (tg_op = 'INSERT' or old.accredited is distinct from true)
     and new.owner_user_id is not null then
    -- varsa (revoked dahil) yeniden aktifleştir; yoksa ekle (NOT EXISTS yerine
    -- UPDATE + if not found — scope_id NULL olduğu için unique index dedupe etmez).
    update conventity_roles
       set status = 'active'
     where auth_user_id = new.owner_user_id
       and scope = 'conventus' and scope_id is null and role = 'vendor';
    if not found then
      insert into conventity_roles
        (auth_user_id, scope, scope_id, role, status, granted_via, note)
      values
        (new.owner_user_id, 'conventus', null, 'vendor', 'active', new.id,
         'auto: accredited Go&Meet provider');
    end if;

  -- (B) Akreditasyon GERİ ALINDI (true -> false/null): yalnız OTOMATİK rolü revoke et
  elsif tg_op = 'UPDATE'
     and old.accredited is true and new.accredited is not true
     and new.owner_user_id is not null then
    update conventity_roles
       set status = 'revoked'
     where auth_user_id = new.owner_user_id
       and scope = 'conventus' and scope_id is null and role = 'vendor'
       and note like 'auto:%';   -- elle verilmiş vendor rolüne dokunma
  end if;

  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_rating_block_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
                                                                                                                     begin
                                                                                                                       raise exception 'conventus_exercise_ratings append-only — değerlendirme değiştirilemez. Yeni değerlendirme ekleyin, en güncel olan geçerlidir.';
                                                                                                                       end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_rating_value(p text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
                                                                                                                             select case p when 'excelled' then 3 when 'met' then 2 when 'partial' then 1
                                                                                                                                             when 'did_not_meet' then 0 else null end;
                                                                                                                                             $function$
;
CREATE OR REPLACE FUNCTION public.conventus_rec_require_basis()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.status = 'issued' then
    if new.level in ('validated','capability_proven')
       and coalesce(array_length(new.basis_observations,1),0) = 0 then
      raise exception 'Dayanaksız tanıma belgesi düzenlenemez: % seviyesi en az bir gözlem kaydı gerektirir.', new.level;
    end if;
    if new.issued_at is null then new.issued_at := now(); end if;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_sel_apply_verification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.field_key = 'validation_tier' then
    update public.conventus_selection_applications
      set validation_tier_verified = new.verified_value,
          verified_by = new.verifier_id, verified_at = new.created_at,
          verification_note = new.note
    where id = new.application_id;
  elsif new.field_key = 'trl_demo' then
    update public.conventus_selection_applications
      set trl_verified = nullif(new.verified_value,'')::int,
          verified_by = new.verifier_id, verified_at = new.created_at
    where id = new.application_id;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_sel_block_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  raise exception 'conventus_selection_assessments append-only — güncelleme/silme yasak. Yeni değerlendirme satırı ekleyin.';
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_sel_block_verif_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  raise exception 'conventus_selection_verifications append-only — teyit kaydı değiştirilemez/silinemez. Yeni kayıt ekleyin.';
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_sel_clone_default_form(p_event_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  insert into public.conventus_selection_form_fields
    (event_id, field_key, section, label_en, label_tr, help_en, help_tr,
     input_type, options, is_core, is_required, is_scored, score_weight, sort_order, active)
  select p_event_id, f.field_key, f.section, f.label_en, f.label_tr, f.help_en, f.help_tr,
         f.input_type, f.options, f.is_core, f.is_required, f.is_scored, f.score_weight, f.sort_order, f.active
  from public.conventus_selection_form_fields f
  where f.event_id is null
  on conflict do nothing;
  get diagnostics n = row_count;
  return n;
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_sel_is_organizer(p_event_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.conventus_selection_events e
    where e.id = p_event_id
      and (e.organizer_id = auth.uid()
           or (e.organizer_id is null and auth.uid() is not null))  -- INTERIM: seed kayıtlar
  );
$function$
;
CREATE OR REPLACE FUNCTION public.conventus_sel_log_transition()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if (tg_op = 'UPDATE' and new.state is distinct from old.state) then
    insert into public.conventus_selection_transitions(application_id, from_state, to_state, actor_id)
    values (new.id, old.state, new.state, auth.uid());
  elsif (tg_op = 'INSERT') then
    insert into public.conventus_selection_transitions(application_id, from_state, to_state, actor_id)
    values (new.id, null, new.state, auth.uid());
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_sel_protect_core_field()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if (tg_op = 'DELETE') then
    if old.is_core then
      raise exception 'Çekirdek alan silinemez: % — motorun girdisidir. Gizlemek yerine etiketini düzenleyin.', old.field_key;
    end if;
    return old;
  end if;

  if old.is_core then
    -- İZİN VERİLENLER: label_*, help_*, sort_order, options (genişletme),
    --                  score_weight VE is_required (artık serbest)
    if new.active = false then
      raise exception 'Çekirdek alan pasife alınamaz: %', old.field_key;
    end if;
    if new.field_key <> old.field_key then
      raise exception 'Çekirdek alanın anahtarı değiştirilemez: %', old.field_key;
    end if;
    if new.input_type <> old.input_type then
      raise exception 'Çekirdek alanın girdi tipi değiştirilemez: %', old.field_key;
    end if;
    if new.is_core = false then
      raise exception 'Çekirdek bayrağı kaldırılamaz: %', old.field_key;
    end if;
    -- is_required kontrolü KALDIRILDI — organizatör açıp kapatabilir.
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_set_event_logistics(p_activity_id uuid, p_logistics jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not conventity_can_manage_event(p_activity_id) then raise exception 'not authorized to manage this event'; end if;
    update conventus_managed_events set logistics = coalesce(p_logistics,'{}'::jsonb) where activity_id = p_activity_id;
    end $function$
;
CREATE OR REPLACE FUNCTION public.conventus_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin new.updated_at = now(); return new; end $function$
;
CREATE OR REPLACE FUNCTION public.convexus_country_code(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case lower(btrim(coalesce(p_name,'')))
    when 'albania' then 'AL'        when 'belgium' then 'BE'
    when 'bulgaria' then 'BG'       when 'canada' then 'CA'
    when 'croatia' then 'HR'        when 'czechia' then 'CZ'
    when 'czech republic' then 'CZ' when 'denmark' then 'DK'
    when 'estonia' then 'EE'        when 'finland' then 'FI'
    when 'france' then 'FR'         when 'germany' then 'DE'
    when 'greece' then 'GR'         when 'hungary' then 'HU'
    when 'iceland' then 'IS'        when 'italy' then 'IT'
    when 'latvia' then 'LV'         when 'lithuania' then 'LT'
    when 'luxembourg' then 'LU'     when 'montenegro' then 'ME'
    when 'netherlands' then 'NL'    when 'the netherlands' then 'NL'
    when 'north macedonia' then 'MK' when 'norway' then 'NO'
    when 'poland' then 'PL'         when 'portugal' then 'PT'
    when 'romania' then 'RO'        when 'slovakia' then 'SK'
    when 'slovenia' then 'SI'       when 'spain' then 'ES'
    when 'sweden' then 'SE'         when 'turkey' then 'TR'
    when 'türkiye' then 'TR'        when 'turkiye' then 'TR'
    when 'united kingdom' then 'GB' when 'uk' then 'GB'
    when 'united states' then 'US'  when 'usa' then 'US'
    when 'united states of america' then 'US'
    when 'ukraine' then 'UA'        when 'switzerland' then 'CH'
    when 'austria' then 'AT'        when 'ireland' then 'IE'
    when 'australia' then 'AU'      when 'japan' then 'JP'
    when 'new zealand' then 'NZ'    when 'south korea' then 'KR'
    when 'korea' then 'KR'          when 'republic of korea' then 'KR'
    else null end;
$function$
;
CREATE OR REPLACE FUNCTION public.convexus_engagement_log_submit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.convexus_engagement_events
    (request_id, from_status, to_status, action, actor_id, note)
  VALUES
    (NEW.id, NULL, NEW.status, 'submitted', auth.uid(), 'auto: front-door submission');
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.convexus_engagement_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.convexus_import_pool_to_event(p_event_code text DEFAULT 'CVX-DEMO-POOL'::text, p_limit integer DEFAULT 25)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_event uuid;
  n int;
begin
  select id into v_event from public.conventus_selection_events
   where event_code = p_event_code;
  if v_event is null then
    raise exception 'Etkinlik bulunamadı: %', p_event_code;
  end if;

  insert into public.conventus_selection_applications (
    event_id, submitted_by, convexus_profile_id,
    company_name, country, registration_country,
    summary, website, contact_email,
    trl_demo, trl_verified,
    artifact_class,          -- havuzda YOK → unknown (gate'te elenir, doğru davranış)
    validation_tier,         -- havuzda YOK → none
    domain_axis,
    raw_intake, state, source_ref
  )
  select
    v_event, null, p.id,
    p.org_name,
    p.org_country,
    public.convexus_country_code(p.org_country),
    p.summary, p.website, p.contact_email,
    nullif(p.trl,0), p.trl_verified,
    'unknown',
    'none',
    'ground',
    jsonb_strip_nulls(jsonb_build_object(
      'source',        'convexus_pool',
      'use_profile',   p.use_profile,
      'cost_class',    p.cost_class,
      'membership_tier', p.membership_tier,
      'ally_engaged',  p.ally_engaged,
      'visibility',    p.visibility,
      'pool_status',   p.status,
      'org_id',        p.org_id
    )),
    'submitted',
    'CVX-POOL-' || p.id::text
  from public.convexus_profiles p
  where p.status = 'active'
    and coalesce(p.org_name,'') <> ''
    and not exists (
      select 1 from public.conventus_selection_applications a
       where a.source_ref = 'CVX-POOL-' || p.id::text
         and a.event_id = v_event)
  order by p.org_name
  limit coalesce(p_limit, 1000000);

  get diagnostics n = row_count;
  return n;
end $function$
;
CREATE OR REPLACE FUNCTION public.cv_event_access(eid bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    exists (select 1
              from public.conventus_invitations i
              join auth.users u on u.id = auth.uid()
             where i.event_id = eid
               and ( lower(i.pattern) = lower(u.email)
                  or (i.pattern like '@%' and lower(u.email) like '%' || lower(i.pattern)) ))
    or exists (select 1 from public.conventus_registrations r
                where r.event_id = eid and r.user_id = auth.uid())
$function$
;
CREATE OR REPLACE FUNCTION public.gm_plan_protect()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if auth.uid() is not null then
    if new.user_id      is distinct from old.user_id
    or new.event_id     is distinct from old.event_id
    or new.category     is distinct from old.category
    or new.inventory_id is distinct from old.inventory_id
    or new.offer_id     is distinct from old.offer_id then
      raise exception 'Plan core fields are immutable';
    end if;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.gm_provider_accredited(pid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select coalesce((select accredited from public.gm_providers where id = pid), false) $function$
;
CREATE OR REPLACE FUNCTION public.gm_providers_protect()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if auth.uid() is not null then
    if new.accredited      is distinct from old.accredited
    or new.commission_rate is distinct from old.commission_rate
    or new.contract_fee    is distinct from old.contract_fee
    or new.contract_date   is distinct from old.contract_date
    or new.contract_note   is distinct from old.contract_note
    or new.owner_user_id   is distinct from old.owner_user_id then
      raise exception 'Protected provider fields can only be changed by Conventity admin';
    end if;
  end if;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.is_convexus_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
      select exists (
          select 1 from public.conventity_roles r
              where r.auth_user_id = auth.uid()
                    and r.role = 'admin'
                          and r.scope in ('ecosystem','convexus')
                            );
                            $function$
;
CREATE OR REPLACE FUNCTION public.is_cv_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
                              select exists (
                                  select 1 from public.conventity_roles r
                                      where r.auth_user_id = auth.uid()
                                            and r.role = 'admin'
                                                  and r.scope = 'ecosystem'
                                                    );
                                                    $function$
;

-- ===================== 6 · VIEWLAR =====================
create or replace view public.conventus_exercise_daily_rollup as
 SELECT o.event_id,
    o.obs_date,
    a.company_name,
    n.code AS challenge_area,
    count(*) FILTER (WHERE o.kind = 'achievement'::text) AS basarilar,
    count(*) FILTER (WHERE o.kind = 'hurdle_jumped'::text) AS asilan_engeller,
    count(*) FILTER (WHERE o.kind = 'hurdle_hit'::text) AS karsilasilan_engeller,
    count(*) FILTER (WHERE o.kind = 'hurdle_hit'::text AND o.impact = 'blocking'::text) AS durduran_engeller,
    count(*) AS toplam_gozlem
   FROM conventus_exercise_observations o
     LEFT JOIN conventus_selection_applications a ON a.id = o.application_id
     LEFT JOIN conventus_selection_needs n ON n.id = o.need_id
  GROUP BY o.event_id, o.obs_date, a.company_name, n.code
  ORDER BY o.obs_date DESC, (count(*) FILTER (WHERE o.kind = 'hurdle_hit'::text)) DESC;
create or replace view public.conventus_exercise_rating_latest as
 SELECT DISTINCT ON (application_id, need_id, dimension_code) id,
    event_id,
    application_id,
    need_id,
    dimension_code,
    rating,
    note,
    rater_id,
    created_at
   FROM conventus_exercise_ratings
  ORDER BY application_id, need_id, dimension_code, created_at DESC;
create or replace view public.conventus_exercise_rating_summary as
 SELECT r.event_id,
    r.application_id,
    a.company_name,
    r.need_id,
    n.code AS challenge_area,
    count(*) FILTER (WHERE r.rating <> 'not_assessed'::text) AS degerlendirilen_boyut,
    round(avg(conventus_rating_value(r.rating)), 2) AS ortalama,
    count(*) FILTER (WHERE r.rating = 'excelled'::text) AS ustun,
    count(*) FILTER (WHERE r.rating = 'met'::text) AS karsilayan,
    count(*) FILTER (WHERE r.rating = 'partial'::text) AS kismen,
    count(*) FILTER (WHERE r.rating = 'did_not_meet'::text) AS karsilamayan,
        CASE
            WHEN count(*) FILTER (WHERE r.rating <> 'not_assessed'::text) = 0 THEN 'not_assessed'::text
            WHEN avg(conventus_rating_value(r.rating)) >= 2.5 THEN 'excelled'::text
            WHEN avg(conventus_rating_value(r.rating)) >= 1.5 THEN 'met'::text
            WHEN avg(conventus_rating_value(r.rating)) >= 0.5 THEN 'partial'::text
            ELSE 'did_not_meet'::text
        END AS sonuc
   FROM conventus_exercise_rating_latest r
     JOIN conventus_selection_applications a ON a.id = r.application_id
     LEFT JOIN conventus_selection_needs n ON n.id = r.need_id
  GROUP BY r.event_id, r.application_id, a.company_name, r.need_id, n.code;
create or replace view public.conventus_recognition_basis as
 SELECT a.id AS application_id,
    a.event_id,
    a.company_name,
    a.state,
    a.validation_tier,
    a.validation_tier_verified,
    a.validation_tier_verified IS NOT NULL AS beyan_teyitli,
    count(DISTINCT o.id) AS gozlem_sayisi,
    count(DISTINCT o.id) FILTER (WHERE o.kind = 'achievement'::text) AS basari,
    count(DISTINCT o.id) FILTER (WHERE o.kind = 'hurdle_jumped'::text) AS asilan,
    count(DISTINCT o.id) FILTER (WHERE o.kind = 'hurdle_hit'::text) AS karsilasilan,
    count(DISTINCT o.need_id) AS kapsanan_alan,
    count(DISTINCT m.id) AS gorsel_kanit,
    ( SELECT round(avg(conventus_rating_value(rl.rating)), 2) AS round
           FROM conventus_exercise_rating_latest rl
          WHERE rl.application_id = a.id AND rl.rating <> 'not_assessed'::text) AS degerlendirme_ort,
    a.data_sharing_consent,
        CASE
            WHEN count(DISTINCT o.id) = 0 THEN 'participated'::text
            WHEN (( SELECT count(*) AS count
               FROM conventus_exercise_rating_latest rl
              WHERE rl.application_id = a.id AND rl.rating <> 'not_assessed'::text)) = 0 THEN 'demonstrated'::text
            WHEN a.validation_tier_verified IS NULL THEN 'demonstrated'::text
            WHEN (( SELECT avg(conventus_rating_value(rl.rating)) AS avg
               FROM conventus_exercise_rating_latest rl
              WHERE rl.application_id = a.id AND rl.rating <> 'not_assessed'::text)) >= 2.0 THEN 'capability_proven'::text
            ELSE 'validated'::text
        END AS onerilen_seviye
   FROM conventus_selection_applications a
     LEFT JOIN conventus_exercise_observations o ON o.application_id = a.id
     LEFT JOIN conventus_exercise_media m ON m.application_id = a.id
  GROUP BY a.id;
create or replace view public.conventus_selection_orion_export as
 WITH latest AS (
         SELECT DISTINCT ON (conventus_selection_assessments.application_id) conventus_selection_assessments.id,
            conventus_selection_assessments.run_id,
            conventus_selection_assessments.application_id,
            conventus_selection_assessments.source,
            conventus_selection_assessments.gate_passed,
            conventus_selection_assessments.gate_fails,
            conventus_selection_assessments.score_total,
            conventus_selection_assessments.score_breakdown,
            conventus_selection_assessments.matched_needs,
            conventus_selection_assessments.decision,
            conventus_selection_assessments.promoted,
            conventus_selection_assessments.promotion_reason,
            conventus_selection_assessments.badges,
            conventus_selection_assessments.rationale,
            conventus_selection_assessments.assessor_id,
            conventus_selection_assessments.created_at,
            conventus_selection_assessments.primary_capability_code,
            conventus_selection_assessments.primary_capability_name,
            conventus_selection_assessments.primary_confidence,
            conventus_selection_assessments.primary_signal,
            conventus_selection_assessments.alternative_capabilities,
            conventus_selection_assessments.fit_status
           FROM conventus_selection_assessments
          ORDER BY conventus_selection_assessments.application_id, conventus_selection_assessments.created_at DESC
        )
 SELECT a.id AS contribution_id,
    a.company_name AS organisation,
    COALESCE(a.registration_country, a.country) AS country,
    a.created_at AS submitted_at,
    a.contact_name,
    a.contact_role,
    a.system_name AS capability_name_claimed,
    ( SELECT string_agg(n.code, ', '::text) AS string_agg
           FROM conventus_selection_app_needs an
             JOIN conventus_selection_needs n ON n.id = an.need_id
          WHERE an.application_id = a.id) AS focus_area,
    a.trl_demo AS trl,
    a.summary AS description,
    a.use_case,
    a.validation_detail AS evidence,
    COALESCE(a.interoperability_note, array_to_string(a.integration_standards, ', '::text)) AS interoperability,
    a.diana_backed AS diana,
    a.nif_backed AS nif,
    a.isc_domain,
    a.isc_pilot_area,
    l.primary_capability_code,
    l.primary_capability_name,
    l.primary_confidence,
    l.primary_signal,
    l.decision AS fit_verdict,
    l.score_total AS fit_suitability,
    l.rationale AS fit_rationale,
    l.alternative_capabilities,
    ( SELECT r.engine_version
           FROM conventus_selection_runs r
          WHERE r.id = l.run_id) AS fit_model_id,
    l.fit_status,
    l.created_at AS fit_generated_at,
    a.state,
    a.event_id
   FROM conventus_selection_applications a
     LEFT JOIN latest l ON l.application_id = a.id;
create or replace view public.conventus_selection_production_stats as
 SELECT e.event_code,
    e.title,
    e.host_nation,
    e.status,
    count(a.id) AS basvuru_sayisi,
    count(*) FILTER (WHERE a.state = 'invited'::text) AS davet_edilen,
    count(*) FILTER (WHERE a.state = 'demonstrated'::text) AS gosterim_yapan
   FROM conventus_selection_events e
     LEFT JOIN conventus_selection_applications a ON a.event_id = e.id
  WHERE e.data_origin = 'production'::text
  GROUP BY e.id, e.event_code, e.title, e.host_nation, e.status;
create or replace view public.conventus_selection_verification_status as
 SELECT id AS application_id,
    event_id,
    company_name,
    validation_tier AS beyan,
    validation_tier_verified AS teyit,
    validation_tier_verified IS NOT NULL AS teyitli,
    validation_tier_verified IS DISTINCT FROM validation_tier AND validation_tier_verified IS NOT NULL AS duzeltildi,
    trl_demo,
    trl_verified,
    ( SELECT count(*) AS count
           FROM convexus_activity_records r
          WHERE r.application_id = a.id) AS faaliyet_kaydi,
    ( SELECT count(*) AS count
           FROM convexus_activity_records r
          WHERE r.application_id = a.id AND r.verified) AS teyitli_faaliyet
   FROM conventus_selection_applications a;
create or replace view public.convexus_activity_map as
 SELECT activity_code,
    activity_name,
    activity_type,
    organiser,
    organiser_tier,
    year,
    count(*) AS kayit_sayisi,
    count(*) FILTER (WHERE engagement_level = 'demonstrated'::text) AS gosterim_yapan,
    count(*) FILTER (WHERE engagement_level = 'participated'::text) AS sadece_katilan,
    count(*) FILTER (WHERE assessment_outcome = 'excelled'::text) AS ustun,
    count(*) FILTER (WHERE assessment_outcome = 'met'::text) AS karsilayan,
    count(*) FILTER (WHERE assessment_outcome = 'did_not_meet'::text) AS karsilamayan,
    count(*) FILTER (WHERE assessment_outcome = ANY (ARRAY['not_assessed'::text, 'unknown'::text])) AS degerlendirilmemis,
    count(*) FILTER (WHERE verified) AS teyit_edilmis
   FROM convexus_activity_records r
  GROUP BY activity_code, activity_name, activity_type, organiser, organiser_tier, year
  ORDER BY year DESC NULLS LAST, (count(*)) DESC;
create or replace view public.convexus_demand_signals_public as
 SELECT id,
    code,
    title,
    summary,
    focus_area,
    status,
    created_at,
    updated_at
   FROM convexus_demand_signals
  WHERE status = 'active'::text;
create or replace view public.gm_providers_public as
 SELECT id,
    name,
    type,
    type_other,
    city,
    country,
    website
   FROM gm_providers
  WHERE accredited = true;

-- ===================== 7 · TRIGGERLAR =====================
drop trigger if exists trg_audit_conventity_evidence on public.conventity_evidence;
CREATE TRIGGER trg_audit_conventity_evidence AFTER INSERT OR DELETE OR UPDATE ON public.conventity_evidence FOR EACH ROW EXECUTE FUNCTION conventity_audit_trg();
drop trigger if exists trg_audit_conventity_matches on public.conventity_matches;
CREATE TRIGGER trg_audit_conventity_matches AFTER INSERT OR DELETE OR UPDATE ON public.conventity_matches FOR EACH ROW EXECUTE FUNCTION conventity_audit_trg();
drop trigger if exists trg_audit_conventity_orgs on public.conventity_orgs;
CREATE TRIGGER trg_audit_conventity_orgs AFTER INSERT OR DELETE OR UPDATE ON public.conventity_orgs FOR EACH ROW EXECUTE FUNCTION conventity_audit_trg();
drop trigger if exists trg_audit_conventity_roles on public.conventity_roles;
CREATE TRIGGER trg_audit_conventity_roles AFTER INSERT OR DELETE OR UPDATE ON public.conventity_roles FOR EACH ROW EXECUTE FUNCTION conventity_audit_trg();
drop trigger if exists trg_membership_cascade on public.conventity_roles;
CREATE TRIGGER trg_membership_cascade AFTER INSERT ON public.conventity_roles FOR EACH ROW EXECUTE FUNCTION conventus_membership_cascade();
drop trigger if exists trg_membership_revoke on public.conventity_roles;
CREATE TRIGGER trg_membership_revoke AFTER DELETE ON public.conventity_roles FOR EACH ROW EXECUTE FUNCTION conventus_membership_revoke_cascade();
drop trigger if exists trg_role_audit on public.conventity_roles;
CREATE TRIGGER trg_role_audit AFTER INSERT OR DELETE OR UPDATE ON public.conventity_roles FOR EACH ROW EXECUTE FUNCTION conventus_log_role_event();
drop trigger if exists trg_audit_conventity_solutions on public.conventity_solutions;
CREATE TRIGGER trg_audit_conventity_solutions AFTER INSERT OR DELETE OR UPDATE ON public.conventity_solutions FOR EACH ROW EXECUTE FUNCTION conventity_audit_trg();
drop trigger if exists conventus_ann_touch on public.conventus_announcements;
CREATE TRIGGER conventus_ann_touch BEFORE UPDATE ON public.conventus_announcements FOR EACH ROW EXECUTE FUNCTION conventus_touch_updated_at();
drop trigger if exists trg_cc_depth on public.conventus_communities;
CREATE TRIGGER trg_cc_depth BEFORE INSERT OR UPDATE ON public.conventus_communities FOR EACH ROW EXECUTE FUNCTION conventus_cc_depth_guard();
drop trigger if exists trg_ceo_append_only on public.conventus_exercise_observations;
CREATE TRIGGER trg_ceo_append_only BEFORE DELETE OR UPDATE ON public.conventus_exercise_observations FOR EACH ROW EXECUTE FUNCTION conventus_obs_block_mutation();
drop trigger if exists trg_cer_append_only on public.conventus_exercise_ratings;
CREATE TRIGGER trg_cer_append_only BEFORE DELETE OR UPDATE ON public.conventus_exercise_ratings FOR EACH ROW EXECUTE FUNCTION conventus_rating_block_mutation();
drop trigger if exists trg_crr_basis on public.conventus_recognition_records;
CREATE TRIGGER trg_crr_basis BEFORE INSERT OR UPDATE ON public.conventus_recognition_records FOR EACH ROW EXECUTE FUNCTION conventus_rec_require_basis();
drop trigger if exists trg_registration_audit on public.conventus_registrations;
CREATE TRIGGER trg_registration_audit AFTER INSERT OR UPDATE ON public.conventus_registrations FOR EACH ROW EXECUTE FUNCTION conventus_log_registration_event();
drop trigger if exists trg_cst_log on public.conventus_selection_applications;
CREATE TRIGGER trg_cst_log AFTER INSERT OR UPDATE ON public.conventus_selection_applications FOR EACH ROW EXECUTE FUNCTION conventus_sel_log_transition();
drop trigger if exists trg_csas_append_only on public.conventus_selection_assessments;
CREATE TRIGGER trg_csas_append_only BEFORE DELETE OR UPDATE ON public.conventus_selection_assessments FOR EACH ROW EXECUTE FUNCTION conventus_sel_block_mutation();
drop trigger if exists trg_csff_protect on public.conventus_selection_form_fields;
CREATE TRIGGER trg_csff_protect BEFORE DELETE OR UPDATE ON public.conventus_selection_form_fields FOR EACH ROW EXECUTE FUNCTION conventus_sel_protect_core_field();
drop trigger if exists trg_csv_append_only on public.conventus_selection_verifications;
CREATE TRIGGER trg_csv_append_only BEFORE DELETE OR UPDATE ON public.conventus_selection_verifications FOR EACH ROW EXECUTE FUNCTION conventus_sel_block_verif_mutation();
drop trigger if exists trg_csv_apply on public.conventus_selection_verifications;
CREATE TRIGGER trg_csv_apply AFTER INSERT ON public.conventus_selection_verifications FOR EACH ROW EXECUTE FUNCTION conventus_sel_apply_verification();
drop trigger if exists conventus_sessions_touch on public.conventus_sessions;
CREATE TRIGGER conventus_sessions_touch BEFORE UPDATE ON public.conventus_sessions FOR EACH ROW EXECUTE FUNCTION conventus_touch_updated_at();
drop trigger if exists trg_convexus_demand_touch on public.convexus_demand_signals;
CREATE TRIGGER trg_convexus_demand_touch BEFORE UPDATE ON public.convexus_demand_signals FOR EACH ROW EXECUTE FUNCTION convexus_engagement_touch_updated_at();
drop trigger if exists trg_convexus_engagement_submit on public.convexus_engagement_requests;
CREATE TRIGGER trg_convexus_engagement_submit AFTER INSERT ON public.convexus_engagement_requests FOR EACH ROW EXECUTE FUNCTION convexus_engagement_log_submit();
drop trigger if exists trg_convexus_engagement_touch on public.convexus_engagement_requests;
CREATE TRIGGER trg_convexus_engagement_touch BEFORE UPDATE ON public.convexus_engagement_requests FOR EACH ROW EXECUTE FUNCTION convexus_engagement_touch_updated_at();
drop trigger if exists gm_inv_touch on public.gm_inventory;
CREATE TRIGGER gm_inv_touch BEFORE UPDATE ON public.gm_inventory FOR EACH ROW EXECUTE FUNCTION conventus_touch_updated_at();
drop trigger if exists gm_offers_touch on public.gm_offers;
CREATE TRIGGER gm_offers_touch BEFORE UPDATE ON public.gm_offers FOR EACH ROW EXECUTE FUNCTION conventus_touch_updated_at();
drop trigger if exists gm_plan_protect_tg on public.gm_plan;
CREATE TRIGGER gm_plan_protect_tg BEFORE UPDATE ON public.gm_plan FOR EACH ROW EXECUTE FUNCTION gm_plan_protect();
drop trigger if exists gm_plan_touch on public.gm_plan;
CREATE TRIGGER gm_plan_touch BEFORE UPDATE ON public.gm_plan FOR EACH ROW EXECUTE FUNCTION conventus_touch_updated_at();
drop trigger if exists gm_ratings_touch on public.gm_provider_ratings;
CREATE TRIGGER gm_ratings_touch BEFORE UPDATE ON public.gm_provider_ratings FOR EACH ROW EXECUTE FUNCTION conventus_touch_updated_at();
drop trigger if exists gm_providers_protect_tg on public.gm_providers;
CREATE TRIGGER gm_providers_protect_tg BEFORE UPDATE ON public.gm_providers FOR EACH ROW EXECUTE FUNCTION gm_providers_protect();
drop trigger if exists trg_provider_role_sync on public.gm_providers;
CREATE TRIGGER trg_provider_role_sync AFTER INSERT OR UPDATE OF accredited ON public.gm_providers FOR EACH ROW EXECUTE FUNCTION conventus_provider_role_sync();

-- ===================== 8 · RLS =====================
-- .org'da public şemasındaki HER tabloda RLS açık. Tek tek yazmak yerine
-- döngü: yeni tablo eklendiğinde de atlanmaz.
do $cvblock$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', r.tablename);
  end loop;
end $cvblock$;

-- ===================== 9 · POLITIKALAR =====================
drop policy if exists conv_act_admin on public.conventity_activities;
create policy conv_act_admin on public.conventity_activities as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_act_read on public.conventity_activities;
create policy conv_act_read on public.conventity_activities as permissive for select to public using (true);
drop policy if exists conv_audit_select on public.conventity_audit;
create policy conv_audit_select on public.conventity_audit as permissive for select to public using (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_cap_admin on public.conventity_capabilities;
create policy conv_cap_admin on public.conventity_capabilities as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_cap_read on public.conventity_capabilities;
create policy conv_cap_read on public.conventity_capabilities as permissive for select to public using (true);
drop policy if exists conv_caps_read on public.conventity_capabilities;
create policy conv_caps_read on public.conventity_capabilities as permissive for select to public using (true);
drop policy if exists conv_caps_write on public.conventity_capabilities;
create policy conv_caps_write on public.conventity_capabilities as permissive for all to authenticated using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists cn_conn_read on public.conventity_cn_connections;
create policy cn_conn_read on public.conventity_cn_connections as permissive for select to public using ((conventity_is_admin('ecosystem'::text) OR (requester_id = conventity_cn_my_person_id()) OR (addressee_id = conventity_cn_my_person_id())));
drop policy if exists cn_exp_delete on public.conventity_cn_expertise;
create policy cn_exp_delete on public.conventity_cn_expertise as permissive for delete to public using ((conventity_is_admin('ecosystem'::text) OR (person_id = conventity_cn_my_person_id())));
drop policy if exists cn_exp_insert on public.conventity_cn_expertise;
create policy cn_exp_insert on public.conventity_cn_expertise as permissive for insert to public with check ((conventity_is_admin('ecosystem'::text) OR (person_id = conventity_cn_my_person_id())));
drop policy if exists cn_exp_read on public.conventity_cn_expertise;
create policy cn_exp_read on public.conventity_cn_expertise as permissive for select to public using ((auth.uid() IS NOT NULL));
drop policy if exists cn_exp_update on public.conventity_cn_expertise;
create policy cn_exp_update on public.conventity_cn_expertise as permissive for update to public using ((conventity_is_admin('ecosystem'::text) OR (person_id = conventity_cn_my_person_id())));
drop policy if exists cn_groups_delete on public.conventity_cn_groups;
create policy cn_groups_delete on public.conventity_cn_groups as permissive for delete to public using ((conventity_is_admin('ecosystem'::text) OR (created_by = conventity_cn_my_person_id())));
drop policy if exists cn_groups_insert on public.conventity_cn_groups;
create policy cn_groups_insert on public.conventity_cn_groups as permissive for insert to public with check (((conventity_cn_my_person_id() IS NOT NULL) AND (created_by = conventity_cn_my_person_id())));
drop policy if exists cn_groups_read on public.conventity_cn_groups;
create policy cn_groups_read on public.conventity_cn_groups as permissive for select to public using (((visibility = 'ecosystem'::text) OR conventity_is_admin('ecosystem'::text) OR conventity_cn_is_group_member(id)));
drop policy if exists cn_groups_update on public.conventity_cn_groups;
create policy cn_groups_update on public.conventity_cn_groups as permissive for update to public using ((conventity_is_admin('ecosystem'::text) OR (created_by = conventity_cn_my_person_id())));
drop policy if exists cn_memb_delete on public.conventity_cn_memberships;
create policy cn_memb_delete on public.conventity_cn_memberships as permissive for delete to public using ((conventity_is_admin('ecosystem'::text) OR (person_id = conventity_cn_my_person_id()) OR (EXISTS ( SELECT 1
   FROM conventity_cn_memberships mod
  WHERE ((mod.group_id = conventity_cn_memberships.group_id) AND (mod.person_id = conventity_cn_my_person_id()) AND (mod.role = 'moderator'::text))))));
drop policy if exists cn_memb_insert on public.conventity_cn_memberships;
create policy cn_memb_insert on public.conventity_cn_memberships as permissive for insert to public with check ((conventity_is_admin('ecosystem'::text) OR (person_id = conventity_cn_my_person_id()) OR (EXISTS ( SELECT 1
   FROM conventity_cn_memberships mod
  WHERE ((mod.group_id = conventity_cn_memberships.group_id) AND (mod.person_id = conventity_cn_my_person_id()) AND (mod.role = 'moderator'::text))))));
drop policy if exists cn_memb_read on public.conventity_cn_memberships;
create policy cn_memb_read on public.conventity_cn_memberships as permissive for select to public using ((conventity_is_admin('ecosystem'::text) OR (person_id = conventity_cn_my_person_id()) OR conventity_cn_is_group_member(group_id)));
drop policy if exists cn_msg_read on public.conventity_cn_messages;
create policy cn_msg_read on public.conventity_cn_messages as permissive for select to public using ((conventity_is_admin('ecosystem'::text) OR (sender_id = conventity_cn_my_person_id()) OR (recipient_id = conventity_cn_my_person_id())));
drop policy if exists cn_comment_read on public.conventity_cn_post_comments;
create policy cn_comment_read on public.conventity_cn_post_comments as permissive for select to public using ((conventity_is_admin('ecosystem'::text) OR (EXISTS ( SELECT 1
   FROM (conventity_cn_posts po
     JOIN conventity_cn_memberships m ON ((m.group_id = po.group_id)))
  WHERE ((po.id = conventity_cn_post_comments.post_id) AND (m.person_id = conventity_cn_my_person_id()))))));
drop policy if exists cn_react_read on public.conventity_cn_post_reactions;
create policy cn_react_read on public.conventity_cn_post_reactions as permissive for select to public using ((conventity_is_admin('ecosystem'::text) OR (EXISTS ( SELECT 1
   FROM (conventity_cn_posts po
     JOIN conventity_cn_memberships m ON ((m.group_id = po.group_id)))
  WHERE ((po.id = conventity_cn_post_reactions.post_id) AND (m.person_id = conventity_cn_my_person_id()))))));
drop policy if exists cn_posts_delete on public.conventity_cn_posts;
create policy cn_posts_delete on public.conventity_cn_posts as permissive for delete to public using ((conventity_is_admin('ecosystem'::text) OR (author_id = conventity_cn_my_person_id())));
drop policy if exists cn_posts_insert on public.conventity_cn_posts;
create policy cn_posts_insert on public.conventity_cn_posts as permissive for insert to public with check (((author_id = conventity_cn_my_person_id()) AND conventity_cn_is_group_member(group_id)));
drop policy if exists cn_posts_read on public.conventity_cn_posts;
create policy cn_posts_read on public.conventity_cn_posts as permissive for select to public using ((conventity_is_admin('ecosystem'::text) OR conventity_cn_is_group_member(group_id)));
drop policy if exists conv_ev_insert on public.conventity_evidence;
create policy conv_ev_insert on public.conventity_evidence as permissive for insert to public with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_ev_read on public.conventity_evidence;
create policy conv_ev_read on public.conventity_evidence as permissive for select to public using (true);
drop policy if exists conventity_matches_read on public.conventity_matches;
create policy conventity_matches_read on public.conventity_matches as permissive for select to public using (conventity_is_admin('ecosystem'::text));
drop policy if exists conventity_matches_write on public.conventity_matches;
create policy conventity_matches_write on public.conventity_matches as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_orgs_admin on public.conventity_orgs;
create policy conv_orgs_admin on public.conventity_orgs as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_orgs_read on public.conventity_orgs;
create policy conv_orgs_read on public.conventity_orgs as permissive for select to public using (true);
drop policy if exists conv_part_admin on public.conventity_participation;
create policy conv_part_admin on public.conventity_participation as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_ppl_admin on public.conventity_people;
create policy conv_ppl_admin on public.conventity_people as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_ppl_self on public.conventity_people;
create policy conv_ppl_self on public.conventity_people as permissive for select to public using ((auth_user_id = auth.uid()));
drop policy if exists conv_pc_admin on public.conventity_problem_capability;
create policy conv_pc_admin on public.conventity_problem_capability as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_pc_read on public.conventity_problem_capability;
create policy conv_pc_read on public.conventity_problem_capability as permissive for select to public using (true);
drop policy if exists conv_ps_admin on public.conventity_problem_solution;
create policy conv_ps_admin on public.conventity_problem_solution as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_ps_read on public.conventity_problem_solution;
create policy conv_ps_read on public.conventity_problem_solution as permissive for select to public using (true);
drop policy if exists conv_prob_admin on public.conventity_problems;
create policy conv_prob_admin on public.conventity_problems as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_prob_read on public.conventity_problems;
create policy conv_prob_read on public.conventity_problems as permissive for select to public using (true);
drop policy if exists conv_rel_admin on public.conventity_relations;
create policy conv_rel_admin on public.conventity_relations as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_roles_admin on public.conventity_roles;
create policy conv_roles_admin on public.conventity_roles as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists roles_activity_delete on public.conventity_roles;
create policy roles_activity_delete on public.conventity_roles as permissive for delete to public using (((scope = 'activity'::text) AND ((auth_user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.activity_id = conventity_roles.scope_id) AND conventity_can_manage_community(e.community_id)))))));
drop policy if exists roles_activity_insert on public.conventity_roles;
create policy roles_activity_insert on public.conventity_roles as permissive for insert to public with check (((scope = 'activity'::text) AND (role = ANY (ARRAY['event_manager'::text, 'organizer'::text])) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.activity_id = conventity_roles.scope_id) AND conventity_can_manage_community(e.community_id) AND conventity_uid_in_community(conventity_roles.auth_user_id, e.community_id))))));
drop policy if exists roles_activity_select on public.conventity_roles;
create policy roles_activity_select on public.conventity_roles as permissive for select to public using (((scope = 'activity'::text) AND ((auth_user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.activity_id = conventity_roles.scope_id) AND conventity_can_manage_community(e.community_id)))))));
drop policy if exists roles_activity_update on public.conventity_roles;
create policy roles_activity_update on public.conventity_roles as permissive for update to public using (((scope = 'activity'::text) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.activity_id = conventity_roles.scope_id) AND conventity_can_manage_community(e.community_id))))));
drop policy if exists roles_community_delete on public.conventity_roles;
create policy roles_community_delete on public.conventity_roles as permissive for delete to public using (((scope = 'community'::text) AND ((auth_user_id = auth.uid()) OR conventity_can_manage_community(scope_id))));
drop policy if exists roles_community_insert on public.conventity_roles;
create policy roles_community_insert on public.conventity_roles as permissive for insert to public with check (((scope = 'community'::text) AND (conventity_can_manage_community(scope_id) OR ((auth_user_id = auth.uid()) AND (role = 'member'::text) AND (EXISTS ( SELECT 1
   FROM conventus_communities c
  WHERE ((c.id = conventity_roles.scope_id) AND (c.join_policy = ANY (ARRAY['open'::text, 'request'::text])))))))));
drop policy if exists roles_community_select on public.conventity_roles;
create policy roles_community_select on public.conventity_roles as permissive for select to public using (((scope = 'community'::text) AND ((auth_user_id = auth.uid()) OR conventity_can_manage_community(scope_id))));
drop policy if exists roles_community_update on public.conventity_roles;
create policy roles_community_update on public.conventity_roles as permissive for update to public using (((scope = 'community'::text) AND conventity_can_manage_community(scope_id))) with check (((scope = 'community'::text) AND conventity_can_manage_community(scope_id)));
drop policy if exists conv_signin_insert_self on public.conventity_signin_log;
create policy conv_signin_insert_self on public.conventity_signin_log as permissive for insert to public with check ((auth.uid() = auth_user_id));
drop policy if exists conv_signin_select on public.conventity_signin_log;
create policy conv_signin_select on public.conventity_signin_log as permissive for select to public using (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_sc_admin on public.conventity_solution_capability;
create policy conv_sc_admin on public.conventity_solution_capability as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_sc_read on public.conventity_solution_capability;
create policy conv_sc_read on public.conventity_solution_capability as permissive for select to public using (true);
drop policy if exists conv_sol_admin on public.conventity_solutions;
create policy conv_sol_admin on public.conventity_solutions as permissive for all to public using (conventity_is_admin('ecosystem'::text)) with check (conventity_is_admin('ecosystem'::text));
drop policy if exists conv_sol_read on public.conventity_solutions;
create policy conv_sol_read on public.conventity_solutions as permissive for select to public using (true);
drop policy if exists ann_audience_read on public.conventus_announcements;
create policy ann_audience_read on public.conventus_announcements as permissive for select to anon, authenticated using (((is_published = true) AND ((audience = 'all'::text) OR ((audience = 'approved'::text) AND (EXISTS ( SELECT 1
   FROM conventus_registrations r
  WHERE ((r.event_id = conventus_announcements.event_id) AND (r.user_id = auth.uid()) AND (r.status = ANY (ARRAY['approved'::text, 'checked_in'::text])))))) OR ((audience = 'pending'::text) AND (EXISTS ( SELECT 1
   FROM conventus_registrations r
  WHERE ((r.event_id = conventus_announcements.event_id) AND (r.user_id = auth.uid()))))) OR ((audience = 'community_members'::text) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND (e.community_id IS NOT NULL) AND conventity_in_community(e.community_id))))) OR ((audience = 'organizers'::text) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND conventity_can_manage_event(e.activity_id))))))));
drop policy if exists ann_manager_read on public.conventus_announcements;
create policy ann_manager_read on public.conventus_announcements as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND conventity_can_manage_event(e.activity_id)))));
drop policy if exists ann_owner_delete on public.conventus_announcements;
create policy ann_owner_delete on public.conventus_announcements as permissive for delete to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists ann_owner_insert on public.conventus_announcements;
create policy ann_owner_insert on public.conventus_announcements as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists ann_owner_read on public.conventus_announcements;
create policy ann_owner_read on public.conventus_announcements as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists ann_owner_update on public.conventus_announcements;
create policy ann_owner_update on public.conventus_announcements as permissive for update to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND (e.created_by = auth.uid()))))) with check ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_announcements.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists cc_delete on public.conventus_communities;
create policy cc_delete on public.conventus_communities as permissive for delete to public using ((conventity_is_admin('ecosystem'::text) OR ((parent_id IS NOT NULL) AND conventity_can_manage_community(parent_id))));
drop policy if exists cc_insert on public.conventus_communities;
create policy cc_insert on public.conventus_communities as permissive for insert to public with check ((((parent_id IS NULL) AND conventity_is_admin('ecosystem'::text)) OR ((parent_id IS NOT NULL) AND conventity_can_manage_community(parent_id))));
drop policy if exists cc_select on public.conventus_communities;
create policy cc_select on public.conventus_communities as permissive for select to public using (((visibility = 'public'::text) OR conventity_in_community(id) OR conventity_is_admin('ecosystem'::text)));
drop policy if exists cc_update on public.conventus_communities;
create policy cc_update on public.conventus_communities as permissive for update to public using (conventity_can_manage_community(id)) with check (conventity_can_manage_community(id));
drop policy if exists doc_audience_read on public.conventus_documents;
create policy doc_audience_read on public.conventus_documents as permissive for select to anon, authenticated using (((is_published = true) AND ((audience = 'all'::text) OR ((audience = 'approved'::text) AND (EXISTS ( SELECT 1
   FROM conventus_registrations r
  WHERE ((r.event_id = conventus_documents.event_id) AND (r.user_id = auth.uid()) AND (r.status = ANY (ARRAY['approved'::text, 'checked_in'::text])))))) OR ((audience = 'pending'::text) AND (EXISTS ( SELECT 1
   FROM conventus_registrations r
  WHERE ((r.event_id = conventus_documents.event_id) AND (r.user_id = auth.uid()))))) OR ((audience = 'community_members'::text) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_documents.event_id) AND (e.community_id IS NOT NULL) AND conventity_in_community(e.community_id))))) OR ((audience = 'organizers'::text) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_documents.event_id) AND conventity_can_manage_event(e.activity_id))))))));
drop policy if exists doc_manager_all on public.conventus_documents;
create policy doc_manager_all on public.conventus_documents as permissive for all to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_documents.event_id) AND ((e.created_by = auth.uid()) OR conventity_can_manage_event(e.activity_id)))))) with check ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_documents.event_id) AND ((e.created_by = auth.uid()) OR conventity_can_manage_event(e.activity_id))))));
drop policy if exists "conventus_events public read" on public.conventus_events;
create policy "conventus_events public read" on public.conventus_events as permissive for select to public using (true);
drop policy if exists cem_delete on public.conventus_exercise_media;
create policy cem_delete on public.conventus_exercise_media as permissive for delete to public using (conventus_sel_is_organizer(event_id));
drop policy if exists cem_insert on public.conventus_exercise_media;
create policy cem_insert on public.conventus_exercise_media as permissive for insert to authenticated with check (conventus_sel_is_organizer(event_id));
drop policy if exists cem_read on public.conventus_exercise_media;
create policy cem_read on public.conventus_exercise_media as permissive for select to public using (conventus_sel_is_organizer(event_id));
drop policy if exists ceo_insert on public.conventus_exercise_observations;
create policy ceo_insert on public.conventus_exercise_observations as permissive for insert to authenticated with check (conventus_sel_is_organizer(event_id));
drop policy if exists ceo_read on public.conventus_exercise_observations;
create policy ceo_read on public.conventus_exercise_observations as permissive for select to public using (conventus_sel_is_organizer(event_id));
drop policy if exists cer_insert on public.conventus_exercise_ratings;
create policy cer_insert on public.conventus_exercise_ratings as permissive for insert to authenticated with check (conventus_sel_is_organizer(event_id));
drop policy if exists cer_read on public.conventus_exercise_ratings;
create policy cer_read on public.conventus_exercise_ratings as permissive for select to public using (conventus_sel_is_organizer(event_id));
drop policy if exists cvi_owner_all on public.conventus_invitations;
create policy cvi_owner_all on public.conventus_invitations as permissive for all to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_invitations.event_id) AND ((e.created_by = auth.uid()) OR is_cv_admin()))))) with check ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_invitations.event_id) AND ((e.created_by = auth.uid()) OR is_cv_admin())))));
drop policy if exists "events: owner all" on public.conventus_managed_events;
create policy "events: owner all" on public.conventus_managed_events as permissive for all to authenticated using ((auth.uid() = created_by)) with check ((auth.uid() = created_by));
drop policy if exists "events: public read open" on public.conventus_managed_events;
create policy "events: public read open" on public.conventus_managed_events as permissive for select to anon, authenticated using ((registration_open = true));
drop policy if exists cme_admin_delete on public.conventus_managed_events;
create policy cme_admin_delete on public.conventus_managed_events as permissive for delete to authenticated using (is_cv_admin());
drop policy if exists cme_admin_update on public.conventus_managed_events;
create policy cme_admin_update on public.conventus_managed_events as permissive for update to authenticated using (is_cv_admin()) with check (is_cv_admin());
drop policy if exists cme_owner_delete on public.conventus_managed_events;
create policy cme_owner_delete on public.conventus_managed_events as permissive for delete to authenticated using ((created_by = auth.uid()));
drop policy if exists cme_visibility_gate on public.conventus_managed_events;
create policy cme_visibility_gate on public.conventus_managed_events as restrictive for select to public using (((visibility = 'public'::text) OR (created_by = auth.uid()) OR is_cv_admin() OR cv_event_access(id)));
drop policy if exists events_owner_update on public.conventus_managed_events;
create policy events_owner_update on public.conventus_managed_events as permissive for update to authenticated using ((created_by = auth.uid())) with check ((created_by = auth.uid()));
drop policy if exists crd_manage on public.conventus_rating_dimensions;
create policy crd_manage on public.conventus_rating_dimensions as permissive for all to authenticated using (((event_id IS NOT NULL) AND conventus_sel_is_organizer(event_id))) with check (((event_id IS NOT NULL) AND conventus_sel_is_organizer(event_id)));
drop policy if exists crd_read on public.conventus_rating_dimensions;
create policy crd_read on public.conventus_rating_dimensions as permissive for select to public using (((event_id IS NULL) OR conventus_sel_is_organizer(event_id)));
drop policy if exists crr_manage on public.conventus_recognition_records;
create policy crr_manage on public.conventus_recognition_records as permissive for all to authenticated using (conventus_sel_is_organizer(event_id)) with check (conventus_sel_is_organizer(event_id));
drop policy if exists crr_read on public.conventus_recognition_records;
create policy crr_read on public.conventus_recognition_records as permissive for select to public using ((conventus_sel_is_organizer(event_id) OR ((status = 'issued'::text) AND (EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_recognition_records.application_id) AND (a.submitted_by = auth.uid())))))));
drop policy if exists crege_select on public.conventus_registration_events;
create policy crege_select on public.conventus_registration_events as permissive for select to public using (((registrant_uid = auth.uid()) OR (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registration_events.event_id) AND conventity_can_manage_event(e.activity_id))))));
drop policy if exists "reg: organiser read" on public.conventus_registrations;
create policy "reg: organiser read" on public.conventus_registrations as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registrations.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists "reg: organiser update" on public.conventus_registrations;
create policy "reg: organiser update" on public.conventus_registrations as permissive for update to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registrations.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists "reg: own read" on public.conventus_registrations;
create policy "reg: own read" on public.conventus_registrations as permissive for select to authenticated using ((auth.uid() = user_id));
drop policy if exists "reg: own update" on public.conventus_registrations;
create policy "reg: own update" on public.conventus_registrations as permissive for update to authenticated using ((auth.uid() = user_id)) with check ((auth.uid() = user_id));
drop policy if exists reg_manager_insert on public.conventus_registrations;
create policy reg_manager_insert on public.conventus_registrations as permissive for insert to public with check (((registered_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registrations.event_id) AND conventity_can_manage_event(e.activity_id))))));
drop policy if exists reg_manager_read on public.conventus_registrations;
create policy reg_manager_read on public.conventus_registrations as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registrations.event_id) AND conventity_can_manage_event(e.activity_id)))));
drop policy if exists reg_manager_update on public.conventus_registrations;
create policy reg_manager_update on public.conventus_registrations as permissive for update to public using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registrations.event_id) AND conventity_can_manage_event(e.activity_id))))) with check ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registrations.event_id) AND conventity_can_manage_event(e.activity_id)))));
drop policy if exists reg_self_insert_open on public.conventus_registrations;
create policy reg_self_insert_open on public.conventus_registrations as permissive for insert to authenticated with check (((auth.uid() = user_id) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_registrations.event_id) AND (e.registration_open = true))))));
drop policy if exists reg_self_read on public.conventus_registrations;
create policy reg_self_read on public.conventus_registrations as permissive for select to authenticated using ((user_id = auth.uid()));
drop policy if exists cre_select on public.conventus_role_events;
create policy cre_select on public.conventus_role_events as permissive for select to public using ((conventity_is_admin('ecosystem'::text) OR ((scope = 'community'::text) AND conventity_can_manage_community(scope_id)) OR ((scope = 'activity'::text) AND (EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.activity_id = conventus_role_events.scope_id) AND conventity_can_manage_community(e.community_id)))))));
drop policy if exists csel_crit_insert on public.conventus_selection_app_criteria;
create policy csel_crit_insert on public.conventus_selection_app_criteria as permissive for insert to anon, authenticated with check ((EXISTS ( SELECT 1
   FROM (conventus_selection_applications a
     JOIN conventus_selection_events e ON ((e.id = a.event_id)))
  WHERE ((a.id = conventus_selection_app_criteria.application_id) AND (e.status = 'open'::text)))));
drop policy if exists csel_crit_manage on public.conventus_selection_app_criteria;
create policy csel_crit_manage on public.conventus_selection_app_criteria as permissive for all to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_app_criteria.application_id) AND conventus_sel_is_organizer(a.event_id))))) with check ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_app_criteria.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists csel_crit_read on public.conventus_selection_app_criteria;
create policy csel_crit_read on public.conventus_selection_app_criteria as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_app_criteria.application_id) AND (conventus_sel_is_organizer(a.event_id) OR (a.submitted_by = auth.uid()))))));
drop policy if exists csel_an_insert on public.conventus_selection_app_needs;
create policy csel_an_insert on public.conventus_selection_app_needs as permissive for insert to anon, authenticated with check ((EXISTS ( SELECT 1
   FROM (conventus_selection_applications a
     JOIN conventus_selection_events e ON ((e.id = a.event_id)))
  WHERE ((a.id = conventus_selection_app_needs.application_id) AND (e.status = 'open'::text)))));
drop policy if exists csel_an_manage on public.conventus_selection_app_needs;
create policy csel_an_manage on public.conventus_selection_app_needs as permissive for all to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_app_needs.application_id) AND conventus_sel_is_organizer(a.event_id))))) with check ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_app_needs.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists csel_an_read on public.conventus_selection_app_needs;
create policy csel_an_read on public.conventus_selection_app_needs as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_app_needs.application_id) AND (conventus_sel_is_organizer(a.event_id) OR (a.submitted_by = auth.uid()))))));
drop policy if exists csel_app_delete on public.conventus_selection_applications;
create policy csel_app_delete on public.conventus_selection_applications as permissive for delete to public using (conventus_sel_is_organizer(event_id));
drop policy if exists csel_app_insert_public on public.conventus_selection_applications;
create policy csel_app_insert_public on public.conventus_selection_applications as permissive for insert to anon, authenticated with check ((EXISTS ( SELECT 1
   FROM conventus_selection_events e
  WHERE ((e.id = conventus_selection_applications.event_id) AND (e.status = 'open'::text)))));
drop policy if exists csel_app_manage on public.conventus_selection_applications;
create policy csel_app_manage on public.conventus_selection_applications as permissive for update to public using (conventus_sel_is_organizer(event_id)) with check (conventus_sel_is_organizer(event_id));
drop policy if exists csel_app_read on public.conventus_selection_applications;
create policy csel_app_read on public.conventus_selection_applications as permissive for select to public using ((conventus_sel_is_organizer(event_id) OR (submitted_by = auth.uid())));
drop policy if exists csel_as_insert on public.conventus_selection_assessments;
create policy csel_as_insert on public.conventus_selection_assessments as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_assessments.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists csel_as_read on public.conventus_selection_assessments;
create policy csel_as_read on public.conventus_selection_assessments as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_assessments.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists csel_ev_read on public.conventus_selection_events;
create policy csel_ev_read on public.conventus_selection_events as permissive for select to public using (((status = ANY (ARRAY['open'::text, 'published'::text])) OR conventus_sel_is_organizer(id)));
drop policy if exists csel_ev_write on public.conventus_selection_events;
create policy csel_ev_write on public.conventus_selection_events as permissive for all to public using (((organizer_id = auth.uid()) OR ((organizer_id IS NULL) AND (auth.uid() IS NOT NULL)))) with check (((organizer_id = auth.uid()) OR ((organizer_id IS NULL) AND (auth.uid() IS NOT NULL))));
drop policy if exists csel_ff_read on public.conventus_selection_form_fields;
create policy csel_ff_read on public.conventus_selection_form_fields as permissive for select to public using (((event_id IS NULL) OR (EXISTS ( SELECT 1
   FROM conventus_selection_events e
  WHERE ((e.id = conventus_selection_form_fields.event_id) AND ((e.status = ANY (ARRAY['open'::text, 'published'::text])) OR conventus_sel_is_organizer(e.id)))))));
drop policy if exists csel_ff_write on public.conventus_selection_form_fields;
create policy csel_ff_write on public.conventus_selection_form_fields as permissive for all to public using (((event_id IS NOT NULL) AND conventus_sel_is_organizer(event_id))) with check (((event_id IS NOT NULL) AND conventus_sel_is_organizer(event_id)));
drop policy if exists csel_mat_insert on public.conventus_selection_materials;
create policy csel_mat_insert on public.conventus_selection_materials as permissive for insert to anon, authenticated with check ((EXISTS ( SELECT 1
   FROM (conventus_selection_applications a
     JOIN conventus_selection_events e ON ((e.id = a.event_id)))
  WHERE ((a.id = conventus_selection_materials.application_id) AND (e.status = 'open'::text)))));
drop policy if exists csel_mat_manage on public.conventus_selection_materials;
create policy csel_mat_manage on public.conventus_selection_materials as permissive for all to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_materials.application_id) AND conventus_sel_is_organizer(a.event_id))))) with check ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_materials.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists csel_mat_read on public.conventus_selection_materials;
create policy csel_mat_read on public.conventus_selection_materials as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_materials.application_id) AND (conventus_sel_is_organizer(a.event_id) OR (a.submitted_by = auth.uid()))))));
drop policy if exists csel_need_read on public.conventus_selection_needs;
create policy csel_need_read on public.conventus_selection_needs as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_events e
  WHERE ((e.id = conventus_selection_needs.event_id) AND ((e.status = ANY (ARRAY['open'::text, 'published'::text])) OR conventus_sel_is_organizer(e.id))))));
drop policy if exists csel_need_write on public.conventus_selection_needs;
create policy csel_need_write on public.conventus_selection_needs as permissive for all to public using (conventus_sel_is_organizer(event_id)) with check (conventus_sel_is_organizer(event_id));
drop policy if exists csel_run_all on public.conventus_selection_runs;
create policy csel_run_all on public.conventus_selection_runs as permissive for all to public using (conventus_sel_is_organizer(event_id)) with check (conventus_sel_is_organizer(event_id));
drop policy if exists csel_tr_read on public.conventus_selection_transitions;
create policy csel_tr_read on public.conventus_selection_transitions as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_transitions.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists csv_insert on public.conventus_selection_verifications;
create policy csv_insert on public.conventus_selection_verifications as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_verifications.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists csv_read on public.conventus_selection_verifications;
create policy csv_read on public.conventus_selection_verifications as permissive for select to public using ((EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = conventus_selection_verifications.application_id) AND conventus_sel_is_organizer(a.event_id)))));
drop policy if exists sessions_owner_delete on public.conventus_sessions;
create policy sessions_owner_delete on public.conventus_sessions as permissive for delete to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_sessions.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists sessions_owner_insert on public.conventus_sessions;
create policy sessions_owner_insert on public.conventus_sessions as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_sessions.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists sessions_owner_read on public.conventus_sessions;
create policy sessions_owner_read on public.conventus_sessions as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_sessions.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists sessions_owner_update on public.conventus_sessions;
create policy sessions_owner_update on public.conventus_sessions as permissive for update to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_sessions.event_id) AND (e.created_by = auth.uid()))))) with check ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = conventus_sessions.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists sessions_public_read_published on public.conventus_sessions;
create policy sessions_public_read_published on public.conventus_sessions as permissive for select to anon, authenticated using ((is_published = true));
drop policy if exists car_insert_public on public.convexus_activity_records;
create policy car_insert_public on public.convexus_activity_records as permissive for insert to anon, authenticated with check ((EXISTS ( SELECT 1
   FROM (conventus_selection_applications a
     JOIN conventus_selection_events e ON ((e.id = a.event_id)))
  WHERE ((a.id = convexus_activity_records.application_id) AND (e.status = 'open'::text)))));
drop policy if exists car_manage on public.convexus_activity_records;
create policy car_manage on public.convexus_activity_records as permissive for all to authenticated using (((application_id IS NULL) OR (EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = convexus_activity_records.application_id) AND conventus_sel_is_organizer(a.event_id)))))) with check (((application_id IS NULL) OR (EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = convexus_activity_records.application_id) AND conventus_sel_is_organizer(a.event_id))))));
drop policy if exists car_read on public.convexus_activity_records;
create policy car_read on public.convexus_activity_records as permissive for select to public using (((application_id IS NULL) OR (EXISTS ( SELECT 1
   FROM conventus_selection_applications a
  WHERE ((a.id = convexus_activity_records.application_id) AND (conventus_sel_is_organizer(a.event_id) OR (a.submitted_by = auth.uid())))))));
drop policy if exists ceng_admins_all on public.convexus_admins;
create policy ceng_admins_all on public.convexus_admins as permissive for all to authenticated using (is_convexus_admin()) with check (is_convexus_admin());
drop policy if exists cds_admin_delete on public.convexus_demand_signals;
create policy cds_admin_delete on public.convexus_demand_signals as permissive for delete to authenticated using (is_convexus_admin());
drop policy if exists cds_admin_insert on public.convexus_demand_signals;
create policy cds_admin_insert on public.convexus_demand_signals as permissive for insert to authenticated with check (is_convexus_admin());
drop policy if exists cds_admin_read on public.convexus_demand_signals;
create policy cds_admin_read on public.convexus_demand_signals as permissive for select to authenticated using (is_convexus_admin());
drop policy if exists cds_admin_update on public.convexus_demand_signals;
create policy cds_admin_update on public.convexus_demand_signals as permissive for update to authenticated using (is_convexus_admin()) with check (is_convexus_admin());
drop policy if exists cds_public_read_active on public.convexus_demand_signals;
create policy cds_public_read_active on public.convexus_demand_signals as permissive for select to public using ((status = 'active'::text));
drop policy if exists "public read domains" on public.convexus_domains;
create policy "public read domains" on public.convexus_domains as permissive for select to public using (true);
drop policy if exists ceng_evt_admin_insert on public.convexus_engagement_events;
create policy ceng_evt_admin_insert on public.convexus_engagement_events as permissive for insert to authenticated with check (is_convexus_admin());
drop policy if exists ceng_evt_admin_select on public.convexus_engagement_events;
create policy ceng_evt_admin_select on public.convexus_engagement_events as permissive for select to authenticated using (is_convexus_admin());
drop policy if exists ceng_req_admin_delete on public.convexus_engagement_requests;
create policy ceng_req_admin_delete on public.convexus_engagement_requests as permissive for delete to authenticated using (is_convexus_admin());
drop policy if exists ceng_req_admin_insert on public.convexus_engagement_requests;
create policy ceng_req_admin_insert on public.convexus_engagement_requests as permissive for insert to authenticated with check (is_convexus_admin());
drop policy if exists ceng_req_admin_select on public.convexus_engagement_requests;
create policy ceng_req_admin_select on public.convexus_engagement_requests as permissive for select to authenticated using (is_convexus_admin());
drop policy if exists ceng_req_admin_update on public.convexus_engagement_requests;
create policy ceng_req_admin_update on public.convexus_engagement_requests as permissive for update to authenticated using (is_convexus_admin()) with check (is_convexus_admin());
drop policy if exists ceng_req_public_submit on public.convexus_engagement_requests;
create policy ceng_req_public_submit on public.convexus_engagement_requests as permissive for insert to public with check (((status = 'received'::text) AND (taxonomy_status = 'untriaged'::text) AND (demand_status = 'untriaged'::text) AND (triage_notes IS NULL) AND (proposed_capability_area IS NULL) AND (profile_id IS NULL) AND (demand_signal_id IS NULL) AND (routed_to IS NULL) AND (route_reasons IS NULL)));
drop policy if exists cfa_admin_delete on public.convexus_focus_areas;
create policy cfa_admin_delete on public.convexus_focus_areas as permissive for delete to authenticated using (is_convexus_admin());
drop policy if exists cfa_admin_insert on public.convexus_focus_areas;
create policy cfa_admin_insert on public.convexus_focus_areas as permissive for insert to authenticated with check (is_convexus_admin());
drop policy if exists cfa_admin_read on public.convexus_focus_areas;
create policy cfa_admin_read on public.convexus_focus_areas as permissive for select to authenticated using (is_convexus_admin());
drop policy if exists cfa_admin_update on public.convexus_focus_areas;
create policy cfa_admin_update on public.convexus_focus_areas as permissive for update to authenticated using (is_convexus_admin()) with check (is_convexus_admin());
drop policy if exists cfa_public_read on public.convexus_focus_areas;
create policy cfa_public_read on public.convexus_focus_areas as permissive for select to public using ((origin <> 'candidate'::text));
drop policy if exists ndpp_read on public.convexus_ndpp_codes;
create policy ndpp_read on public.convexus_ndpp_codes as permissive for select to public using (true);
drop policy if exists ndpp_write on public.convexus_ndpp_codes;
create policy ndpp_write on public.convexus_ndpp_codes as permissive for all to authenticated using (true) with check (true);
drop policy if exists "delete ownerless profile_domains (interim)" on public.convexus_profile_domains;
create policy "delete ownerless profile_domains (interim)" on public.convexus_profile_domains as permissive for delete to authenticated using ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_domains.profile_id) AND (p.owner_id IS NULL)))));
drop policy if exists "manage ownerless profile_domains (interim)" on public.convexus_profile_domains;
create policy "manage ownerless profile_domains (interim)" on public.convexus_profile_domains as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_domains.profile_id) AND (p.owner_id IS NULL)))));
drop policy if exists "profile_domains owner delete" on public.convexus_profile_domains;
create policy "profile_domains owner delete" on public.convexus_profile_domains as permissive for delete to authenticated using ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_domains.profile_id) AND (p.owner_id = auth.uid())))));
drop policy if exists "profile_domains owner insert" on public.convexus_profile_domains;
create policy "profile_domains owner insert" on public.convexus_profile_domains as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_domains.profile_id) AND (p.owner_id = auth.uid())))));
drop policy if exists "profile_domains public read" on public.convexus_profile_domains;
create policy "profile_domains public read" on public.convexus_profile_domains as permissive for select to public using (true);
drop policy if exists "public read profile_domains" on public.convexus_profile_domains;
create policy "public read profile_domains" on public.convexus_profile_domains as permissive for select to public using (true);
drop policy if exists "delete ownerless profile_focus (interim)" on public.convexus_profile_focus_areas;
create policy "delete ownerless profile_focus (interim)" on public.convexus_profile_focus_areas as permissive for delete to authenticated using ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_focus_areas.profile_id) AND (p.owner_id IS NULL)))));
drop policy if exists "manage ownerless profile_focus (interim)" on public.convexus_profile_focus_areas;
create policy "manage ownerless profile_focus (interim)" on public.convexus_profile_focus_areas as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_focus_areas.profile_id) AND (p.owner_id IS NULL)))));
drop policy if exists "profile_focus owner delete" on public.convexus_profile_focus_areas;
create policy "profile_focus owner delete" on public.convexus_profile_focus_areas as permissive for delete to authenticated using ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_focus_areas.profile_id) AND (p.owner_id = auth.uid())))));
drop policy if exists "profile_focus owner insert" on public.convexus_profile_focus_areas;
create policy "profile_focus owner insert" on public.convexus_profile_focus_areas as permissive for insert to authenticated with check ((EXISTS ( SELECT 1
   FROM convexus_profiles p
  WHERE ((p.id = convexus_profile_focus_areas.profile_id) AND (p.owner_id = auth.uid())))));
drop policy if exists "profile_focus public read" on public.convexus_profile_focus_areas;
create policy "profile_focus public read" on public.convexus_profile_focus_areas as permissive for select to public using (true);
drop policy if exists "public read profile_focus_areas" on public.convexus_profile_focus_areas;
create policy "public read profile_focus_areas" on public.convexus_profile_focus_areas as permissive for select to public using (true);
drop policy if exists "delete ownerless profiles (interim)" on public.convexus_profiles;
create policy "delete ownerless profiles (interim)" on public.convexus_profiles as permissive for delete to authenticated using ((owner_id IS NULL));
drop policy if exists "manage ownerless profiles (interim)" on public.convexus_profiles;
create policy "manage ownerless profiles (interim)" on public.convexus_profiles as permissive for update to authenticated using ((owner_id IS NULL)) with check ((owner_id IS NULL));
drop policy if exists "profiles owner delete" on public.convexus_profiles;
create policy "profiles owner delete" on public.convexus_profiles as permissive for delete to authenticated using ((owner_id = auth.uid()));
drop policy if exists "profiles owner insert" on public.convexus_profiles;
create policy "profiles owner insert" on public.convexus_profiles as permissive for insert to authenticated with check ((owner_id = auth.uid()));
drop policy if exists "profiles owner update" on public.convexus_profiles;
create policy "profiles owner update" on public.convexus_profiles as permissive for update to authenticated using ((owner_id = auth.uid())) with check ((owner_id = auth.uid()));
drop policy if exists "profiles public read" on public.convexus_profiles;
create policy "profiles public read" on public.convexus_profiles as permissive for select to public using (true);
drop policy if exists "public read profiles" on public.convexus_profiles;
create policy "public read profiles" on public.convexus_profiles as permissive for select to public using (true);
drop policy if exists "public read reference_frameworks" on public.convexus_reference_frameworks;
create policy "public read reference_frameworks" on public.convexus_reference_frameworks as permissive for select to public using (true);
drop policy if exists cra_admin_write on public.convexus_requirement_attributes;
create policy cra_admin_write on public.convexus_requirement_attributes as permissive for all to public using (is_convexus_admin()) with check (is_convexus_admin());
drop policy if exists cra_public_read on public.convexus_requirement_attributes;
create policy cra_public_read on public.convexus_requirement_attributes as permissive for select to public using (true);
drop policy if exists csa_admin_write on public.convexus_signal_attributes;
create policy csa_admin_write on public.convexus_signal_attributes as permissive for all to public using (is_convexus_admin()) with check (is_convexus_admin());
drop policy if exists csa_public_read on public.convexus_signal_attributes;
create policy csa_public_read on public.convexus_signal_attributes as permissive for select to public using (true);
drop policy if exists "public read use_profiles" on public.convexus_use_profiles;
create policy "public read use_profiles" on public.convexus_use_profiles as permissive for select to public using (true);
drop policy if exists cva_self_read on public.cv_admins;
create policy cva_self_read on public.cv_admins as permissive for select to authenticated using ((user_id = auth.uid()));
drop policy if exists gmi_anon_showcase on public.gm_inventory;
create policy gmi_anon_showcase on public.gm_inventory as permissive for select to anon using (((is_active = true) AND gm_provider_accredited(provider_id)));
drop policy if exists gmi_auth_read_active on public.gm_inventory;
create policy gmi_auth_read_active on public.gm_inventory as permissive for select to authenticated using (((is_active = true) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_inventory.provider_id) AND (p.accredited = true))))));
drop policy if exists gmi_owner_all on public.gm_inventory;
create policy gmi_owner_all on public.gm_inventory as permissive for all to authenticated using ((EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_inventory.provider_id) AND (p.owner_user_id = auth.uid()) AND (p.accredited = true))))) with check ((EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_inventory.provider_id) AND (p.owner_user_id = auth.uid()) AND (p.accredited = true)))));
drop policy if exists gmo_auth_read_approved on public.gm_offers;
create policy gmo_auth_read_approved on public.gm_offers as permissive for select to authenticated using (((status = 'approved'::text) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_offers.provider_id) AND (p.accredited = true))))));
drop policy if exists gmo_owner_delete on public.gm_offers;
create policy gmo_owner_delete on public.gm_offers as permissive for delete to authenticated using (((status <> 'approved'::text) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_offers.provider_id) AND (p.owner_user_id = auth.uid()) AND (p.accredited = true))))));
drop policy if exists gmo_owner_insert on public.gm_offers;
create policy gmo_owner_insert on public.gm_offers as permissive for insert to authenticated with check (((status = ANY (ARRAY['draft'::text, 'pending'::text])) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_offers.provider_id) AND (p.owner_user_id = auth.uid()) AND (p.accredited = true))))));
drop policy if exists gmo_owner_read on public.gm_offers;
create policy gmo_owner_read on public.gm_offers as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_offers.provider_id) AND (p.owner_user_id = auth.uid())))));
drop policy if exists gmo_owner_update on public.gm_offers;
create policy gmo_owner_update on public.gm_offers as permissive for update to authenticated using (((status = ANY (ARRAY['draft'::text, 'pending'::text, 'rejected'::text])) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_offers.provider_id) AND (p.owner_user_id = auth.uid()) AND (p.accredited = true)))))) with check (((status = ANY (ARRAY['draft'::text, 'pending'::text])) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_offers.provider_id) AND (p.owner_user_id = auth.uid()) AND (p.accredited = true))))));
drop policy if exists gmpl_organizer_read on public.gm_plan;
create policy gmpl_organizer_read on public.gm_plan as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM conventus_managed_events e
  WHERE ((e.id = gm_plan.event_id) AND (e.created_by = auth.uid())))));
drop policy if exists gmpl_provider_read on public.gm_plan;
create policy gmpl_provider_read on public.gm_plan as permissive for select to authenticated using (((EXISTS ( SELECT 1
   FROM (gm_inventory i
     JOIN gm_providers p ON ((p.id = i.provider_id)))
  WHERE ((i.id = gm_plan.inventory_id) AND (p.owner_user_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM (gm_offers o
     JOIN gm_providers p ON ((p.id = o.provider_id)))
  WHERE ((o.id = gm_plan.offer_id) AND (p.owner_user_id = auth.uid()))))));
drop policy if exists gmpl_provider_update on public.gm_plan;
create policy gmpl_provider_update on public.gm_plan as permissive for update to authenticated using (((EXISTS ( SELECT 1
   FROM (gm_inventory i
     JOIN gm_providers p ON ((p.id = i.provider_id)))
  WHERE ((i.id = gm_plan.inventory_id) AND (p.owner_user_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM (gm_offers o
     JOIN gm_providers p ON ((p.id = o.provider_id)))
  WHERE ((o.id = gm_plan.offer_id) AND (p.owner_user_id = auth.uid())))))) with check ((status = ANY (ARRAY['requested'::text, 'confirmed'::text, 'cancelled'::text])));
drop policy if exists gmpl_user_delete on public.gm_plan;
create policy gmpl_user_delete on public.gm_plan as permissive for delete to authenticated using (((user_id = auth.uid()) AND (status = 'requested'::text)));
drop policy if exists gmpl_user_insert on public.gm_plan;
create policy gmpl_user_insert on public.gm_plan as permissive for insert to authenticated with check (((user_id = auth.uid()) AND (status = 'requested'::text)));
drop policy if exists gmpl_user_select on public.gm_plan;
create policy gmpl_user_select on public.gm_plan as permissive for select to authenticated using ((user_id = auth.uid()));
drop policy if exists gmpl_user_update on public.gm_plan;
create policy gmpl_user_update on public.gm_plan as permissive for update to authenticated using ((user_id = auth.uid())) with check (((user_id = auth.uid()) AND (status = ANY (ARRAY['requested'::text, 'cancelled'::text]))));
drop policy if exists gmr_auth_read_verified on public.gm_provider_ratings;
create policy gmr_auth_read_verified on public.gm_provider_ratings as permissive for select to authenticated using ((verified = true));
drop policy if exists gmr_owner_delete on public.gm_provider_ratings;
create policy gmr_owner_delete on public.gm_provider_ratings as permissive for delete to authenticated using (((verified = false) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_provider_ratings.provider_id) AND (p.owner_user_id = auth.uid()))))));
drop policy if exists gmr_owner_insert on public.gm_provider_ratings;
create policy gmr_owner_insert on public.gm_provider_ratings as permissive for insert to authenticated with check (((verified = false) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_provider_ratings.provider_id) AND (p.owner_user_id = auth.uid()) AND (p.accredited = true))))));
drop policy if exists gmr_owner_read on public.gm_provider_ratings;
create policy gmr_owner_read on public.gm_provider_ratings as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_provider_ratings.provider_id) AND (p.owner_user_id = auth.uid())))));
drop policy if exists gmr_owner_update on public.gm_provider_ratings;
create policy gmr_owner_update on public.gm_provider_ratings as permissive for update to authenticated using (((verified = false) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_provider_ratings.provider_id) AND (p.owner_user_id = auth.uid())))))) with check (((verified = false) AND (EXISTS ( SELECT 1
   FROM gm_providers p
  WHERE ((p.id = gm_provider_ratings.provider_id) AND (p.owner_user_id = auth.uid()))))));
drop policy if exists gmp_owner_read on public.gm_providers;
create policy gmp_owner_read on public.gm_providers as permissive for select to authenticated using ((owner_user_id = auth.uid()));
drop policy if exists gmp_owner_update on public.gm_providers;
create policy gmp_owner_update on public.gm_providers as permissive for update to authenticated using ((owner_user_id = auth.uid())) with check ((owner_user_id = auth.uid()));
drop policy if exists gmp_self_apply on public.gm_providers;
create policy gmp_self_apply on public.gm_providers as permissive for insert to authenticated with check (((owner_user_id = auth.uid()) AND (accredited = false) AND (commission_rate IS NULL) AND (contract_fee IS NULL) AND (contract_date IS NULL) AND (contract_note IS NULL)));

-- ===================== 10 · YETKILER =====================
-- PostgREST rolleri tablo ayrıcalığı olmadan RLS'e hiç ulaşamaz.
-- .org'da üç role de public'teki tüm tablo/view üzerinde tam yetki verilmiş;
-- gerçek sınır RLS politikalarıdır (yukarıda).
do $cvblock$
declare r record;
begin
  for r in select tablename as rel from pg_tables where schemaname = 'public'
           union all
           select viewname  as rel from pg_views  where schemaname = 'public' loop
    execute format('grant all on public.%I to anon, authenticated, service_role', r.rel);
  end loop;
end $cvblock$;

alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;

-- ============ 11 · YABANCI ANAHTARLAR (en sonda) ============
do $cvblock$
declare r record;
begin
  for r in select * from (values
    ('conventity_cn_connections', 'conventity_cn_connections_addressee_id_fkey', $d$FOREIGN KEY (addressee_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_connections', 'conventity_cn_connections_requester_id_fkey', $d$FOREIGN KEY (requester_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_expertise', 'conventity_cn_expertise_person_id_fkey', $d$FOREIGN KEY (person_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_memberships', 'conventity_cn_memberships_group_id_fkey', $d$FOREIGN KEY (group_id) REFERENCES conventity_cn_groups(id) ON DELETE CASCADE$d$),
    ('conventity_cn_memberships', 'conventity_cn_memberships_link_participation_id_fkey', $d$FOREIGN KEY (link_participation_id) REFERENCES conventity_participation(id)$d$),
    ('conventity_cn_memberships', 'conventity_cn_memberships_person_id_fkey', $d$FOREIGN KEY (person_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_messages', 'conventity_cn_messages_recipient_id_fkey', $d$FOREIGN KEY (recipient_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_messages', 'conventity_cn_messages_sender_id_fkey', $d$FOREIGN KEY (sender_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_post_comments', 'conventity_cn_post_comments_author_id_fkey', $d$FOREIGN KEY (author_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_post_comments', 'conventity_cn_post_comments_post_id_fkey', $d$FOREIGN KEY (post_id) REFERENCES conventity_cn_posts(id) ON DELETE CASCADE$d$),
    ('conventity_cn_post_reactions', 'conventity_cn_post_reactions_person_id_fkey', $d$FOREIGN KEY (person_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_post_reactions', 'conventity_cn_post_reactions_post_id_fkey', $d$FOREIGN KEY (post_id) REFERENCES conventity_cn_posts(id) ON DELETE CASCADE$d$),
    ('conventity_cn_posts', 'conventity_cn_posts_author_id_fkey', $d$FOREIGN KEY (author_id) REFERENCES conventity_people(id) ON DELETE CASCADE$d$),
    ('conventity_cn_posts', 'conventity_cn_posts_group_id_fkey', $d$FOREIGN KEY (group_id) REFERENCES conventity_cn_groups(id) ON DELETE CASCADE$d$),
    ('conventity_evidence', 'conventity_evidence_activity_id_fkey', $d$FOREIGN KEY (activity_id) REFERENCES conventity_activities(id)$d$),
    ('conventity_evidence', 'conventity_evidence_org_id_fkey', $d$FOREIGN KEY (org_id) REFERENCES conventity_orgs(id)$d$),
    ('conventity_matches', 'conventity_matches_org_id_fkey', $d$FOREIGN KEY (org_id) REFERENCES conventity_orgs(id) ON DELETE SET NULL$d$),
    ('conventity_matches', 'conventity_matches_problem_id_fkey', $d$FOREIGN KEY (problem_id) REFERENCES conventity_problems(id) ON DELETE CASCADE$d$),
    ('conventity_matches', 'conventity_matches_solution_id_fkey', $d$FOREIGN KEY (solution_id) REFERENCES conventity_solutions(id) ON DELETE CASCADE$d$),
    ('conventity_participation', 'conventity_participation_activity_id_fkey', $d$FOREIGN KEY (activity_id) REFERENCES conventity_activities(id)$d$),
    ('conventity_participation', 'conventity_participation_org_id_fkey', $d$FOREIGN KEY (org_id) REFERENCES conventity_orgs(id)$d$),
    ('conventity_participation', 'conventity_participation_person_id_fkey', $d$FOREIGN KEY (person_id) REFERENCES conventity_people(id)$d$),
    ('conventity_people', 'conventity_people_home_org_id_fkey', $d$FOREIGN KEY (home_org_id) REFERENCES conventity_orgs(id)$d$),
    ('conventity_problem_capability', 'conventity_problem_capability_capability_id_fkey', $d$FOREIGN KEY (capability_id) REFERENCES conventity_capabilities(id)$d$),
    ('conventity_problem_capability', 'conventity_problem_capability_problem_id_fkey', $d$FOREIGN KEY (problem_id) REFERENCES conventity_problems(id)$d$),
    ('conventity_problem_solution', 'conventity_problem_solution_problem_id_fkey', $d$FOREIGN KEY (problem_id) REFERENCES conventity_problems(id)$d$),
    ('conventity_problem_solution', 'conventity_problem_solution_solution_id_fkey', $d$FOREIGN KEY (solution_id) REFERENCES conventity_solutions(id)$d$),
    ('conventity_problems', 'conventity_problems_authority_org_fk', $d$FOREIGN KEY (authority_org_id) REFERENCES conventity_orgs(id) ON DELETE SET NULL$d$),
    ('conventity_roles', 'conventity_roles_person_id_fkey', $d$FOREIGN KEY (person_id) REFERENCES conventity_people(id)$d$),
    ('conventity_solution_capability', 'conventity_solution_capability_capability_id_fkey', $d$FOREIGN KEY (capability_id) REFERENCES conventity_capabilities(id)$d$),
    ('conventity_solution_capability', 'conventity_solution_capability_solution_id_fkey', $d$FOREIGN KEY (solution_id) REFERENCES conventity_solutions(id)$d$),
    ('conventity_solutions', 'conventity_solutions_org_id_fkey', $d$FOREIGN KEY (org_id) REFERENCES conventity_orgs(id)$d$),
    ('conventus_announcements', 'conventus_announcements_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_managed_events(id) ON DELETE CASCADE$d$),
    ('conventus_communities', 'conventus_communities_org_id_fkey', $d$FOREIGN KEY (org_id) REFERENCES conventity_orgs(id)$d$),
    ('conventus_communities', 'conventus_communities_parent_id_fkey', $d$FOREIGN KEY (parent_id) REFERENCES conventus_communities(id) ON DELETE RESTRICT$d$),
    ('conventus_exercise_media', 'conventus_exercise_media_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_exercise_media', 'conventus_exercise_media_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_exercise_media', 'conventus_exercise_media_need_id_fkey', $d$FOREIGN KEY (need_id) REFERENCES conventus_selection_needs(id) ON DELETE SET NULL$d$),
    ('conventus_exercise_media', 'conventus_exercise_media_observation_id_fkey', $d$FOREIGN KEY (observation_id) REFERENCES conventus_exercise_observations(id) ON DELETE CASCADE$d$),
    ('conventus_exercise_observations', 'conventus_exercise_observations_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_exercise_observations', 'conventus_exercise_observations_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_exercise_observations', 'conventus_exercise_observations_need_id_fkey', $d$FOREIGN KEY (need_id) REFERENCES conventus_selection_needs(id) ON DELETE SET NULL$d$),
    ('conventus_exercise_ratings', 'conventus_exercise_ratings_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_exercise_ratings', 'conventus_exercise_ratings_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_exercise_ratings', 'conventus_exercise_ratings_need_id_fkey', $d$FOREIGN KEY (need_id) REFERENCES conventus_selection_needs(id) ON DELETE SET NULL$d$),
    ('conventus_invitations', 'conventus_invitations_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_managed_events(id) ON DELETE CASCADE$d$),
    ('conventus_managed_events', 'conventus_managed_events_activity_id_fkey', $d$FOREIGN KEY (activity_id) REFERENCES conventity_activities(id)$d$),
    ('conventus_managed_events', 'conventus_managed_events_community_id_fkey', $d$FOREIGN KEY (community_id) REFERENCES conventus_communities(id)$d$),
    ('conventus_managed_events', 'conventus_managed_events_created_by_fkey', $d$FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE CASCADE$d$),
    ('conventus_rating_dimensions', 'conventus_rating_dimensions_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_rating_dimensions', 'conventus_rating_dimensions_need_id_fkey', $d$FOREIGN KEY (need_id) REFERENCES conventus_selection_needs(id) ON DELETE CASCADE$d$),
    ('conventus_recognition_records', 'conventus_recognition_records_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_recognition_records', 'conventus_recognition_records_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_registrations', 'conventus_registrations_activity_id_fkey', $d$FOREIGN KEY (activity_id) REFERENCES conventity_activities(id)$d$),
    ('conventus_registrations', 'conventus_registrations_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_managed_events(id) ON DELETE CASCADE$d$),
    ('conventus_registrations', 'conventus_registrations_org_id_fkey', $d$FOREIGN KEY (org_id) REFERENCES conventity_orgs(id)$d$),
    ('conventus_registrations', 'conventus_registrations_person_id_fkey', $d$FOREIGN KEY (person_id) REFERENCES conventity_people(id)$d$),
    ('conventus_registrations', 'conventus_registrations_user_id_fkey', $d$FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$d$),
    ('conventus_selection_app_criteria', 'conventus_selection_app_criteria_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_selection_app_criteria', 'conventus_selection_app_criteria_need_id_fkey', $d$FOREIGN KEY (need_id) REFERENCES conventus_selection_needs(id) ON DELETE CASCADE$d$),
    ('conventus_selection_app_needs', 'conventus_selection_app_needs_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_selection_app_needs', 'conventus_selection_app_needs_need_id_fkey', $d$FOREIGN KEY (need_id) REFERENCES conventus_selection_needs(id) ON DELETE CASCADE$d$),
    ('conventus_selection_applications', 'conventus_selection_applications_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_selection_assessments', 'conventus_selection_assessments_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_selection_assessments', 'conventus_selection_assessments_run_id_fkey', $d$FOREIGN KEY (run_id) REFERENCES conventus_selection_runs(id) ON DELETE SET NULL$d$),
    ('conventus_selection_events', 'conventus_selection_events_activity_id_fkey', $d$FOREIGN KEY (activity_id) REFERENCES conventity_activities(id)$d$),
    ('conventus_selection_form_fields', 'conventus_selection_form_fields_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_selection_materials', 'conventus_selection_materials_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_selection_needs', 'conventus_selection_needs_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_selection_runs', 'conventus_selection_runs_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_selection_events(id) ON DELETE CASCADE$d$),
    ('conventus_selection_transitions', 'conventus_selection_transitions_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_selection_verifications', 'conventus_selection_verifications_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('conventus_sessions', 'conventus_sessions_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_managed_events(id) ON DELETE CASCADE$d$),
    ('convexus_activity_records', 'convexus_activity_records_application_id_fkey', $d$FOREIGN KEY (application_id) REFERENCES conventus_selection_applications(id) ON DELETE CASCADE$d$),
    ('convexus_admins', 'convexus_admins_user_id_fkey', $d$FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$d$),
    ('convexus_demand_signals', 'convexus_demand_signals_origin_request_id_fkey', $d$FOREIGN KEY (origin_request_id) REFERENCES convexus_engagement_requests(id) ON DELETE SET NULL$d$),
    ('convexus_demand_signals', 'convexus_demand_signals_problem_id_fkey', $d$FOREIGN KEY (problem_id) REFERENCES conventity_problems(id)$d$),
    ('convexus_engagement_events', 'convexus_engagement_events_request_id_fkey', $d$FOREIGN KEY (request_id) REFERENCES convexus_engagement_requests(id) ON DELETE CASCADE$d$),
    ('convexus_engagement_requests', 'convexus_engagement_requests_demand_signal_fk', $d$FOREIGN KEY (demand_signal_id) REFERENCES convexus_demand_signals(id) ON DELETE SET NULL$d$),
    ('convexus_engagement_requests', 'convexus_engagement_requests_profile_id_fkey', $d$FOREIGN KEY (profile_id) REFERENCES convexus_profiles(id) ON DELETE SET NULL$d$),
    ('convexus_profile_domains', 'convexus_profile_domains_domain_code_fkey', $d$FOREIGN KEY (domain_code) REFERENCES convexus_domains(code)$d$),
    ('convexus_profile_domains', 'convexus_profile_domains_profile_id_fkey', $d$FOREIGN KEY (profile_id) REFERENCES convexus_profiles(id) ON DELETE CASCADE$d$),
    ('convexus_profile_focus_areas', 'convexus_profile_focus_areas_focus_code_fkey', $d$FOREIGN KEY (focus_code) REFERENCES convexus_focus_areas(code)$d$),
    ('convexus_profile_focus_areas', 'convexus_profile_focus_areas_profile_id_fkey', $d$FOREIGN KEY (profile_id) REFERENCES convexus_profiles(id) ON DELETE CASCADE$d$),
    ('convexus_profiles', 'convexus_profiles_org_id_fkey', $d$FOREIGN KEY (org_id) REFERENCES conventity_orgs(id)$d$),
    ('convexus_profiles', 'convexus_profiles_owner_id_fkey', $d$FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE SET NULL$d$),
    ('convexus_profiles', 'convexus_profiles_use_profile_fkey', $d$FOREIGN KEY (use_profile) REFERENCES convexus_use_profiles(code)$d$),
    ('convexus_signal_attributes', 'convexus_signal_attributes_attribute_code_fkey', $d$FOREIGN KEY (attribute_code) REFERENCES convexus_requirement_attributes(code) ON DELETE CASCADE$d$),
    ('convexus_signal_attributes', 'convexus_signal_attributes_signal_id_fkey', $d$FOREIGN KEY (signal_id) REFERENCES convexus_demand_signals(id) ON DELETE CASCADE$d$),
    ('gm_inventory', 'gm_inventory_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_managed_events(id) ON DELETE SET NULL$d$),
    ('gm_inventory', 'gm_inventory_provider_id_fkey', $d$FOREIGN KEY (provider_id) REFERENCES gm_providers(id) ON DELETE CASCADE$d$),
    ('gm_offers', 'gm_offers_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_managed_events(id) ON DELETE SET NULL$d$),
    ('gm_offers', 'gm_offers_provider_id_fkey', $d$FOREIGN KEY (provider_id) REFERENCES gm_providers(id) ON DELETE CASCADE$d$),
    ('gm_plan', 'gm_plan_event_id_fkey', $d$FOREIGN KEY (event_id) REFERENCES conventus_managed_events(id) ON DELETE CASCADE$d$),
    ('gm_plan', 'gm_plan_inventory_id_fkey', $d$FOREIGN KEY (inventory_id) REFERENCES gm_inventory(id) ON DELETE SET NULL$d$),
    ('gm_plan', 'gm_plan_offer_id_fkey', $d$FOREIGN KEY (offer_id) REFERENCES gm_offers(id) ON DELETE SET NULL$d$),
    ('gm_provider_ratings', 'gm_provider_ratings_provider_id_fkey', $d$FOREIGN KEY (provider_id) REFERENCES gm_providers(id) ON DELETE CASCADE$d$),
    ('profiles', 'profiles_id_fkey', $d$FOREIGN KEY (id) REFERENCES auth.users(id)$d$),
    ('projects', 'projects_owner_id_fkey', $d$FOREIGN KEY (owner_id) REFERENCES profiles(id)$d$)
  ) v(tbl, con, def) loop
    if not exists (
      select 1 from pg_constraint c
      join pg_class rel on rel.oid = c.conrelid
      join pg_namespace n on n.oid = rel.relnamespace
      where n.nspname = 'public' and rel.relname = r.tbl and c.conname = r.con
    ) then
      execute format('alter table public.%I add constraint %I %s', r.tbl, r.con, r.def);
    end if;
  end loop;
end $cvblock$;
-- -- (yabanci anahtar sonu)

-- ============================================================================
-- .org'daki satır sayıları — SADECE BİLGİ. Bu dosya hiçbirini kopyalamaz.
-- Şablon/referans verisi taşıyan tablolar (form alanları, puanlama boyutları,
-- focus area / domain sözlükleri) ileride ayrı bir seed dosyasıyla gelecek.
-- ============================================================================
--   conventity_activities                            6 satir
--   conventity_audit                                 9 satir
--   conventity_capabilities                          0 satir
--   conventity_cn_connections                        3 satir
--   conventity_cn_expertise                         26 satir
--   conventity_cn_groups                             1 satir
--   conventity_cn_memberships                        1 satir
--   conventity_cn_messages                           0 satir
--   conventity_cn_post_comments                      0 satir
--   conventity_cn_post_reactions                     1 satir
--   conventity_cn_posts                              1 satir
--   conventity_evidence                              3 satir
--   conventity_matches                               3 satir
--   conventity_orgs                                158 satir
--   conventity_participation                         2 satir
--   conventity_people                               20 satir
--   conventity_problem_capability                    0 satir
--   conventity_problem_solution                      0 satir
--   conventity_problems                              9 satir
--   conventity_relations                             0 satir
--   conventity_roles                                11 satir
--   conventity_signin_log                           16 satir
--   conventity_solution_capability                   0 satir
--   conventity_solutions                            10 satir
--   conventus_announcements                          1 satir
--   conventus_communities                            2 satir
--   conventus_documents                              0 satir
--   conventus_events                                18 satir
--   conventus_exercise_media                         0 satir
--   conventus_exercise_observations                  0 satir
--   conventus_exercise_ratings                       0 satir
--   conventus_invitations                            0 satir
--   conventus_managed_events                         3 satir
--   conventus_rating_dimensions                     15 satir
--   conventus_recognition_records                    0 satir
--   conventus_registration_events                    0 satir
--   conventus_registrations                          1 satir
--   conventus_role_events                            8 satir
--   conventus_selection_app_criteria                 0 satir
--   conventus_selection_app_needs                   81 satir
--   conventus_selection_applications                75 satir
--   conventus_selection_assessments               1002 satir
--   conventus_selection_events                       4 satir
--   conventus_selection_form_fields                173 satir
--   conventus_selection_materials                    0 satir
--   conventus_selection_needs                        7 satir
--   conventus_selection_runs                        20 satir
--   conventus_selection_transitions                 75 satir
--   conventus_selection_verifications                2 satir
--   conventus_sessions                               1 satir
--   convexus_activity_records                       32 satir
--   convexus_admins                                  1 satir
--   convexus_demand_signals                          6 satir
--   convexus_domains                                 6 satir
--   convexus_engagement_events                      12 satir
--   convexus_engagement_requests                     2 satir
--   convexus_focus_areas                            24 satir
--   convexus_ndpp_codes                             14 satir
--   convexus_profile_domains                       249 satir
--   convexus_profile_focus_areas                   358 satir
--   convexus_profiles                              147 satir
--   convexus_reference_frameworks                    3 satir
--   convexus_requirement_attributes                  8 satir
--   convexus_signal_attributes                      25 satir
--   convexus_use_profiles                            3 satir
--   cv_admins                                        1 satir
--   gm_inventory                                     0 satir
--   gm_offers                                        0 satir
--   gm_plan                                          0 satir
--   gm_provider_ratings                              0 satir
--   gm_providers                                     2 satir
--   profiles                                         0 satir
--   projects                                         0 satir
