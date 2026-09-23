-- ============================================================================
-- 08_landcom_conference.sql  ·  LANDCOM Konferansı 2026 — ilk dikey dilim
--
-- NE KURAR: LANDCOM topluluğu + Kasım 2026 konferansı + omurga bağı
--           (conventity_activities) + sahibe topluluk rolü.
--
-- NEDEN SEED, YENİ KOD DEĞİL: Conventus tarafında etkinlik makinesi hazır —
--   event-studio · new-event · event-manage · my-events · applications ·
--   programme · agenda · announcements sayfaları `.org`'dan taşındı ve
--   çağırdıkları 26 tablo/view + 7 RPC'nin hepsi bu şemada var
--   (scripts/check-page-schema-refs.py temiz). Eksik olan tek şey veriydi.
--   Şema davet ve başvuruyu zaten destekliyor:
--     davet    -> event-manage "adına kayıt" (tekli/toplu) + status='invited'
--     başvuru  -> requires_approval=true, aday submitted -> approved/rejected
--
-- NEDEN RPC DEĞİL DOĞRUDAN INSERT: `conventus_create_managed_event`
--   `conventity_can_manage_community()` istiyor, o da `auth.uid()` okuyor.
--   SQL Editor'de oturum yok (uid null), RPC orada hep patlar. Bu dosya
--   RPC'nin yaptığının aynısını yapıyor — activity'yi aynı `source_ref` ile
--   açıyor, böylece ikisi çakışmıyor.
--
-- KULLANIM: 02–07'den SONRA. Tekrar çalıştırılabilir; ikinci çalıştırma
--   hiçbir satırı çoğaltmaz, mevcut kayıtları da EZMEZ (etkinliği arayüzden
--   düzenledikten sonra tekrar çalıştırırsan değişikliklerin durur).
-- ============================================================================

-- ---- 0) YANLIŞ PROJE KORUMASI ----------------------------------------------
do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.conventus_communities') is null then
    raise exception E'\n\n  Bu projede sema yok — once 02_clean_install.sql calistir.\n';
  end if;
  -- .org parmak izi: orada 147 convexus profili var, temiz kurulumda 0.
  -- (conventity_orgs'a BAKMIYORUZ: bu dosya ileride org da seed edebilir.)
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n'
      '  Hicbir sey yazilmadi.\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) SEED ----------------------------------------------------------------
do $cvseed$
declare
  -- ======================= DEĞİŞTİRİLECEK TEK YER =========================
  k_owner_mail  constant text := 'serkancopul@gmail.com';   -- topluluk sahibi
  k_comm_slug   constant text := 'landcom';
  k_comm_name   constant text := 'LANDCOM';
  k_comm_tag    constant text := 'NATO Allied Land Command';
  k_code        constant text := 'LANDCOM-CONF-2026';
  k_title       constant text := 'LANDCOM Konferansı 2026';
  k_start       constant date := date '2026-11-17';         -- kesinleşince değiştir
  k_end         constant date := date '2026-11-19';
  k_location    constant text := 'Belirlenecek';
  k_host        constant text := 'LANDCOM';
  k_capacity    constant int  := 150;
  k_desc        constant text :=
    'LANDCOM ev sahipliğinde düzenlenen konferans. Katılım davet ve başvuru '
    'yoluyla; başvurular organizatör onayından geçer.';
  -- ========================================================================
  v_comm   uuid;
  v_act    uuid;
  v_event  bigint;
  v_uid    uuid;
  v_person uuid;
begin
  -- 1a) sahibin auth hesabi — ZORUNLU.
  -- `conventus_managed_events.created_by` NOT NULL ve varsayilani `auth.uid()`;
  -- SQL Editor'de oturum olmadigi icin uid null gelir ve insert patlar. Bu
  -- yuzden sahibi e-postadan bulup created_by'a ACIKCA yaziyoruz.
  select id into v_uid from auth.users
   where lower(email) = lower(k_owner_mail) order by created_at limit 1;
  if v_uid is null then
    raise exception E'\n\n  % icin Supabase Auth hesabi yok.\n'
      '  Once hesabi ac (Dashboard -> Authentication -> Users -> Add user,\n'
      '  "Auto Confirm User" isaretli) ve 03_bootstrap_owner.sql''i calistir,\n'
      '  sonra bu dosyayi tekrar dene. Hicbir sey yazilmadi.\n', k_owner_mail;
  end if;
  select id into v_person from public.conventity_people where auth_user_id = v_uid limit 1;

  -- 1b) topluluk
  select id into v_comm from public.conventus_communities where slug = k_comm_slug;
  if v_comm is null then
    insert into public.conventus_communities
      (slug, name, short_name, tagline, level, visibility, join_policy, is_active, source_ref)
    values
      (k_comm_slug, k_comm_name, k_comm_name, k_comm_tag, 1, 'public', 'invite', true,
       'seed:community:' || k_comm_slug)
    returning id into v_comm;
    raise notice 'topluluk acildi : % (%)', k_comm_name, v_comm;
  else
    raise notice 'topluluk zaten var: % (%)', k_comm_name, v_comm;
  end if;

  -- 1c) omurga faaliyeti — RPC ile AYNI source_ref, cakismasin
  select id into v_act from public.conventity_activities
   where source_ref = 'conventus_event_code:' || k_code;
  if v_act is null then
    begin
      insert into public.conventity_activities (title, activity_type, source, origin_ref, source_ref)
      values (k_title, 'event', 'internal', 'conventus', 'conventus_event_code:' || k_code)
      returning id into v_act;
    exception when check_violation then
      -- 'event' CHECK'te yoksa RPC'nin yaptigi gibi 'challenge'a dus
      insert into public.conventity_activities (title, activity_type, source, origin_ref, source_ref)
      values (k_title, 'challenge', 'internal', 'conventus', 'conventus_event_code:' || k_code)
      returning id into v_act;
    end;
    raise notice 'omurga faaliyeti: %', v_act;
  end if;

  -- 1d) etkinlik — davet + basvuru birlikte:
  --     visibility='public'      -> vitrinlerde gorunur, basvuru alinabilir
  --     invite_only=false        -> basvuru kapisi acik
  --     requires_approval=true   -> her basvuru organizator onayindan gecer
  --     davet yolu               -> event-manage "adina kayit" (status onayli)
  select id into v_event from public.conventus_managed_events where code = k_code;
  if v_event is null then
    insert into public.conventus_managed_events
      (code, title, start_date, end_date, location, host_org, description,
       registration_open, invite_only, requires_approval, waitlist_enabled,
       capacity, visibility, published, community_id, activity_id, created_by)
    values
      (k_code, k_title, k_start, k_end, k_location, k_host, k_desc,
       true, false, true, true,
       k_capacity, 'public', true, v_comm, v_act, v_uid)
    returning id into v_event;
    raise notice 'etkinlik acildi : % (id=%)', k_code, v_event;
  else
    raise notice 'etkinlik zaten var: % (id=%) — ustune YAZILMADI', k_code, v_event;
  end if;

  -- 1e) sahibe topluluk rolu (ekosistem admini zaten her seyi yonetebilir;
  --     bu rol, ekosistem admini OLMAYAN organizatorlerin yolunu da acar)
  if not exists (select 1 from public.conventity_roles
                  where auth_user_id = v_uid and scope = 'community'
                    and scope_id = v_comm and role = 'owner') then
    insert into public.conventity_roles
      (person_id, auth_user_id, scope, scope_id, role, status, source_ref)
    values
      (v_person, v_uid, 'community', v_comm, 'owner', 'active',
       'seed:community_owner:' || k_comm_slug);
    raise notice 'topluluk sahibi rolu verildi: %', k_owner_mail;
  end if;
end $cvseed$;

-- ---- 2) DOĞRULAMA — tek sorgu (SQL Editor yalniz sonuncuyu gosteriyor) ------
select
  e.code                                   as "kod",
  e.title                                  as "baslik",
  to_char(e.start_date, 'DD.MM.YYYY')      as "baslangic",
  to_char(e.end_date,   'DD.MM.YYYY')      as "bitis",
  c.name                                   as "topluluk",
  e.capacity                               as "kontenjan",
  e.registration_open                      as "kayit acik",
  e.requires_approval                      as "onay gerekli",
  (e.activity_id is not null)              as "omurga bagli",
  (select count(*) from public.conventus_registrations r where r.event_id = e.id) as "kayit",
  (select count(*) from public.conventity_roles ro
     where ro.scope = 'community' and ro.scope_id = c.id and ro.status = 'active') as "topluluk rolu"
from public.conventus_managed_events e
join public.conventus_communities c on c.id = e.community_id
where e.code = 'LANDCOM-CONF-2026';
