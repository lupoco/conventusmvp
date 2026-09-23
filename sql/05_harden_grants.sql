-- ============================================================================
-- 05_harden_grants.sql  ·  anon yetkilerinin daraltılması
--
-- NEDEN: 02_clean_install.sql, .org şemasını sadık biçimde kopyaladığı için
--        `grant all on <her tablo/view> to anon, authenticated, service_role`
--        satırını da taşıyor. Yani anon rolü her tabloda SELECT+INSERT+UPDATE+
--        DELETE+TRUNCATE+REFERENCES+TRIGGER yetkisine sahip; tek sınır RLS.
--
-- SOMUT AÇIK (yerelde üretilip doğrulandı, teorik değil):
--        public şemasındaki 10 view `security_invoker=off` ve sahibi postgres.
--        Bu view'ler taban tablonun RLS'ini ATLAR. Üçü aynı zamanda
--        otomatik-güncellenebilir:
--            gm_providers_public
--            convexus_demand_signals_public
--            conventus_selection_verification_status
--        anon bunlarda UPDATE/DELETE yetkisine sahip olduğundan, RLS hiç
--        devreye girmeden taban tablodaki satırları değiştirebiliyor/
--        silebiliyor. PostgREST view'leri de endpoint olarak açtığı için
--        bu internet üzerinden anon anahtarıyla erişilebilir.
--        Kanıt: `scripts/test-harden-grants.sql` (öncesi/sonrası).
--
-- NE YAPAR:
--   tablolarda  anon → UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER geri alınır;
--               INSERT yalnız politikayla izin verilen tablolarda kalır
--   view'lerde  anon ve authenticated → tüm yazma yetkileri geri alınır
--   gelecekte açılacak tablolarda anon'a otomatik yetki verilmesini durdurur
--
-- NE YAPMAZ: SELECT yetkilerine DOKUNMAZ — okuma sınırını RLS ve definer
--            view'ler çiziyor, mevcut durum kasıtlı (04, `conventity_access_
--            requests`te SELECT'i bilerek hiç vermiyor; buraya SELECT eklemek
--            onu geri açardı). Politikalara, RLS'e, authenticated/service_role'ün
--            tablo yetkilerine de dokunmaz. Veri yazmaz/silmez.
--
-- KULLANIM: 02 (ve varsa 04) çalıştıktan SONRA. Tekrar çalıştırılabilir.
--           Geri alma: 05_harden_grants_ROLLBACK.sql
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

-- ---- 1) TABLOLAR: anon → SELECT, artı politikayla izinli yerde INSERT ------
-- INSERT beyaz listesi kataloğdan türetilir: rolleri arasında açıkça `anon`
-- geçen INSERT/ALL politikası olan tablolar. Buna ek olarak `to public` yazılan
-- ama WITH CHECK'inde hiçbir auth koşulu bulunmayan — yani gerçekten herkese
-- açık — formlar elle eklenir (aşağıdaki `extra`).
do $cvblock$
declare
  r        record;
  ins_ok   text[];
  extra    constant text[] := array[
    'convexus_engagement_requests'   -- convexus-engagement.html · kamuya açık talep formu
  ];
  n_ins    int := 0;
  n_rev    int := 0;
begin
  select coalesce(array_agg(distinct tablename::text), '{}'::text[])
    into ins_ok
  from pg_policies
  where schemaname = 'public'
    and cmd in ('INSERT', 'ALL')
    and roles && array['anon']::name[];

  ins_ok := ins_ok || extra;

  for r in select tablename from pg_tables where schemaname = 'public' order by 1 loop
    execute format(
      'revoke insert, update, delete, truncate, references, trigger on public.%I from anon',
      r.tablename);
    if r.tablename = any (ins_ok) then
      execute format('grant insert on public.%I to anon', r.tablename);
      n_ins := n_ins + 1;
    else
      n_rev := n_rev + 1;
    end if;
  end loop;

  raise notice 'tablo: anon INSERT korunan %, INSERT geri alinan %', n_ins, n_rev;
end $cvblock$;

-- ---- 2) VIEW'LER: anon ve authenticated → yalnız SELECT --------------------
-- View'ler security_invoker=off olduğu için taban tablonun RLS'ini atlar.
-- Okuma tarafında bu kasıtlı (kamuya açık vitrinler). Yazma tarafında değil:
-- otomatik-güncellenebilir bir view, RLS'i tamamen devre dışı bırakan bir
-- yazma kanalı açar. security_invoker'ı AÇMIYORUZ — açarsak vitrinler boşalır;
-- bunun yerine yazma yetkisini kaldırıyoruz.
do $cvblock$
declare r record; n int := 0;
begin
  for r in select viewname from pg_views where schemaname = 'public' order by 1 loop
    execute format(
      'revoke insert, update, delete, truncate, references, trigger on public.%I from anon, authenticated',
      r.viewname);
    n := n + 1;
  end loop;
  raise notice 'view: % adet — anon ve authenticated yazma yetkileri kaldirildi', n;
end $cvblock$;

-- ---- 3) GELECEKTEKİ TABLOLAR ------------------------------------------------
-- 02'deki `alter default privileges ... grant all on tables to anon` yüzünden
-- yeni açılan her tablo anon'a sonuna kadar açık doğuyordu; RLS açmayı unutan
-- tek bir migration yeter. (conventity_access_requests'te tam bunu yakaladık.)
-- Bundan sonra yeni tablo anon'a KAPALI doğar; kamuya açılacaksa ilgili
-- migration açıkça `grant select`/`grant insert` yazar.
alter default privileges in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;

-- ---- 4) DOĞRULAMA -----------------------------------------------------------
select 'anon tablo yetkileri' as rapor, privilege_type, count(*)::text as adet
from information_schema.role_table_grants g
join pg_tables t on t.schemaname = g.table_schema and t.tablename = g.table_name
where g.grantee = 'anon' and g.table_schema = 'public'
group by 2 order by 2;

select 'anon view yetkileri' as rapor, privilege_type, count(*)::text as adet
from information_schema.role_table_grants g
join pg_views v on v.schemaname = g.table_schema and v.viewname = g.table_name
where g.grantee = 'anon' and g.table_schema = 'public'
group by 2 order by 2;

select 'anon INSERT kalan tablolar' as rapor, g.table_name as ad
from information_schema.role_table_grants g
join pg_tables t on t.schemaname = g.table_schema and t.tablename = g.table_name
where g.grantee = 'anon' and g.table_schema = 'public' and g.privilege_type = 'INSERT'
order by 2;
