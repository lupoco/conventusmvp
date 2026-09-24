-- ============================================================================
-- 05_harden_grants_ROLLBACK.sql  ·  05'i geri alır
--
-- 02_clean_install.sql'deki yetki durumuna döner: public şemasındaki her tablo
-- ve view'de anon/authenticated/service_role → grant all.
--
-- DİKKAT: bu, 05'in kapattığı açığı geri açar — anon, otomatik-güncellenebilir
-- view'ler (gm_providers_public, convexus_demand_signals_public,
-- conventus_selection_verification_status) üzerinden RLS'i atlayarak taban
-- tabloya yazabilir hale gelir. Yalnızca 05 bir sayfayı kırdıysa ve nedenini
-- teşhis etmek için geçici olarak kullan.
--
-- SONRASINDA: kendi `revoke ... from anon` satırları olan HER dosyayı tekrar
--             çalıştır — bu dosya her tabloya `grant all` verdiği için onları
--             da siliyor ve `05` SELECT'e dokunmadığı için geri getirmiyor:
--               · sql/04_access_requests.sql   (erişim talepleri)
--               · sql/09_registration_wizard.sql (onay / parkur tabloları)
--             Yeni bir migration kendi yetkisini daraltıyorsa bu listeye ekle.
-- ============================================================================

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
alter default privileges for role postgres in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to anon, authenticated, service_role;
