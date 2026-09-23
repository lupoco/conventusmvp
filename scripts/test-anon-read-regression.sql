-- anon, SELECT yetkisi olan HER tabloyu/view'i okuyabiliyor mu?
-- 07'den sonra politika icindeki bir fonksiyon yuzunden patlayan var mi?
do $$
declare r record; n_ok int:=0; n_err int:=0; bad text:='';
begin
  for r in select c.relname, c.relkind from pg_class c
           join pg_namespace n on n.oid=c.relnamespace
           where n.nspname='public' and c.relkind in ('r','v')
             and has_table_privilege('anon', c.oid, 'SELECT')
           order by 1 loop
    begin
      execute format('select 1 from public.%I limit 1', r.relname);
      n_ok := n_ok + 1;
    exception when others then
      n_err := n_err + 1; bad := bad || E'\n   ' || r.relname || ' -> ' || sqlerrm;
    end;
  end loop;
  raise notice 'anon okuma: % basarili, % HATA%', n_ok, n_err, case when bad='' then '' else bad end;
end $$;
