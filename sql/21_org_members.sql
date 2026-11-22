-- ============================================================================
-- 21_org_members.sql  ·  conventity.org üyeliği (KAPALI kurulur)
--
-- conventity.org için e-postayla giriş yapan üyeler: firma temsilcisi,
-- paydaş (yönetici tanımlar) ve bülten abonesi. Hesap altyapısı ortaktır
-- (auth.users); .org üyeliği bu tabloda ayrı durur ve conventity.com
-- üyeliği (conventity_is_member) ile karışmaz. Üç tür aynı içeriği görür;
-- tür yalnız etikettir.
--
-- KAPALI: conventity_org_settings.membership_open = false. Kapalıyken
-- yönetici dışında kimse üye olamaz; açmak kurucu kararıdır (conventity.org
-- deposu → docs/kararlar.md BK-2, BK-9, BK-12).
--
-- Tasarım notları:
--   * Üye kendi satırına doğrudan yazamaz; yalnız aşağıdaki işlevlerle.
--   * Paydaş türünü yalnız yönetici verir.
--   * Bülten rızasının zamanı saklanır (bulletin_at); rıza geri alınınca silinir.
--   * Üyelik yalnız e-postaya gelen kodla açılan oturumda işlem görür (conventity_org_verified).
--   * Ayrılan üyenin hesabı da silinir, başka kaydı yoksa (conventity_org_forget).
--   * Üye ayrılınca satırı SİLİNİR. Bu yüzden tabloya denetim tetikleyicisi
--     bağlanmaz: conventity_audit silinemez ve e-postayı tutmaya devam ederdi.
--
-- NEREDE ÇALIŞIR: conventity-prod → SQL Editor. Tekrar çalıştırılabilir.
-- Geri alma: 21_org_members_ROLLBACK.sql
-- ============================================================================

-- ---- 0) yanlış proje / eksik şema koruması --------------------------------
do $cvguard$
declare n_prof bigint := 0;
begin
  if to_regprocedure('public.conventity_is_admin(text)') is null
     or to_regclass('public.conventity_roles') is null or to_regclass('public.conventity_people') is null or to_regclass('public.profiles') is null then
    raise exception E'\n\n  omurga eksik (conventity_is_admin, conventity_roles, conventity_people, profiles) — once 02_clean_install.sql calistir.\n';
  end if;
  if to_regclass('public.convexus_profiles') is not null then
    select count(*) into n_prof from public.convexus_profiles;
  end if;
  if n_prof >= 100 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) ayarlar (bayrak) ---------------------------------------------------
create table if not exists public.conventity_org_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
insert into public.conventity_org_settings(key, value)
select 'membership_open', 'false'::jsonb
 where not exists (select 1 from public.conventity_org_settings where key = 'membership_open');
-- Kapı belirteci: kapalı önizleme süresince, giriş yapan üyeye haftalık kod sorulmaması için.
-- Değeri bu dosyada DURMAZ ve boş kurulur; kurulumda ayrıca yazılır ve conventity.org
-- deposundaki .htaccess ile aynı olmalıdır. Boşken hiçbir üyeye belirteç verilmez.
insert into public.conventity_org_settings(key, value)
select 'gate_token', 'null'::jsonb
 where not exists (select 1 from public.conventity_org_settings where key = 'gate_token');

alter table public.conventity_org_settings enable row level security;
drop policy if exists org_settings_admin on public.conventity_org_settings;
create policy org_settings_admin on public.conventity_org_settings
  for all using (conventity_is_admin('ecosystem')) with check (conventity_is_admin('ecosystem'));

-- ---- 2) üyeler -------------------------------------------------------------
create table if not exists public.conventity_org_members (
  id           uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique,
  email        text not null,
  kind         text not null default 'subscriber',
  status       text not null default 'active',
  bulletin     boolean not null default false,
  bulletin_at  timestamptz,
  org_name     text,
  note         text,
  invited_by   uuid,
  created_at   timestamptz not null default now(),
  accepted_at  timestamptz,
  closed_at    timestamptz
);

do $ck$
begin
  if not exists (select 1 from pg_constraint where conname = 'conventity_org_members_kind_check') then
    alter table public.conventity_org_members
      add constraint conventity_org_members_kind_check check (kind in ('firm','stakeholder','subscriber'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'conventity_org_members_status_check') then
    alter table public.conventity_org_members
      add constraint conventity_org_members_status_check check (status in ('invited','active','closed'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'conventity_org_members_email_check') then
    alter table public.conventity_org_members
      add constraint conventity_org_members_email_check check (email = lower(email) and email like '%_@_%._%' and length(email) <= 254);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'conventity_org_members_len_check') then
    alter table public.conventity_org_members
      add constraint conventity_org_members_len_check check (coalesce(length(org_name),0) <= 160 and coalesce(length(note),0) <= 1000);
  end if;
end $ck$;

create unique index if not exists uq_conv_org_members_email on public.conventity_org_members(email);
create index if not exists idx_conv_org_members_kind on public.conventity_org_members(kind, status);

alter table public.conventity_org_members enable row level security;

-- Okuma: üye yalnız kendi satırını; yönetici hepsini.
drop policy if exists org_members_select_self on public.conventity_org_members;
create policy org_members_select_self on public.conventity_org_members
  for select using (auth_user_id = auth.uid());
-- Yazma: yalnız yönetici. Üye işlemleri aşağıdaki işlevlerden geçer.
drop policy if exists org_members_admin on public.conventity_org_members;
create policy org_members_admin on public.conventity_org_members
  for all using (conventity_is_admin('ecosystem')) with check (conventity_is_admin('ecosystem'));

revoke all on public.conventity_org_members  from anon;
revoke all on public.conventity_org_settings from anon;

-- ---- 3) işlevler -----------------------------------------------------------
create or replace function public.conventity_org_open()
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce((select value = 'true'::jsonb from conventity_org_settings where key = 'membership_open'), false);
$fn$;

-- Oturum, e-postaya gelen tek kullanımlık kodla (ya da bağlantıyla) açıldıysa true.
-- Ortak altyapıda parolayla açılmış bir hesap, adresi doğrulanmamış olabilir; böyle bir oturum
-- başkasının davetini kabul edememeli. Bu yüzden .org üyeliği yalnız kodla açılan oturumda işlem görür.
create or replace function public.conventity_org_verified()
returns boolean language sql stable security definer set search_path = public, auth as $fn$
  select auth.uid() is not null
     and exists (select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null
                   and lower(u.email::text) = lower(nullif(trim(auth.jwt() ->> 'email'), '')))
     and exists (select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
                  where a ->> 'method' in ('otp', 'magiclink'));
$fn$;

-- Kendi üyelik durumum: { open, invited, member }. invited: bu e-postaya yönetici davet açmış, henüz kabul edilmemiş.
create or replace function public.conventity_org_me()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'open', conventity_org_open(),
    'invited', conventity_org_verified() and exists(select 1 from conventity_org_members i
                       where i.email = lower(nullif(trim(auth.jwt() ->> 'email'), '')) and i.auth_user_id is null and i.status = 'invited'),
    'member', (select jsonb_build_object('email', m.email, 'kind', m.kind, 'status', m.status,
                                         'bulletin', m.bulletin, 'org_name', m.org_name, 'created_at', m.created_at)
                 from conventity_org_members m where m.auth_user_id = auth.uid()));
$fn$;

-- Üye ol ya da daveti kabul et. E-posta, doğrulanmış oturumdan okunur; istemciden alınmaz.
create or replace function public.conventity_org_join(p_kind text default 'subscriber', p_bulletin boolean default false, p_org_name text default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_uid   uuid := auth.uid();
  v_email text := lower(nullif(trim(auth.jwt() ->> 'email'), ''));
  v_row   conventity_org_members%rowtype;
  v_org   text := nullif(left(trim(coalesce(p_org_name, '')), 160), '');
begin
  if v_uid is null or v_email is null or not conventity_org_verified() then
    return jsonb_build_object('ok', false, 'reason', 'signin');
  end if;

  select * into v_row from conventity_org_members where auth_user_id = v_uid or email = v_email
   order by (auth_user_id = v_uid) desc nulls last limit 1;

  if found then
    if v_row.status = 'closed' then
      return jsonb_build_object('ok', false, 'reason', 'closed');
    end if;
    -- Davet edilmiş ya da var olan üyelik: hesaba bağla. Türü üye değiştiremez.
    update conventity_org_members
       set auth_user_id = v_uid, status = 'active', accepted_at = coalesce(accepted_at, now()),
           bulletin = case when status = 'invited' then coalesce(p_bulletin, false) else bulletin end,
           bulletin_at = case when status = 'invited' and coalesce(p_bulletin, false) then now() else bulletin_at end,
           org_name = coalesce(org_name, v_org)
     where id = v_row.id;
    return jsonb_build_object('ok', true);
  end if;

  if not (conventity_org_open() or conventity_is_admin('ecosystem')) then
    return jsonb_build_object('ok', false, 'reason', 'not_open');
  end if;
  if p_kind not in ('firm', 'subscriber') then
    return jsonb_build_object('ok', false, 'reason', 'kind');
  end if;

  insert into conventity_org_members(auth_user_id, email, kind, status, bulletin, bulletin_at, org_name, accepted_at)
  values (v_uid, v_email, p_kind, 'active', coalesce(p_bulletin, false),
          case when coalesce(p_bulletin, false) then now() end, v_org, now());
  return jsonb_build_object('ok', true);
end
$fn$;

-- Bülten rızasını ver ya da geri al.
create or replace function public.conventity_org_set_bulletin(p_on boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  update conventity_org_members
     set bulletin = coalesce(p_on, false), bulletin_at = case when coalesce(p_on, false) then now() end
   where auth_user_id = auth.uid() and status = 'active';
  return jsonb_build_object('ok', found);
end
$fn$;

-- Üyelikten ayrıl: satır silinir. Yöneticinin kapattığı üyelik silinmez (yeniden kayıt engeli olarak kalır).
create or replace function public.conventity_org_leave()
returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  delete from conventity_org_members where auth_user_id = auth.uid() and status <> 'closed';
  return jsonb_build_object('ok', found);
end
$fn$;

-- Kapı belirteci: yalnız etkin üyeye (kodla açılmış oturumda) ve yöneticiye verilir.
-- Üyeliği kapatılan kişi yeni belirteç alamaz; tarayıcısındaki eski belirteç en geç 24 saatte düşer.
create or replace function public.conventity_org_gate()
returns text language sql stable security definer set search_path = public as $fn$
  select case when (conventity_org_verified() and exists (select 1 from conventity_org_members m
                                                           where m.auth_user_id = auth.uid() and m.status = 'active'))
                then (select nullif(value #>> '{}', '') from conventity_org_settings where key = 'gate_token')
          end;
$fn$;

-- Hesabı da sil: YALNIZ bu sayfanın kodla oluşturduğu, başka hiçbir izi olmayan hesap.
-- Üyelikten ayrılan ya da üyelik kapalıyken kod isteyip "açık değil" yanıtı alan kişinin adresi
-- ortak hesap tablosunda kalmasın diye. Şunlardan biri varsa hesap KALIR:
--   * parola (conventity.com'a kayıt olmuş ya da onay bekliyor olabilir: 06_pending_members.sql),
--   * e-posta dışında bir kimlik sağlayıcı (Google, LinkedIn),
--   * .org üyeliği, rol, profil, hesaba ya da aynı e-postaya bağlı kişi kaydı,
--   * başka bir tablonun bu hesaba bağı (silme reddedilir).
create or replace function public.conventity_org_forget()
returns jsonb language plpgsql security definer set search_path = public, auth as $fn$
declare
  v_uid   uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then return jsonb_build_object('ok', false); end if;
  select lower(u.email::text) into v_email from auth.users u where u.id = v_uid;
  if exists (select 1 from auth.users u where u.id = v_uid and coalesce(u.encrypted_password, '') <> '')
     or exists (select 1 from auth.identities i where i.user_id = v_uid and i.provider <> 'email')
     or exists (select 1 from conventity_org_members m where m.auth_user_id = v_uid)
     or exists (select 1 from conventity_roles r where r.auth_user_id = v_uid)
     or exists (select 1 from conventity_people p where p.auth_user_id = v_uid or (v_email is not null and lower(p.email) = v_email))
     or exists (select 1 from profiles p where p.id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'in_use');
  end if;
  begin
    delete from auth.users where id = v_uid;
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'in_use');
  end;
  return jsonb_build_object('ok', true);
end
$fn$;

do $gr$
declare f text;
begin
  foreach f in array array['conventity_org_open()', 'conventity_org_verified()', 'conventity_org_me()', 'conventity_org_join(text, boolean, text)',
                           'conventity_org_set_bulletin(boolean)', 'conventity_org_leave()', 'conventity_org_forget()', 'conventity_org_gate()'] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('revoke all on function public.%s from anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $gr$;

-- ---- 4) PostgREST şema önbelleği -----------------------------------------
notify pgrst, 'reload schema';

-- ---- 5) doğrulama ----------------------------------------------------------
select (select value from public.conventity_org_settings where key = 'membership_open') as membership_open,
       (select count(*) from public.conventity_org_members) as uye,
       (select count(*) from pg_policies where schemaname = 'public' and tablename = 'conventity_org_members') as politika;
