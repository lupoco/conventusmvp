-- 22_tenant_branding.sql
-- Beyaz etiket: kurumsal kimlik KOD degil YAPILANDIRMA.
--
-- demo/beyaz-etiket-demo.html'de onaylanan alti kolon. Temel palet (krem
-- zemin, lacivert metin) sabit kalir; kiraciya gore degisen yalnizca vurgu
-- rengi, gonderen adi, rozet, dil ve acik moduller. Boylece sayfa musterinin
-- kurumuna ait hissettirir ama tasarim butunlugu ve MERKEZI BAKIM bozulmaz:
-- musteriye ozel kod dali acmiyoruz.
--
-- Idempotent.

begin;

-- ---------------------------------------------------------------------------
-- 1) Kiraci kimligi
-- ---------------------------------------------------------------------------
alter table public.conventus_communities
  add column if not exists brand_accent     text,
  add column if not exists brand_accent_ink text not null default '#ffffff',
  add column if not exists mail_from_name   text,
  add column if not exists show_badge       boolean not null default true,
  add column if not exists default_lang     text not null default 'tr',
  add column if not exists modules          text[] not null default '{}'::text[];

-- Renk gercekten renk olsun: istemci bunu dogrudan CSS'e yaziyor.
-- Dogrulanmamis bir deger stil enjeksiyonuna acik kapi birakirdi.
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname='comm_brand_accent_ck'
                    and conrelid='public.conventus_communities'::regclass) then
    alter table public.conventus_communities
      add constraint comm_brand_accent_ck
      check (brand_accent is null or brand_accent ~ '^#[0-9A-Fa-f]{6}$');
  end if;
  if not exists (select 1 from pg_constraint
                  where conname='comm_brand_ink_ck'
                    and conrelid='public.conventus_communities'::regclass) then
    alter table public.conventus_communities
      add constraint comm_brand_ink_ck
      check (brand_accent_ink ~ '^#[0-9A-Fa-f]{6}$');
  end if;
  if not exists (select 1 from pg_constraint
                  where conname='comm_default_lang_ck'
                    and conrelid='public.conventus_communities'::regclass) then
    alter table public.conventus_communities
      add constraint comm_default_lang_ck
      check (default_lang in ('tr','en'));
  end if;
end $$;

comment on column public.conventus_communities.brand_accent is
  'Kiracinin tek vurgu rengi (#RRGGBB). Istemci --pf belirtecine yazar.';
comment on column public.conventus_communities.show_badge is
  '"Conventity ile guclendirilmistir" rozeti. Varsayilan acik; musteri talebiyle kapatilabilir.';
comment on column public.conventus_communities.modules is
  'Acik ozellikler (protocol, go_and_meet, marketplace). Musteriye gore kapatilir — kod dali degil.';

-- ---------------------------------------------------------------------------
-- 2) Musteri acma: tek islem
--    Elle SQL her yeni musteride hata riski; merkezi bakim sozunu ilk bozan
--    sey odur. Topluluk + yonetici rolu birlikte kurulur, yarida kalirsa
--    hicbiri yazilmaz (tek transaction).
-- ---------------------------------------------------------------------------
create or replace function public.conventity_provision_tenant(
  p_slug          text,
  p_name          text,
  p_short_name    text    default null,
  p_domain        text    default null,
  p_contact_email text    default null,
  p_brand_accent  text    default null,
  p_admin_email   text    default null,
  p_modules       text[]  default '{}'::text[],
  p_tagline       text    default null,
  p_default_lang  text    default 'tr'
) returns uuid
language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_id       uuid;
  v_admin_id uuid;
begin
  -- KAPI: yalnizca ekosistem yoneticisi musteri acabilir.
  if not public.conventity_is_admin('ecosystem') then
    raise exception 'Yalnizca ekosistem yoneticisi kiraci acabilir.'
      using errcode = '42501';
  end if;

  if p_slug !~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$' then
    raise exception 'slug: kucuk harf, rakam ve tire; 3-40 karakter (gelen: %)', p_slug
      using errcode = '22023';
  end if;
  if coalesce(trim(p_name),'') = '' then
    raise exception 'name zorunlu.' using errcode = '22023';
  end if;
  if p_brand_accent is not null and p_brand_accent !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'brand_accent #RRGGBB olmali (gelen: %)', p_brand_accent
      using errcode = '22023';
  end if;

  insert into public.conventus_communities
    (slug, name, short_name, tagline, domain, contact_email,
     brand_accent, mail_from_name, default_lang, modules,
     visibility, is_active, provisioned_by, provisioned_at,
     source_ref)
  values
    (p_slug, trim(p_name), coalesce(p_short_name, upper(left(p_name, 8))), p_tagline,
     p_domain, p_contact_email, p_brand_accent,
     coalesce(p_short_name, trim(p_name)), coalesce(p_default_lang,'tr'),
     coalesce(p_modules,'{}'::text[]),
     'public', true, auth.uid(), now(),
     'tenant:' || p_slug)
  on conflict (slug) do update
     set name           = excluded.name,
         short_name     = excluded.short_name,
         tagline        = coalesce(excluded.tagline, conventus_communities.tagline),
         domain         = coalesce(excluded.domain, conventus_communities.domain),
         contact_email  = coalesce(excluded.contact_email, conventus_communities.contact_email),
         brand_accent   = coalesce(excluded.brand_accent, conventus_communities.brand_accent),
         mail_from_name = coalesce(excluded.mail_from_name, conventus_communities.mail_from_name),
         default_lang   = excluded.default_lang,
         modules        = excluded.modules,
         updated_at     = now()
  returning id into v_id;

  -- Yonetici rolu: adres verilmisse ve o adresin bir hesabi varsa baglanir.
  -- Hesap yoksa SESSIZCE GECILMEZ — cagirana bildirilir.
  if p_admin_email is not null then
    select u.id into v_admin_id from auth.users u
     where lower(u.email) = lower(trim(p_admin_email));
    if v_admin_id is null then
      raise warning 'Yonetici hesabi bulunamadi (%): kiraci acildi ama rol ATANMADI. Hesap olusunca rolu elle verin.',
        p_admin_email;
    else
      insert into public.conventity_roles (auth_user_id, scope, scope_id, role, status)
      select v_admin_id, 'community', v_id, 'admin', 'active'
       where not exists (
         select 1 from public.conventity_roles
          where auth_user_id = v_admin_id and scope='community'
            and scope_id = v_id and role='admin');
    end if;
  end if;

  return v_id;
end;
$fn$;

revoke execute on function public.conventity_provision_tenant(
  text,text,text,text,text,text,text,text[],text,text) from public, anon;
grant execute on function public.conventity_provision_tenant(
  text,text,text,text,text,text,text,text[],text,text) to authenticated;

commit;

-- ---------------------------------------------------------------------------
-- DOGRULAMA
-- ---------------------------------------------------------------------------
select
  (select count(*) from information_schema.columns
    where table_name='conventus_communities'
      and column_name in ('brand_accent','brand_accent_ink','mail_from_name',
                          'show_badge','default_lang','modules'))       as "yeni kolon (6)",
  (select count(*) from pg_constraint
    where conrelid='public.conventus_communities'::regclass
      and conname in ('comm_brand_accent_ck','comm_brand_ink_ck',
                      'comm_default_lang_ck'))                          as "kisit (3)",
  (select count(*) from pg_proc
    where proname='conventity_provision_tenant')                        as "RPC (1)";
