-- ============================================================================
-- 06_pending_members.sql  ·  Bekleyen kayıtlar — listele + onayla
--
-- NEDEN: kapalı testte kayıt olmak tek başına erişim vermiyor —
--        `conventity_is_member()` fail-closed, rolü ya da `conventity_people`
--        kaydı olmayan hesap içeri giremiyor. Doğru davranış, ama yöneticinin
--        KİMİN kayıt olduğunu görebileceği bir yer yoktu: `auth.users`
--        istemciye kapalı (öyle de kalmalı). Bu dosya o boşluğu kapatıyor.
--
-- NE KURAR:
--   conventity_pending_members()  → bekleyenleri listeler (yalnız ekosistem admini)
--   conventity_approve_member()   → kişi + rol kaydını açar (yalnız ekosistem admini)
--
-- GÜVENLİK: ikisi de SECURITY DEFINER — `auth.users`'ı okuyabilmeleri için
--   şart. Bu yüzden gövdenin İLK işi yetki kontrolü; admin değilse 42501 ile
--   patlar, hiçbir satır dönmez. `anon`a execute verilmez; sadece
--   `authenticated` çağırabilir, o da admin değilse hata alır.
--   Onay fonksiyonu rol/kapsam parametrelerini kendi doğrular — istemciden
--   gelen değere güvenmez (CHECK'ler zaten var, burada erken ve anlaşılır
--   hata veriyoruz).
--
-- KULLANIM: 02 → 03 → 04 → 05 → **06**. Tekrar çalıştırılabilir.
-- ============================================================================

-- ---- 0) YANLIŞ PROJE KORUMASI ----------------------------------------------
do $cvguard$
declare n_org bigint; n_prof bigint;
begin
  if to_regclass('public.conventity_orgs') is null then
    raise exception E'\n\n  Bu projede sema yok — once 02_clean_install.sql calistir.\n';
  end if;
  select count(*) into n_org  from public.conventity_orgs;
  select count(*) into n_prof from public.convexus_profiles;
  if n_org > 0 or n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: conventity_orgs=% satir, convexus_profiles=% satir.\n'
      '  Temiz kurulumda ikisi de 0 olmali — burasi .org (shbwylrwpioqypbdhjgn).\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n'
      '  Hicbir sey yazilmadi.\n', n_org, n_prof;
  end if;
end $cvguard$;

-- ---- 1) BEKLEYENLER ---------------------------------------------------------
-- "Bekleyen" tanımı `conventity_is_member()` ile aynı mantığın tersi:
-- ne rolü var, ne auth_user_id ile eşleşen kişi kaydı, ne de e-posta ile
-- eşleşen kişi kaydı. Üçünden biri varsa zaten üye, listede çıkmaz.
create or replace function public.conventity_pending_members()
returns table (
  auth_user_id    uuid,
  email           text,
  created_at      timestamptz,
  email_confirmed boolean,
  last_sign_in_at timestamptz,
  full_name       text,
  org_name        text,
  country         text,
  account_type    text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
begin
  if not coalesce(public.conventity_is_admin('ecosystem'), false) then
    raise exception 'yetki yok: bekleyen kayitlari yalniz ekosistem yoneticisi gorebilir'
      using errcode = '42501';
  end if;

  return query
  select
    u.id,
    u.email::text,
    u.created_at,
    (u.email_confirmed_at is not null),
    u.last_sign_in_at,
    nullif(btrim(coalesce(u.raw_user_meta_data ->> 'username',
                          u.raw_user_meta_data ->> 'auth_person', '')), ''),
    nullif(btrim(coalesce(u.raw_user_meta_data ->> 'company_name', '')), ''),
    nullif(btrim(coalesce(u.raw_user_meta_data ->> 'country', '')), ''),
    nullif(btrim(coalesce(u.raw_user_meta_data ->> 'account_type', '')), '')
  from auth.users u
  where not exists (select 1 from public.conventity_roles r  where r.auth_user_id = u.id)
    and not exists (select 1 from public.conventity_people p where p.auth_user_id = u.id)
    and not exists (select 1 from public.conventity_people p
                     where p.email is not null and u.email is not null
                       and lower(p.email) = lower(u.email::text))
  order by u.created_at desc;
end
$fn$;

-- ---- 2) ONAYLA --------------------------------------------------------------
-- Kişi kaydı yoksa açar, e-posta ile eşleşen sahipsiz bir kayıt varsa onu
-- hesaba bağlar, sonra rolü verir. İki kez çalıştırmak ikinci bir satır açmaz.
create or replace function public.conventity_approve_member(
  p_uid   uuid,
  p_role  text default 'member',
  p_scope text default 'ecosystem'
)
returns text
language plpgsql
volatile
security definer
set search_path to 'public'
as $fn$
declare
  v_email  text;
  v_name   text;
  v_person uuid;
  v_by     uuid;
begin
  if not coalesce(public.conventity_is_admin('ecosystem'), false) then
    raise exception 'yetki yok: uye onayini yalniz ekosistem yoneticisi yapabilir'
      using errcode = '42501';
  end if;

  if p_role is null or p_role not in
     ('admin','organizer','vendor','member','owner','event_manager') then
    raise exception 'gecersiz rol: %', coalesce(p_role,'<null>') using errcode = '22023';
  end if;

  -- community/activity kapsamları bir scope_id ister; bu fonksiyon onlar için değil.
  if p_scope is null or p_scope not in
     ('ecosystem','convexus','conventus','conventlab','connectus','consultus','convergens') then
    raise exception 'gecersiz kapsam: % (community/activity icin ayri akis gerekir)',
      coalesce(p_scope,'<null>') using errcode = '22023';
  end if;

  select u.email::text,
         nullif(btrim(coalesce(u.raw_user_meta_data ->> 'username',
                               u.raw_user_meta_data ->> 'auth_person', '')), '')
    into v_email, v_name
  from auth.users u
  where u.id = p_uid;

  if not found then
    raise exception 'kullanici bulunamadi: %', p_uid using errcode = 'P0002';
  end if;

  -- kişi kaydı: önce uid, sonra e-posta, yoksa yeni
  select p.id into v_person
  from public.conventity_people p where p.auth_user_id = p_uid limit 1;

  if v_person is null and v_email is not null then
    select p.id into v_person
    from public.conventity_people p
    where p.email is not null and lower(p.email) = lower(v_email)
    limit 1;

    if v_person is not null then
      update public.conventity_people
         set auth_user_id = p_uid
       where id = v_person and auth_user_id is null;
    end if;
  end if;

  if v_person is null then
    insert into public.conventity_people (full_name, email, auth_user_id, source, source_ref)
    values (coalesce(v_name, split_part(coalesce(v_email,''), '@', 1), 'Isimsiz'),
            v_email, p_uid, 'frontdoor', 'signup:' || p_uid::text)
    returning id into v_person;
  end if;

  -- rol: aynısı varsa yeniden açma, yalnız aktifleştir
  if exists (select 1 from public.conventity_roles r
              where r.auth_user_id = p_uid and r.scope = p_scope and r.role = p_role) then
    update public.conventity_roles
       set status = 'active'
     where auth_user_id = p_uid and scope = p_scope and role = p_role
       and status is distinct from 'active';
    return 'zaten onayli';
  end if;

  select p.id into v_by
  from public.conventity_people p where p.auth_user_id = auth.uid() limit 1;

  insert into public.conventity_roles
    (person_id, auth_user_id, scope, role, status, granted_by, source_ref)
  values
    (v_person, p_uid, p_scope, p_role, 'active', v_by,
     'approve:' || p_uid::text || ':' || p_scope || ':' || p_role);

  return 'onaylandi';
end
$fn$;

-- ---- 3) YETKİLER ------------------------------------------------------------
-- anon hiçbir şekilde çağıramaz. authenticated çağırabilir ama gövdedeki
-- admin kontrolüne takılır — yetki kontrolü tek yerde, fonksiyonun içinde.
-- `from public` tek basina yetmez: Supabase `anon`a DOGRUDAN yetki veriyor,
-- o ayrica geri alinmali. (Bu dosyanin ilk surumunde eksikti; `07` genel
-- cozumu kuruyor, burasi kendi basina da dogru olsun diye tekrarliyor.)
revoke all on function public.conventity_pending_members()                 from public, anon;
revoke all on function public.conventity_approve_member(uuid, text, text)  from public, anon;
grant execute on function public.conventity_pending_members()                to authenticated;
grant execute on function public.conventity_approve_member(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

-- ---- 4) DOĞRULAMA -----------------------------------------------------------
select 'fonksiyon' as nesne, p.proname as ad,
       case p.prosecdef when true then 'SECURITY DEFINER' else 'invoker' end as mod,
       array_to_string(p.proacl::text[], ' ') as yetkiler
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('conventity_pending_members','conventity_approve_member')
order by 2;
