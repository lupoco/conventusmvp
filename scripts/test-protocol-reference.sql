-- sql/10_protocol_reference.sql + sql/11_protocol_seed.sql — guvenlik ve kural testi.
-- On kosul: 10 ve 11 calistirildi.
\set ON_ERROR_STOP on

select '== 1) VERI BUTUNLUGU =====================================';

do $$ declare n int; begin
  select count(*) into n from public.conventity_ref_rank r
   where not exists (select 1 from public.conventity_ref_nato_grade g where g.code = r.grade_code);
  if n > 0 then raise exception 'VERI HATASI: % rutbenin kademesi yok', n; end if;
  raise notice '   her rutbenin kademesi var';

  select count(*) into n from public.conventity_ref_nation where code_mil !~ '^[A-Z]{3}$';
  if n > 0 then raise exception 'VERI HATASI: % ulusun askeri kodu 3 harf degil', n; end if;
  raise notice '   askeri kodlar STANAG bicimde (3 harf)';

  -- sivil kod askeri koddan FARKLI olabilir; ikisini ayni saymak gecmiste hata kaynagiydi
  select count(*) into n from public.conventity_ref_nation
   where bloc='nato' and code_civ is not null and length(code_civ) <> 2 and code_mil <> 'NOM';
  if n > 0 then raise exception 'VERI HATASI: % NATO ulkesinin sivil kodu 2 harf degil', n; end if;
  raise notice '   NATO sivil kodlari 2 harf (NOM kaynak dipnotu haric)';

  select count(*) into n from (
    select list_key, position from public.conventity_ref_precedence_item
     group by 1,2 having count(*) > 1) x;
  if n > 0 then raise exception 'VERI HATASI: oncelik listesinde tekrarli sira'; end if;
  raise notice '   oncelik siralari tekil';

  -- her listenin sirasi 1..n, bosluksuz olmali
  select count(*) into n from (
    select list_key, count(*) c, max(position) m
      from public.conventity_ref_precedence_item group by 1) x where c <> m;
  if n > 0 then raise exception 'VERI HATASI: oncelik listesinde bosluk var'; end if;
  raise notice '   oncelik listeleri boslueksuz (1..n)';
end $$;

select '== 2) ONCELIK KURALLARI (§2.2 + V25) =====================';

do $$ declare v int; begin
  -- §2.2 Positional Authority: Albay olan CHOD, CHOD onceligi alir
  v := public.conventity_precedence_score(null,'chief_of_defence',null,'OF-5');
  if v <> 1050 then raise exception 'KURAL HATASI: Albay CHOD = % (1050 olmali)', v; end if;
  raise notice '   Albay CHOD, CHOD onceligi aliyor (1050)';

  -- Ezme yetkisi OLMAYAN sifat rutbeyi bastirmamali
  v := public.conventity_precedence_score(null,'national_rep',null,'OF-9');
  if v <> 700 then raise exception 'KURAL HATASI: 4 yildizli ulusal temsilci = % (700 olmali)', v; end if;
  v := public.conventity_precedence_score(null,'national_rep',null,'OF-5');
  if v <> 400 then raise exception 'KURAL HATASI: Albay ulusal temsilci = % (400 olmali)', v; end if;
  raise notice '   ulusal temsilcide rutbe belirleyici (700 vs 400)';

  -- §2.2 Temsil: Principal adina gelen onun onceligini alir
  v := public.conventity_precedence_score(null,'national_rep','minister','OF-3');
  if v <> 1100 then raise exception 'KURAL HATASI: bakani temsilen binbasi = % (1100 olmali)', v; end if;
  raise notice '   temsilci, temsil edilenin onceligini aliyor (1100)';

  -- V25 adim 1: stratejik unvan her seyi ezer
  v := public.conventity_precedence_score('secretary_general','observer',null,'OF-1');
  if v <> 1500 then raise exception 'KURAL HATASI: Genel Sekreter = % (1500 olmali)', v; end if;
  raise notice '   stratejik unvan ezmesi calisiyor (1500)';

  -- Rutbesiz sivile taban var ama rutbeliyi geri atmiyor
  v := public.conventity_precedence_score(null,'interpreter',null,null);
  if v >= 200 then raise exception 'KURAL HATASI: tercuman tabani % — OF-1 (200) altinda olmali', v; end if;
  raise notice '   rutbesiz katilimcinin tabani OF-1 altinda';

  -- Ezme yetkisi olmayan unvan grubu (command/staff/civilian) skoru degistirmemeli
  v := public.conventity_precedence_score('cos','national_rep',null,'OF-5');
  if v <> 400 then raise exception 'KURAL HATASI: COS unvani rutbeyi ezdi (%)', v; end if;
  raise notice '   command/staff/civilian unvanlari ezme yapmiyor';
end $$;

select '== 3) KIMLIK DIZESI (§2.1) ===============================';

do $$ declare t text; begin
  t := public.conventity_identity_string('GEN','Doe','TUR','A');
  if t <> 'GEN "Doe" TUR A' then raise exception 'BICIM HATASI: % (GEN "Doe" TUR A olmali)', t; end if;
  raise notice '   bicim dogru: %', t;
  -- eksik alanlarda bosluk birakmamali
  t := public.conventity_identity_string('COL',null,'USA','N');
  if t like '%  %' then raise exception 'BICIM HATASI: cift bosluk — %', t; end if;
  raise notice '   eksik alanda cift bosluk yok: %', t;
end $$;

select '== 4) HITAP ==============================================';

do $$ declare t text; begin
  t := public.conventity_salutation('GBR','mod','written');
  if t <> 'Dear Secretary of State' then raise exception 'HITAP HATASI: GBR MOD yazili = %', t; end if;
  t := public.conventity_salutation('GBR','mod','personal');
  if t <> 'Sir' then raise exception 'HITAP HATASI: GBR MOD sozlu = %', t; end if;
  raise notice '   sozlu ve yazili hitap ayri donuyor';
end $$;

select '== 5) YETKILER ===========================================';

set role anon;
select '   anon ulus goruyor    : '||count(*) from public.conventity_ref_nation;
select '   anon rutbe goruyor   : '||count(*) from public.conventity_ref_rank;
select '   anon oncelik goruyor : '||count(*) from public.conventity_ref_precedence_item;

do $$ begin
  insert into public.conventity_ref_nation (code_mil, name_en, bloc) values ('ZZZ','Testland','nato');
  raise exception 'GUVENLIK HATASI: anon referans verisi ekledi';
exception when insufficient_privilege then raise notice '   anon yazma: REDDEDILDI (dogru)'; end $$;

do $$ declare n int; begin
  update public.conventity_ref_nato_grade set ordinal = 9999 where code='OF-9';
  get diagnostics n = row_count;
  if n > 0 then raise exception 'GUVENLIK HATASI: anon kademe agirligini degistirdi'; end if;
  raise notice '   anon guncelleme: ETKISIZ (dogru)';
exception when insufficient_privilege then raise notice '   anon guncelleme: REDDEDILDI (dogru)'; end $$;

reset role;
set role authenticated;
do $$ declare n int; begin
  update public.conventity_ref_capacity set precedence_weight = 9999 where key='observer';
  get diagnostics n = row_count;
  if n > 0 then raise exception 'GUVENLIK HATASI: admin olmayan agirlik degistirdi (% satir)', n; end if;
  raise notice '   admin olmayan authenticated yazma: ETKISIZ (dogru)';
exception when insufficient_privilege then raise notice '   admin olmayan yazma: REDDEDILDI (dogru)'; end $$;
reset role;

do $$ declare n int; begin
  select count(*) into n from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
   where ns.nspname='public' and c.relname='conventus_precedence_v'
     and coalesce(c.reloptions::text,'') like '%security_invoker=true%';
  if n <> 1 then raise exception 'GUVENLIK HATASI: precedence view RLS bypass ediyor'; end if;
  raise notice '   view security_invoker=true (RLS bypass yok)';
end $$;

select '== 6) AGIRLIK TUTARLILIGI ================================';

do $$ declare n int; begin
  -- Kural: ezme yetkisi >= 800; taban band < OF-1 (200). Arada kalan olmamali.
  select count(*) into n from public.conventity_ref_capacity
   where precedence_weight >= 200 and precedence_weight < 800;
  if n > 0 then raise exception
    'AGIRLIK HATASI: % sifat 200-800 arasinda — ne ezer ne taban, rutbeyi rastgele bastirir', n;
  end if;
  raise notice '   butun sifatlar ya ezme (>=800) ya taban (<200) bandinda';
end $$;

select '== TESTLER GECTI =========================================';
