-- 18_reg_self_service.sql
-- Katilimci self-servis (gorme / duzenleme / iptal) icin guvenli yazma siniri.
--
-- NEDEN: "reg: own update" politikasi USING/CHECK olarak yalnizca
-- (auth.uid() = user_id) diyor. Hicbir RESTRICTIVE politika, hicbir trigger
-- status degisimini sinirlamiyordu. Kanitlandi: katilimci kendi kaydini
-- 'approved' yapabiliyordu. Iptal/duzenleme arayuzu tam da bu yolun ustune
-- kurulacagi icin once sinir cizilir.
--
-- YONTEM: RESTRICTIVE politika OLD satiri goremez (WITH CHECK yalnizca NEW
-- gorur), bu yuzden gecis kurali BEFORE UPDATE trigger'i ile kurulur.
-- Trigger politikadan bagimsiz calisir; gercek sinir odur.
--
-- Idempotent.

begin;

-- ---------------------------------------------------------------------------
-- 1) Katilimcinin kendi kaydinda neyi degistirebilecegi
-- ---------------------------------------------------------------------------
create or replace function public.conventus_reg_self_guard()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_uid        uuid := auth.uid();
  v_yonetici   boolean := false;
  -- karar oncesi durumlar: katilimci hala kendi verisini duzeltebilir
  k_duzenlenebilir constant text[] :=
    array['invited','draft','submitted','under_review','waitlisted'];
  -- katilimcinin kendi elinden birakabilecegi durumlar
  k_iptal_edilebilir constant text[] :=
    array['invited','draft','submitted','under_review','waitlisted','approved'];
begin
  -- Sunucu tarafi is (trigger zinciri, seed, servis anahtari) serbest.
  if v_uid is null then
    return new;
  end if;

  -- Etkinligi yonetebilen kisi icin bu guard yok; onun sinirini RLS cizer.
  begin
    v_yonetici := public.conventity_can_manage_event(coalesce(new.activity_id, old.activity_id));
  exception when others then
    v_yonetici := false;
  end;
  if v_yonetici then
    return new;
  end if;

  -- Buradan asagisi: satirin sahibi olan sivil katilimci.
  if old.user_id is distinct from v_uid then
    return new;  -- sahibi degil; erisimi zaten RLS reddeder
  end if;

  -- 1a) Kimlik/baglanti kolonlari katilimci tarafindan degistirilemez.
  if new.id                is distinct from old.id
  or new.event_id          is distinct from old.event_id
  or new.activity_id       is distinct from old.activity_id
  or new.user_id           is distinct from old.user_id
  or new.registered_by     is distinct from old.registered_by
  or new.person_id         is distinct from old.person_id
  or new.org_id            is distinct from old.org_id
  or new.confirmation_code is distinct from old.confirmation_code
  or new.created_at        is distinct from old.created_at then
    raise exception
      'Bu alanlar kayit sahibi tarafindan degistirilemez (kimlik/baglanti kolonlari).'
      using errcode = '42501';
  end if;

  -- 1b) Protokol sirasini belirleyen alanlar da katilimcinin elinde degil.
  --     (kendini onde gosterme yolu kapanir)
  if new.is_guest_of_honour is distinct from old.is_guest_of_honour then
    raise exception 'Onur konugu isareti yalnizca organizator tarafindan konur.'
      using errcode = '42501';
  end if;

  -- 1c) Durum gecisi: yalnizca iptal. Onay/red/check-in organizatorundur.
  if new.status is distinct from old.status then
    if new.status = 'cancelled' and old.status = any (k_iptal_edilebilir) then
      null;  -- izinli: kendi kaydini geri cekiyor
    else
      raise exception
        'Kayit durumunu yalnizca organizator degistirebilir; kayit sahibi yalnizca iptal edebilir (% -> %).',
        old.status, new.status
        using errcode = '42501';
    end if;
  end if;

  -- 1d) Karar verilmis/kapanmis kayitta icerik duzenlemesi yok.
  --     (onay sonrasi pasaport/isim degisimi yaka karti ve giris listesini bozar)
  if old.status <> all (k_duzenlenebilir)
     and not (new.status = 'cancelled' and old.status is distinct from 'cancelled') then
    if to_jsonb(new) - 'status' is distinct from to_jsonb(old) - 'status' then
      raise exception
        'Kayit "%" durumunda; degisiklik icin organizatore basvurun.', old.status
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$fn$;

comment on function public.conventus_reg_self_guard() is
  'Kayit sahibinin kendi satirinda yapabilecegi degisikligi sinirlar: onay/red/check-in yok, yalnizca iptal; kimlik ve protokol kolonlari sabit.';

drop trigger if exists trg_conventus_reg_self_guard on public.conventus_registrations;
create trigger trg_conventus_reg_self_guard
  before update on public.conventus_registrations
  for each row execute function public.conventus_reg_self_guard();

-- ---------------------------------------------------------------------------
-- 2) Katilimcinin kendi kayitlarini listelemesi icin gorunum
--    (etkinlik adi/tarihi ile birlikte; RLS cagiran kullaniciya gore isler)
-- ---------------------------------------------------------------------------
drop view if exists public.conventus_my_registrations_v;
create view public.conventus_my_registrations_v
with (security_invoker = true) as
select
  r.id,
  r.activity_id,
  r.event_id,
  r.status,
  r.reg_type,
  r.confirmation_code,
  r.created_at,
  r.first_name,
  r.last_name,
  r.email,
  r.institution,
  e.code        as event_code,
  e.title       as event_title,
  e.start_date  as event_start_date,
  e.end_date    as event_end_date,
  e.location    as event_location,
  e.city        as event_city,
  e.country     as event_country,
  e.community_id,
  (r.status = any (array['invited','draft','submitted','under_review','waitlisted']))
                as can_edit,
  (r.status = any (array['invited','draft','submitted','under_review','waitlisted','approved']))
                as can_cancel
from public.conventus_registrations r
left join public.conventus_managed_events e on e.activity_id = r.activity_id
where r.user_id = auth.uid();

comment on view public.conventus_my_registrations_v is
  'Oturum sahibinin kendi kayitlari + etkinlik ozeti + can_edit/can_cancel bayraklari.';

grant select on public.conventus_my_registrations_v to authenticated;

commit;

-- ---------------------------------------------------------------------------
-- DOGRULAMA
-- ---------------------------------------------------------------------------
select
  (select count(*) from pg_trigger
    where tgrelid = 'public.conventus_registrations'::regclass
      and tgname  = 'trg_conventus_reg_self_guard')            as "guard trigger (1)",
  (select count(*) from pg_views
    where schemaname='public' and viewname='conventus_my_registrations_v') as "gorunum (1)",
  (select c.reloptions::text from pg_class c
    where c.oid = 'public.conventus_my_registrations_v'::regclass)         as "security_invoker";
