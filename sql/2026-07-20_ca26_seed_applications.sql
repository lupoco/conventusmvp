-- =====================================================================
-- CA'26 EFDI PILOT 4 — 50 GERCEK BASVURU SEED
--
-- Kaynak: CA26_EFDI_Pilot4_Company_Assessment.pdf (DEFINE / RAIN Global,
-- 16 Mart 2026). Motor kalibrasyonunda kullanilan ayni veri seti.
--
-- Amac: triyaj konsolunu gercek hacimde test etmek. Motor calistirildiginda
-- beklenen sonuc: MUST 9 / MAYBE 17 / NO 24, portfoy terfisi Stridar + Alfatec.
--
-- submitted_by = NULL  -> sistem seed (gercek kullanici basvurusu degil)
-- source_ref uzerinden idempotent: tekrar calistirilirsa kopya olusmaz.
--
-- Idempotent. Onceki 4 migration calistirildktan SONRA calistir.
-- =====================================================================

-- Seed izlenebilirligi icin isaretleyici kolon
alter table public.conventus_selection_applications
  add column if not exists source_ref text;

create unique index if not exists uq_csa_source_ref
  on public.conventus_selection_applications(source_ref)
  where source_ref is not null;

-- ---------------------------------------------------------------------
-- 1) 50 BASVURU
-- ---------------------------------------------------------------------
with ev as (
  select id from public.conventus_selection_events where event_code = 'CA26-EFDI-P4'
),
src(company_name, country, registration_country, org_type, system_name,
    trl_demo, artifact_class, domain_axis, isc_domain, validation_tier,
    summary, integration_path, blockers, fit_flags, diana_backed) as (
  values
  ('NATRIX','LV','LV','startup','NATRIX system',9,'ugv_platform','ground','LAND','combat_fielded','Combat-proven cargo/CASEVAC/ISTAR/demining UGV, Ukraine frontline.',true,'{}',ARRAY['host_nation']::text[],false),
  ('Ark Robotics','EE','EE','startup','Ark Robotics system',9,'ugv_platform','ground','LAND','combat_fielded','A1 ~1000 units to UA AF (TRL9), M4 TRL7. US Army xTech. TAK via DiBaX.',true,'{}',ARRAY['c2_integration','allied_program']::text[],false),
  ('ARX Robotics','UK/DE','UK/DE','startup','ARX Robotics system',8,'ugv_platform','ground','LAND','combat_fielded','Ongoing UA deployment. LANDCOM EFDL Pilots 1&2. Sandhurst, British Army exercises.',true,'{}',ARRAY['prior_efdi']::text[],false),
  ('LMTK LLC','UA','UA','scaleup','LMTK LLC system',9,'ugv_platform','ground','LAND','combat_fielded','Combat-proven logistics UGV, 384km before first maintenance.',false,'{}','{}',false),
  ('Husarion','PL','PL','industry','Husarion system',8,'ugv_platform','ground','LAND','national_trial','Panther UGV, ROS2, modular payload interface, MESH, swappable batteries.',true,'{}',ARRAY['c2_integration']::text[],false),
  ('Libertus Dynamics AB','SE','SE','industry','Libertus Dynamics AB system',7,'ugv_platform','ground','LAND','allied_exercise','Ironhorse Ranger tracked UGV. EFDI/TFX Finland pilot. Swedish AF K4 winter.',true,'{}',ARRAY['prior_efdi']::text[],false),
  ('Alfatec Group','EE','EE','startup','Alfatec Group system',8,'mountable_subsystem','ground','LAND','combat_tested','WPU + GANYMEDE GNSS CRPA anti-jam, combat-tested with UA AF 383rd UAV Bde.',true,'{}','{}',false),
  ('Cyborg Dynamics Eng.','AU','AU','industry','Cyborg Dynamics Eng. system',8,'ugv_platform','ground','LAND','allied_exercise','340kg payload, 8h runtime, 20kWh swappable. PC-C5, Talisman Sabre.',true,'{}','{}',false),
  ('Stridar','US/XK','US/XK','startup','Stridar system',6,'ugv_platform','ground','LAND','national_trial','Siderunner UGV + EW sensors + tethered drone relay. 1st CAV US Army trials.',true,'{}','{}',false),
  ('RACOM s.r.o.','CZ','CZ','industry','RACOM s.r.o. system',7,'mountable_subsystem','ground','LAND','allied_exercise','WaSP SDR for UGV/UAV MESH. FPGA, interference-resistant. Deployed in NATO armies.',true,'{}','{}',false),
  ('Quell','UK','UK','startup','Quell system',8,'mountable_subsystem','ground','LAND','allied_exercise','SkySpyke passive EO C-UAS. Army Warfighting Experiment, UK-US trials.',false,'{}','{}',false),
  ('Beechat Network','UK','UK','startup','Beechat Network system',6,'mountable_subsystem','ground','LAND','national_trial','Kaonic tactical mesh radio, sub-GHz SDR. DIANA 2026. REPMUS confirmed.',false,'{}',ARRAY['diana']::text[],true),
  ('Bluestaq LLC','US','US','industry','Bluestaq LLC system',8,'embedded_software','ground','LAND','allied_exercise','Edge UDL sensor/C2 data federation. MITRE validated, AFCENT deployed.',true,'{}',ARRAY['c2_integration']::text[],false),
  ('Tern AI Inc','US','US','startup','Tern AI Inc system',7,'embedded_software','ground','LAND','none','IDPS GNSS-denied nav via OBD-II sensor fusion. No external validation cited.',false,'{}','{}',false),
  ('ORASIO','FR','FR','startup','ORASIO system',7,'embedded_software','ground','LAND','national_trial','Argos edge video analytics. AI detection/tracking in operational environments.',false,'{}','{}',false),
  ('Visgrid AB','SE','SE','startup','Visgrid AB system',7,'mountable_subsystem','ground','LAND','national_trial','Stereoscopic passive EO/IR 3D tracking, 2km FPV detection. Frontex red/blue validation.',true,'{}','{}',false),
  ('CyberHive','UK','UK','industry','CyberHive system',8,'embedded_software','ground','LAND','national_trial','Identity-based encrypted comms overlay for degraded networks. UK defence evaluated.',false,'{}','{}',false),
  ('Moduler Makina','TR','TR','startup','Moduler Makina system',7,'ugv_platform','ground','LAND','none','ENOCH modular battery-electric/hybrid ground vehicle. Operational prototype, no field validation.',false,'{}','{}',false),
  ('KUARTIS','TR','TR','industry','KUARTIS system',8,'embedded_software','ground','LAND','national_trial','KILAVUZ.AI universal autonomy suite on tracked UGV, tactical wheeled, 8x8.',true,'{}','{}',false),
  ('Elitac Wearables','NL','NL','startup','Elitac Wearables system',6,'mountable_subsystem','ground','LAND','national_trial','Acoustic vector sensor + haptic operator alerting. Royal Netherlands Armed Forces.',false,'{}','{}',false),
  ('BeephoniX','NL','NL','startup','BeephoniX system',7,'mountable_subsystem','ground','LAND','national_trial','Passive acoustic drone detection, MEMS arrays + AI. Dutch MOD demos.',false,'{}','{}',false),
  ('Bareways','DE','DE','startup','Bareways system',5,'embedded_software','ground','LAND','national_trial','Decentralised DDIL coordination, offline-first COTS Android. Rheinmetall partner.',false,'{}','{}',false),
  ('Adscensus MB','LT','LT','industry','Adscensus MB system',7,'ops_enabler','ground','LAND','combat_tested','Man-portable tactical power units 3-6kW. Shipping to Ukraine.',false,'{}','{}',false),
  ('Avientus','CH','CH','startup','Avientus system',6,'adjacent_platform','aerial','AIR','national_trial','Transport drones. Prototype sold to Swiss Armed Forces. Aerial, not ground.',false,'{}','{}',false),
  ('LayerX GmbH','DE','DE','startup','LayerX GmbH system',5,'mountable_subsystem','ground','LAND','national_trial','Trailer-mounted HEL C-UAS towable by autonomous ground platform. Bundeswehr trials Apr 2026.',true,'{}','{}',false),
  ('Brasa Defence Systems','LV','LV','industry','Brasa Defence Systems system',8,'ugv_platform','ground','LAND','national_trial','Modular ground support platforms for Latvian Armed Forces. Local company.',false,'{}',ARRAY['host_nation']::text[],false),
  ('Atlas Innovative Tech','UK','UK','startup','Atlas Innovative Tech system',6,'ops_enabler','ground','LAND','national_trial','Arachnet deployable fibre-optic comms for EW-contested C2. DIANA 2026.',false,'{}',ARRAY['diana']::text[],true),
  ('Red Hat','US','US','industry','Red Hat system',8,'out_of_domain','other',null,'national_trial','Enterprise edge computing / Kubernetes. Too far from UGV operational demo.',false,'{}','{}',false),
  ('Farsight Vision','EE','EE','startup','Farsight Vision system',7,'embedded_software','ground','LAND','none','RT-Path route planning. Online-mode only — contradicts EW/DDIL requirement.',false,ARRAY['requires_backend']::text[],'{}',false),
  ('ROBOTDRONES IKE','GR','GR','startup','ROBOTDRONES IKE system',6,'out_of_domain','other',null,'national_trial','Underground anti-drone ''Capsule''. Static defence, not mobile ground autonomy.',false,'{}','{}',false),
  ('TOBB ETU','TR','TR','industry','TOBB ETU system',null,'unknown','other',null,'none','All fields filled with ''TOBB ETU''. No usable information.',false,ARRAY['incomplete_application']::text[],'{}',false),
  ('Design Lead Oy','FI','FI','spinoff','Design Lead Oy system',6,'ugv_platform','ground','LAND','none','Autonomous drone carrier vehicle. No references, no materials shareable.',false,ARRAY['incomplete_application']::text[],'{}',false),
  ('Verac','UK','UK','startup','Verac system',6,'out_of_domain','other',null,'none','Maritime AIS anomaly detection. No ground autonomy relevance.',false,'{}','{}',false),
  ('Hydro Road Ltd','UK','UK','startup','Hydro Road Ltd system',7,'out_of_domain','other',null,'none','Soil stabilisation / road engineering.',false,'{}','{}',false),
  ('Cihatek Elektronik','TR','TR','startup','Cihatek Elektronik system',7,'out_of_domain','other',null,'none','Spectra laser rifle guidance — small arms aiming device.',false,'{}','{}',false),
  ('Exentech Savunma','TR','TR','startup','Exentech Savunma system',4,'mountable_subsystem','ground','LAND','none','SightSphere confined-space imaging. TRL 4 primary. Linked to Cihatek.',false,'{}','{}',false),
  ('Hubble Network','US','US','startup','Hubble Network system',8,'mountable_subsystem','other',null,'national_trial','Space-based Bluetooth-to-satellite. Cannot demonstrate in exercise.',false,ARRAY['infrastructure_dependent']::text[],'{}',false),
  ('TAG','US','US','small_business','TAG system',6,'mountable_subsystem','ground','LAND','national_trial','Resilient PNT, M-Code receiver. US-restricted — export/classification blocker.',false,ARRAY['export_restricted']::text[],'{}',false),
  ('Aware Robotics','TR','TR','industry','Aware Robotics system',5,'ugv_platform','ground','LAND','none','Autonomous quadruped, prototype. TRL 5, no references or deployments.',false,'{}','{}',false),
  ('VSight UAB','LT','LT','startup','VSight UAB system',8,'out_of_domain','other',null,'national_trial','AR remote maintenance assistance. Not ground autonomy.',false,'{}','{}',false),
  ('RePG Energy Systems','TR','TR','startup','RePG Energy Systems system',8,'out_of_domain','other',null,'none','Waste heat to electricity (ORC). Industrial, not tactical.',false,'{}','{}',false),
  ('Radius Defence','TR/UK','TR/UK','startup','Radius Defence system',5,'embedded_software','ground','LAND','none','Game-theory strategic integration layer. Consulting, no deployable technology.',false,ARRAY['research_stage']::text[],'{}',false),
  ('BVK Technology','TR','TR','industry','BVK Technology system',6,'mountable_subsystem','ground','LAND','none','GNSSGard4000 resilient positioning. Isolated subsystem, no platform integration.',false,'{}','{}',false),
  ('DT Cloud','TR','TR','startup','DT Cloud system',7,'out_of_domain','other',null,'none','Sovereign edge-to-core compute. Cloud infrastructure, not a UGV demo.',false,'{}','{}',false),
  ('Singularity R&D','TR','TR','startup','Singularity R&D system',7,'out_of_domain','other',null,'none','AutoSecOps cybersecurity / predictive maintenance. No ground autonomy relevance.',false,'{}','{}',false),
  ('Aereus GmbH','DE','DE','startup','Aereus GmbH system',5,'embedded_software','aerial','AIR','national_trial','Multi-modal sensor fusion / 3D reconstruction from drone imagery. TRL 5, aerial ISR.',false,'{}',ARRAY['diana']::text[],true),
  ('Infinite Foundry','PT','PT','startup','Infinite Foundry system',6,'embedded_software','ground','LAND','none','AMIDA orchestration software. No hardware to demonstrate, limited validation.',false,'{}','{}',false),
  ('Volinor Savunma','TR','TR','startup','Volinor Savunma system',1,'mountable_subsystem','ground','LAND','none','Anti-drone netting material research. TRL 1.',false,'{}','{}',false),
  ('REPWR','CA','CA','startup','REPWR system',6,'ops_enabler','ground','LAND','none','Containerised expeditionary microgrid. Less proven than Adscensus.',false,'{}','{}',false),
  ('Wiewiorka Works','PL','PL','startup','Wiewiorka Works system',5,'mountable_subsystem','ground','LAND','none','Open-source C-UAS forensic drone recovery. Self-funded, no defence customers.',false,'{}','{}',false)
)
insert into public.conventus_selection_applications
  (event_id, submitted_by, company_name, country, registration_country, org_type,
   system_name, trl_demo, artifact_class, domain_axis, isc_domain,
   validation_tier, validation_detail, summary, integration_path,
   blockers, fit_flags, diana_backed, state, source_ref)
select ev.id, null, s.company_name, s.country, s.registration_country, s.org_type,
       s.system_name, s.trl_demo, s.artifact_class, s.domain_axis, s.isc_domain,
       s.validation_tier, s.summary, s.summary, s.integration_path,
       s.blockers, s.fit_flags, s.diana_backed, 'submitted',
       'CA26-SEED-' || s.company_name
from src s cross join ev
where not exists (
  select 1 from public.conventus_selection_applications x
  where x.source_ref = 'CA26-SEED-' || s.company_name
);

-- ---------------------------------------------------------------------
-- 2) CHALLENGE ALANI BAGLANTILARI (app_needs)
--    is_primary: portfoy gecisinin dayandigi alan, basvuru basina TAM BIR tane
-- ---------------------------------------------------------------------
with ev as (
  select id from public.conventus_selection_events where event_code = 'CA26-EFDI-P4'
),
m(company_name, need_code, is_primary) as (
  values
  ('NATRIX', 'MODULAR', true),
  ('NATRIX', 'EW', false),
  ('NATRIX', 'ENDURANCE', false),
  ('Ark Robotics', 'MODULAR', true),
  ('Ark Robotics', 'EW', false),
  ('Ark Robotics', 'ENDURANCE', false),
  ('ARX Robotics', 'MODULAR', true),
  ('ARX Robotics', 'ENDURANCE', false),
  ('LMTK LLC', 'ENDURANCE', true),
  ('Husarion', 'MODULAR', true),
  ('Husarion', 'EW', false),
  ('Husarion', 'ENDURANCE', false),
  ('Libertus Dynamics AB', 'MODULAR', true),
  ('Libertus Dynamics AB', 'EW', false),
  ('Libertus Dynamics AB', 'ENDURANCE', false),
  ('Alfatec Group', 'EW', true),
  ('Cyborg Dynamics Eng.', 'MODULAR', false),
  ('Cyborg Dynamics Eng.', 'ENDURANCE', true),
  ('Stridar', 'EW', true),
  ('RACOM s.r.o.', 'EW', true),
  ('Quell', 'MODULAR', true),
  ('Beechat Network', 'EW', true),
  ('Bluestaq LLC', 'EW', true),
  ('Tern AI Inc', 'EW', true),
  ('ORASIO', 'EW', true),
  ('ORASIO', 'ENDURANCE', false),
  ('Visgrid AB', 'MODULAR', false),
  ('Visgrid AB', 'EW', true),
  ('CyberHive', 'EW', true),
  ('Moduler Makina', 'MODULAR', true),
  ('Moduler Makina', 'EW', false),
  ('KUARTIS', 'ENDURANCE', true),
  ('Elitac Wearables', 'MODULAR', true),
  ('Elitac Wearables', 'ENDURANCE', false),
  ('BeephoniX', 'MODULAR', true),
  ('Bareways', 'EW', true),
  ('Bareways', 'ENDURANCE', false),
  ('Adscensus MB', 'ENDURANCE', true),
  ('Avientus', 'EW', false),
  ('Avientus', 'ENDURANCE', true),
  ('LayerX GmbH', 'MODULAR', true),
  ('Brasa Defence Systems', 'ENDURANCE', true),
  ('Atlas Innovative Tech', 'EW', true),
  ('Red Hat', 'MODULAR', false),
  ('Red Hat', 'EW', true),
  ('Red Hat', 'ENDURANCE', false),
  ('Farsight Vision', 'EW', true),
  ('ROBOTDRONES IKE', 'MODULAR', true),
  ('ROBOTDRONES IKE', 'EW', false),
  ('ROBOTDRONES IKE', 'ENDURANCE', false),
  ('Design Lead Oy', 'EW', true),
  ('Verac', 'EW', true),
  ('Hydro Road Ltd', 'ENDURANCE', true),
  ('Cihatek Elektronik', 'MODULAR', true),
  ('Cihatek Elektronik', 'ENDURANCE', false),
  ('Exentech Savunma', 'MODULAR', true),
  ('Exentech Savunma', 'EW', false),
  ('Exentech Savunma', 'ENDURANCE', false),
  ('Hubble Network', 'EW', true),
  ('TAG', 'EW', true),
  ('Aware Robotics', 'MODULAR', true),
  ('Aware Robotics', 'EW', false),
  ('Aware Robotics', 'ENDURANCE', false),
  ('VSight UAB', 'EW', true),
  ('RePG Energy Systems', 'ENDURANCE', true),
  ('Radius Defence', 'EW', true),
  ('BVK Technology', 'EW', true),
  ('BVK Technology', 'ENDURANCE', false),
  ('DT Cloud', 'EW', true),
  ('DT Cloud', 'ENDURANCE', false),
  ('Singularity R&D', 'MODULAR', false),
  ('Singularity R&D', 'EW', true),
  ('Singularity R&D', 'ENDURANCE', false),
  ('Aereus GmbH', 'EW', true),
  ('Aereus GmbH', 'ENDURANCE', false),
  ('Infinite Foundry', 'ENDURANCE', true),
  ('Volinor Savunma', 'MODULAR', true),
  ('REPWR', 'ENDURANCE', true),
  ('Wiewiorka Works', 'MODULAR', true),
  ('Wiewiorka Works', 'EW', false),
  ('Wiewiorka Works', 'ENDURANCE', false)
)
insert into public.conventus_selection_app_needs (application_id, need_id, is_primary)
select a.id, n.id, m.is_primary
from m
join ev on true
join public.conventus_selection_applications a
  on a.event_id = ev.id and a.source_ref = 'CA26-SEED-' || m.company_name
join public.conventus_selection_needs n
  on n.event_id = ev.id and n.code = m.need_code
where not exists (
  select 1 from public.conventus_selection_app_needs x
  where x.application_id = a.id and x.need_id = n.id
);

-- ---------------------------------------------------------------------
-- 3) DOGRULAMA
-- ---------------------------------------------------------------------
select
  (select count(*) from public.conventus_selection_applications a
     join public.conventus_selection_events e on e.id = a.event_id
    where e.event_code = 'CA26-EFDI-P4')                        as basvuru_sayisi,
  (select count(*) from public.conventus_selection_app_needs an
     join public.conventus_selection_applications a on a.id = an.application_id
     join public.conventus_selection_events e on e.id = a.event_id
    where e.event_code = 'CA26-EFDI-P4')                        as alan_baglantisi,
  (select count(*) from public.conventus_selection_app_needs an
     join public.conventus_selection_applications a on a.id = an.application_id
     join public.conventus_selection_events e on e.id = a.event_id
    where e.event_code = 'CA26-EFDI-P4' and an.is_primary)      as ana_alan_sayisi;

-- Beklenen: basvuru_sayisi = 50, ana_alan_sayisi = 49 (TOBB ETU'nun alani yok)
-- =====================================================================
