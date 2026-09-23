-- ============================================================================
-- 07_harden_functions_ROLLBACK.sql  ·  07'yi geri alır
--
-- Supabase'in varsayılanına döner: public şemasındaki tüm fonksiyonlar
-- anon'a da çağrılabilir olur.
--
-- DİKKAT: bu, iç yetki kontrolü olmayan 9 SECURITY DEFINER fonksiyonu
-- (connectus_directory, connectus_post_comments, convexus_import_pool_to_event,
-- conventus_clone_rating_dims, conventus_sel_clone_default_form, …) yeniden
-- anon anahtarıyla internetten çağrılabilir hale getirir. Yalnızca 07 bir
-- sayfayı kırdıysa ve nedenini teşhis etmek için geçici olarak kullan.
-- ============================================================================

do $cvblock$
declare r record;
begin
  for r in
    select p.proname, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('grant execute on function public.%I(%s) to anon', r.proname, r.args);
  end loop;
end $cvblock$;

alter default privileges in schema public grant execute on functions to anon;
alter default privileges for role postgres in schema public grant execute on functions to anon;
