-- 23_marketplace_approval.sql
-- Pazar yeri onay kuyrugu: hizmet saglayici teklif girer -> ETKINLIK YONETICISI
-- karara baglar -> katilimciya gorunur.
--
-- BUGUNKU DURUM (olculdu, uydurulmadi):
--   * Saglayici kendi teklifini onaylayamiyor. gmo_owner_update'in WITH CHECK'i
--     saglayiciyi draft|pending ile siniriyor. DOGRU yazilmis, dokunmuyoruz.
--   * Ama gm_offers'ta ETKINLIK YONETICISI icin HIC politika yok:
--       - yonetici bekleyen teklifi GOREMIYOR (0 satir)
--       - yonetici teklifi ONAYLAYAMIYOR (pending'de kaliyor)
--     Yani kuyruk hem gorunmez hem onaylanamaz. Eksik olan "onaylayan".
--
-- EKLENEN
--   1) gmo_manager_read   — yonetici KENDI etkinliginin tekliflerini gorur
--   2) gmo_manager_decide — yonetici yalnizca approved|rejected'a cevirir;
--                           teklifin ICERIGINI degistiremez (saglayicinin sozu)
--   3) bildirim — teklif geldi -> yoneticiye; karar verildi -> saglayiciya
--
-- Idempotent.

begin;

-- ---------------------------------------------------------------------------
-- 0) KATILIMCI OKUMASI BOZUKTU
--    gmo_auth_read_approved, akreditasyonu gm_providers'a BAKARAK soruyordu:
--
--      exists (select 1 from gm_providers p
--               where p.id = gm_offers.provider_id and p.accredited = true)
--
--    Ama gm_providers'ta yalnizca "gmp_owner_read" var: satiri SADECE sahibi
--    okuyabiliyor. Politika icindeki alt sorgu da cagiranin haklariyla
--    calistigi icin bu EXISTS, saglayicinin kendisi disinda HERKES icin
--    false donuyordu. Sonuc: onaylanmis hicbir teklif hicbir katilimciya
--    GORUNMUYORDU. (Olculdu; tahmin degil.)
--
--    gm_providers'i okumaya acmak cozum DEGIL: o tabloda commission_rate,
--    contract_fee, contract_note gibi ticari veri var. Zaten bu yuzden
--    gm_providers_public gorunumu ve SECURITY DEFINER olan
--    gm_provider_accredited(uuid) yardimcisi var — gm_inventory'nin anon
--    politikasi dogru sekilde onu kullaniyor. Teklif politikasi kullanmiyordu.
--    Ayni yardimciya cekiyoruz: yalnizca "akredite mi" biti disari cikar,
--    ticari alanlar kapali kalir.
-- ---------------------------------------------------------------------------
drop policy if exists gmo_auth_read_approved on public.gm_offers;
create policy gmo_auth_read_approved on public.gm_offers
  for select to authenticated
  using (status = 'approved'
         and coalesce(public.gm_provider_accredited(provider_id), false));

-- ---------------------------------------------------------------------------
-- 1) Yonetici okuma
-- ---------------------------------------------------------------------------
drop policy if exists gmo_manager_read on public.gm_offers;
create policy gmo_manager_read on public.gm_offers
  for select to authenticated
  using (exists (
    select 1 from public.conventus_managed_events e
     where e.id = gm_offers.event_id
       and public.conventity_can_manage_event(e.activity_id)));

-- ---------------------------------------------------------------------------
-- 2) Yonetici karari
--    USING: yalnizca karar bekleyen teklif (draft saglayicinin ozel alani).
--    WITH CHECK: yalnizca approved|rejected'a cikilabilir.
--    Icerik degismezligi trigger ile: politika OLD/NEW karsilastiramaz.
-- ---------------------------------------------------------------------------
drop policy if exists gmo_manager_decide on public.gm_offers;
create policy gmo_manager_decide on public.gm_offers
  for update to authenticated
  using (
    status in ('pending','approved','rejected')
    and exists (select 1 from public.conventus_managed_events e
                 where e.id = gm_offers.event_id
                   and public.conventity_can_manage_event(e.activity_id)))
  with check (
    status in ('approved','rejected')
    and exists (select 1 from public.conventus_managed_events e
                 where e.id = gm_offers.event_id
                   and public.conventity_can_manage_event(e.activity_id)));

-- ---------------------------------------------------------------------------
-- 3) Yonetici teklifin ICERIGINI degistiremez
--    Onay, saglayicinin yazdigi sozun onayidir. Yonetici metni degistirip
--    "onayladim" derse ortada saglayicinin kabul etmedigi bir teklif kalir.
-- ---------------------------------------------------------------------------
create or replace function public.gm_offer_decide_guard()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_sahip boolean := false;
begin
  if auth.uid() is null then
    return new;   -- sunucu tarafi is
  end if;

  select exists (select 1 from public.gm_providers p
                  where p.id = old.provider_id and p.owner_user_id = auth.uid())
    into v_sahip;
  if v_sahip then
    return new;   -- saglayici kendi teklifinde; sinirini RLS ciziyor
  end if;

  -- Buradan asagisi: yonetici (ya da yetkisiz; onu RLS zaten durdurur).
  if new.title       is distinct from old.title
  or new.body        is distinct from old.body
  or new.tag         is distinct from old.tag
  or new.tag_other   is distinct from old.tag_other
  or new.price_note  is distinct from old.price_note
  or new.price_amount is distinct from old.price_amount
  or new.currency    is distinct from old.currency
  or new.date_from   is distinct from old.date_from
  or new.date_to     is distinct from old.date_to
  or new.provider_id is distinct from old.provider_id
  or new.event_id    is distinct from old.event_id then
    raise exception
      'Teklifin icerigi yonetici tarafindan degistirilemez; yalnizca onay/red verilir. Duzeltme gerekiyorsa teklifi reddedin.'
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_gm_offer_decide_guard on public.gm_offers;
create trigger trg_gm_offer_decide_guard
  before update on public.gm_offers
  for each row execute function public.gm_offer_decide_guard();

-- ---------------------------------------------------------------------------
-- 4) Bildirim: teklif geldi / karar verildi
--    20_notifications.sql'deki kuyrugu kullanir (ayni transaction, dedupe'li).
-- ---------------------------------------------------------------------------
create or replace function public.gm_offer_notify()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_ev  record;
  v_pr  record;
  v_p   jsonb;
begin
  select e.id, e.code, e.title, e.community_id, e.activity_id, e.poc_email, e.poc_name
    into v_ev from public.conventus_managed_events e where e.id = new.event_id;
  if not found then return new; end if;

  select p.name, p.contact_email into v_pr
    from public.gm_providers p where p.id = new.provider_id;

  v_p := jsonb_build_object(
    'offer_id',      new.id,
    'offer_title',   new.title,
    'provider_name', coalesce(v_pr.name,'—'),
    'event_code',    v_ev.code,
    'event_title',   v_ev.title,
    'status',        new.status);

  -- saglayici teklifi sundu -> yonetici
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    perform public.conventity_enqueue_mail(
      'mgr_offer_submitted', v_ev.poc_email, v_ev.poc_name, 'tr',
      v_ev.community_id, v_ev.activity_id, v_ev.id, v_p,
      'mgr_offer_submitted:' || new.id::text);

  -- yonetici karar verdi -> saglayici
  elsif tg_op = 'UPDATE' and new.status in ('approved','rejected')
        and old.status is distinct from new.status then
    perform public.conventity_enqueue_mail(
      'offer_' || new.status, v_pr.contact_email, v_pr.name, 'tr',
      v_ev.community_id, v_ev.activity_id, v_ev.id, v_p,
      'offer_' || new.status || ':' || new.id::text);
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_gm_offer_notify on public.gm_offers;
create trigger trg_gm_offer_notify
  after insert or update on public.gm_offers
  for each row execute function public.gm_offer_notify();

commit;

-- ---------------------------------------------------------------------------
-- DOGRULAMA
-- ---------------------------------------------------------------------------
select
  (select count(*) from pg_policies
    where tablename='gm_offers' and policyname='gmo_manager_read')        as "yonetici okuma (1)",
  (select count(*) from pg_policies
    where tablename='gm_offers' and policyname='gmo_manager_decide')      as "yonetici karari (1)",
  (select count(*) from pg_trigger
    where tgrelid='public.gm_offers'::regclass
      and tgname='trg_gm_offer_decide_guard')                            as "icerik kilidi (1)",
  (select count(*) from pg_trigger
    where tgrelid='public.gm_offers'::regclass
      and tgname='trg_gm_offer_notify')                                  as "bildirim (1)",
  (select count(*) from pg_policies where tablename='gm_offers')          as "toplam politika (7)",
  (select count(*) from pg_policies
    where tablename='gm_offers' and policyname='gmo_auth_read_approved'
      and qual like '%gm_provider_accredited%')                             as "katilimci okumasi onarildi (1)";
