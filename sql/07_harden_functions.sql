-- ============================================================================
-- 07_harden_functions.sql  ·  anon'un fonksiyon yetkilerini daraltır
--
-- NASIL ORTAYA ÇIKTI: `06_pending_members.sql` çalıştırıldıktan sonra
-- doğrulama çıktısı `anon=X/postgres` gösterdi — yani `anon`, ekosistem
-- yöneticisine özel iki fonksiyonu da çağırabiliyordu. Sebep: `06`'daki
-- `revoke all ... from public` bir role DOĞRUDAN verilmiş yetkiyi kaldırmaz,
-- Supabase ise `alter default privileges ... grant all on functions to anon,
-- authenticated, service_role` ile geliyor. Yani `public` şemasında açılan
-- HER fonksiyon anon'a çağrılabilir doğuyor.
--
-- `06` için sonuç sızıntı değildi (gövdenin ilk satırı admin kontrolü, anon
-- 42501 alıyor) ama aynı varsayılan başka fonksiyonlarda ciddi:
-- `public` şemasında iç yetki kontrolü OLMAYAN 9 SECURITY DEFINER fonksiyon
-- var ve definer oldukları için RLS'i atlıyorlar —
--   okuma : connectus_directory, connectus_org_detail, connectus_post_comments,
--           conventity_in_community, conventity_uid_in_community,
--           gm_provider_accredited
--   yazma : conventus_clone_rating_dims, conventus_sel_clone_default_form,
--           convexus_import_pool_to_event
-- PostgREST fonksiyonları /rest/v1/rpc/<ad> olarak açtığı için bunlar
-- internetten anon anahtarıyla çağrılabilirdi. (Şu an şema boş olduğu için
-- eldeki veri yok; veri geldikçe anlamı büyür — launch öncesi kapatılmalı.)
--
-- KARAR: `anon`ın çağırması gereken fonksiyon YOK. Girişten önce açılan
-- sayfaların (index · login · register · forgot/reset-password · verified ·
-- verified-directory · under-construction) hiçbiri RPC çağırmıyor; erişim
-- talebi formu da düz tablo INSERT'i kullanıyor. Depodaki tüm `.rpc(` çağrıları
-- oturum açmış sayfalardan geliyor.
--
-- ÖNEMLİ İSTİSNA — RLS POLİTİKALARINDA ÇAĞRILAN FONKSİYONLAR:
-- Politika ifadesinin içindeki fonksiyon, sorguyu ATAN rolün yetkisiyle
-- çalışır. `anon`dan EXECUTE'u topluca alırsan `conventus_managed_events`
-- gibi tablolara yapılan okuma "0 satır" yerine
-- `permission denied for function is_cv_admin` ile PATLAR — yani kamuya açık
-- sayfalar kırılır. (İlk denememde bunu kaçırdım: yalnız `anon`dan geri
-- almıştım, `PUBLIC` yetkisi hâlâ durduğu için politika çalışmaya devam
-- etmiş ve testi yanıltmıştı. İkinci turda yakalandı.)
--
-- Bu yüzden beyaz liste ELLE YAZILMIYOR, `pg_policies`ten TÜRETİLİYOR:
-- bir fonksiyonun adı herhangi bir politika ifadesinde geçiyorsa EXECUTE'u
-- korunur. Politikalar değişince liste kendiliğinden güncellenir, unutulmaz.
-- Korunanların hepsi boolean/uid döndüren kapı bekçileri (is_admin,
-- can_manage_*, is_group_member, …) — veri kümesi döndürmezler.
--
-- KULLANIM: 02 → 03 → 04 → 05 → 06 → **07**. Tekrar çalıştırılabilir.
-- Geri alma: 07_harden_functions_ROLLBACK.sql
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

-- ---- 1) anon'dan EXECUTE'u geri al -----------------------------------------
-- İKİ AYRI KANAL kapatılmalı, yoksa iş görmez:
--   a) Supabase'in `anon`a verdiği DOĞRUDAN yetki, ve
--   b) PostgreSQL'in her fonksiyona varsayılan verdiği `PUBLIC` yetkisi —
--      `anon` bunu rol olarak devralır. Yalnız (a)'yı geri almak hiçbir şey
--      değiştirmez; ilk denemede tam bu oldu, testte yakalandı.
-- `PUBLIC` kalktığı için `authenticated` ve `service_role`'a EXECUTE açıkça
-- yeniden verilir — onların erişimi değişmemeli.
--
-- Beyaz liste şimdilik boş. Girişten önce çağrılması gereken bir RPC
-- eklenirse adını `keep` dizisine yaz — tek yer burası, dağılmasın.
do $cvblock$
declare
  r      record;
  keep   text[];
  -- Elle eklenecek istisnalar (girişten önce çağrılması gereken bir RPC
  -- çıkarsa buraya yaz ve nedenini yorumla). Şimdilik gerek yok: girişsiz
  -- açılan sayfaların hiçbiri RPC çağırmıyor.
  manual constant text[] := array[]::text[];
  n_rev  int := 0;
  n_kept int := 0;
begin
  -- Politika ifadelerinde adı geçen public fonksiyonlar — anon bunları
  -- çağıramazsa RLS'li okumalar yetki hatasıyla patlar.
  select coalesce(array_agg(distinct m[1]), '{}'::text[])
    into keep
  from pg_policies pol,
       lateral regexp_matches(coalesce(pol.qual, '') || ' ' || coalesce(pol.with_check, ''),
                              '([a-z_][a-z0-9_]*)\(', 'g') m
  where pol.schemaname = 'public'
    and exists (select 1 from pg_proc f
                join pg_namespace fn on fn.oid = f.pronamespace
                where fn.nspname = 'public' and f.proname = m[1]);

  keep := keep || manual;

  for r in
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and not exists (select 1 from pg_depend d
                       where d.objid = p.oid and d.deptype = 'e')   -- eklenti fonksiyonları hariç
    order by 2
  loop
    execute format('revoke execute on function public.%I(%s) from public, anon',
                   r.proname, r.args);
    execute format('grant execute on function public.%I(%s) to authenticated, service_role',
                   r.proname, r.args);
    if r.proname = any (keep) then
      execute format('grant execute on function public.%I(%s) to anon', r.proname, r.args);
      n_kept := n_kept + 1;
    else
      n_rev := n_rev + 1;
    end if;
  end loop;
  raise notice 'fonksiyon: anon''dan geri alinan %, politika gerekli oldugu icin korunan %', n_rev, n_kept;
end $cvblock$;

-- ---- 2) GELECEKTEKİ FONKSİYONLAR -------------------------------------------
-- Yeni fonksiyon artık anon'a kapalı doğsun. Açılması gerekiyorsa ilgili
-- migration açıkça `grant execute ... to anon` yazar ve nedenini yorumlar.
alter default privileges in schema public revoke execute on functions from public, anon;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon;
alter default privileges in schema public grant execute on functions to authenticated, service_role;
alter default privileges for role postgres in schema public grant execute on functions to authenticated, service_role;

-- ---- 3) DOĞRULAMA -----------------------------------------------------------
-- TEK sorgu: Supabase SQL Editor yalnız son ifadenin sonucunu gösteriyor,
-- ayrı SELECT'ler yazınca üsttekiler kayboluyor.
-- Eklenti fonksiyonları (pgcrypto vb.) sayılmaz.
with f as (
  select p.oid
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
),
pol as (   -- politika ifadelerinde adı geçen, yani anon'da KALMASI gereken fonksiyonlar
  select distinct p.oid
  from f join pg_proc p on p.oid = f.oid
  where exists (
    select 1 from pg_policies pl,
         lateral regexp_matches(coalesce(pl.qual,'') || ' ' || coalesce(pl.with_check,''),
                                '([a-z_][a-z0-9_]*)\(', 'g') m
    where pl.schemaname = 'public' and m[1] = p.proname)
)
select
  (select count(*) from f)                                                        as "public fonksiyon",
  (select count(*) from f where has_function_privilege('anon', f.oid, 'EXECUTE')) as "anon cagirabilir",
  (select count(*) from pol)                                                      as "politika bekcisi (beklenen)",
  (select count(*) from f
    where has_function_privilege('anon', f.oid, 'EXECUTE')
      and f.oid not in (select oid from pol))                                     as "ACIKTA KALAN (0 olmali)",
  (select count(*) from f where has_function_privilege('authenticated', f.oid, 'EXECUTE'))
                                                                                  as "authenticated (degismemeli)";
