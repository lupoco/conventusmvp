-- RLS deseni nobetcisi: "sahibi" ile "yoneteni" karistirma hatasi geri gelmesin.
--
-- Bu hata projede DORT kez cikti (conventus_managed_events UPDATE ve SELECT,
-- gm_plan SELECT, sonra toplu taramada conventus_sessions / _announcements /
-- _invitations). Hicbirinde hata mesaji yok: okumada bos liste, yazmada
-- sessiz basari gorunur. Bu yuzden nobetci test.
--
-- KURAL: event_id tasiyan bir tabloda bir islem icin yetki
--   `created_by = auth.uid()` ile tanimlanmissa, ayni islem icin
--   conventity_can_manage_event cagiran bir politika da OLMALI.
--   (`for all` politikalari her islemin kapsayicisi sayilir.)
\set ON_ERROR_STOP on

do $$
declare n int; liste text;
begin
  with et as (
    select distinct c.relname tbl from pg_attribute a
     join pg_class c on c.oid=a.attrelid join pg_namespace ns on ns.oid=c.relnamespace
     where ns.nspname='public' and c.relkind='r' and a.attnum>0 and not a.attisdropped
       and a.attname='event_id'
  ), p as (
    select tablename, cmd, coalesce(qual,'')||' '||coalesce(with_check,'') g
      from pg_policies where schemaname='public'
  ), islem as (
    select distinct tablename, cmd from p join et on et.tbl=p.tablename where cmd <> 'ALL'
  ), acik as (
    select i.tablename, i.cmd
      from islem i
     where exists (select 1 from p where p.tablename=i.tablename and p.cmd=i.cmd
                     and p.g ~ 'created_by\s*=\s*auth\.uid')
       and not exists (select 1 from p where p.tablename=i.tablename
                         and (p.cmd=i.cmd or p.cmd='ALL')
                         and p.g like '%can_manage_event%')
  )
  select count(*), coalesce(string_agg(tablename||'.'||cmd, ', '), '') into n, liste from acik;

  if n > 0 then
    raise exception E'\n\nRLS DESENI HATASI: % yerde yetki yalniz SAHIPLIK ile tanimli,\n'
      'etkinligi YONETEN ama olusturmamis kullanici disarida kaliyor:\n  %\n\n'
      'Cozum: ilgili tabloya conventity_can_manage_event(e.activity_id) kullanan\n'
      'bir politika ekle (bkz. sql/17_rls_manager_gaps.sql).\n', n, liste;
  end if;
  raise notice '   event_id tasiyan tablolarda sahiplik/yoneticilik acigi yok';
end $$;

-- Ikinci nobetci: yonetici politikalari gercekten ISE YARIYOR mu — yani
-- conventity_can_manage_event anon'a da acik mi? (07'nin beyaz listesi)
do $$ declare ok boolean; begin
  select has_function_privilege('anon', p.oid, 'execute') into ok
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='conventity_can_manage_event' limit 1;
  if not coalesce(ok,false) then
    raise exception 'conventity_can_manage_event anon''a kapali — anon okumalari "permission denied for function" ile patlar';
  end if;
  raise notice '   conventity_can_manage_event politikalardan cagrilabilir';
end $$;

select '== RLS NOBETCISI GECTI ==';
