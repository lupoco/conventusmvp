-- ============================================================================
-- 10_protocol_reference_ROLLBACK.sql  ·  10 ve 11'i birlikte geri alir
--
-- DIKKAT — VERI KAYBI: bu dosya conventus_registrations ve
--   conventus_managed_events'ten protokol kolonlarini DUSURUR. O kolonlarda
--   girilmis rutbe/sifat/unvan/temsil bilgisi GERI GELMEZ. Once yedek al:
--
--     create table _yedek_reg_protokol as
--       select id, nation_code, rank_id, grade_code, capacity_key, title_key,
--              organization_key, date_of_rank, represents_capacity_key,
--              representation_ref, is_guest_of_honour
--         from public.conventus_registrations;
--     create table _yedek_event_protokol as
--       select id, precedence_list, alpha_language, host_nation,
--              partner_placement, dress_code_key, dress_season
--         from public.conventus_managed_events;
--
-- SADECE REFERANS VERISINI TAZELEMEK ICIN BU DOSYAYI KULLANMA:
--   11_protocol_seed.sql upsert'tir, tek basina tekrar calistirmak yeter.
-- ============================================================================

drop view if exists public.conventus_precedence_v;

drop function if exists public.conventus_registration_precedence(bigint);
drop function if exists public.conventity_precedence_score(text,text,text,text);
drop function if exists public.conventity_identity_string(text,text,text,text);
drop function if exists public.conventity_salutation(text,text,text);

-- Sira onemli: address_form -> nation, rank -> nato_grade,
-- precedence_item -> precedence_list ve capacity.
drop table if exists public.conventity_ref_address_form;
drop table if exists public.conventity_ref_precedence_item;
drop table if exists public.conventity_ref_precedence_list;
drop table if exists public.conventity_ref_dress_code;
drop table if exists public.conventity_ref_organization;
drop table if exists public.conventity_ref_title;
drop table if exists public.conventity_ref_capacity;
drop table if exists public.conventity_ref_rank;
drop table if exists public.conventity_ref_nato_grade;
drop table if exists public.conventity_ref_nation;

alter table public.conventus_managed_events
  drop constraint if exists ck_cme_alpha_language,
  drop constraint if exists ck_cme_partner_placement,
  drop constraint if exists ck_cme_dress_season;

alter table public.conventus_managed_events
  drop column if exists precedence_list,
  drop column if exists alpha_language,
  drop column if exists host_nation,
  drop column if exists partner_placement,
  drop column if exists dress_code_key,
  drop column if exists dress_season;

alter table public.conventus_registrations
  drop column if exists nation_code,
  drop column if exists rank_id,
  drop column if exists grade_code,
  drop column if exists capacity_key,
  drop column if exists title_key,
  drop column if exists organization_key,
  drop column if exists date_of_rank,
  drop column if exists represents_capacity_key,
  drop column if exists representation_ref,
  drop column if exists is_guest_of_honour;

notify pgrst, 'reload schema';

select
  (select count(*) from pg_tables where schemaname='public'
     and tablename like 'conventity_ref_%')                       as "kalan referans tablo (0)",
  (select count(*) from pg_views where schemaname='public'
     and viewname='conventus_precedence_v')                       as "kalan view (0)",
  (select count(*) from information_schema.columns where table_schema='public'
     and table_name='conventus_registrations'
     and column_name in ('nation_code','rank_id','grade_code','capacity_key','title_key',
                         'organization_key','date_of_rank','represents_capacity_key',
                         'representation_ref','is_guest_of_honour'))as "kalan kayit kolonu (0)";
