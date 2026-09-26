-- ============================================================================
-- 11_protocol_seed.sql  ·  NATO protokol referans katmani — VERI
--
-- KAYNAK: NATO Protocol guide book + PLCC WEBSITE REQUIREMENTS V23/V25.
--
-- UPSERT NEDEN "DO UPDATE": bu tablolar doktrin kaynagini yansitir. Dosyayi
--   tekrar calistirmak kaynaktaki dogruyu GERI YUKLER. Arayuzden yapilan
--   elle duzeltmeler bu dosya tekrar kosulunca silinir — bilerek boyle.
--   Kalici bir degisiklik gerekiyorsa once BURAYA yaz, sonra calistir.
--
-- ⚠ KAYNAK DISINDA KALAN / DOGRULANMASI GEREKENLER — hepsi asagida isaretli:
--   1) AGIRLIKLAR: V25 yalniz 4 ornek veriyor (Strategic 1000 · Head of
--      Delegation 800 · OF-9 700 · OF-8 600). Digerleri TEKLIF; veri olduklari
--      icin arayuzden degistirilebilir. Stratejik unvan agirliklari §2.2'deki
--      22'lik ic sira konumundan turetildi (1500 - (konum-1)*10).
--   2) FINLANDIYA ve ISVEC: kaynak 2010 tarihli, ikisini de PfP altinda
--      listeliyor. Bugun NATO uyesi (2023 · 2024) — bloc='nato' yazildi,
--      ama 2 harfli SIVIL KODLARI kaynakta YOK, NULL birakildi.
--   3) RUSYA ve BELARUS: kaynakta PfP'de, ama PfP isbirligi askida.
--      is_active=false yazildi (kayit formunda cikmasinlar). Acmak icin:
--      update conventity_ref_nation set is_active=true where code_mil in ('RUS','BLR');
--   4) FRANSIZCA ULUS ADLARI: §2.2 siralamanin EN veya FR olabilecegini
--      soyluyor ama FR adlari kaynakta YOK. NATO uyeleri icin yazildi,
--      partnerler NULL. Protokolden teyit edilmeli.
--   5) KIYAFET KODU "occasions": kaynak ekran goruntusunde en sag sutun kesik.
--      NULL birakildi.
--   6) HITAP BICIMLERI: MNE ve NOM satirlari KAYNAKTA da bos. Monarsi
--      satirlari 2010 tarihli (DNK/GBR/NLD'de hukumdar degisti) — source_note
--      ile isaretli.
--
-- KULLANIM: 10'dan sonra. Tekrar calistirilabilir.
-- ============================================================================

do $cvguard$
declare n_prof bigint;
begin
  if to_regclass('public.conventity_ref_nation') is null then
    raise exception E'\n\n  Referans tablolari yok — once 10_protocol_reference.sql calistir.\n';
  end if;
  select count(*) into n_prof from public.convexus_profiles;
  if n_prof > 0 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=% satir — burasi .org.\n', n_prof;
  end if;
end $cvguard$;

-- ---- 1) ULUSLAR — STANAG 1059 Ed.8 ------------------------------------------
insert into public.conventity_ref_nation
  (code_mil, code_civ, name_en, name_fr, name_tr, bloc, is_active, source_note) values
  ('ALB','AL' ,'Albania'       ,'Albanie'            ,'Arnavutluk'    ,'nato',true ,null),
  ('BEL','BE' ,'Belgium'       ,'Belgique'           ,'Belçika'       ,'nato',true ,null),
  ('BGR','BU' ,'Bulgaria'      ,'Bulgarie'           ,'Bulgaristan'   ,'nato',true ,null),
  ('CAN','CA' ,'Canada'        ,'Canada'             ,'Kanada'        ,'nato',true ,null),
  ('HRV','CR' ,'Croatia'       ,'Croatie'            ,'Hırvatistan'   ,'nato',true ,null),
  ('CZE','CZ' ,'Czech Republic','République tchèque' ,'Çekya'         ,'nato',true ,null),
  ('DNK','DE' ,'Denmark'       ,'Danemark'           ,'Danimarka'     ,'nato',true ,'sivil kod DE — Almanya GE ile karistirilmamali'),
  ('EST','ES' ,'Estonia'       ,'Estonie'            ,'Estonya'       ,'nato',true ,null),
  ('FRA','FR' ,'France'        ,'France'             ,'Fransa'        ,'nato',true ,null),
  ('DEU','GE' ,'Germany'       ,'Allemagne'          ,'Almanya'       ,'nato',true ,null),
  ('GRC','GR' ,'Greece'        ,'Grèce'              ,'Yunanistan'    ,'nato',true ,null),
  ('HUN','HU' ,'Hungary'       ,'Hongrie'            ,'Macaristan'    ,'nato',true ,null),
  ('ISL','IC' ,'Iceland'       ,'Islande'            ,'İzlanda'       ,'nato',true ,null),
  ('ITA','IT' ,'Italy'         ,'Italie'             ,'İtalya'        ,'nato',true ,null),
  ('LVA','LA' ,'Latvia'        ,'Lettonie'           ,'Letonya'       ,'nato',true ,null),
  ('LTU','LI' ,'Lithuania'     ,'Lituanie'           ,'Litvanya'      ,'nato',true ,null),
  ('LUX','LU' ,'Luxembourg'    ,'Luxembourg'         ,'Lüksemburg'    ,'nato',true ,null),
  ('MNE','MO' ,'Montenegro'    ,'Monténégro'         ,'Karadağ'       ,'nato',true ,null),
  ('NLD','NE' ,'Netherlands'   ,'Pays-Bas'           ,'Hollanda'      ,'nato',true ,null),
  ('NOM','NOM','North Macedonia','Macédoine du Nord' ,'Kuzey Makedonya','nato',true,'kaynak dipnotu: tam uyelikle birlikte NM'),
  ('NOR','NO' ,'Norway'        ,'Norvège'            ,'Norveç'        ,'nato',true ,null),
  ('POL','PL' ,'Poland'        ,'Pologne'            ,'Polonya'       ,'nato',true ,null),
  ('PRT','PO' ,'Portugal'      ,'Portugal'           ,'Portekiz'      ,'nato',true ,null),
  ('ROU','RO' ,'Romania'       ,'Roumanie'           ,'Romanya'       ,'nato',true ,null),
  ('SVK','SK' ,'Slovakia'      ,'Slovaquie'          ,'Slovakya'      ,'nato',true ,null),
  ('SVN','SN' ,'Slovenia'      ,'Slovénie'           ,'Slovenya'      ,'nato',true ,null),
  ('ESP','SP' ,'Spain'         ,'Espagne'            ,'İspanya'       ,'nato',true ,null),
  ('TUR','TU' ,'Turkey'        ,'Turquie'            ,'Türkiye'       ,'nato',true ,null),
  ('GBR','UK' ,'United Kingdom','Royaume-Uni'        ,'Birleşik Krallık','nato',true,null),
  ('USA','US' ,'United States' ,'États-Unis'         ,'Amerika Birleşik Devletleri','nato',true,null),
  -- ⚠ (2) kaynakta PfP altinda — bugun NATO uyesi; sivil kodlari kaynakta yok
  ('FIN', null,'Finland'       ,'Finlande'           ,'Finlandiya'    ,'nato',true ,'kaynak PfP altinda listeliyor (2023 uyeligi oncesi); 2 harfli sivil kod kaynakta YOK'),
  ('SWE', null,'Sweden'        ,'Suède'              ,'İsveç'         ,'nato',true ,'kaynak PfP altinda listeliyor (2024 uyeligi oncesi); 2 harfli sivil kod kaynakta YOK'),
  -- Partnership for Peace
  ('ARM','ARM','Armenia'       ,null,'Ermenistan'    ,'pfp' ,true ,null),
  ('AUT','AUT','Austria'       ,null,'Avusturya'     ,'pfp' ,true ,null),
  ('AZE','AZE','Azerbaijan'    ,null,'Azerbaycan'    ,'pfp' ,true ,null),
  ('BLR','BLR','Belarus'       ,null,'Belarus'       ,'pfp' ,false,'⚠ (3) kaynakta PfP; isbirligi askida — is_active=false'),
  ('BIH','BIH','Bosnia and Herzegovina',null,'Bosna-Hersek','pfp',true,null),
  ('GEO','GEO','Georgia'       ,null,'Gürcistan'     ,'pfp' ,true ,null),
  ('IRL','IRE','Ireland'       ,null,'İrlanda'       ,'pfp' ,true ,'askeri IRL / sivil IRE — farkli'),
  ('KAZ','KAZ','Kazakhstan'    ,null,'Kazakistan'    ,'pfp' ,true ,null),
  ('KGZ','KYR','Kyrgyz Republic',null,'Kırgızistan'  ,'pfp' ,true ,'askeri KGZ / sivil KYR — farkli'),
  ('MLT','MAL','Malta'         ,null,'Malta'         ,'pfp' ,true ,null),
  ('MDA','MOL','Moldova'       ,null,'Moldova'       ,'pfp' ,true ,'askeri MDA / sivil MOL — farkli'),
  ('RUS','RUS','Russian Federation',null,'Rusya Federasyonu','pfp',false,'⚠ (3) kaynakta PfP; isbirligi askida — is_active=false'),
  ('SRB','SER','Serbia'        ,null,'Sırbistan'     ,'pfp' ,true ,null),
  ('CHE','SWI','Switzerland'   ,null,'İsviçre'       ,'pfp' ,true ,null),
  ('TJK','TAJ','Tajikistan'    ,null,'Tacikistan'    ,'pfp' ,true ,null),
  ('TKM','TUM','Turkmenistan'  ,null,'Türkmenistan'  ,'pfp' ,true ,null),
  ('UKR','UKR','Ukraine'       ,null,'Ukrayna'       ,'pfp' ,true ,null),
  ('UZB','UZB','Uzbekistan'    ,null,'Özbekistan'    ,'pfp' ,true ,null),
  -- Mediterranean Dialogue
  ('DZA','ALG','Algeria'       ,null,'Cezayir'       ,'md'  ,true ,null),
  ('EGY','EGY','Egypt'         ,null,'Mısır'         ,'md'  ,true ,null),
  ('ISR','ISR','Israel'        ,null,'İsrail'        ,'md'  ,true ,null),
  ('JOR','JOR','Jordan'        ,null,'Ürdün'         ,'md'  ,true ,null),
  ('MRT','MAU','Mauritania'    ,null,'Moritanya'     ,'md'  ,true ,null),
  ('MAR','MOR','Morocco'       ,null,'Fas'           ,'md'  ,true ,null),
  ('TUN','TUN','Tunisia'       ,null,'Tunus'         ,'md'  ,true ,null),
  -- Istanbul Cooperation Initiative
  ('BHR','BAH','Bahrain'       ,null,'Bahreyn'       ,'ici' ,true ,null),
  ('KWT','KUW','Kuwait'        ,null,'Kuveyt'        ,'ici' ,true ,null),
  ('QAT','QAT','Qatar'         ,null,'Katar'         ,'ici' ,true ,null),
  ('ARE','UAE','United Arab Emirates',null,'Birleşik Arap Emirlikleri','ici',true,null),
  -- Partners across the Globe
  ('AFG','AFG','Afghanistan'   ,null,'Afganistan'    ,'patg',true ,null),
  ('AUS','AUS','Australia'     ,null,'Avustralya'    ,'patg',true ,null),
  ('COL','COL','Colombia'      ,null,'Kolombiya'     ,'patg',true ,null),
  ('IRQ','IRQ','Iraq'          ,null,'Irak'          ,'patg',true ,null),
  ('JPN','JAP','Japan'         ,null,'Japonya'       ,'patg',true ,'askeri JPN / sivil JAP — farkli'),
  ('KOR','ROK','Republic of Korea',null,'Kore Cumhuriyeti','patg',true,'askeri KOR / sivil ROK — farkli'),
  ('MNG','MNG','Mongolia'      ,null,'Moğolistan'    ,'patg',true ,null),
  ('NZL','NZL','New Zealand'   ,null,'Yeni Zelanda'  ,'patg',true ,null),
  ('PAK','PAK','Pakistan'      ,null,'Pakistan'      ,'patg',true ,null)
on conflict (code_mil) do update set
  code_civ=excluded.code_civ, name_en=excluded.name_en, name_fr=excluded.name_fr,
  name_tr=excluded.name_tr, bloc=excluded.bloc, is_active=excluded.is_active,
  source_note=excluded.source_note, updated_at=now();

-- ---- 2) NATO KADEME OLCEGI --------------------------------------------------
-- ordinal = adim 4 agirligi. ⚠ (1) OF-9=700 ve OF-8=600 kaynaktan; gerisi teklif.
insert into public.conventity_ref_nato_grade (code, kind, ordinal, civ_equiv, is_selectable, note) values
  ('OF-10','OF',800,null,false,'Honorary/Wartime Rank — kaynakta karsilik listelenmiyor'),
  ('OF-9' ,'OF',700,null,true ,null),
  ('OF-8' ,'OF',600,null,true ,null),
  ('OF-7' ,'OF',500,'A7'  ,true,null),
  ('OF-6' ,'OF',450,'A6'  ,true,null),
  ('OF-5' ,'OF',400,'A5'  ,true,null),
  ('OF-4' ,'OF',350,'A4'  ,true,null),
  ('OF-3' ,'OF',300,'A3'  ,true,null),
  ('OF-2' ,'OF',250,'A2'  ,true,null),
  ('OF-1' ,'OF',200,'A1'  ,true,null),
  ('OR-10','OR',150,null  ,true,null),
  ('OR-9' ,'OR',140,'B5-6',true,null),
  ('OR-8' ,'OR',130,'B4'  ,true,null),
  ('OR-7' ,'OR',120,'B3'  ,true,null),
  ('OR-6' ,'OR',110,'B2'  ,true,'OR-6 ve OR-5 ayni sivil kademeye (B2) karsilik gelir — bire bir eslesme YOK'),
  ('OR-5' ,'OR',100,'B2'  ,true,'OR-6 ve OR-5 ayni sivil kademeye (B2) karsilik gelir — bire bir eslesme YOK'),
  ('OR-4' ,'OR', 90,'B1'  ,true,null),
  ('OR-3' ,'OR', 80,'C5-6',true,null),
  ('OR-2' ,'OR', 70,'C3-4',true,null),
  ('OR-1' ,'OR', 60,'C1-2',true,null)
on conflict (code) do update set
  kind=excluded.kind, ordinal=excluded.ordinal, civ_equiv=excluded.civ_equiv,
  is_selectable=excluded.is_selectable, note=excluded.note;

-- ---- 3) RUTBELER — 63 kayit (Kara 22 · Hava 20 · Deniz 21) ------------------
insert into public.conventity_ref_rank (grade_code, service, name_en, acronym, sort) values
  -- KARA / DENIZ PIYADE
  ('OF-9' ,'A','General','GEN',10),
  ('OF-8' ,'A','Lieutenant General','LGEN',20),
  ('OF-7' ,'A','Major General','MGEN',30),
  ('OF-6' ,'A','Brigadier General','BGEN / BRIG',40),
  ('OF-5' ,'A','Colonel','COL',50),
  ('OF-4' ,'A','Lieutenant Colonel','LTC',60),
  ('OF-3' ,'A','Major','MAJ',70),
  ('OF-2' ,'A','Captain','CPT',80),
  ('OF-1' ,'A','First Lieutenant','1LT',90),
  ('OF-1' ,'A','Second Lieutenant','2LT',100),
  ('OR-10','A','Sergeant Major of the Army / Marine Corps','SMA / SgtMajMarCor',110),
  ('OR-9' ,'A','Command Sergeant Major','CSM',120),
  ('OR-9' ,'A','Sergeant Major','SGM',130),
  ('OR-8' ,'A','First Sergeant','FSGT',140),
  ('OR-8' ,'A','Master Sergeant','MSGT',150),
  ('OR-7' ,'A','Sergeant First Class','SFC',160),
  ('OR-6' ,'A','Staff Sergeant','SSGT',170),
  ('OR-5' ,'A','Sergeant','SGT',180),
  ('OR-4' ,'A','Corporal / Specialist','CPL',190),
  ('OR-3' ,'A','Private First Class','PFC',200),
  ('OR-2' ,'A','Private E2','PV2',210),
  ('OR-1' ,'A','Private E1','PVT',220),
  -- HAVA
  ('OF-9' ,'F','General / Air Chief Marshal','GEN / ACM',10),
  ('OF-8' ,'F','Lieutenant General / Air Marshal','LGEN / AM',20),
  ('OF-7' ,'F','Major General / Air Vice Marshal','MGEN / AVM',30),
  ('OF-6' ,'F','Brigadier General / Air Commodore','BGEN / AIR CDRE',40),
  ('OF-5' ,'F','Colonel / Group Captain','COL / GP CAPT',50),
  ('OF-4' ,'F','Lieutenant Colonel / Wing Commander','LTC / WG CDR',60),
  ('OF-3' ,'F','Major / Squadron Leader','MAJ / SQN LDR',70),
  ('OF-2' ,'F','Captain / Flight Lieutenant','CPT / FLT LT',80),
  ('OF-1' ,'F','First Lieutenant / Flying Officer','1LT / Fg Off',90),
  ('OF-1' ,'F','Second Lieutenant / Pilot Officer','2LT / Plt Off',100),
  ('OR-10','F','Chief Master Sergeant of the Air Force','CMSAF',110),
  ('OR-9' ,'F','Chief Master Sergeant / Warrant Officer','CWO / WO',120),
  ('OR-8' ,'F','Senior Master Sergeant / Flight Sergeant','WO / FLT SGT',130),
  ('OR-7' ,'F','Master Sergeant','FLT SGT',140),
  ('OR-6' ,'F','Technical Sergeant','TSGT',150),
  ('OR-5' ,'F','Staff Sergeant','SSGT',160),
  ('OR-4' ,'F','Senior Airman','SRA',170),
  ('OR-3' ,'F','Airman First Class / Senior Aircraftman','A1C',180),
  ('OR-2' ,'F','Airman','AMN',190),
  ('OR-1' ,'F','Airman Basic','AB',200),
  -- DENIZ
  ('OF-9' ,'N','Admiral','ADM',10),
  ('OF-8' ,'N','Vice Admiral','VADM',20),
  ('OF-7' ,'N','Rear Admiral (Upper Half)','RADM',30),
  ('OF-6' ,'N','Rear Admiral (Lower Half) / Commodore','RDML / CDRE',40),
  ('OF-5' ,'N','Captain','CAPT',50),
  ('OF-4' ,'N','Commander','CDR',60),
  ('OF-3' ,'N','Lieutenant Commander','LCDR',70),
  ('OF-2' ,'N','Lieutenant','LT',80),
  ('OF-1' ,'N','Lieutenant Junior Grade','LTJG',90),
  ('OF-1' ,'N','Ensign','ENS',100),
  ('OF-1' ,'N','Midshipman','MIDN',110),
  ('OR-10','N','Master Chief Petty Officer of the Navy','MCPON',120),
  ('OR-9' ,'N','Fleet / Force / Command Master Chief Petty Officer','MCPO',130),
  ('OR-8' ,'N','Senior Chief Petty Officer','SCPO',140),
  ('OR-7' ,'N','Chief Petty Officer','CPO',150),
  ('OR-6' ,'N','Petty Officer First Class','PO1',160),
  ('OR-5' ,'N','Petty Officer Second Class','PO2',170),
  ('OR-4' ,'N','Petty Officer Third Class','PO3',180),
  ('OR-3' ,'N','Seaman / Airman / Fireman / Constructionman','SN / AN / FN / CN',190),
  ('OR-2' ,'N','Seaman / Airman Apprentice','SA / AA / FA / CA',200),
  ('OR-1' ,'N','Seaman / Airman Recruit','SR / AR / FR / CR',210)
on conflict (service, acronym) do update set
  grade_code=excluded.grade_code, name_en=excluded.name_en, sort=excluded.sort;

-- ---- 4) ETKINLIK SIFATI — V23, 30 kayit -------------------------------------
-- ⚠ (1) agirliklar TEKLIF — V25 yalniz 4 ornek veriyor. Uygulanan kural:
--
--   A) EZEN SIFATLAR (>= 800): kaynagin §2.2'de acikca "Positional Authority"
--      tanidigi roller. Albay olan bir CHOD, CHOD onceligi alir.
--   B) TABAN SIFATLAR (< 200, yani OF-1'in altinda): digerlerinin HEPSI.
--      Rutbesiz bir sivile taban verir ama rutbeli hicbir subayi geri atmaz.
--
-- NEDEN: ilk surumde "National Representative" 740 idi; bu, 4 yildizli bir
-- generali (OF-9 = 700) kendi heyetindeki bir yarbayla ayni skora dusuruyordu.
-- Kaynak ulusal temsilciye ezme yetkisi TANIMIYOR — taban banda alindi.
-- Belirli bir etkinlikte farkli gerekiyorsa agirlik arayuzden yukseltilir.
insert into public.conventity_ref_capacity (key, group_key, label_en, label_tr, precedence_weight, sort) values
  ('head_of_state'           ,'strategic' ,'Head of State'                  ,'Devlet Başkanı'            ,1200, 10),
  ('head_of_government'      ,'strategic' ,'Head of Government'             ,'Hükümet Başkanı'           ,1150, 20),
  ('minister'                ,'strategic' ,'Minister'                       ,'Bakan'                     ,1100, 30),
  ('chief_of_defence'        ,'strategic' ,'Chief of Defence'               ,'Genelkurmay Başkanı'       ,1050, 40),
  ('chairman_mc'             ,'strategic' ,'Chairman of Military Committee' ,'Askeri Komite Başkanı'     ,1030, 50),
  ('strategic_commander'     ,'strategic' ,'Strategic Commander'            ,'Stratejik Komutan'         ,1000, 60),
  ('head_of_delegation'      ,'delegation','Head of National Delegation'    ,'Ulusal Heyet Başkanı'      , 800, 70),
  ('deputy_head_delegation'  ,'delegation','Deputy Head of National Delegation','Ulusal Heyet Başkan Yrd.', 190, 80),
  ('senior_national_rep'     ,'delegation','Senior National Representative' ,'Kıdemli Ulusal Temsilci'   , 180, 90),
  ('national_rep'            ,'delegation','National Representative'        ,'Ulusal Temsilci'           , 160,100),
  ('national_support_element','delegation','National Support Element'       ,'Ulusal Destek Unsuru'      , 90,110),
  ('principal'               ,'principal' ,'Principal'                      ,'Asıl Katılımcı'            , 900,120),
  ('deputy_principal'        ,'principal' ,'Deputy Principal'               ,'Asıl Katılımcı Vekili'     , 860,130),
  ('vip_guest'               ,'principal' ,'VIP Guest'                      ,'VIP Konuk'                 , 850,140),
  ('observer'                ,'principal' ,'Observer'                       ,'Gözlemci'                  , 150,150),
  ('speaker'                 ,'function'  ,'Speaker'                        ,'Konuşmacı'                 , 195,160),
  ('panelist'                ,'function'  ,'Panelist'                       ,'Panelist'                  , 185,170),
  ('moderator'               ,'function'  ,'Moderator'                      ,'Moderatör'                 , 185,180),
  ('sme'                     ,'function'  ,'Subject Matter Expert'          ,'Konu Uzmanı'               , 175,190),
  ('aide_to_principal'       ,'support'   ,'Aide to Principal'              ,'Asıl Katılımcı Yaveri'     , 120,200),
  ('executive_assistant'     ,'support'   ,'Executive Assistant'            ,'İcra Asistanı'             , 110,210),
  ('military_assistant'      ,'support'   ,'Military Assistant'             ,'Askeri Asistan'            , 110,220),
  ('interpreter'             ,'support'   ,'Interpreter'                    ,'Tercüman'                  , 100,230),
  ('protocol_staff'          ,'support'   ,'Protocol Staff'                 ,'Protokol Personeli'        , 100,240),
  ('host_nation_support'     ,'support'   ,'Host Nation Support Team'       ,'Ev Sahibi Ulus Destek Ekibi', 90,250),
  ('security'                ,'security'  ,'Security'                       ,'Güvenlik'                  ,  80,260),
  ('psd'                     ,'security'  ,'Personal Security Detail'       ,'Yakın Koruma'              ,  80,270),
  ('industry_rep'            ,'external'  ,'Industry Representative'        ,'Sanayi Temsilcisi'         ,  60,280),
  ('media'                   ,'external'  ,'Media'                          ,'Basın'                     ,  50,290),
  ('other'                   ,'other'     ,'Other (Specify)'                ,'Diğer (belirtiniz)'        ,   0,300)
on conflict (key) do update set
  group_key=excluded.group_key, label_en=excluded.label_en, label_tr=excluded.label_tr,
  precedence_weight=excluded.precedence_weight, sort=excluded.sort;

-- ---- 5) UNVAN — V23, 5 grup -------------------------------------------------
-- ⚠ (1) stratejik agirliklar §2.2'deki 22'lik ic sira konumundan: 1500-(konum-1)*10.
-- Command/Staff/Civilian gruplari EZME YAPMAZ (agirlik 0) — V25 adim 1-2 yalniz
-- stratejik ve diplomatik unvanlara ait. Onlarda sira sifat ve kademeden gelir.
insert into public.conventity_ref_title
  (key, group_key, label_en, label_tr, is_strategic_override, is_diplomatic_override, precedence_weight, sort) values
  ('secretary_general'  ,'strategic','Secretary General'   ,'Genel Sekreter'          ,true ,false,1500, 10),
  ('deputy_sg'          ,'strategic','Deputy Secretary General','Genel Sekreter Yrd.' ,true ,false,1460, 20),
  ('chairman_mc'        ,'strategic','Chairman of the Military Committee','Askeri Komite Başkanı',true,false,1450,30),
  ('deputy_chairman_mc' ,'strategic','Deputy Chairman of the Military Committee','Askeri Komite Başkan Yrd.',true,false,1380,40),
  ('saceur'             ,'strategic','Supreme Allied Commander Europe (SACEUR)','SACEUR',true,false,1430,50),
  ('dsaceur'            ,'strategic','Deputy Supreme Allied Commander Europe (DSACEUR)','DSACEUR',true,false,1390,60),
  ('sact'               ,'strategic','Supreme Allied Commander Transformation (SACT)','SACT',true,false,1420,70),
  ('permanent_rep'      ,'strategic','Permanent Representative','Daimi Temsilci'      ,true ,false,1470, 80),
  ('chief_of_defence'   ,'strategic','Chief of Defence'    ,'Genelkurmay Başkanı'     ,true ,false,1440, 90),
  ('minister_defence'   ,'strategic','Minister of Defence' ,'Savunma Bakanı'          ,true ,false,1480,100),
  ('minister_foreign'   ,'strategic','Minister of Foreign Affairs','Dışişleri Bakanı' ,true ,false,1490,110),
  ('com'                ,'command','Commander (COM)'              ,'Komutan'              ,false,false,0,200),
  ('dcom'               ,'command','Deputy Commander (DCOM)'      ,'Komutan Yrd.'         ,false,false,0,210),
  ('cos'                ,'command','Chief of Staff (COS)'         ,'Kurmay Başkanı'       ,false,false,0,220),
  ('dcos'               ,'command','Deputy Chief of Staff (DCOS)' ,'Kurmay Başkan Yrd.'   ,false,false,0,230),
  ('acos'               ,'command','Assistant Chief of Staff (ACOS)','Kurmay Başkan Yard.',false,false,0,240),
  ('director'           ,'command','Director'                     ,'Direktör'             ,false,false,0,250),
  ('deputy_director'    ,'command','Deputy Director'              ,'Direktör Yrd.'        ,false,false,0,260),
  ('division_head'      ,'command','Division Head'                ,'Daire Başkanı'        ,false,false,0,270),
  ('branch_head'        ,'command','Branch Head'                  ,'Şube Başkanı'         ,false,false,0,280),
  ('section_head'       ,'command','Section Head'                 ,'Kısım Amiri'          ,false,false,0,290),
  ('xo'                 ,'staff','Executive Officer (XO)'         ,'İcra Subayı'          ,false,false,0,300),
  ('deputy_xo'          ,'staff','Deputy Executive Officer'       ,'İcra Subay Yrd.'      ,false,false,0,310),
  ('senior_staff_officer','staff','Senior Staff Officer'          ,'Kıdemli Kurmay Subay' ,false,false,0,320),
  ('staff_officer'      ,'staff','Staff Officer'                  ,'Kurmay Subay'         ,false,false,0,330),
  ('action_officer'     ,'staff','Action Officer'                 ,'İşlem Subayı'         ,false,false,0,340),
  ('project_officer'    ,'staff','Project Officer'                ,'Proje Subayı'         ,false,false,0,350),
  ('programme_officer'  ,'staff','Programme Officer'              ,'Program Subayı'       ,false,false,0,360),
  ('lno'                ,'staff','Liaison Officer (LNO)'          ,'İrtibat Subayı'       ,false,false,0,370),
  ('adc'                ,'staff','Aide-de-Camp (ADC)'             ,'Yaver'                ,false,false,0,380),
  ('military_assistant' ,'staff','Military Assistant'             ,'Askeri Asistan'       ,false,false,0,390),
  ('senior_enlisted'    ,'staff','Senior Enlisted Leader'         ,'Kıdemli Astsubay Lideri',false,false,0,400),
  ('command_sgt_major'  ,'staff','Command Sergeant Major'         ,'Komutanlık Başçavuşu' ,false,false,0,410),
  ('sergeant_major'     ,'staff','Sergeant Major'                 ,'Başçavuş'             ,false,false,0,420),
  ('director_general'   ,'civilian','Director General'            ,'Genel Direktör'       ,false,false,0,500),
  ('deputy_dg'          ,'civilian','Deputy Director General'     ,'Genel Direktör Yrd.'  ,false,false,0,510),
  ('head_of_office'     ,'civilian','Head of Office'              ,'Ofis Başkanı'         ,false,false,0,520),
  ('head_of_unit'       ,'civilian','Head of Unit'                ,'Birim Başkanı'        ,false,false,0,530),
  ('principal_officer'  ,'civilian','Principal Officer'           ,'Baş Uzman'            ,false,false,0,540),
  ('senior_adviser'     ,'civilian','Senior Adviser'              ,'Kıdemli Danışman'     ,false,false,0,550),
  ('special_adviser'    ,'civilian','Special Adviser'             ,'Özel Danışman'        ,false,false,0,560),
  ('legal_adviser'      ,'civilian','Legal Adviser'               ,'Hukuk Danışmanı'      ,false,false,0,570),
  ('political_adviser'  ,'civilian','Political Adviser'           ,'Siyasi Danışman'      ,false,false,0,580),
  ('senior_civ_rep'     ,'civilian','Senior Civilian Representative','Kıdemli Sivil Temsilci',false,false,0,590),
  ('programme_manager'  ,'civilian','Programme Manager'           ,'Program Yöneticisi'   ,false,false,0,600),
  ('project_manager'    ,'civilian','Project Manager'             ,'Proje Yöneticisi'     ,false,false,0,610),
  ('policy_officer'     ,'civilian','Policy Officer'              ,'Politika Uzmanı'      ,false,false,0,620),
  ('analyst'            ,'civilian','Analyst'                     ,'Analist'              ,false,false,0,630),
  ('sme'                ,'civilian','Subject Matter Expert'       ,'Konu Uzmanı'          ,false,false,0,640),
  ('ambassador'         ,'diplomatic','Ambassador'                ,'Büyükelçi'            ,false,true ,1200,700),
  ('deputy_perm_rep'    ,'diplomatic','Deputy Permanent Representative','Daimi Temsilci Yrd.',false,true,1350,710),
  ('military_rep'       ,'diplomatic','Military Representative'   ,'Askeri Temsilci'      ,false,true ,1410,720),
  ('deputy_military_rep','diplomatic','Deputy Military Representative','Askeri Temsilci Yrd.',false,true,1290,730),
  ('defence_attache'    ,'diplomatic','Defence Attaché'           ,'Savunma Ataşesi'      ,false,true ,300 ,740),
  ('political_counsellor','diplomatic','Political Counsellor'     ,'Siyasi Müsteşar'      ,false,true ,250 ,750),
  ('senior_national_rep','diplomatic','Senior National Representative','Kıdemli Ulusal Temsilci',false,true,260,760)
on conflict (key) do update set
  group_key=excluded.group_key, label_en=excluded.label_en, label_tr=excluded.label_tr,
  is_strategic_override=excluded.is_strategic_override,
  is_diplomatic_override=excluded.is_diplomatic_override,
  precedence_weight=excluded.precedence_weight, sort=excluded.sort;

-- ---- 6) KURULUS — V23 --------------------------------------------------------
-- Partner kuruluslari ("<Ulke> PNMR") BILEREK yazilmadi: ulus listesinden
-- turetilir, iki yerde tutulursa kacinilmaz olarak ayrisirlar.
-- JALLC ve JWC hem NCS hem NFS listesinde geciyor — anahtarlar grup onekli.
insert into public.conventity_ref_organization (key, group_key, label_en, label_tr, sort) values
  ('hq_ims','nato_hq','NATO HQ (IMS)','NATO Karargâhı (IMS)',10),
  ('hq_is' ,'nato_hq','NATO HQ (IS)' ,'NATO Karargâhı (IS)' ,20),
  ('ncs_saceur','ncs','SACEUR',null,10),        ('ncs_dsaceur','ncs','DSACEUR',null,20),
  ('ncs_sact','ncs','SACT',null,30),            ('ncs_cos_shape','ncs','COS SHAPE',null,40),
  ('ncs_jfc_brunssum','ncs','JFC Brunssum',null,50),('ncs_jfc_naples','ncs','JFC Naples',null,60),
  ('ncs_jfc_norfolk','ncs','JFC Norfolk',null,70),  ('ncs_jlsgbs','ncs','JLSGBS',null,80),
  ('ncs_jlsgnp','ncs','JLSGNP',null,90),        ('ncs_aircom','ncs','AIRCOM',null,100),
  ('ncs_marcom','ncs','MARCOM',null,110),       ('ncs_ncisg','ncs','NCISG',null,120),
  ('ncs_jallc','ncs','JALLC',null,130),         ('ncs_jftc','ncs','JFTC',null,140),
  ('ncs_jwc','ncs','JWC',null,150),             ('ncs_caoct','ncs','CAOCT',null,160),
  ('ncs_caocu','ncs','CAOCU',null,170),         ('ncs_daccc','ncs','DACCC',null,180),
  ('ncs_nshq','ncs','NSHQ',null,190),           ('ncs_jsec','ncs','JSEC',null,200),
  ('ncs_sjcsg','ncs','SJCSG',null,210),         ('ncs_kfor_hq','ncs','KFOR HQ',null,220),
  ('ncs_nmi','ncs','NATO Mission Iraq',null,230),('ncs_nhqsa','ncs','NHQSa',null,240),
  ('nfs_arrc','nfs','ARRC',null,10),            ('nfs_nrdc_ita','nfs','NRDC ITA',null,20),
  ('nfs_nrdc_esp','nfs','NRDC ESP',null,30),    ('nfs_nrdc_tur','nfs','NRDC TUR',null,40),
  ('nfs_1gnc','nfs','1st GNC',null,50),         ('nfs_eurocorps','nfs','EUROCORPS',null,60),
  ('nfs_rrc_fra','nfs','RRC FRA',null,70),      ('nfs_nrdc_grc','nfs','NRDC GRC',null,80),
  ('nfs_mnc_ne','nfs','MNC-NE',null,90),        ('nfs_mnd_ne','nfs','MND-NE',null,100),
  ('nfs_mnd_se','nfs','MND-SE',null,110),       ('nfs_mnd_c','nfs','MND-C',null,120),
  ('nfs_mnc_se','nfs','MNC-SE',null,130),       ('nfs_mnd_s','nfs','MND-S',null,140),
  ('nfs_mnd_n','nfs','MND-N',null,150),         ('nfs_jallc','nfs','JALLC',null,160),
  ('nfs_jwc','nfs','JWC',null,170),             ('nfs_nadefcol','nfs','NADEFCOL',null,180),
  ('agc_nso','agency','NSO',null,10),           ('agc_nsos','agency','NSOS',null,20),
  ('agc_ccoe','agency','CCOE',null,30),         ('agc_mncg','agency','MNCG',null,40),
  ('agc_dat','agency','DAT',null,50)
on conflict (key) do update set
  group_key=excluded.group_key, label_en=excluded.label_en,
  label_tr=excluded.label_tr, sort=excluded.sort;

-- ---- 7) ONCELIK LISTELERI ---------------------------------------------------
insert into public.conventity_ref_precedence_list (key, label_en, label_tr, description_en, description_tr, source_ref) values
  ('nato_internal','NATO internal order of precedence','NATO iç öncelik sırası',
   'For NATO-only events.','Salt NATO katılımlı etkinlikler için.',
   'NATO Protocol guide book §2.2'),
  ('vip_civil','Precedence list for events with military VIPs, civilian dignitaries and citizens',
   'Askerî VIP, sivil erkân ve vatandaş katılımlı etkinlikler için öncelik listesi',
   'For mixed events with civilian dignitaries and local officials.',
   'Sivil erkân ve yerel yetkililerin de katıldığı karma etkinlikler için.',
   'NATO Protocol guide book Appendix 2-1')
on conflict (key) do update set
  label_en=excluded.label_en, label_tr=excluded.label_tr,
  description_en=excluded.description_en, description_tr=excluded.description_tr,
  source_ref=excluded.source_ref;

insert into public.conventity_ref_precedence_item (list_key, position, label_en) values
  ('nato_internal', 1,'The Secretary General, Chairman of the North Atlantic Council'),
  ('nato_internal', 2,'Ministers of Foreign Affairs of member countries in order of precedence'),
  ('nato_internal', 3,'Ministers of Defence Affairs of member countries in order of precedence'),
  ('nato_internal', 4,'Permanent Representatives on the NAC in order of precedence'),
  ('nato_internal', 5,'The Deputy Secretary General'),
  ('nato_internal', 6,'The Chairman of the Military Committee'),
  ('nato_internal', 7,'Chiefs-of-Defence of member countries in order of precedence'),
  ('nato_internal', 8,'SACEUR'),
  ('nato_internal', 9,'SACT'),
  ('nato_internal',10,'Military Representatives in order of precedence'),
  ('nato_internal',11,'Four-stars Admirals and Generals in order of precedence'),
  ('nato_internal',12,'The Director of the Private Office of the Secretary General'),
  ('nato_internal',13,'Assistant Secretaries General in order of appointment'),
  ('nato_internal',14,'The Deputy Chairman of the Military Committee'),
  ('nato_internal',15,'The Director General of the International Military Staff'),
  ('nato_internal',16,'Deputy Permanent Representatives in order of precedence'),
  ('nato_internal',17,'SACEURREP and SACTREPEUR'),
  ('nato_internal',18,'Three-stars Admirals and Generals'),
  ('nato_internal',19,'Directors General of NATO Agencies'),
  ('nato_internal',20,'A7, OF7 and comparable officers in order of appointment, in the IS and IMS'),
  ('nato_internal',21,'A6, OF6 and comparable officers in order of appointment, in the IS and IMS'),
  ('nato_internal',22,'Deputy Military Representatives in order of appointment'),
  ('vip_civil', 1,'A Reigning Monarch / The Pope / Heads of State'),
  ('vip_civil', 2,'Head of Government'),
  ('vip_civil', 3,'Vice Heads of State'),
  ('vip_civil', 4,'A Head or Governor of a State or Province in his own State or Province'),
  ('vip_civil', 5,'Secretary General of NATO and International Organizations'),
  ('vip_civil', 6,'Former Heads of State'),
  ('vip_civil', 7,'Ambassadors when at post'),
  ('vip_civil', 8,'Ambassadors Extraordinary and Plenipotentiary of foreign powers'),
  ('vip_civil', 9,'Widows of former Heads of State'),
  ('vip_civil',10,'Ministers and Envoys Extraordinary of foreign powers'),
  ('vip_civil',11,'Ministers of Defence'),
  ('vip_civil',12,'Permanent Representatives to NATO and International Organizations'),
  ('vip_civil',13,'Senators / House of Lords'),
  ('vip_civil',14,'Mayors in their own town'),
  ('vip_civil',15,'Deputy Secretary General'),
  ('vip_civil',16,'Heads or Governors of Provinces or States (outside of their own state/province)'),
  ('vip_civil',17,'Acting heads of executive departments e.g. Acting Ministers'),
  ('vip_civil',18,'Former Vice Heads of Government'),
  ('vip_civil',19,'Members of the House of Representative / Members of Parliaments'),
  ('vip_civil',20,'Chairman of the Military Committee'),
  ('vip_civil',21,'Charge d''Affaires of Foreign Powers'),
  ('vip_civil',22,'Former Ministers'),
  ('vip_civil',23,'Ambassadors at Large (An Ambassador who is not assigned to a specific country)'),
  ('vip_civil',24,'Chiefs of Defence'),
  ('vip_civil',25,'Strategic Commander SACEUR'),
  ('vip_civil',26,'Strategic Commander SACT'),
  ('vip_civil',27,'Military Representatives to NATO'),
  ('vip_civil',28,'Four-star generals and admirals by seniority'),
  ('vip_civil',29,'Director of the Private Office, Assistant Secretaries General in order of appointment'),
  ('vip_civil',30,'Deputy Chairman of the Military Committee'),
  ('vip_civil',31,'Director General of the International Military Staff'),
  ('vip_civil',32,'Cardinals'),
  ('vip_civil',33,'Archbishops'),
  ('vip_civil',34,'Deputy Permanent Representatives'),
  ('vip_civil',35,'Deputy SACEUR and Deputy SACT'),
  ('vip_civil',36,'Three-star generals and admirals by seniority'),
  ('vip_civil',37,'Bishops'),
  ('vip_civil',38,'Defence Attachés'),
  ('vip_civil',39,'Two-star generals and admirals by seniority'),
  ('vip_civil',40,'One-star generals and admirals by seniority'),
  ('vip_civil',41,'Mayors outside of their town')
on conflict (list_key, position) do update set label_en=excluded.label_en;

-- ---- 8) KIYAFET KODU — §3.1 --------------------------------------------------
-- ⚠ (5) "occasions" sutunu kaynak ekran goruntusunde kesik — NULL.
insert into public.conventity_ref_dress_code
  (key, ordinal, label_en, label_tr, winter_uniform, summer_uniform, civilian, note) values
  ('mess_dress',1,'Mess Dress / Black Tie','Mess Dress / Black Tie',
   'Mess Dress / Dinner Dress — Black Tie · Short Jacket as defined by National requirements · Tails as appropriate · Miniature Medals',
   'Mess Dress / Dinner Dress — Black Tie · Short Jacket as defined by National requirements · Tails as appropriate · Miniature Medals',
   'Black Tie — Dinner Jacket (smoking) · Bow Tie', 'En resmi üniforma'),
  ('ceremonial',2,'Ceremonial / Formal','Tören / Resmî',
   'Ceremonial Dress — Service Dress with Medals · Swords and Gloves as required',
   'Ceremonial Dress — Service Dress (lightweight equivalent) with Medals · Long Sleeves · Closed neck or tie',
   'Formal — Dark Lounge / Business Suit', null),
  ('service_a',3,'Service Dress (Class A) / Informal','Service Dress (A) / Yarı resmî',
   'Service Dress (Class A) — Day Uniform with jacket and tie · Ribbons',
   'Service Dress (Class A) — Winter eşdeğeri hafif; Deniz için beyaz, ceketli',
   'Informal — Lounge / Business Suit · One Colour', null),
  ('working_b',4,'Working Dress (Class B) / Casual','Working Dress (B) / Günlük',
   'Working Dress (Class B) — Service Dress without jacket · Pullover / Sweater may be worn',
   'Working Dress (Class B) — Short Sleeved Shirt · Open Neck',
   'Casual — Tie · Different colour slacks and jacket', null),
  ('field',5,'Field Dress / Very Casual','Arazi Kıyafeti / Çok günlük',
   'Field Dress — Combat Uniform','Field Dress — Combat Uniform, sleeves rolled up',
   'Very Casual — Open neck', null),
  ('relaxed',6,'Relaxed','Serbest', null, null, 'Relaxed — Anything goes',
   'Askerî karşılığı kaynakta yok')
on conflict (key) do update set
  ordinal=excluded.ordinal, label_en=excluded.label_en, label_tr=excluded.label_tr,
  winter_uniform=excluded.winter_uniform, summer_uniform=excluded.summer_uniform,
  civilian=excluded.civilian, note=excluded.note;

-- Kaynagin acik notu — arayuzde dipnot olarak aynen gosterilecek.
comment on table public.conventity_ref_dress_code is
  'NATO Protocol guide book §3.1. Kaynak notu: "Protocol Offices do not dictate to civilian ladies correct form of dress. Ladies take their cue from the Men''s Dress Code."';

-- ---- 9) UNVANLAR VE HITAP BICIMLERI — App 3-3 --------------------------------
-- ⚠ (6) MNE ve NOM satirlari KAYNAKTA da bos. Monarsi satirlari 2010 tarihli.
insert into public.conventity_ref_address_form
  (nation_code, role, official_title, personal_form, written_form, source_note) values
  ('ALB','mod' ,'Minister of Defence','Minister','Minister',null),
  ('ALB','chod','Chief of the General Staff','General Doe','General Doe',null),
  ('ALB','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('BEL','mod' ,'Minister of Defence','Your Excellency','Your Excellency',null),
  ('BEL','chod','Chief of the General Staff of Belgium','General Doe','General Doe',null),
  ('BEL','monarch','King','Your Majesty','His/Her Majesty','kaynak 2010 tarihli — güncelliği teyit edilmeli'),
  ('BEL','ambassador','Ambassador','Your Excellence','Ambassador',null),
  ('BEL','knighted','Knight','Sir','Sir',null),
  ('BGR','mod' ,'Minister of Defence','Minister','Minister',null),
  ('BGR','chod','Chief of the General Staff','General Doe','General Doe',null),
  ('BGR','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('CAN','mod' ,'Minister of National Defence','Your Excellency','Your Excellency',null),
  ('CAN','chod','Chief of Defence Staff of Canada','General Doe','General Doe',null),
  ('CAN','monarch','Queen','Your Majesty','Queen Elizabeth II, Queen of Canada','kaynak 2010 tarihli — hükümdar değişti'),
  ('CAN','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('HRV','mod' ,'Minister of Defence','Minister','Minister',null),
  ('HRV','chod','Chief of the General Staff','General Doe','General Doe',null),
  ('HRV','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('CZE','mod' ,'Minister of Defence','Your Excellency','Your Excellency',null),
  ('CZE','chod','Chief of General Staff','Lieutenant General','Lieutenant General',null),
  ('CZE','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('DNK','mod' ,'Minister of Defence','Sir','Your Excellency',null),
  ('DNK','chod','Chief of Defence','General Doe','Sir',null),
  ('DNK','monarch','Queen','Your Majesty','Her Majesty Queen Margrethe II','kaynak 2010 tarihli — hükümdar değişti'),
  ('DNK','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('EST','mod' ,'Minister of Defence','Excellency "Doe"','Excellency "Doe"',null),
  ('EST','chod','Commander of Estonian Defence Forces','Major General "Doe"','"Doe"',null),
  ('EST','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('FRA','mod' ,'Minister of Defence','Madam or Mrs. Minister "Doe"','Madame or Mr. Minister of Defence "Doe"',null),
  ('FRA','chod','Chief of Staff','General "Doe"','Chief of Staff',null),
  ('FRA','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('DEU','mod' ,'Federal Minister of Defence','His/Her Excellency "Doe"','Excellency',null),
  ('DEU','chod','Chief of Staff, Bundeswehr','General "Doe"','Sir',null),
  ('DEU','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('GRC','mod' ,'Minister of National Defence','His/Her Excellency "Doe"','His/Her Excellency Minister of National Defence "Doe"',null),
  ('GRC','chod','Chief of the Hellenic National Defence General Staff','General "Doe"','General "Doe"',null),
  ('GRC','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('HUN','mod' ,'Minister of Defence','His/Her Excellency "Doe"','His/Her Excellency "Doe"',null),
  ('HUN','chod','Chief of Defence Staff','General "Doe"','General "Doe"',null),
  ('HUN','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('ISL','mod' ,'Minister of Foreign Affairs','His/Her Excellency "Doe"','Your Excellency','İzlanda''nın ordusu yok — MOD yerine Dışişleri Bakanı'),
  ('ISL','chod','Director, Defence Department, Ministry for Foreign Affairs and External Trade of Iceland','Ambassador "Doe"','Ambassador "Doe"',null),
  ('ISL','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('ITA','mod' ,'Minister of Defence','His/Her Excellency "Doe"','Minister "Doe"',null),
  ('ITA','chod','Chief of Defence Staff of Italy','Admiral "Doe"','Sir',null),
  ('ITA','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('LVA','mod' ,'Minister of Defence','Sir','Sir',null),
  ('LVA','chod','Commander of National Armed Force','Brigadier General "Doe"','Sir',null),
  ('LVA','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('LTU','mod' ,'Ministry of Defence of the Republic of Lithuania','Your Excellency','Your Excellency',null),
  ('LTU','chod','Chief of Defence','General','Major General',null),
  ('LTU','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('LUX','mod' ,'Minister of Defence','Your Excellency "Doe"','Your Excellency',null),
  ('LUX','chod','Chief of Staff of the Luxembourg Army','Colonel "Doe"','Sir',null),
  ('LUX','monarch','Grand Duke',null,null,'kaynak 2010 tarihli'),
  ('LUX','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('MNE','mod' ,'Minister of Defence',null,null,'⚠ kaynakta bu satır boş'),
  ('MNE','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('NLD','mod' ,'Minister of Defence','Your Excellency "Doe"','Your Excellency "Doe"',null),
  ('NLD','chod','Chief of Defence Staff','Sir','General "Doe"',null),
  ('NLD','monarch','Queen','Your Majesty','Your Majesty','kaynak 2010 tarihli — hükümdar değişti'),
  ('NLD','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('NOM','mod' ,'Minister of Defence',null,null,'⚠ kaynakta bu satır boş'),
  ('NOM','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('NOR','mod' ,'Minister of Defence','Your Excellency','Your Excellency',null),
  ('NOR','chod','Chief of Defence','General "Doe"','General "Doe"',null),
  ('NOR','monarch','King','Your Majesty','His Majesty the King of Norway','kaynak 2010 tarihli — teyit edilmeli'),
  ('NOR','ambassador','Ambassador','Ambassador','Ambassador',null),
  ('POL','mod' ,'Minister of Defence','His/Her Excellency "Doe"','Excellency',null),
  ('POL','chod','Chief of Defence of the Polish Armed Forces','Sir','Sir',null),
  ('POL','ambassador','Ambassador of Republic of Poland','Ambassador','Ambassador',null),
  ('PRT','mod' ,'Minister of Defence','Your Excellency','Your Excellency',null),
  ('PRT','chod','Chief of Defence','Sir','Sir',null),
  ('PRT','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('ROU','mod' ,'Minister of Defence','Your Excellency','Your Excellency',null),
  ('ROU','chod','Chief of the General Staff','Sir','Sir',null),
  ('ROU','ambassador','Ambassador','Your Excellency','Your Excellency',null),
  ('SVK','mod' ,'Minister of Defence','His/Her Excellency "Doe"','Your Excellency',null),
  ('SVK','chod','Chief of the General Staff of the Slovak Armed Forces','Sir','Sir',null),
  ('SVK','ambassador','Ambassador','Excellency','Excellency',null),
  ('SVN','mod' ,'Minister of Defence','His/Her Excellency "Doe"','Your Excellency',null),
  ('SVN','chod','Chief of the General Staff of the Slovenian Armed Forces','Sir','Sir',null),
  ('SVN','ambassador','Ambassador','Excellency','Excellency',null),
  ('ESP','mod' ,'Minister of Defence','His/Her Excellency "Doe"','Your Excellency',null),
  ('ESP','chod','Chief of Defence Staff','Sir','Sir',null),
  ('ESP','monarch','King','Your Majesty','Your Majesty','kaynak 2010 tarihli'),
  ('ESP','ambassador','Ambassador','Excellency','Excellency',null),
  ('TUR','mod' ,'Minister of Defence','Your Excellency "Doe"','Your Excellency "Doe"',null),
  ('TUR','chod','Commander of The Turkish Armed Forces','Sir','Sir',null),
  ('TUR','ambassador','Ambassador','Excellency','Excellency',null),
  ('GBR','mod' ,'Secretary of State for Defence','Sir','Dear Secretary of State',null),
  ('GBR','chod','Chief of Defence Staff','Sir Doe','Dear Air Chief Marshal',null),
  ('GBR','monarch','Queen','Your Majesty','Your Majesty','kaynak 2010 tarihli — hükümdar değişti'),
  ('GBR','ambassador','Ambassador','Excellency','Excellency',null),
  ('GBR','knighted','Knight','Sir Doe','Dear Sir Doe',null),
  ('USA','mod' ,'Secretary of Defence','The Honourable "Doe"','The Honourable "Doe"',null),
  ('USA','chod','Chairman, Joint Chiefs of Staff','General "Doe"','General "Doe"',null),
  ('USA','ambassador','Ambassador','The Honourable','The Honourable',null)
on conflict (nation_code, role) do update set
  official_title=excluded.official_title, personal_form=excluded.personal_form,
  written_form=excluded.written_form, source_note=excluded.source_note;

-- ---- 10) LANDCOM KONFERANSI — protokol varsayilani --------------------------
-- Salt NATO katilimli: nato_internal (22). Karma katilim olursa etkinlik
-- ayarindan vip_civil'e cevrilir — kod degisikligi gerekmez.
update public.conventus_managed_events
   set precedence_list   = coalesce(precedence_list, 'nato_internal'),
       alpha_language    = coalesce(alpha_language, 'en'),
       partner_placement = coalesce(partner_placement, 'after')
 where code = 'LANDCOM-CONF-2026';

notify pgrst, 'reload schema';

-- ---- 11) DOGRULAMA — tek sorgu ----------------------------------------------
select
  (select count(*) from public.conventity_ref_nation)                          as "ulus (70)",
  (select count(*) from public.conventity_ref_nation where bloc='nato')        as "NATO uyesi (32)",
  (select count(*) from public.conventity_ref_nato_grade)                      as "kademe (20)",
  (select count(*) from public.conventity_ref_rank)                            as "rutbe (63)",
  (select count(*) from public.conventity_ref_capacity)                        as "sifat (30)",
  (select count(*) from public.conventity_ref_title)                           as "unvan (56)",
  (select count(*) from public.conventity_ref_organization)                    as "kurulus (49)",
  (select count(*) from public.conventity_ref_precedence_item where list_key='nato_internal') as "NATO ic sira (22)",
  (select count(*) from public.conventity_ref_precedence_item where list_key='vip_civil')     as "VIP/sivil sira (41)",
  (select count(*) from public.conventity_ref_dress_code)                      as "kiyafet (6)",
  (select count(*) from public.conventity_ref_address_form)                    as "hitap (98)";

-- ---- 12) KURAL SINAMASI — skor dogru mu? ------------------------------------
-- §2.2 "Positional Authority": Albay (OF-5=400) olan bir Genelkurmay Baskani
-- (chief_of_defence=1050) CHOD onceligi almali. Ve temsil eden kisi temsil
-- edilenin onceligini almali.
select
  public.conventity_precedence_score(null,'chief_of_defence',null,'OF-5')   as "Albay CHOD (1050 olmali)",
  public.conventity_precedence_score(null,'national_rep',null,'OF-9')       as "Ulusal temsilci 4 yildiz (700)",
  public.conventity_precedence_score(null,'national_rep',null,'OF-5')       as "Ulusal temsilci Albay (400)",
  public.conventity_precedence_score(null,'interpreter',null,null)          as "Rutbesiz tercuman (100)",
  public.conventity_precedence_score(null,'national_rep','minister','OF-3') as "Bakani temsilen Binbasi (1100)",
  public.conventity_precedence_score('secretary_general','observer',null,'OF-1') as "Genel Sekreter (1500)",
  public.conventity_precedence_score(null,'com',null,null)                  as "tanimsiz sifat (0)",
  public.conventity_identity_string('GEN','Doe','TUR','A')                  as "kimlik dizesi";
