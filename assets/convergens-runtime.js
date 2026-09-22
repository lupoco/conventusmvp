/* ============================================================
   Conventity — Convergens / Conventlab shared map + OSINT engine
   ============================================================
   Extracted from index.html. Drives BOTH:
     • the Leaflet "Eastern Flank" region/corridor map  (Conventlab · #cvgLeafletRegion)
     • the MapLibre world OSINT map                      (Convergens · #cvgWorldMap)
   Each page contains only one of the two map elements; init guards build
   whichever is present. Shared state lives on window (cvgMode, cvgEventMap,
   cvgNaiBump, refreshCvgMarkers, cvgFocusCountry).

   Loaded by platforms/conventlab.html and platforms/convergens.html AFTER
   leaflet + maplibre, and after platform-shell.js.
   ============================================================ */
(function(){
  'use strict';
  const html = document.documentElement;

  // ── Null-safe stubs for landing-only refs that this engine used to share
  //    scope with (the landing's nav/drawer/workspace controllers). On a
  //    standalone platform page they simply no-op. ──
  function closeAllMenus(){}
  const mobileDrawer = { classList:{ add(){}, remove(){}, contains(){return false;} } };
  const workspace    = { classList:{ add(){}, remove(){}, contains(){return false;} } };
  // Stub overlay used when this page doesn't contain #convergensOverlay
  // (e.g. the Conventlab page, which only needs the region map).
  function cvgStub(){
    const noop=function(){};
    return {
      classList:{ add:noop, remove:noop, contains:function(){return false;}, toggle:noop },
      querySelectorAll:function(){return [];},
      querySelector:function(){return null;},
      scrollTo:noop, setAttribute:noop, getAttribute:function(){return null;},
      getBoundingClientRect:function(){return {top:0,left:0,bottom:0,right:0};},
      scrollTop:0, addEventListener:noop
    };
  }

  // ── CONVERGENS OVERLAY ──
  const cvg = document.getElementById('convergensOverlay') || cvgStub();
  // map state
  let cvgMapsReady = false;
  let cvgRegionMap = null, cvgEventMap = null;
  const cvgCountryMarkers = {}, cvgEventMarkers = {};
  let cvgRegionTile = null, cvgEventTile = null;
  function tileUrl() {
    return document.documentElement.dataset.theme === 'dark'
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  }
  function openConvergens() {
    cvg.classList.add('open');
    cvg.setAttribute('aria-hidden','false');
    document.body.style.overflow = 'hidden';
    closeAllMenus();
    mobileDrawer && mobileDrawer.classList.remove('open');
    cvg.scrollTo({ top: 0, behavior: 'instant' });
    setCvgTab('overview');
    // Init Leaflet after the overlay is visible & sized
    setTimeout(() => {
      initCvgMaps();
      if (cvgRegionMap) cvgRegionMap.invalidateSize();
      if (cvgEventMap && typeof cvgEventMap.resize === 'function') cvgEventMap.resize();
    }, 80);
  }
  function closeConvergens() {
    cvg.classList.remove('open');
    cvg.setAttribute('aria-hidden','true');
    if (!workspace.classList.contains('open')) document.body.style.overflow = '';
  }
  function setCvgTab(name) {
    cvg.querySelectorAll('.cvg-tabs a').forEach(a => a.classList.toggle('active', a.dataset.cvgTab === name));
    const anchor = cvg.querySelector(`[data-cvg-anchor="${name}"]`);
    if (anchor) {
      const top = anchor.getBoundingClientRect().top + cvg.scrollTop - 80;
      cvg.scrollTo({ top, behavior: 'smooth' });
    }
  }
  document.querySelectorAll('[data-open-convergens]').forEach(el => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      openConvergens();
    });
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        openConvergens();
      }
    });
  });
  cvg.querySelectorAll('[data-cvg-close]').forEach(b => b.addEventListener('click', closeConvergens));
  cvg.querySelectorAll('.cvg-tabs a').forEach(a => {
    a.addEventListener('click', (e) => { e.preventDefault(); setCvgTab(a.dataset.cvgTab); });
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && cvg.classList.contains('open')) closeConvergens();
  });

  // Filter toggles — show/hide Leaflet event markers by category
  const filterMap = {
    armed:        ['ukraine','sudan','myanmar','yemen','drc'],
    disaster:     ['cali_fire','pak_flood','japan_quake','turkey_fire'],
    political:    ['argentina','haiti','iran_protest'],
    cultural:     ['mali_cpp','yemen_cpp'],
    humanitarian: ['gaza','afghanistan','somalia'],
    hybrid:       ['baltics_hybrid','moldova_hybrid'],
    info:         ['eu_disinfo','africa_disinfo'],
    warn:         ['japan_quake','iran_protest','moldova_hybrid','turkey_fire','mali_cpp'],
    trend:        ['argentina','eu_disinfo','africa_disinfo','baltics_hybrid','afghanistan'],
    '2nd':        ['gaza','ukraine','sudan','pak_flood','yemen','drc']
  };
  // Track per-marker active flags: a marker shows if AT LEAST one of its filters is ON
  // Live-feed categories → analytical layer key, so feed pins obey the same toggles
  const FEEDCAT_TO_FLT = { armed:'armed', mil:'armed', hybrid:'hybrid', cyber:'hybrid', info:'info', infra:'political' };
  function refreshMarkerVisibility() {
    if (!cvgEventMap) return;
    const focus = window.cvgFocusCountry || null;
    const activeFilters = new Set();
    cvg.querySelectorAll('.cvg-filter.on').forEach(f => activeFilters.add(f.dataset.cvgFlt));
    // Build per-event eligibility: an event is visible if any of its categories is in activeFilters
    Object.keys(cvgEventMarkers).forEach(key => {
      // categories that include this event:
      const cats = Object.entries(filterMap).filter(([cat, arr]) => arr.includes(key)).map(([cat]) => cat);
      let visible = cats.length === 0 || cats.some(c => activeFilters.has(c));
      const marker = cvgEventMarkers[key];
      const el = marker.getElement();
      // Country focus override: only that country's points stay active
      if (focus) visible = (el && el.dataset.cc === focus);
      if (el) { el.style.display = visible ? '' : 'none'; el.style.pointerEvents = visible ? 'auto' : 'none'; }
    });
    // Live OSINT feed pins keep flowing on the map regardless of country focus —
    // they represent real-time incoming intel. They still obey the layer toggles.
    document.querySelectorAll('.cvgx-pin').forEach(pin => {
      const flt = FEEDCAT_TO_FLT[pin.dataset.cat];
      const visible = (!flt || activeFilters.has(flt));
      pin.style.display = visible ? '' : 'none';
    });
  }
  window.refreshCvgMarkers = refreshMarkerVisibility;
  cvg.querySelectorAll('.cvg-filter').forEach(f => {
    f.addEventListener('click', () => {
      f.classList.toggle('on');
      refreshMarkerVisibility();
    });
  });

  // ── 2D flat ↔ 3D rotating globe toggle for the world OSINT map ──
  cvg.querySelectorAll('[data-cvg-mode-control] [data-cvg-mode]').forEach(btn => {
    btn.addEventListener('click', () => {
      const mode = btn.dataset.cvgMode;
      cvg.querySelectorAll('[data-cvg-mode-control] [data-cvg-mode]').forEach(b => b.classList.toggle('on', b === btn));
      const map = window.cvgEventMap;
      if (!map || typeof map.setProjection !== 'function') return;
      try {
        if (mode === '3d') {
          map.setProjection({ type: 'globe' });
          if (map.__rotate) map.__rotate.set(false);
        } else {
          if (map.__rotate) map.__rotate.set(false);
          map.setProjection({ type: 'mercator' });
        }
      } catch (e) { /* projection unsupported */ }
    });
  });

  // Layer card click — make it the active layer
  cvg.querySelectorAll('[data-cvg-layer]').forEach(b => {
    b.addEventListener('click', () => {
      cvg.querySelectorAll('[data-cvg-layer]').forEach(x => x.classList.remove('active'));
      b.classList.add('active');
    });
  });

  // Pin click → swap right panel content (Eastern Flank scenarios)
  const cvgEvents = {
    // 1. ARMED CONFLICT
    ukraine:        { cc:'ua', layer:'armed', ll:[48.4, 35.0], c:'#DC2626', lbl:'CONFLICT',    sev:'▲ RED · ARMED CONFLICT', title:'Active war operations',          loc:'Ukraine · eastern oblasts',     dt:'24 May 2026 · 04:18', src:'ACLED · UCDP · GDELT',           rel:'A · Completely reliable', blr:'Continuity of government',  trend:'↘ Deteriorating', conf:'High · 0.91', pop:'Civilian areas',          sum:'Active large-scale conflict with sustained civil environment impact. Resilience functions under pressure across multiple oblasts. Cross-border cascade signals on humanitarian access.' },
    sudan:          { layer:'armed', ll:[15.5, 32.5], c:'#DC2626', lbl:'CONFLICT',    sev:'▲ RED · ARMED CONFLICT', title:'Internal armed conflict',         loc:'Sudan · Darfur region',          dt:'24 May 2026 · 02:42', src:'ACLED · ReliefWeb · UCDP',         rel:'A · Completely reliable', blr:'Mass casualty resilience',   trend:'↘ Deteriorating', conf:'High · 0.88', pop:'Mass civilian displacement', sum:'Sustained internal conflict producing massive displacement and humanitarian access constraints. Cross-border cascade into Chad observed.' },
    myanmar:        { layer:'armed', ll:[19.0, 96.1], c:'#DC2626', lbl:'CONFLICT',    sev:'▲ RED · ARMED CONFLICT', title:'Multi-front armed conflict',      loc:'Myanmar · multiple states',      dt:'23 May 2026 · 22:10', src:'ACLED · UCDP · ACAPS',           rel:'A · Completely reliable', blr:'Civil communications',        trend:'→ Stable',        conf:'High · 0.85', pop:'CAAC concerns',              sum:'Multi-front conflict with significant CAAC and humanitarian access implications. Cultural property at risk in heritage zones.' },
    yemen:          { layer:'armed', ll:[15.5, 44.5], c:'#DC2626', lbl:'CONFLICT',    sev:'▲ RED · ARMED CONFLICT', title:'Protracted conflict',             loc:'Yemen',                              dt:'23 May 2026 · 18:55', src:'ACLED · UCDP',                       rel:'A',                          blr:'Food and water resilience',  trend:'↘ Deteriorating', conf:'High · 0.86', pop:'~21M humanitarian needs',    sum:'Protracted conflict with deep humanitarian and resilience impacts. Food and water resilience critically degraded.' },
    drc:            { layer:'armed', ll:[-1.7, 29.2], c:'#DC2626', lbl:'CONFLICT',    sev:'▲ RED · ARMED CONFLICT', title:'Eastern DRC violence',            loc:'DRC · North/South Kivu',          dt:'23 May 2026 · 16:30', src:'ACLED · UCDP · IOM DTM',         rel:'A',                          blr:'Population movement',         trend:'↘ Deteriorating', conf:'High · 0.89', pop:'IDP flows',                  sum:'Sustained armed group activity producing significant IDP flows and humanitarian protection concerns.' },

    // 2. DISASTERS / ENVIRONMENT
    cali_fire:      { layer:'disaster', ll:[37.0,-120.0], c:'#EA580C', lbl:'WILDFIRE', sev:'▲ ORANGE · WILDFIRE',  title:'Active wildfire complex',         loc:'California · USA',                dt:'24 May 2026 · 01:05', src:'NASA FIRMS · Copernicus',            rel:'A',                          blr:'Continuity of government',    trend:'↗ Increasing',   conf:'High · 0.93', pop:'~85,000 evacuated',         sum:'Thermal anomalies confirmed by FIRMS. Significant population displacement and air quality impact across the region.' },
    pak_flood:      { layer:'disaster', ll:[26.5, 68.0], c:'#EA580C', lbl:'FLOOD',    sev:'▲ ORANGE · FLOOD',     title:'Monsoon flood event',             loc:'Pakistan · Sindh',                dt:'23 May 2026 · 20:00', src:'Copernicus EMS · IOM DTM',           rel:'A',                          blr:'Transportation resilience',   trend:'↘ Deteriorating', conf:'High · 0.87', pop:'~2.1M affected',            sum:'Large-area flood with severe transport disruption and humanitarian impact. Critical infrastructure under stress.' },
    japan_quake:    { layer:'disaster', ll:[37.5,141.0], c:'#EAB308', lbl:'EARTHQUAKE',sev:'▲ YELLOW · EARTHQUAKE',title:'M5.8 earthquake event',           loc:'Japan · Tohoku',                  dt:'23 May 2026 · 14:22', src:'USGS · JMA',                          rel:'A',                          blr:'Mass casualty',                trend:'→ Stable',        conf:'High · 0.95', pop:'Low population impact',     sum:'Moderate earthquake event. No significant infrastructure damage. USGS monitoring continues.' },
    turkey_fire:    { layer:'disaster', ll:[37.0, 30.5], c:'#EA580C', lbl:'WILDFIRE', sev:'▲ ORANGE · WILDFIRE',  title:'Mediterranean wildfire',          loc:'Türkiye · Antalya',           dt:'23 May 2026 · 19:30', src:'NASA FIRMS · Copernicus',            rel:'A',                          blr:'Population movement',          trend:'↗ Increasing',   conf:'High · 0.86', pop:'Tourist areas affected',    sum:'Active wildfire near coastal areas. Smoke plume tracked by satellite. Local resilience response activated.' },

    // 3. POLITICAL / ECONOMIC
    argentina:      { layer:'political', ll:[-34.6,-58.4], c:'#9333EA', lbl:'ECON CRISIS', sev:'▲ ORANGE · ECONOMIC', title:'Inflation & currency stress',   loc:'Argentina',                          dt:'23 May 2026 · 16:00', src:'IMF · Trading Economics',            rel:'B',                          blr:'Continuity of government',     trend:'↗ Increasing',   conf:'Med · 0.78', pop:'National economy',          sum:'Sustained currency depreciation with inflation spike. Macroeconomic pressure on civil services and household resilience.' },
    haiti:          { layer:'political', ll:[18.5,-72.3], c:'#DC2626', lbl:'POLITICAL',   sev:'▲ RED · POLITICAL',    title:'Governance crisis',             loc:'Haiti',                              dt:'23 May 2026 · 12:45', src:'CrisisWatch · ReliefWeb',            rel:'A',                          blr:'Continuity of government',     trend:'↘ Deteriorating', conf:'High · 0.85', pop:'Multi-million affected',    sum:'Sustained governance crisis with armed-group control of urban areas. Severe humanitarian and resilience impact.' },
    iran_protest:   { cc:'ir', layer:'political', ll:[35.7, 51.4], c:'#9333EA', lbl:'PROTESTS',    sev:'▲ YELLOW · UNREST',     title:'Civil unrest signals',          loc:'Iran · multiple cities',          dt:'23 May 2026 · 09:30', src:'ACLED · GDELT',                       rel:'B',                          blr:'Continuity of government',     trend:'→ Stable',        conf:'Med · 0.69', pop:'Urban populations',         sum:'Recurring localised protests. Information environment monitoring recommended.' },

    // 4. CULTURAL PROPERTY
    mali_cpp:       { layer:'cultural', ll:[16.8, -3.0], c:'#C8A24B', lbl:'CPP',      sev:'▲ YELLOW · CPP',       title:'Cultural site damage',            loc:'Mali · Timbuktu',                  dt:'22 May 2026 · 14:00', src:'UNESCO · Blue Shield',                rel:'A',                          blr:'Cultural property',            trend:'→ Stable',        conf:'High · 0.82', pop:'World Heritage sites',      sum:'Damage assessment underway for UNESCO World Heritage zone. Coordination with cultural protection officers in progress.' },
    yemen_cpp:      { layer:'cultural', ll:[15.4, 44.2], c:'#C8A24B', lbl:'CPP',      sev:'▲ ORANGE · CPP',       title:'Heritage at risk',                loc:'Yemen · Sana\'a',                  dt:'21 May 2026 · 11:30', src:'UNESCO · Blue Shield · UNITAR',    rel:'A',                          blr:'Cultural property',            trend:'↘ Deteriorating', conf:'High · 0.84', pop:'Old City heritage',         sum:'Continued risk to Old City heritage. Satellite imagery indicates building damage in protected zone.' },

    // 5. HUMANITARIAN
    gaza:           { layer:'humanitarian', ll:[31.5, 34.5], c:'#2563EB', lbl:'HUMANITARIAN', sev:'▲ RED · HUMANITARIAN', title:'Severe humanitarian crisis',  loc:'Gaza Strip',                          dt:'24 May 2026 · 03:00', src:'OCHA HDX · ReliefWeb · UNRWA',     rel:'A',                          blr:'Food and water',               trend:'↘ Deteriorating', conf:'High · 0.92', pop:'~2.2M affected',            sum:'Severe humanitarian crisis with critical impact on food, water and medical resilience. Humanitarian access constraints.' },
    afghanistan:    { layer:'humanitarian', ll:[34.5, 69.2], c:'#2563EB', lbl:'HUMANITARIAN', sev:'▲ ORANGE · HUMANITARIAN', title:'Compound humanitarian needs', loc:'Afghanistan',                    dt:'23 May 2026 · 19:00', src:'OCHA HDX · ACAPS · IOM DTM',         rel:'A',                          blr:'Food and water',               trend:'→ Stable',        conf:'High · 0.86', pop:'~28M in need',              sum:'Compounded humanitarian needs across food, health and protection sectors. Returnee flows from Pakistan monitored.' },
    somalia:        { layer:'humanitarian', ll:[5.2, 46.2], c:'#2563EB', lbl:'HUMANITARIAN', sev:'▲ ORANGE · HUMANITARIAN', title:'Drought & displacement',     loc:'Somalia',                              dt:'23 May 2026 · 11:00', src:'FEWS NET · IPC · IOM DTM',           rel:'A',                          blr:'Food and water',               trend:'↘ Deteriorating', conf:'High · 0.85', pop:'IDPs + drought-affected',   sum:'Drought-driven displacement compounded by conflict signals. IPC monitoring food security status.' },

    // 6. HYBRID THREATS
    baltics_hybrid: { layer:'hybrid', ll:[57.0, 25.0], c:'#BE185D', lbl:'HYBRID',     sev:'▲ ORANGE · HYBRID',     title:'Hybrid pressure indicators',      loc:'Baltic states',                       dt:'23 May 2026 · 22:00', src:'Hybrid CoE · NATO StratCom',         rel:'B',                          blr:'Civil communications',          trend:'→ Stable',        conf:'Med · 0.75', pop:'Civil infrastructure',      sum:'Coordinated hybrid pressure indicators across Baltic information and infrastructure environments. Corridor coordination recommended.' },
    moldova_hybrid: { layer:'hybrid', ll:[47.0, 28.8], c:'#BE185D', lbl:'HYBRID',     sev:'▲ YELLOW · HYBRID',     title:'Energy dependency pressure',      loc:'Moldova',                              dt:'22 May 2026 · 15:30', src:'Hybrid CoE · IEA',                    rel:'B',                          blr:'Energy resilience',             trend:'→ Stable',        conf:'Med · 0.72', pop:'Energy security',           sum:'Energy dependency pressure with information environment dimensions. Civil resilience monitoring ongoing.' },

    // 7. INFORMATION WARFARE
    eu_disinfo:     { layer:'info', ll:[50.0, 14.5], c:'#6B21A8', lbl:'DISINFO',      sev:'▲ ORANGE · INFO',       title:'Cross-border narrative campaign', loc:'EU · Eastern member states',      dt:'24 May 2026 · 00:42', src:'EUvsDisinfo · DFRLab',                rel:'B',                          blr:'Information resilience',        trend:'↗ Increasing',   conf:'Med · 0.78', pop:'Public narrative environment', sum:'Coordinated narrative pressure across multiple EU member states. STRATCOM awareness recommended; institutional, calm response advised.' },
    africa_disinfo: { layer:'info', ll:[14.5, 0.0], c:'#6B21A8', lbl:'DISINFO',       sev:'▲ YELLOW · INFO',       title:'Sahel narrative pressure',         loc:'Sahel region',                        dt:'23 May 2026 · 17:00', src:'DFRLab · NATO StratCom',              rel:'C',                          blr:'Information resilience',        trend:'↗ Increasing',   conf:'Med · 0.68', pop:'Regional info environment', sum:'Sahel-focused narrative pressure observed. Long-term resilience implications for trust in institutional partners.' },

    // ===== CIMIC COUNTRY NODES (selectable on map → drive Layer A–E reports) =====
    c_ua: { cc:'ua', country:true, layer:'armed',    ll:[49.0, 31.5], c:'#DC2626', lbl:'UKRAINE',   sev:'▲ RED · CIMIC NODE',    title:'Ukraine — active theatre',        loc:'Ukraine',   dt:'live', src:'AJP-3.19 · CCOE · HCSS', rel:'A', blr:'Energy / continuity',        trend:'↘ Deteriorating', conf:'High · 0.92', pop:'Mass displacement',        sum:'Functioning but heavily stressed state. Energy–water–heating nexus the decisive civil vulnerability. Open Layer A–E for the full CIMIC picture.' },
    c_ir: { cc:'ir', country:true, layer:'political', ll:[32.5, 53.7], c:'#DC2626', lbl:'IRAN',      sev:'▲ RED · CIMIC NODE',    title:'Iran — regional & internal tension', loc:'Iran',   dt:'live', src:'CCOE · Hybrid CoE · HCSS', rel:'B', blr:'Water / energy',           trend:'→ Volatile',      conf:'Med · 0.74', pop:'Stressed population',      sum:'Durable regime over a brittle socio-environmental base. Water and energy stress are the key destabilisers; regional proxy hub. Open Layer A–E.' },
    c_fi: { cc:'fi', country:true, layer:'hybrid',    ll:[62.5, 26.0], c:'#EAB308', lbl:'FINLAND',   sev:'▲ YELLOW · CIMIC NODE', title:'Finland — resilient frontline',   loc:'Finland',   dt:'live', src:'AJP-3.19 · Hybrid CoE · HCSS', rel:'A', blr:'All baselines strong',    trend:'→ Stable',        conf:'High · 0.88', pop:'High preparedness',        sum:'Comprehensive-security model; risk concentrated in border & hybrid domains (instrumentalised migration, undersea infrastructure, GNSS). Open Layer A–E.' },
    c_ee: { cc:'ee', country:true, layer:'hybrid',    ll:[58.9, 25.5], c:'#EA580C', lbl:'ESTONIA',   sev:'▲ ORANGE · CIMIC NODE', title:'Estonia — digital frontline',     loc:'Estonia',   dt:'live', src:'CCDCOE · Hybrid CoE · HCSS', rel:'A', blr:'Comms / continuity',      trend:'→ Stable',        conf:'High · 0.84', pop:'Minority cohesion',        sum:'Digitally advanced total-defence state; exposed by size and the information/identity domain (Russian-speaking minority). Open Layer A–E.' },
    c_lv: { cc:'lv', country:true, layer:'hybrid',    ll:[56.9, 24.6], c:'#EA580C', lbl:'LATVIA',    sev:'▲ ORANGE · CIMIC NODE', title:'Latvia — minority & border seam', loc:'Latvia',    dt:'live', src:'Hybrid CoE · CCOE · HCSS', rel:'B', blr:'Comms / energy',          trend:'→ Stable',        conf:'Med · 0.80', pop:'Large minority',           sum:'Frontline state with a large Russian-speaking minority and a Belarus border. Societal cohesion and border security dominate. Open Layer A–E.' },
    c_lt: { cc:'lt', country:true, layer:'hybrid',    ll:[55.2, 23.9], c:'#EA580C', lbl:'LITHUANIA', sev:'▲ ORANGE · CIMIC NODE', title:'Lithuania — Suwałki exposure',    loc:'Lithuania', dt:'live', src:'Hybrid CoE · CCOE · HCSS', rel:'B', blr:'Transport / corridor',     trend:'→ Stable',        conf:'Med · 0.81', pop:'High cohesion',            sum:'Most geographically exposed Baltic — Suwałki corridor between Kaliningrad and Belarus. Energy now a strength; geography the risk. Open Layer A–E.' },
    c_pl: { cc:'pl', country:true, layer:'armed',     ll:[52.1, 19.4], c:'#EA580C', lbl:'POLAND',    sev:'▲ ORANGE · CIMIC NODE', title:'Poland — eastern-flank hub',      loc:'Poland',    dt:'live', src:'AJP-3.19 · CCOE · HCSS', rel:'A', blr:'Transport / population',   trend:'→ Stable',        conf:'High · 0.86', pop:'Largest refugee host',     sum:'Indispensable logistics hub for support to Ukraine and largest refugee host. Multidirectional pressure; aid-transit protection decisive. Open Layer A–E.' },
    c_ro: { cc:'ro', country:true, layer:'hybrid',    ll:[45.9, 24.9], c:'#EAB308', lbl:'ROMANIA',   sev:'▲ YELLOW · CIMIC NODE', title:'Romania — Black Sea flank',       loc:'Romania',   dt:'live', src:'CCOE · Hybrid CoE · HCSS', rel:'B', blr:'Transport / information',  trend:'→ Stable',        conf:'Med · 0.79', pop:'Grain-transit pivot',      sum:'Black Sea / Danube flank state; drone-debris spillover and grain-transit logistics. Election-disinformation the standout vulnerability. Open Layer A–E.' },
  };
  // Helper: update the Selected Event panel
  function cvgShowEvent(k) {
    const e = cvgEvents[k]; if (!e) return;
    const panel = document.getElementById('cvgEvent');
    panel.style.setProperty('--c', e.c);
    document.getElementById('cvgEventSev').textContent = e.sev;
    document.getElementById('cvgEventTitle').textContent = e.title;
    document.getElementById('cvgEventLoc').textContent = e.loc;
    document.getElementById('cvgEventDT').textContent = e.dt;
    document.getElementById('cvgEventSrc').textContent = e.src;
    document.getElementById('cvgEventRel').textContent = e.rel;
    document.getElementById('cvgEventBLR').textContent = e.blr;
    document.getElementById('cvgEventTrend').textContent = e.trend;
    document.getElementById('cvgEventConf').textContent = e.conf;
    document.getElementById('cvgEventPop').textContent = e.pop;
    const bluf = document.getElementById('cvgEventBluf');
    if (bluf) bluf.textContent = e.sum;
    // Manual selection holds the panel against the live feed for 20s
    window.cvgSelPauseUntil = Date.now() + 20000;
  }
  cvg.querySelectorAll('[data-cvg-pin]').forEach(p => {
    p.addEventListener('click', () => cvgShowEvent(p.dataset.cvgPin));
  });

  // Country ↔ map highlight + pin focus
  const countryPins = {
    EST: ['baltics_hybrid'],
    LVA: ['baltics_hybrid','eu_disinfo'],
    LTU: ['baltics_hybrid'],
    POL: ['eu_disinfo'],
    ROU: ['moldova_hybrid']
  };
  function setCountry(iso) {
    document.querySelectorAll('[data-cvg-cc]').forEach(c => c.classList.toggle('active', c.dataset.cvgCc === iso));
    document.querySelectorAll('[data-cvg-cc-card]').forEach(c => c.classList.toggle('active', c.dataset.cvgCcCard === iso));
    // Highlight on Leaflet region map (active marker class)
    Object.entries(cvgCountryMarkers).forEach(([k, m]) => {
      const el = m.getElement();
      if (el) el.classList.toggle('active', k === iso);
    });
    // Fly to the country on the region map
    if (cvgRegionMap && cvgCountryMarkers[iso]) {
      cvgRegionMap.flyTo(cvgCountryMarkers[iso].getLatLng(), 6, { duration: 0.9 });
    }
    // Populate the country detail card
    showCountryDetail(iso);
    // Also focus the OSINT event map on the first event in that country
    const focus = countryPins[iso] || [];
    if (focus[0]) {
      cvgShowEvent(focus[0]);
      if (cvgEventMap && cvgEventMarkers[focus[0]] && cvgEventMarkers[focus[0]].getLngLat) {
        const ll = cvgEventMarkers[focus[0]].getLngLat();
        try { cvgEventMap.flyTo({ center: [ll.lng, ll.lat], zoom: 4.5, duration: 900 }); } catch(e) {}
      }
    }
  }

  // ── Country detail card data + render ──
  const COUNTRY_DETAILS = {
    FIN: { name:'Finland', role:'Northern flank anchor · airspace & border resilience', rows:[
      { k:'Airspace', v:'Yellow', c:'#EAB308' },
      { k:'Energy', v:'Stable', c:'#16A34A' },
      { k:'Civil society', v:'Stable', c:'#16A34A' },
      { k:'Hybrid pressure', v:'Yellow', c:'#EAB308' }
    ]},
    EST: { name:'Estonia', role:'Cyber & information resilience hub', rows:[
      { k:'Cyber', v:'Orange', c:'#EA580C' },
      { k:'Info environment', v:'Orange', c:'#EA580C' },
      { k:'Energy', v:'Stable', c:'#16A34A' },
      { k:'Transport', v:'Stable', c:'#16A34A' }
    ]},
    LVA: { name:'Latvia', role:'Critical infrastructure stability node', rows:[
      { k:'Grid', v:'Red', c:'#DC2626' },
      { k:'Cross-border', v:'Orange', c:'#EA580C' },
      { k:'Cyber', v:'Yellow', c:'#EAB308' },
      { k:'Transport', v:'Stable', c:'#16A34A' }
    ]},
    LTU: { name:'Lithuania', role:'Energy interconnect & transport corridor', rows:[
      { k:'Energy IX', v:'Orange', c:'#EA580C' },
      { k:'Rail', v:'Stable', c:'#16A34A' },
      { k:'Cyber', v:'Yellow', c:'#EAB308' },
      { k:'Population', v:'Stable', c:'#16A34A' }
    ]},
    POL: { name:'Poland', role:'Logistics & humanitarian backbone', rows:[
      { k:'Humanitarian', v:'Yellow', c:'#EAB308' },
      { k:'Rail hub', v:'Stable', c:'#16A34A' },
      { k:'Border movement', v:'Yellow', c:'#EAB308' },
      { k:'Energy', v:'Stable', c:'#16A34A' }
    ]},
    ROU: { name:'Romania', role:'Black Sea / Danube stability node', rows:[
      { k:'Danube transport', v:'Orange', c:'#EA580C' },
      { k:'Airspace', v:'Yellow', c:'#EAB308' },
      { k:'Energy', v:'Stable', c:'#16A34A' },
      { k:'Cyber', v:'Stable', c:'#16A34A' }
    ]},
    // ──────── Bordering states · OSINT monitored ────────
    RUS: { name:'Russia · monitored', role:'Western MD + Kaliningrad + Leningrad oblast · OSINT awareness', rows:[
      { k:'Forward posture', v:'Red',    c:'#DC2626' },
      { k:'A2/AD ring',       v:'Red',    c:'#DC2626' },
      { k:'Information ops',  v:'Red',    c:'#DC2626' },
      { k:'Cyber emissions',  v:'Orange', c:'#EA580C' }
    ]},
    BLR: { name:'Belarus · monitored', role:'Forward staging area · Suwałki adjacency', rows:[
      { k:'Force basing',     v:'Red',    c:'#DC2626' },
      { k:'Air defence',      v:'Orange', c:'#EA580C' },
      { k:'Border movement',  v:'Orange', c:'#EA580C' },
      { k:'Migration vector', v:'Orange', c:'#EA580C' }
    ]},
    UKR: { name:'Ukraine · blue force', role:'Aligned partner · active defensive combat operations', rows:[
      { k:'Active combat',     v:'Red',    c:'#DC2626' },
      { k:'Air defence (IAMD)',v:'Orange', c:'#EA580C' },
      { k:'Energy grid',       v:'Red',    c:'#DC2626' },
      { k:'Civil environment', v:'Red',    c:'#DC2626' },
      { k:'NATO interop',      v:'Stable', c:'#16A34A' }
    ]},
    MDA: { name:'Moldova · monitored', role:'Hybrid pressure · Transnistria adjacency', rows:[
      { k:'Hybrid pressure',   v:'Orange',c:'#EA580C' },
      { k:'Energy dependency', v:'Orange',c:'#EA580C' },
      { k:'Info environment',  v:'Yellow',c:'#EAB308' },
      { k:'Migration',         v:'Yellow',c:'#EAB308' }
    ]}
  };
  function showCountryDetail(iso) {
    const card = document.getElementById('cvgCountryDetail');
    const data = COUNTRY_DETAILS[iso];
    if (!card || !data) return;
    document.getElementById('cvgCdIso').textContent = iso;
    document.getElementById('cvgCdName').textContent = data.name;
    document.getElementById('cvgCdRole').textContent = data.role;
    const rows = data.rows.map(r =>
      '<div class="r" style="--c:' + r.c + '"><span class="k"><i></i>' + r.k + '</span><span class="v">' + r.v + '</span></div>'
    ).join('');
    document.getElementById('cvgCdRows').innerHTML = rows;
    card.classList.add('open');
  }
  // Country detail action buttons
  document.addEventListener('click', (ev) => {
    const b = ev.target.closest('[data-cvg-cd-act]');
    if (!b) return;
    const act = b.dataset.cvgCdAct;
    if (act === 'ai') {
      // Funnel into Convergens AI: scroll to AI Intel and pre-fill prompt
      const iso = document.getElementById('cvgCdIso').textContent;
      const nm = document.getElementById('cvgCdName').textContent;
      const tx = document.getElementById('cvgPromptText');
      if (tx) {
        tx.value = 'Brief me on ' + nm + ' (' + iso + ') — current resilience pressures and cross-border cascade risks.';
        tx.dispatchEvent(new Event('input'));
      }
      setCvgTab('intel');
    } else if (act === 'profile') {
      const orig = b.textContent;
      b.textContent = 'Opening profile…';
      setTimeout(() => { b.textContent = orig; }, 1500);
    }
  });
  document.querySelectorAll('[data-cvg-cc]').forEach(c => c.addEventListener('click', () => setCountry(c.dataset.cvgCc)));
  document.querySelectorAll('[data-cvg-cc-card]').forEach(c => c.addEventListener('click', () => setCountry(c.dataset.cvgCcCard)));

  // ── INIT LEAFLET MAPS ──
  function initCvgMaps() {
    if (cvgMapsReady) return;
    const regionEl = document.getElementById('cvgLeafletRegion');
    // Region map needs Leaflet; if it's on this page but not loaded yet, retry.
    if (regionEl && typeof L === 'undefined') { setTimeout(initCvgMaps, 250); return; }
    if (regionEl) {

    // ----- REGION (CORRIDOR) MAP -----
    cvgRegionMap = L.map(regionEl, {
      center: [55.0, 27.0],
      zoom: 4,
      minZoom: 3, maxZoom: 12,
      zoomControl: false,            // custom cluster (zoom + fullscreen) used instead
      attributionControl: true,
      scrollWheelZoom: false,        // enabled on click — see below
      doubleClickZoom: true,
      touchZoom: true,
      boxZoom: true,
      worldCopyJump: false
    });
    cvgRegionMap.attributionControl.setPosition('bottomleft');
    // Click-to-activate scroll-wheel zoom so map doesn't hijack page scroll.
    // Activated on focus, deactivated when pointer leaves.
    cvgRegionMap.on('click focus', () => cvgRegionMap.scrollWheelZoom.enable());
    cvgRegionMap.on('mouseout',     () => cvgRegionMap.scrollWheelZoom.disable());
    cvgRegionTile = L.tileLayer(tileUrl(), {
      attribution: '© OpenStreetMap · © CARTO',
      subdomains: 'abcd', maxZoom: 18, detectRetina: true
    }).addTo(cvgRegionMap);

    // Live satellite imagery overlay — NASA GIBS MODIS Terra true color, daily
    // (Yesterday's UTC date is used to dodge publishing lag.)
    const gibsDate = (() => {
      const d = new Date(Date.now() - 24 * 3600 * 1000);
      return d.getUTCFullYear() + '-' + String(d.getUTCMonth() + 1).padStart(2, '0') + '-' + String(d.getUTCDate()).padStart(2, '0');
    })();
    const cvgRegionSatTile = L.tileLayer(
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/VIIRS_SNPP_CorrectedReflectance_TrueColor/default/' + gibsDate + '/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg',
      {
        attribution: '© NASA EOSDIS GIBS · VIIRS SNPP · ' + gibsDate,
        maxNativeZoom: 9, maxZoom: 12, opacity: 1, tileSize: 256
      }
    );
    // Labels-only overlay (so place names remain readable on top of imagery)
    function labelsUrl() {
      return document.documentElement.dataset.theme === 'dark'
        ? 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_only_labels/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}{r}.png';
    }
    const cvgRegionLabelsTile = L.tileLayer(labelsUrl(), {
      subdomains: 'abcd', maxZoom: 18, detectRetina: true, pane: 'shadowPane'
    });
    function setBasemap(mode) {
      const dateEl = document.getElementById('cvgBaseImageryDate');
      if (mode === 'sat') {
        if (cvgRegionMap.hasLayer(cvgRegionTile)) cvgRegionMap.removeLayer(cvgRegionTile);
        if (!cvgRegionMap.hasLayer(cvgRegionSatTile))    cvgRegionMap.addLayer(cvgRegionSatTile);
        if (!cvgRegionMap.hasLayer(cvgRegionLabelsTile)) cvgRegionMap.addLayer(cvgRegionLabelsTile);
        if (dateEl) { dateEl.textContent = 'NASA VIIRS · ' + gibsDate; dateEl.classList.add('show'); }
      } else {
        if (cvgRegionMap.hasLayer(cvgRegionSatTile))    cvgRegionMap.removeLayer(cvgRegionSatTile);
        if (cvgRegionMap.hasLayer(cvgRegionLabelsTile)) cvgRegionMap.removeLayer(cvgRegionLabelsTile);
        if (!cvgRegionMap.hasLayer(cvgRegionTile))      cvgRegionMap.addLayer(cvgRegionTile);
        if (dateEl) { dateEl.classList.remove('show'); }
      }
    }
    document.querySelectorAll('[data-cvg-base-toggle] [data-cvg-base]').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('[data-cvg-base-toggle] [data-cvg-base]').forEach(b => b.classList.toggle('on', b === btn));
        setBasemap(btn.dataset.cvgBase);
      });
    });

    const COUNTRIES = {
      FIN: { latlng:[61.92, 25.75], status:'#EAB308' },
      EST: { latlng:[58.60, 25.00], status:'#EA580C' },
      LVA: { latlng:[56.88, 24.60], status:'#DC2626' },
      LTU: { latlng:[55.17, 23.88], status:'#EA580C' },
      POL: { latlng:[52.00, 19.50], status:'#EAB308' },
      ROU: { latlng:[45.94, 24.97], status:'#EA580C' },
      // ---- Aligned partner · active combat operations ----
      UKR: { latlng:[50.45, 30.52], status:'#DC2626', label:'UKR · combat', combat:true },
      // ---- Bordering states · OSINT monitored (non-corridor) ----
      RUS: { latlng:[55.75, 37.62], status:'#DC2626', mon:true, label:'RUS · Moscow' },
      BLR: { latlng:[53.90, 27.57], status:'#DC2626', mon:true },
      MDA: { latlng:[47.00, 28.84], status:'#EA580C', mon:true },
      // ---- Kaliningrad oblast (separate RUS exclave label) ----
      KGD: { latlng:[54.71, 20.51], status:'#DC2626', mon:true, label:'RUS · Kaliningrad' }
    };
    // Corridor polyline (NATO eastern flank only — defensive framing preserved)
    const corridorPath = ['FIN','EST','LVA','LTU','POL','ROU'].map(k => COUNTRIES[k].latlng);
    L.polyline(corridorPath, {
      color: '#1A7A99',
      weight: 2,
      opacity: 0.6,
      dashArray: '4 6'
    }).addTo(cvgRegionMap);

    Object.entries(COUNTRIES).forEach(([iso, c]) => {
      const cls = 'cvg-country-marker' + (c.mon ? ' mon' : '') + (c.combat ? ' combat' : '');
      const icon = L.divIcon({
        className: cls,
        html: `<span class="m-dot" style="background:${c.status}"></span><span class="m-tag">${c.label || iso}</span>`,
        iconSize: [54, 18],
        iconAnchor: [8, 9]
      });
      const m = L.marker(c.latlng, { icon, title: iso, riseOnHover: true }).addTo(cvgRegionMap);
      // KGD funnels into RUS detail; others map to themselves
      const clickIso = (iso === 'KGD') ? 'RUS' : iso;
      m.on('click', () => setCountry(clickIso));
      cvgCountryMarkers[iso] = m;
    });

    // ───────── LIVE LAYERS · radars, sensors, aircraft, airfields, shooters, data centres, networks ─────────
    const airLayer    = L.layerGroup().addTo(cvgRegionMap);
    const radarLayer  = L.layerGroup().addTo(cvgRegionMap);
    const sensorLayer = L.layerGroup().addTo(cvgRegionMap);
    const fieldLayer  = L.layerGroup().addTo(cvgRegionMap);
    const shootLayer  = L.layerGroup();   // off by default — sensitive layer, opt-in
    const dcLayer     = L.layerGroup();
    const netLayer    = L.layerGroup();
    const satLayer    = L.layerGroup();   // satellites — toggleable
    const milLayer    = L.layerGroup();   // military activity — toggleable

    // 1. RADARS — air-surveillance / SAM sites along the corridor (OSINT-public)
    const RADARS = [
      { name:'KAUHAVA',    type:'Air surveillance',  loc:'Finland · Ostrobothnia',  ll:[63.10, 23.05], range:'420 km' },
      { name:'LUONETJÄRVI',type:'AEW · long range',  loc:'Finland · Tikkakoski',    ll:[62.40, 25.67], range:'480 km' },
      { name:'TALLINN-S',  type:'Air surveillance',  loc:'Estonia · Kehra',         ll:[59.34, 25.30], range:'350 km' },
      { name:'ÄMARI',      type:'Air policing',      loc:'Estonia · Ämari AB',      ll:[59.26, 24.21], range:'380 km' },
      { name:'AUDRINI',    type:'Surveillance',      loc:'Latvia · Latgale',        ll:[56.42, 27.34], range:'320 km' },
      { name:'LIELVĀRDE',  type:'Air policing',      loc:'Latvia · Lielvārde AB',   ll:[56.78, 24.85], range:'360 km' },
      { name:'ŠIAULIAI',   type:'Air policing',      loc:'Lithuania · Šiauliai AB', ll:[55.89, 23.40], range:'400 km' },
      { name:'MARIJAMPOLĖ',type:'Surveillance',      loc:'Lithuania · Suvalkija',   ll:[54.55, 23.36], range:'310 km' },
      { name:'BIAŁYSTOK',  type:'Surveillance',      loc:'Poland · Podlaskie',      ll:[53.13, 23.16], range:'350 km' },
      { name:'GDYNIA',     type:'Coastal · maritime',loc:'Poland · Pomerania',      ll:[54.52, 18.55], range:'280 km' },
      { name:'POWIDZ',     type:'Air policing',      loc:'Poland · Powidz AB',      ll:[52.38, 17.85], range:'380 km' },
      { name:'KRAKÓW-S',   type:'Surveillance',      loc:'Poland · Małopolska',     ll:[50.07, 19.78], range:'320 km' },
      { name:'MIHAIL K.',  type:'Air policing',      loc:'Romania · Constanța',     ll:[44.36, 28.49], range:'420 km' },
      { name:'CÂMPIA T.',  type:'Surveillance',      loc:'Romania · Transylvania',  ll:[45.84, 21.93], range:'310 km' },
      { name:'DEVESELU',   type:'Strategic · AEGIS', loc:'Romania · Olt',           ll:[44.05, 24.32], range:'600 km' },
    ];

    function radarIcon() {
      return L.divIcon({
        className: 'cvg-radar-marker',
        html: '<span class="ring r1"></span><span class="ring r2"></span><span class="ring r3"></span><span class="sweep"></span><span class="core"></span>',
        iconSize: [44, 44], iconAnchor: [22, 22]
      });
    }
    RADARS.forEach(r => {
      const m = L.marker(r.ll, { icon: radarIcon(), title: r.name, riseOnHover: true });
      m.bindTooltip(
        `<b>${r.name}</b> · <span style="color:rgba(187,247,208,0.7);">Radar Station</span>` +
        `<div class="row" style="margin-top:4px;"><span>Role</span> ${r.type}</div>` +
        `<div class="row"><span>Site</span> ${r.loc}</div>` +
        `<div class="row"><span>Range</span> ${r.range}</div>`,
        { className: 'cvg-radar-tip', direction: 'top', offset: [0, -8], sticky: true }
      );
      m.addTo(radarLayer);
    });

    // 2. SENSORS — maritime / border / SIGINT
    const SENSORS = [
      // Maritime (Baltic AIS / coastal)
      { kind:'mar', name:'Hanko AIS',           loc:'Finland · Gulf of Finland',   ll:[59.83, 22.97], color:'#3DA5FF' },
      { kind:'mar', name:'Paldiski AIS',        loc:'Estonia · Pakri',             ll:[59.36, 24.05], color:'#3DA5FF' },
      { kind:'mar', name:'Liepāja AIS',         loc:'Latvia · Liepāja',            ll:[56.51, 21.01], color:'#3DA5FF' },
      { kind:'mar', name:'Klaipėda AIS',        loc:'Lithuania · Klaipėda',        ll:[55.71, 21.13], color:'#3DA5FF' },
      { kind:'mar', name:'Hel Peninsula AIS',   loc:'Poland · Hel',                ll:[54.61, 18.81], color:'#3DA5FF' },
      { kind:'mar', name:'Constanța AIS',       loc:'Romania · Constanța',         ll:[44.18, 28.66], color:'#3DA5FF' },

      // Border resilience sensors
      { kind:'bdr', name:'Imatra Node',         loc:'Finland · SE border',         ll:[61.18, 28.78], color:'#C8A24B' },
      { kind:'bdr', name:'Narva Node',          loc:'Estonia · NE border',         ll:[59.38, 28.20], color:'#C8A24B' },
      { kind:'bdr', name:'Daugavpils Node',     loc:'Latvia · SE border',          ll:[55.88, 26.53], color:'#C8A24B' },
      { kind:'bdr', name:'Druskininkai Node',   loc:'Lithuania · S border',        ll:[54.02, 23.97], color:'#C8A24B' },
      { kind:'bdr', name:'Suwałki Gap',         loc:'Poland · NE border',          ll:[54.10, 22.93], color:'#C8A24B' },
      { kind:'bdr', name:'Hrebenne Node',       loc:'Poland · SE border',          ll:[50.43, 23.83], color:'#C8A24B' },
      { kind:'bdr', name:'Siret Node',          loc:'Romania · N border',          ll:[47.95, 26.07], color:'#C8A24B' },

      // SIGINT / ELINT nodes
      { kind:'sig', name:'Sodankylä ELINT',     loc:'Finland · Lapland',           ll:[67.42, 26.59], color:'#F472B6' },
      { kind:'sig', name:'Saaremaa ELINT',      loc:'Estonia · island',            ll:[58.41, 22.49], color:'#F472B6' },
      { kind:'sig', name:'Mazirbe SIGINT',      loc:'Latvia · Cape Kolka',         ll:[57.69, 22.36], color:'#F472B6' },
      { kind:'sig', name:'Bezledy SIGINT',      loc:'Poland · Warmia',             ll:[54.27, 20.85], color:'#F472B6' },
      { kind:'sig', name:'Babadag SIGINT',      loc:'Romania · Dobrogea',          ll:[44.89, 28.71], color:'#F472B6' },
    ];

    function sensorIcon(kind) {
      return L.divIcon({
        className: 'cvg-sensor-marker k-' + kind,
        html: '<span class="glow"></span><span class="core"></span>',
        iconSize: [24, 24], iconAnchor: [12, 12]
      });
    }
    SENSORS.forEach(s => {
      const m = L.marker(s.ll, { icon: sensorIcon(s.kind), title: s.name });
      // Apply per-sensor color via element style after marker creation
      m.on('add', () => {
        const el = m.getElement();
        if (el) el.style.setProperty('--sc', s.color);
      });
      const kindLabel = s.kind === 'mar' ? 'Maritime · AIS coastal' : s.kind === 'bdr' ? 'Border resilience node' : 'SIGINT / ELINT';
      m.bindTooltip(
        `<b>${s.name}</b> · <span style="color:rgba(253,230,138,0.7);">${kindLabel}</span>` +
        `<div class="row" style="margin-top:4px;"><span>Site</span> ${s.loc}</div>` +
        `<div class="row"><span>Status</span> nominal · feed live</div>`,
        { className: 'cvg-sensor-tip', direction: 'top', offset: [0, -10], sticky: true }
      );
      m.addTo(sensorLayer);
    });

    // 3. AIRCRAFT — live(ish) air traffic over the corridor.
    // Strategy: synthetic but plausible fleet maintaining authentic-feeling traffic patterns,
    // refreshed every second; attempts opportunistic OpenSky overlay if reachable.

    // ───────── 4. AIRFIELDS — bilateral · military + key civil hubs ─────────
    // Side: 'nato' (corridor) or 'opp' (bordering · OSINT monitored). All public OSINT.
    const AIRFIELDS = [
      // NATO eastern flank — military / dual-use
      { name:'Ämari AB',       loc:'Estonia · Harju',         ll:[59.260, 24.208], side:'nato', kind:'AF', role:'Air policing · NATO eAP' },
      { name:'Lielvārde AB',   loc:'Latvia · Lielvārde',      ll:[56.777, 24.853], side:'nato', kind:'AF', role:'Air policing' },
      { name:'Šiauliai AB',    loc:'Lithuania · Zokniai',     ll:[55.894, 23.395], side:'nato', kind:'AF', role:'Baltic air policing · F‑35/EFT' },
      { name:'Powidz AB',      loc:'Poland · Wielkopolska',   ll:[52.380, 17.854], side:'nato', kind:'AF', role:'US APS‑2 forward staging' },
      { name:'Łask AB',        loc:'Poland · Łódź',           ll:[51.552, 19.180], side:'nato', kind:'AF', role:'F‑16 / F‑35' },
      { name:'Mińsk Maz. AB',  loc:'Poland · Masovia',        ll:[52.193, 21.660], side:'nato', kind:'AF', role:'MiG‑29 → KAI FA‑50' },
      { name:'Krzesiny AB',    loc:'Poland · Poznań',         ll:[52.331, 16.967], side:'nato', kind:'AF', role:'F‑16 multirole' },
      { name:'Mihail Kog. AB', loc:'Romania · Constanța',     ll:[44.362, 28.488], side:'nato', kind:'AF', role:'NATO multinational hub' },
      { name:'Câmpia Turzii',  loc:'Romania · Cluj',          ll:[46.502, 23.886], side:'nato', kind:'AF', role:'F‑16 · NATO rotational' },
      { name:'Rovaniemi AB',   loc:'Finland · Lapland',       ll:[66.564, 25.830], side:'nato', kind:'AF', role:'Lapland Air Wing · F/A‑18' },
      { name:'Tampere‑Pirkkala',loc:'Finland · Pirkanmaa',    ll:[61.414, 23.604], side:'nato', kind:'AF', role:'Satakunta Air Wing' },
      // Civil hubs (corridor logistics)
      { name:'Helsinki‑Vantaa',loc:'Finland · civil hub',     ll:[60.317, 24.963], side:'nato', kind:'CIV', role:'Nordic gateway' },
      { name:'Warsaw Chopin',  loc:'Poland · civil hub',      ll:[52.165, 20.967], side:'nato', kind:'CIV', role:'Logistics + humanitarian' },
      { name:'Rzeszów‑Jasionka',loc:'Poland · SE civil/mil',  ll:[50.110, 22.019], side:'nato', kind:'CIV', role:'Ukraine aid hub' },
      { name:'Bucharest Otopeni',loc:'Romania · civil hub',   ll:[44.572, 26.085], side:'nato', kind:'CIV', role:'Black Sea gateway' },

      // OPPOSING / bordering states — military
      { name:'Chkalovsk AB',    loc:'Russia · Kaliningrad',    ll:[54.768, 20.392], side:'opp', kind:'AF', role:'Naval Aviation HQ · Baltic Fleet' },
      { name:'Chernyakhovsk AB',loc:'Russia · Kaliningrad',    ll:[54.626, 21.788], side:'opp', kind:'AF', role:'Su‑27/Su‑30' },
      { name:'Pskov AB',        loc:'Russia · Pskov oblast',   ll:[57.793, 28.395], side:'opp', kind:'AF', role:'VDV strategic lift · Il‑76' },
      { name:'Smolensk‑Severny',loc:'Russia · Smolensk',       ll:[54.824, 32.025], side:'opp', kind:'AF', role:'Strategic airlift' },
      { name:'Soltsy AB',       loc:'Russia · Novgorod',       ll:[58.140, 30.327], side:'opp', kind:'AF', role:'LRA bomber base · Tu‑22M3' },
      { name:'Engels (rear)',   loc:'Russia · Saratov (rear)', ll:[51.477, 46.210], side:'opp', kind:'AF', role:'LRA strategic · rear area' },
      { name:'Kubinka AB',      loc:'Russia · Moscow oblast',  ll:[55.611, 36.650], side:'opp', kind:'AF', role:'VKS · showcase wing' },
      { name:'Baranavichy AB',  loc:'Belarus · Brest',         ll:[53.100, 26.043], side:'opp', kind:'AF', role:'61st Fighter AB · Su‑30SM' },
      { name:'Machulishchy AB', loc:'Belarus · Minsk',         ll:[53.770, 27.539], side:'opp', kind:'AF', role:'A‑50 AEW / strategic lift' },
      { name:'Lida AB',         loc:'Belarus · Grodno',        ll:[53.886, 25.379], side:'opp', kind:'AF', role:'Su‑25 / training' },
      { name:'Belbek AB',       loc:'Crimea',                  ll:[44.685, 33.572], side:'opp', kind:'AF', role:'Contested · Black Sea' },
      { name:'Saky AB',         loc:'Crimea',                  ll:[45.092, 33.598], side:'opp', kind:'AF', role:'Naval aviation · contested' },
      // Civil hubs (opposing side)
      { name:'Sheremetyevo',   loc:'Russia · Moscow civil',    ll:[55.972, 37.414], side:'opp', kind:'CIV', role:'Moscow primary hub' },
      { name:'Pulkovo',        loc:'Russia · St Petersburg',   ll:[59.800, 30.262], side:'opp', kind:'CIV', role:'NW Russia hub' },
      { name:'Minsk Nat\u2019l', loc:'Belarus · civil hub',    ll:[53.881, 28.030], side:'opp', kind:'CIV', role:'Belarus primary hub' },
      { name:'Kyiv‑Boryspil',  loc:'Ukraine · civil air closed', ll:[50.345, 30.894], side:'nato', kind:'CIV', role:'Civil aviation closed · contested airspace' },
      { name:'Vasylkiv AB',    loc:'Ukraine · Kyiv oblast',    ll:[50.241, 30.317], side:'nato', kind:'AF',  role:'40th Tactical Aviation Brigade' },
      { name:'Starokostiantyniv',loc:'Ukraine · Khmelnytskyi', ll:[49.732, 27.218], side:'nato', kind:'AF',  role:'Su‑24M · long‑range strike' },
      { name:'Mirgorod AB',    loc:'Ukraine · Poltava',        ll:[49.929, 33.643], side:'nato', kind:'AF',  role:'Su‑27 · F‑16 transition base' },
      { name:'Lviv Sknyliv',   loc:'Ukraine · Lviv civil hub', ll:[49.812, 23.957], side:'nato', kind:'CIV', role:'West UA logistics gateway · NATO aid' },
      { name:'Chișinău',       loc:'Moldova · civil hub',      ll:[46.928, 28.931], side:'opp', kind:'CIV', role:'Moldova gateway' }
    ];
    function fieldIcon(side, kind) {
      // Civil hubs get a teal hue, military slate; opposing side is dashed.
      const fc = (kind === 'CIV') ? '#0EA5A6' : (side === 'opp' ? '#7C8AA7' : '#5B7DA8');
      return L.divIcon({
        className: 'cvg-field-marker' + (side === 'opp' ? ' k-opp' : ''),
        html: `<span class="ring" style="--fc:${fc}"></span><span class="cross" style="--fc:${fc};--rwy:${(side==='opp'?20:35)}deg"></span>`,
        iconSize: [28, 28], iconAnchor: [14, 14]
      });
    }
    AIRFIELDS.forEach(a => {
      const m = L.marker(a.ll, { icon: fieldIcon(a.side, a.kind), title: a.name, riseOnHover: true });
      const sideLbl = a.side === 'nato' ? 'NATO eastern flank' : 'Bordering · OSINT';
      const sideCls = a.side === 'nato' ? 'side' : 'side opp';
      m.bindTooltip(
        `<b>${a.name}</b> <span class="${sideCls}">${sideLbl}</span>` +
        `<div class="row" style="margin-top:4px;"><span>Type</span> ${a.kind === 'CIV' ? 'Civil hub' : 'Air base'}</div>` +
        `<div class="row"><span>Site</span> ${a.loc}</div>` +
        `<div class="row"><span>Role</span> ${a.role}</div>`,
        { className: 'cvg-field-tip', direction: 'top', offset: [0, -10], sticky: true }
      );
      m.addTo(fieldLayer);
    });

    // ───────── 5. SHOOTERS — air-defence / SAM / coastal launcher sites (OSINT public) ─────────
    const SHOOTERS = [
      // NATO side — Patriot / NASAMS / IRIS-T / coastal
      { name:'Patriot · Rzeszów',   sys:'PAC‑3 MSE',     loc:'Poland · Rzeszów approach',     ll:[50.090, 22.04], side:'nato' },
      { name:'Patriot · Warsaw',    sys:'PAC‑3 MSE',     loc:'Poland · Warsaw shield',        ll:[52.07, 20.95],  side:'nato' },
      { name:'NASAMS · Mińsk Maz.', sys:'NASAMS III',    loc:'Poland · Masovia',              ll:[52.18, 21.55],  side:'nato' },
      { name:'Patriot · Gdynia',    sys:'PAC‑3',         loc:'Poland · Pomerania (coastal)',  ll:[54.50, 18.55],  side:'nato' },
      { name:'NSM coastal · Hel',   sys:'Coastal · NSM', loc:'Poland · Hel peninsula',        ll:[54.601, 18.815],side:'nato' },
      { name:'Patriot · Mihail K.', sys:'PAC‑3',         loc:'Romania · Constanța',           ll:[44.36, 28.50],  side:'nato' },
      { name:'AEGIS Ashore · Deveselu', sys:'AEGIS · SM‑3', loc:'Romania · Olt',              ll:[44.052, 24.320],side:'nato' },
      { name:'NASAMS · Ämari',      sys:'NASAMS',        loc:'Estonia · Ämari',               ll:[59.27, 24.22],  side:'nato' },
      { name:'IRIS‑T SLM · Riga',   sys:'IRIS‑T SLM',    loc:'Latvia · Riga shield',          ll:[56.95, 24.10],  side:'nato' },
      { name:'NASAMS · Vilnius',    sys:'NASAMS',        loc:'Lithuania · capital shield',    ll:[54.69, 25.28],  side:'nato' },
      { name:'NASAMS · Helsinki',   sys:'NASAMS II',     loc:'Finland · capital shield',      ll:[60.20, 24.94],  side:'nato' },
      { name:'David\u2019s Sling (cmt)', sys:'Long‑range AD', loc:'Finland · north',          ll:[63.10, 25.20],  side:'nato' },
      // Ukrainian air defence — supplied / domestic, blue force
      { name:'Patriot · Kyiv',      sys:'PAC‑3 MSE',     loc:'Ukraine · Kyiv shield',         ll:[50.45, 30.55],  side:'nato' },
      { name:'NASAMS · Kyiv',       sys:'NASAMS III',    loc:'Ukraine · Kyiv approaches',     ll:[50.40, 30.30],  side:'nato' },
      { name:'IRIS‑T SLM · Odesa',  sys:'IRIS‑T SLM',    loc:'Ukraine · Odesa coastal',       ll:[46.45, 30.75],  side:'nato' },
      { name:'S‑300V1 · Kharkiv',   sys:'S‑300V1 (UA)',  loc:'Ukraine · Kharkiv shield',      ll:[49.99, 36.23],  side:'nato' },
      { name:'Patriot · Lviv',      sys:'PAC‑2 GEM',     loc:'Ukraine · western shield',      ll:[49.84, 23.99],  side:'nato' },
      { name:'SAMP/T · Dnipro',     sys:'SAMP/T (FR/IT)',loc:'Ukraine · Dnipro shield',       ll:[48.46, 35.05],  side:'nato' },

      // Opposing side — S-300/S-400 / Pantsir / Bastion (all publicly disclosed positions)
      { name:'S‑400 · Kaliningrad', sys:'S‑400 Triumf',  loc:'Russia · Kaliningrad oblast',   ll:[54.76, 20.50],  side:'opp' },
      { name:'S‑400 · Gvardeysk',   sys:'S‑400',         loc:'Russia · Kaliningrad oblast',   ll:[54.65, 21.06],  side:'opp' },
      { name:'S‑400 · St Petersburg',sys:'S‑400',        loc:'Russia · Leningrad oblast',     ll:[59.86, 30.10],  side:'opp' },
      { name:'S‑400 · Moscow ring', sys:'S‑400 / S‑500', loc:'Russia · Moscow A‑135 ring',    ll:[55.60, 37.45],  side:'opp' },
      { name:'S‑300 · Pskov',       sys:'S‑300PMU',      loc:'Russia · Pskov oblast',         ll:[57.80, 28.40],  side:'opp' },
      { name:'S‑400 · Smolensk',    sys:'S‑400',         loc:'Russia · Smolensk',             ll:[54.78, 32.07],  side:'opp' },
      { name:'Bastion · Kaliningrad',sys:'K‑300P Bastion·coastal',loc:'Russia · Baltic coast',ll:[54.92, 20.05],  side:'opp' },
      { name:'S‑400 · Baranavichy', sys:'S‑400 (BLR)',   loc:'Belarus · Brest',               ll:[53.13, 26.08],  side:'opp' },
      { name:'S‑300 · Hrodna',      sys:'S‑300PS (BLR)', loc:'Belarus · NW border',           ll:[53.68, 23.85],  side:'opp' },
      { name:'Pantsir‑S1 · Minsk',  sys:'Pantsir‑S1',    loc:'Belarus · capital shield',      ll:[53.95, 27.50],  side:'opp' },
      { name:'S‑400 · Sevastopol',  sys:'S‑400 · contested', loc:'Crimea · Black Sea',        ll:[44.62, 33.55],  side:'opp' },
      { name:'Bastion · Crimea',    sys:'K‑300P · contested',loc:'Crimea · coastal',          ll:[45.34, 32.50],  side:'opp' }
    ];
    function shootIcon(side) {
      const sc = side === 'nato' ? '#0E7490' : '#E11D48';
      return L.divIcon({
        className: 'cvg-shoot-marker',
        html: `<span class="pulse" style="--sc:${sc}"></span><span class="pulse p2" style="--sc:${sc}"></span><span class="arc" style="--sc:${sc}"></span><span class="hex" style="--sc:${sc}"></span>`,
        iconSize: [32, 32], iconAnchor: [16, 16]
      });
    }
    SHOOTERS.forEach(s => {
      const m = L.marker(s.ll, { icon: shootIcon(s.side), title: s.name, riseOnHover: true });
      const sideLbl = s.side === 'nato' ? 'NATO eastern flank' : 'Bordering · OSINT';
      const sideCls = s.side === 'nato' ? 'side' : 'side opp';
      m.bindTooltip(
        `<b>${s.name}</b> <span class="${sideCls}">${sideLbl}</span>` +
        `<div class="row" style="margin-top:4px;"><span>System</span> ${s.sys}</div>` +
        `<div class="row"><span>Site</span> ${s.loc}</div>` +
        `<div class="row"><span>Status</span> ${s.side==='nato'?'NATO IAMD · awareness':'OSINT public · awareness'}</div>`,
        { className: 'cvg-shoot-tip', direction: 'top', offset: [0, -12], sticky: true }
      );
      m.addTo(shootLayer);
    });

    // ───────── 6. DATA CENTRES — hyperscalers + critical national + opposing ─────────
    const DATA_CTRS = [
      // Hyperscalers / Western
      { name:'Google · Hamina',       op:'Google',     loc:'Finland · Hamina',         ll:[60.589, 27.190], side:'nato', tier:'hyperscale' },
      { name:'Microsoft Azure · Sweden Central', op:'Microsoft', loc:'Sweden · Gävle',  ll:[60.674, 17.141], side:'nato', tier:'hyperscale' },
      { name:'Microsoft · Warsaw Region', op:'Microsoft', loc:'Poland · Warsaw',       ll:[52.232, 21.020], side:'nato', tier:'hyperscale' },
      { name:'Google · Warsaw Region',op:'Google',     loc:'Poland · Warsaw',          ll:[52.180, 20.910], side:'nato', tier:'hyperscale' },
      { name:'Amazon AWS · Stockholm',op:'AWS',        loc:'Sweden · Stockholm',       ll:[59.395, 18.080], side:'nato', tier:'hyperscale' },
      { name:'Atea / Telia Tallinn',  op:'Telia',      loc:'Estonia · Tallinn',        ll:[59.420, 24.690], side:'nato', tier:'national' },
      { name:'Bité / LITNIX DC',      op:'Bité',       loc:'Lithuania · Vilnius',      ll:[54.687, 25.270], side:'nato', tier:'national' },
      { name:'LVRTC · Riga',          op:'LVRTC',      loc:'Latvia · Riga',            ll:[56.962, 24.140], side:'nato', tier:'national' },
      { name:'NEXT DATA · Bucharest', op:'NXDATA',     loc:'Romania · Bucharest',      ll:[44.435, 26.103], side:'nato', tier:'national' },
      { name:'Telia Helsinki Pitäjänmäki', op:'Telia',  loc:'Finland · Helsinki',      ll:[60.222, 24.870], side:'nato', tier:'national' },
      { name:'Equinix · WA1',         op:'Equinix',    loc:'Poland · Warsaw',          ll:[52.225, 20.998], side:'nato', tier:'national' },

      // Opposing side
      { name:'Yandex DC · M9',        op:'Yandex',     loc:'Russia · Moscow (Sasovo region)', ll:[54.367, 41.946], side:'opp', tier:'hyperscale' },
      { name:'Rostelecom M9 / MSK‑IX',op:'Rostelecom', loc:'Russia · Moscow Bolshoy Spasoglinishchevskiy', ll:[55.762, 37.633], side:'opp', tier:'national' },
      { name:'Sber DC · Skolkovo',    op:'Sber',       loc:'Russia · Moscow oblast',   ll:[55.703, 37.350], side:'opp', tier:'hyperscale' },
      { name:'VK Cloud · St Petersburg', op:'VK',      loc:'Russia · St Petersburg',   ll:[59.940, 30.310], side:'opp', tier:'national' },
      { name:'beCloud DC · Minsk',    op:'beCloud',    loc:'Belarus · Minsk',          ll:[53.910, 27.580], side:'opp', tier:'national' },
      { name:'Datahata DC',           op:'Datahata',   loc:'Belarus · Minsk',          ll:[53.864, 27.560], side:'opp', tier:'national' },
      { name:'GigaCloud · Kyiv',      op:'GigaCloud',  loc:'Ukraine · Kyiv',           ll:[50.453, 30.520], side:'nato', tier:'national' },
      { name:'De Novo · Kyiv',        op:'De Novo',    loc:'Ukraine · Kyiv',           ll:[50.430, 30.490], side:'nato', tier:'national' },
      { name:'StarLightMedia · Kyiv (bunkered)', op:'critical', loc:'Ukraine · Kyiv',  ll:[50.470, 30.460], side:'nato', tier:'critical' },
      { name:'Moldtelecom DC',        op:'Moldtelecom',loc:'Moldova · Chișinău',       ll:[47.030, 28.860], side:'opp', tier:'national' }
    ];
    function dcIcon(tier) {
      const dcc = tier === 'hyperscale' ? '#8B5CF6' : tier === 'critical' ? '#DC2626' : '#A78BFA';
      return L.divIcon({
        className: 'cvg-dc-marker' + (tier === 'hyperscale' ? ' k-hyper' : ''),
        html: `<span class="box" style="--dcc:${dcc}"></span>`,
        iconSize: [24, 24], iconAnchor: [12, 12]
      });
    }
    DATA_CTRS.forEach(d => {
      const m = L.marker(d.ll, { icon: dcIcon(d.tier), title: d.name, riseOnHover: true });
      const tierLbl = d.tier === 'hyperscale' ? 'Hyperscale' : d.tier === 'critical' ? 'Critical bunkered' : 'National tier';
      m.bindTooltip(
        `<b>${d.name}</b> <span class="badge">${tierLbl}</span>` +
        `<div class="row" style="margin-top:4px;"><span>Operator</span> ${d.op}</div>` +
        `<div class="row"><span>Site</span> ${d.loc}</div>` +
        `<div class="row"><span>Side</span> ${d.side==='nato'?'NATO eastern flank':'Bordering · OSINT'}</div>`,
        { className: 'cvg-dc-tip', direction: 'top', offset: [0, -10], sticky: true }
      );
      m.addTo(dcLayer);
    });

    // ───────── 7. NETWORK NODES — IXPs · submarine cable landings · backbone POPs ─────────
    const NETS = [
      // IXPs · Western
      { name:'FICIX · Espoo',       kind:'IXP',   loc:'Finland · Espoo',        ll:[60.205, 24.665], side:'nato' },
      { name:'TLLIX · Tallinn',     kind:'IXP',   loc:'Estonia · Tallinn',      ll:[59.435, 24.745], side:'nato' },
      { name:'LIX · Riga',          kind:'IXP',   loc:'Latvia · Riga',          ll:[56.946, 24.105], side:'nato' },
      { name:'LITNIX · Vilnius',    kind:'IXP',   loc:'Lithuania · Vilnius',    ll:[54.687, 25.279], side:'nato' },
      { name:'PLIX / EPIX · Warsaw',kind:'IXP',   loc:'Poland · Warsaw',        ll:[52.230, 21.012], side:'nato' },
      { name:'INTERLAN · Bucharest',kind:'IXP',   loc:'Romania · Bucharest',    ll:[44.439, 26.096], side:'nato' },
      // Submarine cable landings
      { name:'C‑Lion1 landing',     kind:'CABLE', loc:'Finland · Helsinki → Rostock', ll:[60.155, 24.870], side:'nato' },
      { name:'Baltic Connector (gas/data parallel)', kind:'CABLE', loc:'Finland · Inkoo', ll:[60.046, 24.005], side:'nato' },
      { name:'EE‑S1 landing',       kind:'CABLE', loc:'Estonia · Paldiski',     ll:[59.355, 24.062], side:'nato' },
      { name:'NordBalt landing',    kind:'CABLE', loc:'Lithuania · Klaipėda',   ll:[55.715, 21.116], side:'nato' },
      { name:'Denmark‑Poland landing',kind:'CABLE',loc:'Poland · Niechorze',    ll:[54.085, 15.072], side:'nato' },
      // Backbone POPs (NATO)
      { name:'Telia Skanova · Stockholm POP', kind:'POP', loc:'Sweden · Stockholm', ll:[59.330, 18.063], side:'nato' },
      { name:'Orange · Warsaw POP', kind:'POP',   loc:'Poland · Warsaw',        ll:[52.252, 20.985], side:'nato' },

      // Opposing side
      { name:'MSK‑IX · Moscow',     kind:'IXP',   loc:'Russia · Moscow M9',     ll:[55.762, 37.633], side:'opp' },
      { name:'SPB‑IX · St Petersburg',kind:'IXP', loc:'Russia · St Petersburg', ll:[59.940, 30.310], side:'opp' },
      { name:'UA‑IX · Kyiv',        kind:'IXP',   loc:'Ukraine · Kyiv',         ll:[50.450, 30.520], side:'nato' },
      { name:'GigaNET · Kyiv',      kind:'IXP',   loc:'Ukraine · Kyiv',         ll:[50.448, 30.500], side:'nato' },
      { name:'BY‑IX · Minsk',       kind:'IXP',   loc:'Belarus · Minsk',        ll:[53.902, 27.567], side:'opp' },
      { name:'Rostelecom Kaliningrad POP', kind:'POP', loc:'Russia · Kaliningrad',ll:[54.708, 20.510], side:'opp' },
      { name:'Rostelecom Sevastopol POP',  kind:'POP', loc:'Crimea · contested',ll:[44.616, 33.525], side:'opp' },
      { name:'Moldtelecom · Chișinău POP', kind:'POP', loc:'Moldova · Chișinău',ll:[46.999, 28.857], side:'opp' }
    ];
    function netIcon(kind, side) {
      const nc = side === 'opp' ? '#F472B6' : (kind === 'CABLE' ? '#22D3EE' : kind === 'POP' ? '#7DD3FC' : '#06B6D4');
      return L.divIcon({
        className: 'cvg-net-marker',
        html: `<span class="ping" style="--nc:${nc}"></span><span class="dia" style="--nc:${nc}"></span>`,
        iconSize: [22, 22], iconAnchor: [11, 11]
      });
    }
    NETS.forEach(n => {
      const m = L.marker(n.ll, { icon: netIcon(n.kind, n.side), title: n.name, riseOnHover: true });
      const kindLbl = n.kind === 'IXP' ? 'Internet Exchange' : n.kind === 'CABLE' ? 'Submarine cable landing' : 'Carrier backbone POP';
      m.bindTooltip(
        `<b>${n.name}</b>` +
        `<div class="row" style="margin-top:4px;"><span>Kind</span> ${kindLbl}</div>` +
        `<div class="row"><span>Site</span> ${n.loc}</div>` +
        `<div class="row"><span>Side</span> ${n.side==='nato'?'NATO eastern flank':'Bordering · OSINT'}</div>`,
        { className: 'cvg-net-tip', direction: 'top', offset: [0, -10], sticky: true }
      );
      m.addTo(netLayer);
    });

    // ───────── 8. SATELLITES — mil + civ ISR / EO / SAR over the corridor ─────────
    // Synthetic but plausible orbital positions. They drift across the bbox; when off-edge they wrap.
    const SATELLITES = [
      // Civilian Earth-observation
      { name:'Sentinel‑1A',        op:'ESA',          kind:'civ', purpose:'C‑band SAR · Earth obs',     alt:'693 km · SSO',   lng:18.0, lat:64.0, vlng:-0.020, vlat:-0.040 },
      { name:'Sentinel‑2B',        op:'ESA',          kind:'civ', purpose:'Optical multispectral',      alt:'786 km · SSO',   lng:25.0, lat:58.0, vlng:-0.018, vlat:-0.038 },
      { name:'Sentinel‑3A',        op:'ESA',          kind:'civ', purpose:'Ocean/land radiometer',      alt:'815 km · SSO',   lng:30.0, lat:62.0, vlng:-0.018, vlat: 0.040 },
      { name:'Landsat 9',          op:'NASA / USGS',  kind:'civ', purpose:'30 m multispectral',         alt:'705 km · SSO',   lng:22.0, lat:48.0, vlng:-0.022, vlat:-0.036 },
      { name:'ICEYE‑X14',          op:'ICEYE',        kind:'civ', purpose:'Commercial SAR · 25 cm',     alt:'570 km · SSO',   lng:33.0, lat:52.0, vlng:-0.024, vlat:-0.042 },
      { name:'Capella‑9',          op:'Capella Space',kind:'civ', purpose:'X‑band SAR · 50 cm',         alt:'525 km · SSO',   lng:21.0, lat:55.0, vlng:-0.025, vlat: 0.042 },
      { name:'Maxar WorldView‑3',  op:'Maxar',        kind:'civ', purpose:'30 cm optical · panchromatic',alt:'617 km · SSO',  lng:28.0, lat:50.0, vlng:-0.020, vlat:-0.040 },
      { name:'Planet SkySat‑21',   op:'Planet Labs',  kind:'civ', purpose:'50 cm optical · revisit',    alt:'500 km · SSO',   lng:35.0, lat:60.0, vlng:-0.024, vlat: 0.038 },
      { name:'Pléiades Neo 4',     op:'Airbus DS',    kind:'civ', purpose:'30 cm commercial optical',   alt:'620 km · SSO',   lng:19.0, lat:46.0, vlng:-0.022, vlat: 0.040 },
      // Military / strategic ISR (positions illustrative only)
      { name:'USA‑326 (KH‑11)',    op:'US · NRO',     kind:'mil', purpose:'KH‑11 Evolved · EO ISR',     alt:'~470 km · LEO',  lng:24.0, lat:53.0, vlng:-0.025, vlat:-0.044 },
      { name:'USA‑290 (FIA‑R)',    op:'US · NRO',     kind:'mil', purpose:'Radar reconnaissance',       alt:'~1100 km · LEO', lng:34.0, lat:51.0, vlng:-0.018, vlat: 0.040 },
      { name:'USA‑279 (Topaz)',    op:'US · NRO',     kind:'mil', purpose:'Future Imagery Arch. radar', alt:'~1100 km · LEO', lng:38.0, lat:58.0, vlng:-0.018, vlat:-0.038 },
      { name:'Kosmos 2576',        op:'RU · MoD',     kind:'mil', purpose:'Persona EO reconnaissance',  alt:'~720 km · LEO',  lng:40.0, lat:49.0, vlng:-0.022, vlat:-0.040 },
      { name:'Kosmos 2558',        op:'RU · MoD',     kind:'mil', purpose:'Inspector / signals',        alt:'~480 km · LEO',  lng:42.0, lat:55.0, vlng:-0.024, vlat: 0.042 },
      { name:'Kosmos 2547 (Tselina)',op:'RU · MoD',   kind:'mil', purpose:'ELINT collector',            alt:'~700 km · LEO',  lng:36.0, lat:62.0, vlng:-0.020, vlat:-0.038 },
      { name:'CSO‑1 (HELIOS gen3)',op:'FR · CNES/DGA',kind:'mil', purpose:'EO ISR · 35 cm',             alt:'~480 km · LEO',  lng:23.0, lat:50.0, vlng:-0.022, vlat: 0.040 },
      { name:'SARah‑1',            op:'DE · BMVg',    kind:'mil', purpose:'Radar ISR (X‑band)',         alt:'~715 km · LEO',  lng:21.0, lat:60.0, vlng:-0.020, vlat:-0.042 },
      { name:'Yaogan‑30‑01 (trio)',op:'CN · PLA',     kind:'mil', purpose:'ELINT triplet · co‑orbital', alt:'~600 km · LEO',  lng:30.0, lat:46.0, vlng:-0.018, vlat: 0.040 }
    ];
    function satIcon(kind) {
      const sc = kind === 'mil' ? '#E11D48' : '#22D3EE';
      return L.divIcon({
        className: 'cvg-sat-marker k-' + kind,
        html: '<span class="halo" style="--sc:' + sc + '"></span>' +
              '<svg class="sat-svg" viewBox="-14 -14 28 28" style="--sc:' + sc + '">' +
                '<rect class="panel" x="-13" y="-2.5" width="7" height="5" rx="0.5"/>' +
                '<rect class="panel" x="6"   y="-2.5" width="7" height="5" rx="0.5"/>' +
                '<rect class="body"  x="-3"  y="-3"   width="6" height="6" rx="0.5"/>' +
                '<circle class="core" cx="0" cy="0" r="1.2"/>' +
              '</svg>',
        iconSize: [36, 36], iconAnchor: [18, 18]
      });
    }
    const satMarkers = [];
    SATELLITES.forEach((s, i) => {
      const m = L.marker([s.lat, s.lng], { icon: satIcon(s.kind), title: s.name, riseOnHover: true });
      // Heading from velocity vector
      const hd = (Math.atan2(s.vlng, s.vlat) * 180 / Math.PI + 360) % 360;
      m.on('add', () => {
        const el = m.getElement();
        if (el) el.style.setProperty('--sat-hd', hd + 'deg');
      });
      const sideCls = s.kind === 'mil' ? 'side mil' : 'side civ';
      const sideLbl = s.kind === 'mil' ? 'MIL' : 'CIV';
      m.bindTooltip(
        `<b>${s.name}</b> <span class="${sideCls}">${sideLbl}</span>` +
        `<div class="row" style="margin-top:4px;"><span>Operator</span> ${s.op}</div>` +
        `<div class="row"><span>Mission</span> ${s.purpose}</div>` +
        `<div class="row"><span>Orbit</span> ${s.alt}</div>`,
        { className: 'cvg-sat-tip', direction: 'top', offset: [0, -14], sticky: true }
      );
      m.addTo(satLayer);
      satMarkers.push({ m, s, hd });
    });
    // Tick: drift satellites; wrap when off the wider bbox.
    function satTick() {
      satMarkers.forEach((entry) => {
        const s = entry.s;
        s.lng += s.vlng * 6;     // amplify for visible motion
        s.lat += s.vlat * 6;
        // Wrap at expanded bbox
        if (s.lng <  -10) s.lng = 60; else if (s.lng > 60) s.lng = -10;
        if (s.lat <   35) s.lat = 75; else if (s.lat > 75) s.lat = 35;
        entry.m.setLatLng([s.lat, s.lng]);
      });
    }
    setInterval(satTick, 1000);
    document.getElementById('cvgSatCount').textContent = SATELLITES.length;

    // ───────── 9. MILITARY ACTIVITY · exercises · movements · engagements ─────────
    // OSINT-curated. Exercises = bbox zones. Movements = line + arrow. Engagements = pulsing rect. Announcements = point markers.
    const MIL_ACTIVITY = [
      // ── NATO / Blue exercises ──
      { id:'EX-01', kind:'exercise',   side:'nato', name:'STEADFAST DEFENDER 25', force:'NATO multi‑corps',          when:'Active · multi‑phase',   loc:'Northern Europe / Baltic', bbox:[[54.0, 17.5], [60.5, 30.0]] },
      { id:'EX-02', kind:'exercise',   side:'nato', name:'SABER STRIKE 25',       force:'US Army · eFP',             when:'Active',                  loc:'Baltic states + Poland',   bbox:[[54.2, 21.5], [57.8, 26.8]] },
      { id:'EX-03', kind:'exercise',   side:'nato', name:'NORTHERN FOREST 25',    force:'Finland · Sweden · US',     when:'Scheduled · Q3',          loc:'Finland · Lapland',        bbox:[[62.5, 23.5], [66.5, 30.5]] },
      { id:'EX-04', kind:'exercise',   side:'nato', name:'COLD RESPONSE 25',      force:'NATO Arctic',               when:'Scheduled · winter',      loc:'Norway / N. Sweden',       bbox:[[66.0, 14.0], [70.5, 22.5]] },
      { id:'EX-05', kind:'exercise',   side:'nato', name:'DEFENDER EUROPE 25',    force:'US V Corps + NATO',         when:'Active',                  loc:'Romania / Bulgaria',       bbox:[[42.0, 22.5], [46.5, 27.5]] },
      { id:'EX-06', kind:'exercise',   side:'nato', name:'IRON DEFENDER',         force:'Polish Army · UK · DE',     when:'Active · east border',    loc:'Poland · east border',     bbox:[[50.5, 22.5], [54.0, 24.0]] },
      { id:'EX-07', kind:'exercise',   side:'nato', name:'SEA BREEZE',            force:'Multinational naval',       force_alt:'NATO + partners',    when:'Active',                  loc:'Black Sea',                bbox:[[43.0, 28.0], [44.6, 31.5]] },
      // ── Red side exercises ──
      { id:'EX-08', kind:'exercise',   side:'opp',  name:'ZAPAD‑2025',            force:'RUS Western MD + BLR',      when:'Announced · Q3',          loc:'Belarus · KGD · west MD',  bbox:[[52.5, 19.0], [56.0, 32.0]] },
      { id:'EX-09', kind:'exercise',   side:'opp',  name:'UNION RESOLVE',         force:'RUS + BLR joint',           when:'Active · rotating',       loc:'Belarus / RUS border',     bbox:[[52.0, 26.5], [55.5, 31.5]] },
      { id:'EX-10', kind:'exercise',   side:'opp',  name:'SEVERNYY VETER',        force:'RUS Northern Fleet',        when:'Active',                  loc:'Kola peninsula · Arctic',  bbox:[[68.0, 32.0], [71.0, 41.5]] },
      { id:'EX-11', kind:'exercise',   side:'opp',  name:'CHERNOMORSKIY FLOT‑X',  force:'RUS Black Sea Fleet',       when:'Active',                  loc:'Crimea / Black Sea',       bbox:[[43.5, 31.0], [45.0, 34.5]] },

      // ── Active engagements ──
      { id:'EG-01', kind:'engagement', side:'opp',  name:'Donbas active front',   force:'UA vs RUS forces',          when:'Ongoing',                 loc:'UA · eastern oblasts',     bbox:[[47.0, 36.0], [49.5, 39.5]] },
      { id:'EG-02', kind:'engagement', side:'opp',  name:'Belgorod–Kursk cross‑border', force:'UA incursion / strikes', when:'Recurring',          loc:'RUS · border oblasts',     bbox:[[50.5, 34.0], [52.0, 37.5]] },
      { id:'EG-03', kind:'engagement', side:'opp',  name:'Sevastopol naval ops',  force:'RUS BSF · contested',       when:'Active',                  loc:'Crimea · Sevastopol',      bbox:[[44.30, 33.20], [44.85, 33.85]] },

      // ── Force movements (lines with arrow head) ──
      { id:'MV-01', kind:'movement', side:'nato', name:'US APS‑2 rotational lift',      force:'US Army Europe',     when:'Ongoing rotation',  loc:'Bremerhaven → Powidz', from:[53.55, 8.58],  to:[52.38, 17.85] },
      { id:'MV-02', kind:'movement', side:'nato', name:'NATO eFP rotation · LVA',       force:'Multinational eFP',  when:'Active',            loc:'Germany → Latvia',     from:[52.50, 13.40], to:[56.95, 24.10] },
      { id:'MV-03', kind:'movement', side:'nato', name:'NATO eFP rotation · LTU',       force:'Multinational eFP',  when:'Active',            loc:'Germany → Lithuania',  from:[52.50, 13.40], to:[54.69, 25.28] },
      { id:'MV-04', kind:'movement', side:'nato', name:'V Corps elements → Mihail K.',  force:'US V Corps',         when:'Active rotation',   loc:'Germany → Constanța',  from:[49.79, 9.95],  to:[44.36, 28.49] },
      { id:'MV-05', kind:'movement', side:'opp',  name:'VDV elements → Pskov AB',       force:'RU VDV',             when:'Reinforcement',     loc:'Moscow → Pskov AB',    from:[55.75, 37.62], to:[57.79, 28.40] },
      { id:'MV-06', kind:'movement', side:'opp',  name:'S‑400 reinforcement · KGD',     force:'RU AD forces',       when:'Movement signal',   loc:'Saint Petersburg → Kaliningrad', from:[59.94, 30.30], to:[54.71, 20.51] },
      { id:'MV-07', kind:'movement', side:'opp',  name:'BSF surge · Sevastopol berth',  force:'RU Black Sea Fleet', when:'Berthing surge',    loc:'Novorossiysk → Sevastopol', from:[44.72, 37.78], to:[44.62, 33.55] },

      // ── Announcements (point) ──
      { id:'AN-01', kind:'announce', side:'nato', name:'NATO eAP F‑35 rotation announced', force:'NATO eAP', when:'Announced', loc:'Ämari AB', ll:[59.26, 24.21] },
      { id:'AN-02', kind:'announce', side:'opp',  name:'ZAPAD‑2025 outline published',     force:'RU MoD',   when:'Announced', loc:'Minsk · BLR MoD', ll:[53.90, 27.57] },
      { id:'AN-03', kind:'announce', side:'nato', name:'Defender Europe contracts awarded', force:'US EUCOM', when:'Announced', loc:'Bucharest · NATO HQ', ll:[44.43, 26.10] }
    ];
    // Render exercises / engagements (rectangles)
    const milRects = {};
    MIL_ACTIVITY.filter(a => a.bbox).forEach(a => {
      const side = a.kind === 'engagement' ? '#DC2626' : (a.side === 'nato' ? '#0E7490' : '#DC2626');
      const cls  = a.kind === 'engagement' ? 'cvg-ex-engage'
                : a.side === 'nato' ? 'cvg-ex-rect-nato' : 'cvg-ex-rect-opp';
      const rect = L.rectangle(a.bbox, {
        color: side, weight: a.kind === 'engagement' ? 2 : 1.4, opacity: 0.85,
        fillColor: side, fillOpacity: a.kind === 'engagement' ? 0.12 : 0.06,
        className: cls
      }).addTo(milLayer);
      const lblCls = a.kind === 'engagement' ? 'kind-engagement'
                   : a.side === 'nato' ? 'side-nato' : 'side-opp';
      rect.bindTooltip(`<b>${a.id}</b> · ${a.name}`, {
        permanent: true, direction: 'center',
        className: 'cvg-ex-label ' + lblCls
      });
      rect.on('click', () => focusMil(a.id));
      milRects[a.id] = { layer: rect, item: a };
    });

    // Render force movement lines + arrowheads
    MIL_ACTIVITY.filter(a => a.kind === 'movement').forEach(a => {
      const color = a.side === 'nato' ? '#0E7490' : '#DC2626';
      const line = L.polyline([a.from, a.to], {
        color, weight: 2, opacity: 0.7,
        dashArray: '4 4',
        className: 'cvg-mv-line'
      }).addTo(milLayer);
      // Arrow head at destination
      const dy = a.to[0] - a.from[0]; // lat diff
      const dx = a.to[1] - a.from[1]; // lng diff
      const headDeg = (Math.atan2(dx, dy) * 180 / Math.PI + 360) % 360;
      const arrow = L.marker(a.to, {
        icon: L.divIcon({
          className: 'cvg-mv-arrow-marker',
          html: `<svg viewBox="-10 -10 20 20" style="--mv-hd:${headDeg}deg;--mc:${color}"><path d="M0 -9 L7 6 L0 2 L-7 6 Z"/></svg>`,
          iconSize: [22, 22], iconAnchor: [11, 11]
        }),
        interactive: true
      }).addTo(milLayer);
      const tipHtml =
        `<b>${a.id}</b> · ${a.name}` +
        `<div class="row" style="margin-top:4px;"><span>Force</span> ${a.force}</div>` +
        `<div class="row"><span>When</span> ${a.when}</div>` +
        `<div class="row"><span>Vector</span> ${a.loc}</div>`;
      line.bindTooltip(tipHtml,  { className: 'cvg-field-tip', direction: 'top', sticky: true });
      arrow.bindTooltip(tipHtml, { className: 'cvg-field-tip', direction: 'top', sticky: true });
      line.on('click',  () => focusMil(a.id));
      arrow.on('click', () => focusMil(a.id));
      milRects[a.id] = { layer: line, item: a };
    });

    // Render announcements (point markers reusing the sensor look)
    MIL_ACTIVITY.filter(a => a.kind === 'announce').forEach(a => {
      const color = a.side === 'nato' ? '#0E7490' : '#DC2626';
      const m = L.circleMarker(a.ll, {
        radius: 5, weight: 2, color, fillColor: color, fillOpacity: 0.55
      }).addTo(milLayer);
      m.bindTooltip(
        `<b>${a.id}</b> · ${a.name}` +
        `<div class="row" style="margin-top:4px;"><span>Force</span> ${a.force}</div>` +
        `<div class="row"><span>When</span> ${a.when}</div>` +
        `<div class="row"><span>Site</span> ${a.loc}</div>`,
        { className: 'cvg-field-tip', direction: 'top', sticky: true }
      );
      m.on('click', () => focusMil(a.id));
      milRects[a.id] = { layer: m, item: a };
    });

    // Side panel renderer + filter
    let milFilter = 'all';
    function renderMilList() {
      const el = document.getElementById('cvgMilList');
      if (!el) return;
      const items = MIL_ACTIVITY.filter(a => milFilter === 'all' || a.kind === milFilter);
      el.innerHTML = items.map(a => (
        '<div class="cvg-mil-row" data-cvg-mil="' + a.id + '">' +
          '<span class="kind ' + a.kind + '">' + a.kind.slice(0,3) + '</span>' +
          '<span class="body">' +
            '<span class="ti">' + a.name + '</span>' +
            '<span class="me"><b>' + (a.force || '—') + '</b> · ' + a.when + ' · ' + a.loc + '</span>' +
          '</span>' +
          '<span class="side ' + (a.side === 'nato' ? 'blue' : 'red') + '"></span>' +
        '</div>'
      )).join('');
      el.querySelectorAll('[data-cvg-mil]').forEach(r => {
        r.addEventListener('click', () => focusMil(r.dataset.cvgMil));
      });
      document.getElementById('cvgMilBlue').textContent = MIL_ACTIVITY.filter(a => a.side === 'nato').length;
      document.getElementById('cvgMilRed').textContent  = MIL_ACTIVITY.filter(a => a.side === 'opp').length;
    }
    function focusMil(id) {
      const r = milRects[id]; if (!r) return;
      try {
        if (r.layer.getBounds) cvgRegionMap.flyToBounds(r.layer.getBounds(), { duration: 0.7, padding: [24, 24] });
        else if (r.layer.getLatLng) cvgRegionMap.flyTo(r.layer.getLatLng(), 7, { duration: 0.7 });
      } catch(e) {}
    }
    renderMilList();
    document.querySelectorAll('[data-cvg-mil-filter] [data-cvg-mil-f]').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('[data-cvg-mil-filter] [data-cvg-mil-f]').forEach(b => b.classList.toggle('on', b === btn));
        milFilter = btn.dataset.cvgMilF;
        renderMilList();
      });
    });
    document.getElementById('cvgMilCount').textContent = MIL_ACTIVITY.length;

    const AIR_BBOX = { lamin: 41.0, lomin: 5.0, lamax: 72.0, lomax: 50.0 };
    const FLEET_BASE = [
      // [callsign, fromLng, fromLat, toLng, toLat, knots]
      ['FIN101', 28.5, 60.0, 13.5, 52.5, 460], // HEL→FRA
      ['FIN228', 24.9, 60.3, 19.0, 47.5, 470], // HEL→BUD
      ['BTI421', 24.1, 56.9, 16.6, 52.4, 440], // RIX→WAW
      ['BTI206', 24.1, 56.9, 19.7, 47.5, 450], // RIX→BUD
      ['LOT3HW', 21.0, 52.2, 28.6, 45.4, 470], // WAW→OTP
      ['LOT4MA', 20.6, 52.0, 24.9, 60.3, 460], // WAW→HEL
      ['DLH9KX', 11.8, 50.0, 26.1, 44.5, 480], // FRA→OTP
      ['DLH1AK', 11.8, 50.0, 24.1, 56.9, 470], // FRA→RIX
      ['THY1LH', 28.8, 41.0, 21.0, 52.2, 470], // IST→WAW
      ['SAS842', 18.0, 59.6, 14.4, 50.1, 460], // ARN→PRG
      ['SWR226', 8.6, 47.4, 24.9, 60.3, 470],  // ZRH→HEL
      ['KLM142', 4.7, 52.3, 26.1, 44.5, 470],  // AMS→OTP
      ['RYR41W', 19.4, 51.1, 24.1, 56.9, 430], // KRK→RIX
      ['RYR8FT', 16.6, 52.4, 28.6, 45.4, 430], // WAW→OTP
      ['ROT384', 26.1, 44.5, 19.4, 51.1, 440], // OTP→KRK
      ['BAW884', -0.45,51.5,24.9, 60.3, 480],  // LHR→HEL
      ['ABG118', 30.4, 50.4, 28.6, 45.4, 440], // KBP→OTP (civil)
      ['MAU312', 19.0, 47.4, 24.1, 56.9, 450], // BUD→RIX
      ['THY4KA', 32.9, 39.9, 21.0, 52.2, 460], // ESB→WAW
      ['AFR9KZ', 2.5, 48.7, 28.6, 45.4, 470],  // CDG→OTP
      ['BTI301', 24.1, 56.9, 24.9, 60.3, 420], // RIX→HEL (short hop)
      ['AAL218', -73.9,40.6,21.0, 52.2, 490],  // JFK→WAW (transat)
      ['ENT104', 24.9, 60.3, 19.0, 47.5, 460],
      ['FIN917', 24.9, 60.3, 30.3, 59.9, 360], // HEL→LED (short)
      ['BTI142', 24.1, 56.9, 11.8, 50.0, 460], // RIX→FRA
      ['LOT281', 21.0, 52.2, 22.4, 45.8, 450], // WAW→TSR
      ['DLH7BA', 11.8, 50.0, 21.0, 52.2, 470], // FRA→WAW
      // ───── Regional spread · whole-bbox coverage ─────
      // Scandinavia / Arctic
      ['SAS412',  17.92, 59.65, 18.92, 69.68, 440], // ARN→TOS
      ['NAX102',  11.10, 60.20, 14.36, 67.27, 440], // OSL→BOO
      ['WIF402',  10.92, 63.46, 18.92, 69.68, 420], // TRD→TOS
      ['FIN451',  24.96, 60.32, 32.75, 68.78, 430], // HEL→MMK proximity
      ['SAS844',  18.0,  59.6,  17.94, 67.85, 440], // ARN→LLA (Luleå)
      ['NAX505',  11.10, 60.20, 24.96, 60.32, 460], // OSL→HEL
      // St Petersburg / NW Russia
      ['SVR321',  30.26, 59.80, 37.41, 55.97, 460], // LED→SVO
      ['AY708',   24.96, 60.32, 30.26, 59.80, 380], // HEL→LED (short hop)
      ['SVR889',  37.27, 55.59, 30.26, 59.80, 450], // VKO→LED
      // Western / inner Russia
      ['UTA421',  37.90, 55.41, 49.28, 55.61, 470], // DME→KZN
      ['AFL501',  37.41, 55.97, 20.51, 54.71, 470], // SVO→KGD (overflies BLR)
      ['SBI180',  37.90, 55.41, 49.92, 53.50, 460], // DME→KUF (Samara region)
      // Belarus / Baltics regional
      ['ABV222',  28.03, 53.88, 37.41, 55.97, 460], // MSQ→SVO
      ['BTI309',  24.1,  56.9,  24.96, 60.32, 420], // RIX→HEL (additional)
      ['ESR402',  30.26, 59.80, 28.03, 53.88, 430], // LED→MSQ
      // Turkey / Black Sea / Caucasus
      ['THY3KL',  28.74, 41.27, 26.10, 44.57, 450], // IST→OTP
      ['THY7BB',  28.74, 41.27, 23.41, 42.69, 440], // IST→SOF
      ['THY9XX',  28.74, 41.27, 44.95, 41.67, 460], // IST→TBS (transcaucasus)
      ['PGT212',  29.31, 40.90, 26.10, 44.57, 440], // SAW→OTP
      ['ROT220',  26.10, 44.57, 23.41, 42.69, 430], // OTP→SOF
      ['SDM602',  28.93, 46.93, 26.10, 44.57, 410], // KIV→OTP
      // South / Central Europe to region
      ['KLM305',   8.57, 50.03, 28.74, 41.27, 470], // FRA→IST
      ['LH4HK',   11.78, 48.35, 24.96, 60.32, 470], // MUC→HEL
      ['ELY7AB',   8.55, 47.46, 28.74, 41.27, 470], // ZRH→IST
      ['AUA422',  16.57, 48.11, 23.41, 42.69, 450], // VIE→SOF
      ['MAU181',  19.26, 47.43, 26.10, 44.57, 440], // BUD→OTP
      // Trans-atlantic transit (visible at altitude across bbox)
      ['AAL902', -73.9,  40.6,  11.78, 48.35, 490], // JFK→MUC
      ['DAL101', -73.7,  40.7,  21.0,  52.2,  490], // JFK→WAW
      // Domestic / inner EU
      ['EJU771',   2.5,  48.7,  21.0,  52.2,  450], // CDG→WAW
      ['LX240',    8.55, 47.46, 21.0,  52.2,  460], // ZRH→WAW
      ['BTI881',  24.1,  56.9,  19.26, 47.43, 440], // RIX→BUD
      ['LOT222',  21.0,  52.2,  24.69, 59.42, 420], // WAW→TLL
      ['LOT338',  21.0,  52.2,  19.79, 50.07, 410]  // WAW→KRK
    ];

    function spawnFleet() {
      // Return mutable fleet — each plane is at a fraction along its route.
      return FLEET_BASE.map((p, i) => {
        const dx = p[3] - p[1];
        const dy = p[4] - p[2];
        const dist = Math.hypot(dx, dy);
        const headingRad = Math.atan2(dx, dy);             // bearing from north, increases CW
        const headingDeg = (headingRad * 180 / Math.PI + 360) % 360;
        return {
          cs: p[0],
          fromLng: p[1], fromLat: p[2],
          toLng: p[3], toLat: p[4],
          knots: p[5],
          progress: (i * 17 + 11) % 100 / 100,   // staggered along route
          heading: headingDeg,
          alt: 9500 + (i * 137) % 3500,           // 9500-13000 m
          dist
        };
      });
    }

    function airIcon() {
      return L.divIcon({
        className: 'cvg-air-marker',
        html: '<div class="ac"><svg viewBox="-10 -10 20 20"><path class="body" d="M0 -8 L2.6 4 L0 2 L-2.6 4 Z"/></svg></div>',
        iconSize: [22, 22], iconAnchor: [11, 11]
      });
    }

    const fleet = spawnFleet();
    const airMarkers = fleet.map((f) => {
      const lng = f.fromLng + (f.toLng - f.fromLng) * f.progress;
      const lat = f.fromLat + (f.toLat - f.fromLat) * f.progress;
      const m = L.marker([lat, lng], { icon: airIcon(), title: f.cs, riseOnHover: true });
      m.on('add', () => {
        const el = m.getElement();
        if (el) {
          const ac = el.querySelector('.ac');
          if (ac) ac.style.setProperty('--hd', f.heading + 'deg');
        }
      });
      m.bindTooltip(
        `<b>${f.cs}</b>` +
        `<div class="row" style="margin-top:3px;"><span>HDG</span> ${Math.round(f.heading).toString().padStart(3,'0')}°</div>` +
        `<div class="row"><span>ALT</span> ${(f.alt).toFixed(0)} m</div>` +
        `<div class="row"><span>SPD</span> ${f.knots} kt</div>`,
        { className: 'cvg-air-tip', direction: 'top', offset: [0, -6], sticky: true }
      );
      m.addTo(airLayer);
      return { m, f };
    });

    // Advance flight progress on a 1Hz tick. Each plane moves ~knots/3600 degrees per sec (approx).
    function airTick() {
      airMarkers.forEach(({ m, f }) => {
        // Approx: 1° lat ≈ 60 NM; lng narrows by cos(lat). For an aesthetic anim, normalise by route length.
        const speedDegPerSec = (f.knots / 3600) / 60 * 1.0; // ~slow visible motion
        f.progress += speedDegPerSec / Math.max(0.001, f.dist) * 6;  // bump for visibility
        if (f.progress >= 1) {
          // flip route — return leg
          [f.fromLng, f.toLng] = [f.toLng, f.fromLng];
          [f.fromLat, f.toLat] = [f.toLat, f.fromLat];
          f.heading = (f.heading + 180) % 360;
          f.progress = 0;
          const el = m.getElement();
          if (el) { const ac = el.querySelector('.ac'); if (ac) ac.style.setProperty('--hd', f.heading + 'deg'); }
        }
        const lng = f.fromLng + (f.toLng - f.fromLng) * f.progress;
        const lat = f.fromLat + (f.toLat - f.fromLat) * f.progress;
        m.setLatLng([lat, lng]);
        // Update tooltip alt drift
        f.alt = 9500 + ((performance.now()/100 + f.cs.charCodeAt(0)) % 3500);
      });
    }
    setInterval(airTick, 1000);

    // ── Opportunistic OpenSky overlay (if reachable; quietly ignored on failure) ──
    (async function tryRealTrafficOverlay() {
      try {
        const url = `https://opensky-network.org/api/states/all?lamin=${AIR_BBOX.lamin}&lomin=${AIR_BBOX.lomin}&lamax=${AIR_BBOX.lamax}&lomax=${AIR_BBOX.lomax}`;
        const r = await fetch(url, { mode: 'cors' });
        if (!r.ok) throw new Error('opensky http ' + r.status);
        const j = await r.json();
        const states = (j && j.states) || [];
        if (!states.length) return;
        // Cap to keep DOM light
        const sample = states.filter(s => s[5] !== null && s[6] !== null).slice(0, 60);
        sample.forEach(s => {
          const cs = (s[1] || s[0] || 'UNK').trim() || 'UNK';
          const lng = s[5], lat = s[6];
          const hd = s[10] || 0;
          const alt = s[7] || 0;
          const m = L.marker([lat, lng], { icon: airIcon(), title: cs, riseOnHover: true });
          m.on('add', () => {
            const el = m.getElement();
            if (el) { const ac = el.querySelector('.ac'); if (ac) ac.style.setProperty('--hd', hd + 'deg'); }
          });
          m.bindTooltip(
            `<b>${cs}</b> · <span style="color:rgba(91,192,255,0.65);">OpenSky · live</span>` +
            `<div class="row" style="margin-top:3px;"><span>HDG</span> ${Math.round(hd).toString().padStart(3,'0')}°</div>` +
            `<div class="row"><span>ALT</span> ${alt.toFixed(0)} m</div>`,
            { className: 'cvg-air-tip', direction: 'top', offset: [0, -6], sticky: true }
          );
          m.addTo(airLayer);
          airMarkers.push({ m, f: { cs, knots: 0, heading: hd, alt, fromLng: lng, toLng: lng, fromLat: lat, toLat: lat, progress: 0, dist: 0 } });
        });
        updateAirCount();
      } catch (e) {
        // Silently fall back to simulated fleet — institutional/non-alarmist.
      }
    })();

    // ── Layer toggle wiring (Air / Radar / Sensors) ──
    function updateAirCount(){
      const ac = document.getElementById('cvgAirCount');
      if (ac) ac.textContent = airLayer.getLayers().length;
    }
    function setLayer(layer, group, on) {
      if (on) { if (!cvgRegionMap.hasLayer(group)) cvgRegionMap.addLayer(group); }
      else    { if (cvgRegionMap.hasLayer(group)) cvgRegionMap.removeLayer(group); }
    }
    document.querySelectorAll('[data-cvg-layers-control] [data-cvg-layer]').forEach(btn => {
      btn.addEventListener('click', () => {
        btn.classList.toggle('on');
        const key = btn.dataset.cvgLayer;
        const on = btn.classList.contains('on');
        if (key === 'air')    setLayer('air', airLayer, on);
        if (key === 'radar')  setLayer('radar', radarLayer, on);
        if (key === 'sensor') setLayer('sensor', sensorLayer, on);
        if (key === 'field')  setLayer('field', fieldLayer, on);
        if (key === 'shoot')  setLayer('shoot', shootLayer, on);
        if (key === 'dc')     setLayer('dc', dcLayer, on);
        if (key === 'net')    setLayer('net', netLayer, on);
        if (key === 'nai')    setLayer('nai', naiLayer, on);
        if (key === 'sat')    setLayer('sat', satLayer, on);
      });
    });

    // Initial counts
    document.getElementById('cvgRadarCount').textContent  = RADARS.length;
    document.getElementById('cvgSensorCount').textContent = SENSORS.length;
    document.getElementById('cvgFieldCount').textContent  = AIRFIELDS.length;
    document.getElementById('cvgShootCount').textContent  = SHOOTERS.length;
    document.getElementById('cvgDcCount').textContent     = DATA_CTRS.length;
    document.getElementById('cvgNetCount').textContent    = NETS.length;

    // ────────────── PEACE / CRISIS / WAR MODE ──────────────
    // cvgMode is exposed for the feed + NAI subsystems below.
    window.cvgMode = 'peace';
    const MODE_PROFILES = {
      peace:    { air:true,  radar:true,  sensor:true,  field:true,  shoot:false, dc:false, net:true, nai:false, sat:true },
      crisis:   { air:true,  radar:true,  sensor:true,  field:true,  shoot:false, dc:true,  net:true, nai:true,  sat:true },
      conflict: { air:true,  radar:true,  sensor:true,  field:true,  shoot:true,  dc:true,  net:true, nai:true,  sat:true }
    };
    function applyMode(mode) {
      window.cvgMode = mode;
      const profile = MODE_PROFILES[mode] || MODE_PROFILES.peace;
      const mapHost = document.querySelector('.cvg-region-map');
      if (mapHost) mapHost.setAttribute('data-cvg-mode', mode);
      // Sync layer toggle buttons + actual leaflet layers
      const layers = { air: airLayer, radar: radarLayer, sensor: sensorLayer, field: fieldLayer, shoot: shootLayer, dc: dcLayer, net: netLayer, nai: naiLayer, sat: satLayer };
      Object.entries(profile).forEach(([k, on]) => {
        setLayer(k, layers[k], on);
        const btn = document.querySelector('[data-cvg-layers-control] [data-cvg-layer="' + k + '"]');
        if (btn) btn.classList.toggle('on', !!on);
      });
      // Update mode segment UI
      document.querySelectorAll('[data-cvg-mode-toggle] [data-cvg-mode]').forEach(b => {
        b.classList.toggle('on', b.dataset.cvgMode === mode);
      });
      // Notify subsystems (feed, NAI) — they listen for this event
      document.dispatchEvent(new CustomEvent('cvg:mode', { detail: { mode } }));
    }
    document.querySelectorAll('[data-cvg-mode-toggle] [data-cvg-mode]').forEach(btn => {
      btn.addEventListener('click', () => applyMode(btn.dataset.cvgMode));
    });

    // ────────────── NAI / TAI · Critical Areas ──────────────
    const NAI_TAI = [
      // NAIs · watch zones
      { id:'NAI-01', kind:'nai', name:'Suwałki Gap',            crit:'Cross‑corridor cutoff vector · land link', bbox:[[53.95, 22.40], [54.55, 23.60]] },
      { id:'NAI-02', kind:'nai', name:'Kaliningrad approaches', crit:'A2/AD outer ring · naval / SAM',           bbox:[[54.20, 19.20], [55.30, 21.70]] },
      { id:'NAI-03', kind:'nai', name:'Kola peninsula approach',crit:'SSBN bastion · northern flank',            bbox:[[67.40, 31.50], [69.60, 38.50]] },
      { id:'NAI-04', kind:'nai', name:'Hrodna salient',         crit:'BLR NW staging area',                       bbox:[[53.50, 23.40], [54.10, 25.20]] },
      { id:'NAI-05', kind:'nai', name:'Transnistria pocket',    crit:'Frozen conflict · OG‑Russian forces',       bbox:[[46.40, 28.60], [48.40, 30.30]] },
      { id:'NAI-06', kind:'nai', name:'Belgorod–Kursk border',  crit:'Cross‑border activity · UA front',          bbox:[[50.30, 34.20], [52.30, 37.20]] },
      { id:'NAI-07', kind:'nai', name:'Constanța / Black Sea',  crit:'Maritime ISR · NATO logistics',             bbox:[[43.40, 27.80], [45.10, 30.70]] },
      { id:'NAI-08', kind:'nai', name:'Pripyat south border',   crit:'BLR→UA staging axis',                       bbox:[[51.00, 28.30], [52.20, 31.70]] },
      // TAIs · alert‑armed
      { id:'TAI-A',  kind:'tai', name:'Kaliningrad SAM ring',   crit:'S‑400 Gvardeysk + KGD · IADS',              bbox:[[54.50, 19.80], [55.00, 21.60]] },
      { id:'TAI-B',  kind:'tai', name:'Sevastopol naval area',  crit:'Black Sea Fleet HQ · AD belt',              bbox:[[44.35, 33.20], [44.85, 33.85]] },
      { id:'TAI-C',  kind:'tai', name:'Moscow A‑135 ring',      crit:'Strategic AD · S‑400 / S‑500 belt',          bbox:[[55.25, 36.80], [56.10, 38.30]] },
      { id:'TAI-D',  kind:'tai', name:'Saky / Belbek complex',  crit:'LRA airfield cluster · contested',          bbox:[[44.55, 33.30], [45.20, 33.90]] }
    ];
    const naiLayer = L.layerGroup();   // toggleable; mode profile decides initial visibility
    const naiRects = {};
    NAI_TAI.forEach(a => {
      const isTai = a.kind === 'tai';
      const color = isTai ? '#DC2626' : '#1A7A99';
      const rect = L.rectangle(a.bbox, {
        color, weight: 1.5, opacity: 0.85,
        fillColor: color, fillOpacity: 0.06,
        dashArray: isTai ? '4 4' : '6 5',
        className: 'cvg-nai-rect ' + (isTai ? 'cvg-tai-rect' : 'cvg-nai-rect-only')
      }).addTo(naiLayer);
      rect.bindTooltip(`<b>${a.id}</b> · ${a.name}`, {
        permanent: true, direction: 'center',
        className: 'cvg-nai-label' + (isTai ? ' kind-tai' : '')
      });
      rect.on('click', () => focusNAI(a.id));
      naiRects[a.id] = { rect, area: a, activity: 0 };
    });

    // Render side list
    const naiListEl = document.getElementById('cvgNaiList');
    function renderNaiList() {
      if (!naiListEl) return;
      naiListEl.innerHTML = NAI_TAI.map(a => {
        const st = naiRects[a.id];
        const hot = st && st.activity >= 3;
        return (
          '<div class="cvg-nai-row kind-' + a.kind + (hot ? ' hot' : '') + '" data-cvg-nai="' + a.id + '" role="listitem">' +
            '<span class="code">' + a.id + '</span>' +
            '<span class="nm">' + a.name + '<span class="crit">' + a.crit + '</span></span>' +
            '<span class="act">signals <b id="cvgNaiCt-' + a.id + '">' + (st ? st.activity : 0) + '</b></span>' +
          '</div>'
        );
      }).join('');
      document.getElementById('cvgNaiCountNai').textContent = NAI_TAI.filter(a => a.kind === 'nai').length;
      document.getElementById('cvgNaiCountTai').textContent = NAI_TAI.filter(a => a.kind === 'tai').length;
      naiListEl.querySelectorAll('[data-cvg-nai]').forEach(r => {
        r.addEventListener('click', () => focusNAI(r.dataset.cvgNai));
      });
    }
    renderNaiList();

    function focusNAI(id) {
      const st = naiRects[id]; if (!st) return;
      cvgRegionMap.flyToBounds(st.rect.getBounds(), { duration: 0.8, padding: [24, 24] });
    }

    // Stub: define area button — placeholder for future polygon drawing
    document.querySelector('[data-cvg-nai-act="define"]')?.addEventListener('click', (ev) => {
      const b = ev.currentTarget;
      const orig = b.textContent;
      b.textContent = 'Click two corners on map…';
      setTimeout(() => { b.textContent = orig; }, 2200);
    });

    // Exposed: increment NAI activity when an event's coords fall in a bbox
    window.cvgNaiBump = function (lat, lng, weight = 1) {
      let bumped = false;
      NAI_TAI.forEach(a => {
        const [[la1, lo1], [la2, lo2]] = a.bbox;
        const inLat = lat >= Math.min(la1, la2) && lat <= Math.max(la1, la2);
        const inLng = lng >= Math.min(lo1, lo2) && lng <= Math.max(lo1, lo2);
        if (inLat && inLng) {
          naiRects[a.id].activity += weight;
          const el = document.getElementById('cvgNaiCt-' + a.id);
          if (el) {
            el.textContent = naiRects[a.id].activity;
            el.parentElement.parentElement.classList.toggle('hot', naiRects[a.id].activity >= 3);
          }
          bumped = true;
        }
      });
      return bumped;
    };

    // Mode‑responsive rectangle restyle
    document.addEventListener('cvg:mode', (ev) => {
      const mode = ev.detail.mode;
      Object.values(naiRects).forEach(({ rect, area }) => {
        const isTai = area.kind === 'tai';
        if (mode === 'conflict') {
          rect.setStyle({ weight: isTai ? 2.5 : 2, opacity: 1, fillOpacity: isTai ? 0.14 : 0.08 });
        } else if (mode === 'crisis') {
          rect.setStyle({ weight: isTai ? 2 : 1.5, opacity: 0.9, fillOpacity: isTai ? 0.10 : 0.06 });
        } else {
          rect.setStyle({ weight: 1.5, opacity: 0.7, fillOpacity: 0.04 });
        }
      });
    });

    // ════════════ LIVE INTEL FEED ════════════
    const FEED_TEMPLATES = [
      // ARMED CONFLICT
      { cat:'armed', src:'ACLED',    hl:'Indirect fire reported · multiple rocket launchers',  loc:'UA · Donbas front',         ll:[48.40, 38.50], grade:['A2','B2'] },
      { cat:'armed', src:'ACLED',    hl:'Cross‑border shelling · civilian casualties reported',loc:'RUS · Belgorod oblast',     ll:[50.65, 36.60], grade:['B2','B3'] },
      { cat:'armed', src:'GDELT',    hl:'Drone strike claimed · refinery damage',              loc:'RUS · Smolensk',            ll:[54.78, 32.07], grade:['B3','C3'] },
      { cat:'armed', src:'ACLED',    hl:'Long‑range fires · ammunition depot impacted',        loc:'UA · Kharkiv oblast',       ll:[49.99, 36.23], grade:['A2','B2'] },
      { cat:'armed', src:'GDELT',    hl:'Reported MLRS strike · railway logistics hub',        loc:'RUS · Bryansk oblast',      ll:[53.25, 34.36], grade:['B3','C3'] },
      { cat:'armed', src:'social',   hl:'UAV swarm engagement · multiple intercepts',          loc:'UA · Kyiv shield',          ll:[50.45, 30.52], grade:['B2','C2'] },
      // HYBRID
      { cat:'hybrid', src:'GDELT',   hl:'Border movement surge · irregular migration vector',  loc:'BLR · LT border',           ll:[54.40, 25.50], grade:['B2','C3'] },
      { cat:'hybrid', src:'Telegram',hl:'Coordinated channel surge · staged escalation frame', loc:'RUS · west MD',             ll:[55.75, 37.62], grade:['C3','D4'] },
      { cat:'hybrid', src:'GDELT',   hl:'Hybrid pressure · grid sabotage rumours',             loc:'MDA · Transnistria',        ll:[47.00, 29.50], grade:['C3','D4'] },
      { cat:'hybrid', src:'social',  hl:'Provocation pattern · escalation language detected',  loc:'POL · Suwałki gap',         ll:[54.10, 22.93], grade:['C3','D5'] },
      // CYBER
      { cat:'cyber', src:'sigint',   hl:'DDoS surge · government domains targeted',            loc:'LVA · Riga',                ll:[56.95, 24.11], grade:['A2','B2'] },
      { cat:'cyber', src:'sigint',   hl:'Banking sector probing · credential stuffing pattern',loc:'EST · Tallinn',             ll:[59.43, 24.75], grade:['B2','C3'] },
      { cat:'cyber', src:'GDELT',    hl:'APT‑linked spearphishing · ministry of energy',       loc:'POL · Warsaw',              ll:[52.23, 21.01], grade:['B3','C3'] },
      { cat:'cyber', src:'sigint',   hl:'Wiper malware indicator · logistics provider',        loc:'UA · Kyiv',                 ll:[50.45, 30.52], grade:['A2','B2'] },
      { cat:'cyber', src:'social',   hl:'Reported hyperscaler outage · region failover',       loc:'FIN · Hamina (Google)',     ll:[60.59, 27.19], grade:['C3','D4'] },
      // AIR
      { cat:'air', src:'OpenSky',    hl:'Strategic lift transit · IL‑76 squadron movement',    loc:'RUS · Pskov AB',            ll:[57.79, 28.40], grade:['A1','B2'] },
      { cat:'air', src:'OpenSky',    hl:'A‑50 AEW orbit detected · Belarus airspace',          loc:'BLR · Machulishchy',        ll:[53.77, 27.54], grade:['A2','B2'] },
      { cat:'air', src:'radar',      hl:'Squawk anomaly · transponder loss · 3 contacts',      loc:'POL · NE FIR',              ll:[53.50, 23.00], grade:['B2','C3'] },
      { cat:'air', src:'OpenSky',    hl:'Civil traffic divert · NOTAM activated',              loc:'EE · Tallinn FIR',          ll:[59.40, 24.80], grade:['A1','B2'] },
      { cat:'air', src:'radar',      hl:'Bomber proximity track · Tu‑22M3 corridor',           loc:'RUS · Soltsy AB',           ll:[58.14, 30.33], grade:['B2','C3'] },
      { cat:'air', src:'OpenSky',    hl:'NATO E‑3 AWACS orbit · Black Sea sector',             loc:'ROU · Constanța',           ll:[44.18, 28.66], grade:['A1','A2'] },
      // MARITIME
      { cat:'mar', src:'AIS',        hl:'AIS spoofing pattern · 4 vessels under shadow',       loc:'Black Sea · Bosphorus E',   ll:[43.50, 30.00], grade:['B2','C3'] },
      { cat:'mar', src:'AIS',        hl:'Anchor cluster anomaly · cable corridor adjacent',    loc:'Baltic · Hel approach',     ll:[54.61, 18.81], grade:['B3','C3'] },
      { cat:'mar', src:'sat',        hl:'Sentinel‑1 SAR · naval movement Sevastopol',          loc:'Crimea · Sevastopol',       ll:[44.62, 33.55], grade:['A2','B2'] },
      { cat:'mar', src:'AIS',        hl:'Tanker shadow fleet · port call irregularity',        loc:'RUS · Ust‑Luga',            ll:[59.67, 28.40], grade:['B2','C3'] },
      // INFRASTRUCTURE
      { cat:'infra', src:'GDELT',    hl:'Power grid frequency excursion · interconnector',     loc:'LTU · Kruonis',             ll:[54.78, 24.46], grade:['A2','B2'] },
      { cat:'infra', src:'social',   hl:'Submarine cable disturbance reported',                loc:'FIN · Inkoo landing',       ll:[60.05, 24.00], grade:['B3','C3'] },
      { cat:'infra', src:'sat',      hl:'Pipeline pressure anomaly · cross‑border segment',    loc:'POL · PL/UA',               ll:[50.43, 23.83], grade:['B2','C3'] },
      { cat:'infra', src:'GDELT',    hl:'Substation incident · capital ring',                  loc:'UA · Kyiv ring',            ll:[50.50, 30.40], grade:['A2','B2'] },
      { cat:'infra', src:'GDELT',    hl:'Rail signalling fault · East–West corridor',          loc:'ROU · Bucharest hub',       ll:[44.43, 26.10], grade:['C3','D4'] },
      { cat:'infra', src:'sat',      hl:'Refinery flare cluster · industrial alert',           loc:'RUS · Saratov rear',        ll:[51.48, 46.21], grade:['B2','C3'] },
      // INFO ENVIRONMENT
      { cat:'info', src:'Telegram',  hl:'Narrative push · staged provocation framing',         loc:'BLR · channels',            ll:[53.90, 27.57], grade:['C3','D4'] },
      { cat:'info', src:'social',    hl:'Coordinated bot amplification · capital protests',    loc:'MDA · Chișinău',            ll:[47.00, 28.84], grade:['C3','D4'] },
      { cat:'info', src:'GDELT',     hl:'State media tonal shift · escalation indicator',      loc:'RUS · domestic',            ll:[55.75, 37.62], grade:['B3','C3'] },
      { cat:'info', src:'social',    hl:'Deepfake artefact detected · senior official voice',  loc:'UA · info space',           ll:[50.45, 30.52], grade:['D4','E5'] }
    ];

    const feedStreamEl = document.getElementById('cvgFeedStream');
    const feedClockEl  = document.getElementById('cvgFeedClock');
    const feedPauseBtn = document.getElementById('cvgFeedPause');
    let feedPaused = false;
    let feedFilter = 'all';
    let feedRecent = []; // {time, cat, naiId} — last 90s for fusion detection

    function tickClock() {
      const now = new Date();
      const z = (n) => String(n).padStart(2,'0');
      const t = z(now.getUTCHours()) + ':' + z(now.getUTCMinutes()) + ':' + z(now.getUTCSeconds()) + ' UTC';
      if (feedClockEl) feedClockEl.textContent = t;
    }
    tickClock();
    setInterval(tickClock, 1000);

    function pickGrade(template) {
      // Mode tilts grade distribution: war → more A/B (high reliability fast reporting), peace → more C/D
      const pool = template.grade.slice();
      if (window.cvgMode === 'conflict') pool.unshift('A1','A2');
      if (window.cvgMode === 'crisis')pool.push('C3');
      if (window.cvgMode === 'peace') pool.push('D4','E5');
      return pool[Math.floor(Math.random() * pool.length)];
    }

    function whichNAI(lat, lng) {
      // Returns first matching area id (NAI or TAI), or null
      for (const a of NAI_TAI) {
        const [[la1, lo1], [la2, lo2]] = a.bbox;
        if (lat >= Math.min(la1,la2) && lat <= Math.max(la1,la2) &&
            lng >= Math.min(lo1,lo2) && lng <= Math.max(lo1,lo2)) {
          return a;
        }
      }
      return null;
    }

    function addFeedRow(payload) {
      if (!feedStreamEl) return;
      const row = document.createElement('div');
      row.className = 'cvg-feed-row' + (payload.fusion ? ' fusion' : '');
      row.dataset.cat = payload.cat || 'all';
      const t = payload.time || new Date();
      const ts = String(t.getUTCHours()).padStart(2,'0') + ':' + String(t.getUTCMinutes()).padStart(2,'0') + ':' + String(t.getUTCSeconds()).padStart(2,'0');
      const grade = payload.grade || 'C3';
      const gradeLetter = grade[0];
      const naiHit = payload.naiHit
        ? '<span class="nai-hit' + (payload.naiHit.kind==='tai' ? ' tai' : '') + '">' + payload.naiHit.id + '</span>'
        : '';
      row.innerHTML = (
        '<span class="ts">' + ts + '</span>' +
        '<span class="src s-' + payload.srcKey + '">' + payload.srcLabel + '</span>' +
        '<span class="head">' +
          '<span class="h1">' + payload.hl + naiHit + '</span>' +
          '<span class="h2">' + (payload.sub || payload.cat.toUpperCase()) + '</span>' +
        '</span>' +
        '<span class="loc">' + payload.loc + '</span>' +
        '<span class="grade g-' + gradeLetter + '" title="' + (window.admTip?window.admTip(grade):'') + '">' + grade + '</span>'
      );
      // Apply current filter
      if (feedFilter !== 'all' && payload.cat !== feedFilter && !payload.fusion) {
        row.style.display = 'none';
      }
      // Priority by category severity (reliability is the Admiralty grade)
      var PRIO = { armed:'P1', cyber:'P1', air:'P1', hybrid:'P2', infra:'P2', mar:'P2', info:'P3', mil:'P3' };
      var prio = payload.fusion ? 'P1' : (PRIO[payload.cat] || 'P3');
      row.dataset.prio = prio;
      feedStreamEl.prepend(row);
      // Cap stream length
      while (feedStreamEl.children.length > 40) {
        feedStreamEl.removeChild(feedStreamEl.lastChild);
      }
      dropFeedPin(payload, grade, ts, prio);
    }

    function dropFeedPin(payload, grade, ts, prio){
      if (!payload || !payload.ll || typeof L === 'undefined' || !cvgRegionMap) return;
      if (!document.getElementById('cvgFeedPinCSS')){
        var st=document.createElement('style'); st.id='cvgFeedPinCSS'; st.textContent=
          '.cvg-feed-pin .fp{display:block;width:14px;height:14px;border-radius:50%;background:var(--fc);box-shadow:0 0 0 3px color-mix(in srgb,var(--fc) 22%,transparent),0 0 9px var(--fc);}'+
          '.cvg-fp-popwrap .leaflet-popup-content-wrapper{background:var(--paper);color:var(--ink);border:1px solid var(--line);border-radius:12px;box-shadow:0 18px 40px -22px rgba(8,16,34,.5);}'+
          '.cvg-fp-popwrap .leaflet-popup-content{margin:12px 14px;}.cvg-fp-popwrap .leaflet-popup-tip{background:var(--paper);border:1px solid var(--line);}'+
          '.cvg-fp-pop{min-width:232px;font-family:inherit;}'+
          '.cvg-fp-pop .ph{display:flex;align-items:center;gap:7px;margin-bottom:6px;}'+
          '.cvg-fp-pop .pr{font-family:\'JetBrains Mono\',monospace;font-size:9px;font-weight:800;color:#fff;background:var(--fc);padding:2px 7px;border-radius:5px;}'+
          '.cvg-fp-pop .cat{font-size:12px;font-weight:800;color:var(--ink);}'+
          '.cvg-fp-pop .gr{margin-left:auto;font-family:\'JetBrains Mono\',monospace;font-size:8.5px;color:var(--muted);}'+
          '.cvg-fp-pop .hl{font-size:12.5px;font-weight:700;color:var(--ink);line-height:1.3;margin-bottom:8px;}'+
          '.cvg-fp-pop .w5{display:flex;flex-direction:column;gap:3px;margin-bottom:8px;}'+
          '.cvg-fp-pop .w5>div{display:grid;grid-template-columns:42px 1fr;gap:8px;font-size:11px;line-height:1.35;}'+
          '.cvg-fp-pop .w5 b{font-family:\'JetBrains Mono\',monospace;font-size:8.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted);}'+
          '.cvg-fp-pop .w5 span{color:var(--ink-2);}'+
          '.cvg-fp-pop .bluf{font-size:11px;line-height:1.4;color:var(--ink);border-top:1px solid var(--line);padding-top:7px;}'+
          '.cvg-fp-pop .bluf b{font-family:\'JetBrains Mono\',monospace;font-size:8.5px;letter-spacing:.1em;color:var(--fc);margin-right:6px;}'+
          '.cvg-fp-pop .rel{margin-top:6px;font-family:\'JetBrains Mono\',monospace;font-size:8.5px;color:var(--muted);}'+
          '.cvg-feed-row[data-prio="P1"]{box-shadow:inset 3px 0 0 #DC2626;}.cvg-feed-row[data-prio="P2"]{box-shadow:inset 3px 0 0 #F59E0B;}.cvg-feed-row[data-prio="P3"]{box-shadow:inset 3px 0 0 #64748B;}';
        document.head.appendChild(st);
      }
      if (!window.__cvgFeedLayer){ try{ window.__cvgFeedLayer = L.layerGroup().addTo(cvgRegionMap); }catch(e){ return; } }
      if (!window.__cvgFeedPins) window.__cvgFeedPins = [];
      var PC = { P1:'#DC2626', P2:'#F59E0B', P3:'#64748B' }, col = PC[prio] || '#64748B';
      var CATL = {armed:'Armed conflict',hybrid:'Hybrid',cyber:'Cyber',air:'Air',mar:'Maritime',infra:'Infrastructure',info:'Information',mil:'Military'};
      var WHY = {armed:'Kinetic activity affecting the civil environment.',hybrid:'Sub\u2011threshold coercion \u2014 deniable by design.',cyber:'Disruption of state / critical\u2011service continuity.',air:'Air activity altering the recognised air picture.',mar:'Risk to sea lines & undersea infrastructure.',infra:'Stress on critical infrastructure \u2014 cascade potential.',info:'Information\u2011environment manipulation.',mil:'Force posture / movement signalling intent.'};
      var BLUF = {armed:'Localised kinetic event \u2014 watch for escalation.',hybrid:'Deniable pressure \u2014 expect continuation.',cyber:'Service\u2011continuity risk \u2014 contain & harden.',air:'Readiness signal \u2014 reconcile with NOTAMs.',mar:'SLOC / seabed risk \u2014 correlate AIS gaps.',infra:'Cascade risk \u2014 verify & pre\u2011position.',info:'Perception\u2011shaping \u2014 pre\u2011bunk & monitor.',mil:'Posture change \u2014 confirm intent vs routine.'};
      var REL = {A:'completely reliable',B:'usually reliable',C:'fairly reliable',D:'not usually reliable',E:'unreliable',F:'unverified'};
      var icon = L.divIcon({ className:'cvg-feed-pin', html:'<span class="fp" style="--fc:'+col+'"></span>', iconSize:[14,14], iconAnchor:[7,7] });
      var m = L.marker(payload.ll, { icon:icon, riseOnHover:true }).addTo(window.__cvgFeedLayer);
      var html = '<div class="cvg-fp-pop" style="--fc:'+col+'">'+
        '<div class="ph"><span class="pr">'+prio+'</span><span class="cat">'+(CATL[payload.cat]||payload.cat)+'</span><span class="gr">'+payload.srcLabel+' \u00b7 '+grade+'</span></div>'+
        '<div class="hl">'+payload.hl+'</div>'+
        '<div class="w5"><div><b>Who</b><span>'+payload.srcLabel+' \u00b7 '+(CATL[payload.cat]||'')+'</span></div>'+
        '<div><b>What</b><span>'+payload.hl+'</span></div>'+
        '<div><b>When</b><span>'+ts+' UTC</span></div>'+
        '<div><b>Where</b><span>'+payload.loc+'</span></div>'+
        '<div><b>Why</b><span>'+(WHY[payload.cat]||'')+'</span></div></div>'+
        '<div class="bluf"><b>BLUF</b>'+(BLUF[payload.cat]||'')+'</div>'+
        '<div class="rel">Reliability \u00b7 '+grade+' \u2014 '+(REL[grade[0]]||'')+'</div>'+
        '</div>';
      m.bindPopup(html, { className:'cvg-fp-popwrap', maxWidth:300 });
      window.__cvgFeedPins.push(m);
      while (window.__cvgFeedPins.length > 18){ var oldp = window.__cvgFeedPins.shift(); try{ window.__cvgFeedLayer.removeLayer(oldp); }catch(e){} }
    }

    function emitFeedEvent() {
      if (feedPaused) return;
      // Tilt selection by mode: war emphasises armed/air/cyber; crisis adds hybrid/infra; peace tilts info/mar
      const all = FEED_TEMPLATES;
      const weights = {
        peace:    { armed:1, hybrid:2, cyber:2, air:3, mar:3, infra:2, info:3 },
        crisis:   { armed:3, hybrid:4, cyber:4, air:4, mar:3, infra:4, info:3 },
        conflict: { armed:6, hybrid:3, cyber:5, air:6, mar:3, infra:4, info:2 }
      }[window.cvgMode || 'peace'];
      // weighted pool
      const pool = [];
      all.forEach(t => { for (let i = 0; i < (weights[t.cat] || 1); i++) pool.push(t); });
      const tmpl = pool[Math.floor(Math.random() * pool.length)];

      const srcMap = {
        'ACLED':'acled','GDELT':'gdelt','OpenSky':'opensky','AIS':'ais','sat':'sat',
        'social':'soc','Telegram':'tg','radar':'radar','sigint':'sigint'
      };
      const grade = pickGrade(tmpl);
      const naiHit = whichNAI(tmpl.ll[0], tmpl.ll[1]);
      const payload = {
        time: new Date(),
        cat: tmpl.cat,
        ll: tmpl.ll,
        srcKey: srcMap[tmpl.src] || 'gdelt',
        srcLabel: tmpl.src,
        hl: tmpl.hl,
        loc: tmpl.loc,
        grade,
        naiHit,
        sub: tmpl.cat.toUpperCase() + ' · ' + (tmpl.src.toUpperCase())
      };
      addFeedRow(payload);
      // Bump NAI activity counter for area hits
      if (naiHit) {
        window.cvgNaiBump(tmpl.ll[0], tmpl.ll[1], 1);
        feedRecent.push({ time: Date.now(), cat: tmpl.cat, naiId: naiHit.id, srcKey: payload.srcKey });
      }
      // Trim feedRecent to last 90s
      const cutoff = Date.now() - 90000;
      feedRecent = feedRecent.filter(r => r.time >= cutoff);
      // Check for cross‑source fusion: ≥3 events in same NAI within window from ≥2 distinct sources
      const byNai = {};
      feedRecent.forEach(r => {
        (byNai[r.naiId] = byNai[r.naiId] || []).push(r);
      });
      Object.entries(byNai).forEach(([naiId, arr]) => {
        const distinctSrc = new Set(arr.map(r => r.srcKey));
        if (arr.length >= 3 && distinctSrc.size >= 2) {
          // Emit fusion once per cluster — flush feedRecent for that NAI
          const area = NAI_TAI.find(a => a.id === naiId);
          if (!area) return;
          const fusionGrade = (window.cvgMode === 'conflict') ? 'A1' : (window.cvgMode === 'crisis') ? 'B2' : 'B3';
          addFeedRow({
            time: new Date(),
            cat: 'fusion',
            srcKey: 'fusion',
            srcLabel: 'FUSION',
            hl: 'COMPOSITE INDICATOR · ' + arr.length + ' signals · ' + distinctSrc.size + ' sources converge on ' + area.id,
            sub: 'CROSS‑SOURCE FUSION · ' + area.name.toUpperCase(),
            loc: area.name,
            grade: fusionGrade,
            naiHit: area,
            fusion: true
          });
          // Visual ping on rect
          if (naiRects[naiId]) {
            const r = naiRects[naiId].rect;
            r.setStyle({ weight: 3.5 });
            setTimeout(() => {
              if (window.cvgMode === 'conflict') r.setStyle({ weight: area.kind==='tai'?2.5:2 });
              else if (window.cvgMode === 'crisis') r.setStyle({ weight: area.kind==='tai'?2:1.5 });
              else r.setStyle({ weight: 1.5 });
            }, 1200);
          }
          // Notify subscribers (Cascade panel etc.)
          document.dispatchEvent(new CustomEvent('cvg:fusion', { detail: { naiId, naiKind: area.kind, naiName: area.name, signals: arr.length, sources: distinctSrc.size } }));
          // Clear so we don't re-emit immediately
          feedRecent = feedRecent.filter(r => r.naiId !== naiId);
        }
      });
    }

    // Pace by mode
    let feedTimer = null;
    function startFeed() {
      if (feedTimer) clearTimeout(feedTimer);
      const next = () => {
        emitFeedEvent();
        const base = (window.cvgMode === 'conflict') ? 1400 : (window.cvgMode === 'crisis') ? 2400 : 4200;
        const jitter = base * 0.6;
        feedTimer = setTimeout(next, base + Math.random() * jitter);
      };
      feedTimer = setTimeout(next, 700);
    }
    startFeed();

    // Re-pace on mode change
    document.addEventListener('cvg:mode', () => { if (!feedPaused) startFeed(); });

    // Filter handler
    document.querySelectorAll('[data-cvg-feed-filter] [data-cvg-feed-f]').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('[data-cvg-feed-filter] [data-cvg-feed-f]').forEach(b => b.classList.toggle('on', b === btn));
        feedFilter = btn.dataset.cvgFeedF;
        Array.from(feedStreamEl.children).forEach(row => {
          const isFusion = row.classList.contains('fusion');
          if (feedFilter === 'all' || row.dataset.cat === feedFilter || isFusion) {
            row.style.display = '';
          } else {
            row.style.display = 'none';
          }
        });
      });
    });

    // Pause handler
    feedPauseBtn?.addEventListener('click', () => {
      feedPaused = !feedPaused;
      feedPauseBtn.classList.toggle('paused', feedPaused);
      feedPauseBtn.innerHTML = feedPaused
        ? '<svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><polygon points="6,4 20,12 6,20"/></svg> RESUME'
        : '<svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg> PAUSE';
      if (!feedPaused) startFeed();
    });

    // Seed: emit a few events immediately so the feed isn't empty
    for (let i = 0; i < 5; i++) setTimeout(emitFeedEvent, 60 + i * 220);

    // ════════════ PATTERN OF LIFE (PoL) BASELINE ════════════
    // Each site has a baseline activity profile (14 half-day buckets, 7d).
    // Current state vs baseline → delta %. Anomaly when delta > 35%.
    const POL_SITES = [
      { id:'soltsy',     name:'Soltsy AB',           type:'LRA bomber base · Tu‑22M3', ll:[58.14, 30.33], baseline:[42,38,45,40,44,39,46,41,43,40,44,38,42,40], live:[42,38,45,40,44,39,46,41,43,40,48,52,71,84] },
      { id:'machulish',  name:'Machulishchy AB',     type:'A‑50 AEW · BLR',            ll:[53.77, 27.54], baseline:[28,25,30,27,29,26,31,28,30,27,29,26,28,27], live:[28,25,30,27,29,26,31,28,30,27,29,58,62,55] },
      { id:'kgd-sam',    name:'Gvardeysk S‑400',     type:'KGD SAM · IADS',            ll:[54.65, 21.06], baseline:[55,50,58,52,56,51,59,53,57,52,56,50,55,53], live:[55,50,58,52,56,51,59,53,57,52,56,50,55,53] },
      { id:'sevastopol', name:'Sevastopol naval',    type:'Black Sea Fleet HQ',        ll:[44.62, 33.55], baseline:[60,55,62,58,61,56,63,59,62,57,61,55,60,58], live:[60,55,62,58,61,56,63,59,62,57,69,76,82,88] },
      { id:'pskov',      name:'Pskov VDV AB',        type:'Strategic lift · IL‑76',    ll:[57.79, 28.40], baseline:[48,44,50,46,49,45,51,47,50,46,49,44,48,46], live:[48,44,50,46,49,45,51,47,50,46,49,44,48,46] },
      { id:'cable-fin',  name:'C‑Lion1 landing',     type:'Cable · Helsinki–Rostock',  ll:[60.15, 24.87], baseline:[12,10,13,11,12,10,13,11,12,10,13,11,12,10], live:[12,10,13,11,12,10,13,11,12,10,8,5,3,2] },
      { id:'kyiv-grid',  name:'Kyiv ring substation',type:'Critical infra · UA',       ll:[50.50, 30.40], baseline:[35,32,36,33,35,32,37,34,36,33,35,32,35,33], live:[35,32,36,33,35,32,37,34,36,33,48,62,71,79] }
    ];
    function calcDelta(baseline, live) {
      const tail = (arr) => arr.slice(-2).reduce((s,n) => s+n, 0) / 2;
      const b = tail(baseline), l = tail(live);
      if (b === 0) return 0;
      return Math.round(((l - b) / b) * 100);
    }
    function renderPolList() {
      const el = document.getElementById('cvgPolList');
      if (!el) return;
      const max = Math.max(...POL_SITES.flatMap(s => s.live.concat(s.baseline)), 1);
      const items = POL_SITES.map(s => {
        const delta = calcDelta(s.baseline, s.live);
        const cls = delta > 20 ? 'up' : delta < -20 ? 'down' : 'flat';
        const sign = delta > 0 ? '+' : '';
        const bars = s.live.map((v, i) => {
          const h = Math.max(2, Math.round((v / max) * 22));
          const baseV = s.baseline[i] || 0;
          const over = v > baseV * 1.35;
          return `<span class="b${over?' over':''}" style="height:${h}px"></span>`;
        }).join('');
        return (
          '<div class="cvg-pol-row" data-cvg-pol="' + s.id + '">' +
            '<span class="meta">' + s.name + '<span class="ty">' + s.type + '</span></span>' +
            '<span class="cvg-pol-spark">' + bars + '</span>' +
            '<span class="delta ' + cls + '">' + sign + delta + '%</span>' +
          '</div>'
        );
      }).join('');
      el.innerHTML = items;
      // Click → fly to site
      el.querySelectorAll('[data-cvg-pol]').forEach(r => {
        r.addEventListener('click', () => {
          const s = POL_SITES.find(x => x.id === r.dataset.cvgPol);
          if (s && cvgRegionMap) cvgRegionMap.flyTo(s.ll, 7, { duration: 0.9 });
        });
      });
      // Anomaly count (delta > 35%)
      const anomCount = POL_SITES.filter(s => Math.abs(calcDelta(s.baseline, s.live)) > 35).length;
      const ce = document.getElementById('cvgPolAnomCount');
      if (ce) ce.textContent = anomCount;
    }
    renderPolList();
    // Re-render when mode changes — tilt anomaly intensity
    document.addEventListener('cvg:mode', (ev) => {
      const mode = ev.detail.mode;
      POL_SITES.forEach(s => {
        // Restore baseline, then add mode-driven uplift to live tail
        const tail = 4;
        for (let i = 0; i < tail; i++) {
          const idx = s.live.length - 1 - i;
          const base = s.baseline[idx] || 30;
          let uplift = 1.0;
          if (mode === 'crisis') uplift = (s.id === 'kgd-sam' || s.id === 'pskov') ? 1.05 : 1.3;
          else if (mode === 'conflict') uplift = 1.8 + Math.random() * 0.5;
          // Random sites stay quiet to avoid global red
          if (s.id === 'kgd-sam' && mode !== 'conflict') uplift = 1.0;
          if (s.id === 'pskov' && mode === 'peace') uplift = 1.0;
          s.live[idx] = Math.round(base * uplift);
        }
      });
      renderPolList();
    });

    // ════════════ CASCADE PREDICTION ════════════
    const CASCADES = {
      cable: {
        trigger: 'C‑Lion1 submarine cable disturbance · Helsinki–Rostock',
        l2: [
          { blr:'COMMS',   txt:'FICIX ↔ MSK / DECIX routing failover · 8–14 ms added latency Nordic ↔ DE' },
          { blr:'COMMS',   txt:'Baltic DC traffic re‑homes via SE / DK · Tallinn IX load +35%' },
          { blr:'TRUST',   txt:'Public attribution noise · social amplification of sabotage narrative' }
        ],
        l3: [
          { blr:'GOV',     txt:'Continuity‑of‑government dashboards flag degraded telework links' },
          { blr:'ECON',    txt:'Banking latency · payment settlement windows reschedule' },
          { blr:'STRAT',   txt:'NATO maritime patrol uplift across Baltic cable corridor' }
        ]
      },
      'kgd-sam': {
        trigger: 'Kaliningrad S‑400 ring activation · TAI‑A',
        l2: [
          { blr:'AIR',     txt:'Civil traffic NOTAM expanded · 2 corridors re‑routed S‑bound' },
          { blr:'INFO',    txt:'State‑media tonal shift · escalation framing' },
          { blr:'STRAT',   txt:'NATO eAP scramble posture raised at Ämari / Šiauliai / Powidz' }
        ],
        l3: [
          { blr:'ECON',    txt:'Airline fuel cost spike · Baltic regional carriers' },
          { blr:'POP',     txt:'Public anxiety telemetry · Baltic capitals' },
          { blr:'GOV',     txt:'EUCOM consult triggered · ambassadors recalled to brief' }
        ]
      },
      suwalki: {
        trigger: 'Suwałki Gap · cross‑border activity surge · NAI‑01',
        l2: [
          { blr:'TRANS',   txt:'Rail / road throughput stress · LT ↔ PL corridor' },
          { blr:'BORDER',  txt:'Irregular migration vector amplification · BLR push' },
          { blr:'INFO',    txt:'Coordinated Telegram channels surge — staged provocation framing' }
        ],
        l3: [
          { blr:'GOV',     txt:'Schengen consultations · interior ministers cluster call' },
          { blr:'STRAT',   txt:'NATO eFP rotational lift accelerated · POL & LT' },
          { blr:'POP',     txt:'Displacement spike modelled · 12–18 k over 72 h' }
        ]
      },
      'black-sea': {
        trigger: 'Black Sea AIS spoof cluster · TAI‑B vicinity',
        l2: [
          { blr:'MAR',     txt:'Shipping insurance premium spike · Bosphorus exit lanes' },
          { blr:'GRAIN',   txt:'UA grain corridor throughput drop · 20–30%' },
          { blr:'MIL',     txt:'NATO E‑3 AWACS orbit over Constanța sector' }
        ],
        l3: [
          { blr:'ECON',    txt:'Global wheat futures +4–8% · MENA importers exposed' },
          { blr:'GOV',     txt:'EU food‑security cell convenes' },
          { blr:'INFO',    txt:'Disinfo campaign on grain weaponisation · multi‑language' }
        ]
      }
    };
    const CAS_SEV = { cable:{n:4,t:'HIGH'}, 'kgd-sam':{n:5,t:'SEVERE'}, suwalki:{n:4,t:'HIGH'}, 'black-sea':{n:3,t:'ELEVATED'} };
    function renderCascade(key) {
      const c = CASCADES[key];
      const frame = document.getElementById('cvgCascadeFrame');
      const tree = document.getElementById('cvgCasTree');
      const trigger = document.getElementById('cvgCasTriggerName');
      const badge = document.getElementById('cvgCasBadge');
      if (!c || !tree) return;
      trigger.textContent = c.trigger;
      const arrow = '<div class="cas-arrow"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v15M6 13l6 6 6-6"/></svg></div>';
      tree.innerHTML = (
        '<div class="cas-flow">' +
          arrow +
          '<div class="cas-band l2"><span class="lvl">2ND ORDER</span><span class="cas-ct">' + c.l2.length + ' effects</span></div>' +
          '<div class="effects">' + c.l2.map(e => '<div class="eff l2-eff"><span class="blr">'+e.blr+'</span><span>'+e.txt+'</span></div>').join('') + '</div>' +
          arrow +
          '<div class="cas-band l3"><span class="lvl">3RD ORDER</span><span class="cas-ct">' + c.l3.length + ' effects</span></div>' +
          '<div class="effects">' + c.l3.map(e => '<div class="eff l3-eff"><span class="blr">'+e.blr+'</span><span>'+e.txt+'</span></div>').join('') + '</div>' +
        '</div>'
      );
      const sev = CAS_SEV[key] || { n:3, t:'ELEVATED' };
      const mv = document.getElementById('cvgCasMeterV');
      if (mv) mv.textContent = sev.t;
      frame.querySelectorAll('.cas-meter-bar i').forEach((b,i) => b.classList.toggle('on', i < sev.n));
      frame.classList.add('active');
      badge.classList.add('hot');
      badge.innerHTML = '<span class="d"></span>FORECAST · ' + key.toUpperCase();
      document.querySelectorAll('[data-cvg-cas-scn]').forEach(b => {
        b.classList.toggle('on', b.dataset.cvgCasScn === key);
      });
    }
    document.querySelectorAll('[data-cvg-cas-scn]').forEach(btn => {
      btn.addEventListener('click', () => renderCascade(btn.dataset.cvgCasScn));
    });

    // Auto-bind cascade to fusion events — pick a scenario by NAI hit
    const NAI_TO_CASCADE = {
      'NAI-01': 'suwalki', 'NAI-08': 'suwalki',
      'NAI-02': 'kgd-sam', 'TAI-A':  'kgd-sam',
      'NAI-05': 'suwalki',
      'NAI-07': 'black-sea', 'TAI-B': 'black-sea', 'TAI-D': 'black-sea',
      'NAI-03': 'cable'
    };
    document.addEventListener('cvg:fusion', (ev) => {
      const key = NAI_TO_CASCADE[ev.detail.naiId] || 'cable';
      renderCascade(key);
    });

    // ════════════ TASKING BOARD ════════════
    const TASKS = [
      { id:'T-001', ref:'TAI-A', refKind:'tai', title:'Continuous watch · Kaliningrad SAM ring',     cell:'ISR Cell · NATO eAP',    prio:'P1', status:'Active' },
      { id:'T-002', ref:'NAI-05',refKind:'nai', title:'Transnistria hybrid pressure assessment',     cell:'CIMIC Cell · MDA desk',  prio:'P2', status:'Active' },
      { id:'T-003', ref:'NAI-01',refKind:'nai', title:'Suwałki Gap throughput · daily SITREP',       cell:'JLSG · POL/LT',          prio:'P2', status:'Active' },
      { id:'T-004', ref:'TAI-B', refKind:'tai', title:'Sevastopol naval movement · SAR tasking',     cell:'Maritime ISR Cell',      prio:'P1', status:'Active' },
      { id:'T-005', ref:'NAI-07',refKind:'nai', title:'Black Sea AIS anomaly · grain corridor watch',cell:'Maritime Cell · ROU',    prio:'P3', status:'Pending' }
    ];
    function renderTasks() {
      const el = document.getElementById('cvgTaskList');
      if (!el) return;
      el.innerHTML = TASKS.map(t => (
        '<div class="cvg-task-row">' +
          '<span class="code">' + t.id + '</span>' +
          '<span class="body">' +
            '<span class="ti"><span class="nai-ref' + (t.refKind==='tai'?' tai':'') + '">'+t.ref+'</span>'+t.title+'</span>' +
            '<span class="meta">' + t.cell + ' · <b>' + t.status.toUpperCase() + '</b></span>' +
          '</span>' +
          '<span class="prio ' + t.prio.toLowerCase() + '">' + t.prio + '</span>' +
        '</div>'
      )).join('');
      const active  = TASKS.filter(t => t.status === 'Active').length;
      const pending = TASKS.filter(t => t.status === 'Pending').length;
      document.getElementById('cvgTaskActive').textContent  = active;
      document.getElementById('cvgTaskPending').textContent = pending;
    }
    renderTasks();
    document.getElementById('cvgTaskAdd')?.addEventListener('click', () => {
      // Pick the hottest NAI/TAI (highest activity) and spawn a new task for it
      const hot = Object.entries(naiRects).sort((a,b) => b[1].activity - a[1].activity)[0];
      if (!hot) return;
      const [naiId, info] = hot;
      const n = (TASKS.length + 1).toString().padStart(3, '0');
      TASKS.unshift({
        id: 'T-' + n,
        ref: naiId, refKind: info.area.kind,
        title: 'Auto‑tasked watch · ' + info.area.name,
        cell: 'Auto · Connectus dispatch',
        prio: info.area.kind === 'tai' ? 'P1' : 'P2',
        status: 'Pending'
      });
      renderTasks();
    });

    // ════════════ INTEL PACK · printable export ════════════
    function buildIntelPack() {
      const mode = (window.cvgMode || 'peace').toUpperCase();
      const now = new Date();
      const ts = now.toISOString().replace('T',' ').replace(/\..+/,'') + ' UTC';
      // Top feed events (latest 12 visible non-fusion + 2 fusion)
      const rows = Array.from(document.querySelectorAll('#cvgFeedStream .cvg-feed-row')).slice(0, 14).map(r => ({
        ts:   r.querySelector('.ts')?.textContent || '',
        src:  r.querySelector('.src')?.textContent || '',
        hl:   r.querySelector('.h1')?.textContent || '',
        loc:  r.querySelector('.loc')?.textContent || '',
        grade:r.querySelector('.grade')?.textContent || '',
        fusion: r.classList.contains('fusion')
      }));
      // NAI/TAI activity snapshot
      const naiSnap = NAI_TAI.map(a => ({
        id: a.id, kind: a.kind, name: a.name,
        crit: a.crit, activity: naiRects[a.id]?.activity || 0
      })).sort((x,y) => y.activity - x.activity);
      // PoL anomalies
      const polSnap = POL_SITES.map(s => ({
        name: s.name, type: s.type, delta: calcDelta(s.baseline, s.live)
      })).sort((a,b) => Math.abs(b.delta) - Math.abs(a.delta));
      // Tasks
      const taskSnap = TASKS.slice();

      const naiRows = naiSnap.map(a => (
        '<tr><td><b>'+a.id+'</b></td><td>'+a.name+'</td><td>'+a.crit+'</td><td style="text-align:right;font-weight:700;color:'+(a.activity>=3?'#B91C1C':'#1f2937')+'">'+a.activity+'</td></tr>'
      )).join('');
      const polRows = polSnap.map(s => {
        const c = Math.abs(s.delta) > 35 ? '#B91C1C' : (Math.abs(s.delta) > 15 ? '#A16207' : '#166534');
        return '<tr><td>'+s.name+'</td><td>'+s.type+'</td><td style="text-align:right;font-weight:700;color:'+c+'">'+(s.delta>0?'+':'')+s.delta+'%</td></tr>';
      }).join('');
      const feedRows = rows.map(r => (
        '<tr class="'+(r.fusion?'fusion':'')+'"><td>'+r.ts+'</td><td>'+r.src+'</td><td>'+r.hl+'</td><td>'+r.loc+'</td><td style="text-align:center;font-weight:700">'+r.grade+'</td></tr>'
      )).join('');
      const taskRows = taskSnap.map(t => (
        '<tr><td><b>'+t.id+'</b></td><td>'+t.ref+'</td><td>'+t.title+'</td><td>'+t.cell+'</td><td style="text-align:center"><b>'+t.prio+'</b></td><td>'+t.status+'</td></tr>'
      )).join('');

      const modeColor = mode === 'CONFLICT' ? '#B91C1C' : mode === 'CRISIS' ? '#C2410C' : '#15803D';

      return `<!doctype html><html><head><meta charset="utf-8">
<title>Convergens · Intel Pack · ${ts}</title>
<style>
  *{box-sizing:border-box}
  body{font-family:Georgia,'Times New Roman',serif;color:#111;margin:0;padding:32px 40px;font-size:11pt;line-height:1.45;background:#fff}
  h1{font-family:'Helvetica Neue',Arial,sans-serif;font-size:22pt;letter-spacing:-0.02em;margin:0 0 4px}
  h2{font-family:'Helvetica Neue',Arial,sans-serif;font-size:13pt;letter-spacing:0.04em;margin:22px 0 8px;text-transform:uppercase;border-bottom:2px solid #111;padding-bottom:3px}
  .ribbon{display:inline-block;font-family:'Helvetica Neue',Arial,sans-serif;font-size:9pt;letter-spacing:0.18em;font-weight:800;text-transform:uppercase;padding:5px 12px;background:${modeColor};color:#fff;border-radius:2px}
  .meta{font-family:'Helvetica Neue',Arial,sans-serif;font-size:9pt;color:#555;letter-spacing:0.08em;margin-top:6px}
  table{width:100%;border-collapse:collapse;margin-top:4px;font-size:9.5pt}
  th{text-align:left;background:#f3f4f6;font-family:'Helvetica Neue',Arial,sans-serif;font-weight:700;font-size:8.5pt;letter-spacing:0.1em;text-transform:uppercase;padding:5px 8px;border-bottom:1.5px solid #111}
  td{padding:5px 8px;border-bottom:1px solid #e5e7eb;vertical-align:top}
  tr.fusion td{background:#fef2f2}
  .grid2{display:grid;grid-template-columns:1fr 1fr;gap:18px}
  .summary{font-style:italic;color:#374151;padding:10px 14px;border-left:3px solid #111;background:#f9fafb;margin:8px 0 16px}
  .footer{margin-top:30px;font-family:'Helvetica Neue',Arial,sans-serif;font-size:8pt;color:#6b7280;letter-spacing:0.08em;border-top:1px solid #d1d5db;padding-top:10px}
  @media print { body{padding:18mm 16mm} h2{break-after:avoid} table{break-inside:avoid} }
</style></head><body>
<div class="ribbon">${mode} MODE · DEFENSIVE · OSINT · NON‑KINETIC</div>
<h1>Convergens Intel Pack <span style="font-style:italic;font-weight:400;color:#555">— Eastern Flank corridor</span></h1>
<div class="meta">Generated ${ts} · Convergens AI · Conventity ecosystem · For institutional briefing</div>

<div class="summary">
  Bilateral civil resilience corridor across 7 blue‑force partners (FIN, EST, LVA, LTU, POL, ROU, UKR) and 3 OSINT‑monitored bordering states (RUS incl. KGD, BLR, MDA). Operating mode <b>${mode}</b>. Cross‑source fusion engine active across ACLED, GDELT, OpenSky, AIS, Sentinel, social, Telegram, sigint and radar feeds.
</div>

<h2>Live Intel Feed — top ${rows.length}</h2>
<table><thead><tr><th style="width:8%">UTC</th><th style="width:11%">Source</th><th>Headline</th><th style="width:22%">Location</th><th style="width:7%">Adm.</th></tr></thead><tbody>${feedRows}</tbody></table>

<div class="grid2">
  <div>
    <h2>Critical Areas (NAI / TAI)</h2>
    <table><thead><tr><th style="width:14%">Code</th><th>Name</th><th>Watch criteria</th><th style="width:14%">Signals</th></tr></thead><tbody>${naiRows}</tbody></table>
  </div>
  <div>
    <h2>Pattern of Life · anomalies</h2>
    <table><thead><tr><th>Site</th><th>Type</th><th style="width:18%">Δ vs 7d</th></tr></thead><tbody>${polRows}</tbody></table>
  </div>
</div>

<h2>Tasking · collection priorities</h2>
<table><thead><tr><th style="width:9%">Code</th><th style="width:10%">Area</th><th>Task</th><th style="width:22%">Cell</th><th style="width:7%">Prio</th><th style="width:10%">Status</th></tr></thead><tbody>${taskRows}</tbody></table>

<div class="footer">
  Convergens AI · Conventity · Civil‑Military Convergence Environment · Defensive · OSINT‑based · Non‑kinetic ·
  This pack is a snapshot of the live operational picture at generation time. Reliability per NATO Admiralty Code.
</div>

<script>setTimeout(function(){window.focus();window.print();},350);<\/script>
</body></html>`;
    }
    document.getElementById('cvgIntelPackBtn')?.addEventListener('click', () => {
      const html = buildIntelPack();
      const w = window.open('', '_blank', 'width=920,height=900');
      if (!w) {
        // Popup blocked — fall back to data URI download
        const blob = new Blob([html], { type: 'text/html' });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'convergens-intel-pack.html';
        a.click();
        return;
      }
      w.document.open(); w.document.write(html); w.document.close();
    });

    // Sync initial visual state with PEACE profile (hides NAI, shoot, dc; shows air/radar/sensor/field/net)
    applyMode('peace');

    // ════════════ FULLSCREEN ════════════
    // Both maps share one handler. Tries the Fullscreen API; falls back to a
    // fixed-position CSS class when the API is blocked (e.g. cross-origin iframe).
    function isInFs(el) {
      const fs = document.fullscreenElement || document.webkitFullscreenElement;
      return fs === el || el.classList.contains('cvg-fs-fallback');
    }
    function enterFs(el) {
      const req = el.requestFullscreen || el.webkitRequestFullscreen || el.msRequestFullscreen;
      if (req) {
        req.call(el).catch(() => el.classList.add('cvg-fs-fallback'));
      } else {
        el.classList.add('cvg-fs-fallback');
      }
    }
    function exitFs(el) {
      const exit = document.exitFullscreen || document.webkitExitFullscreen;
      if (document.fullscreenElement || document.webkitFullscreenElement) {
        exit && exit.call(document);
      } else {
        el.classList.remove('cvg-fs-fallback');
      }
    }
    function refreshMapsAfterFs() {
      // Give the browser a tick to apply layout, then tell maps to redraw.
      setTimeout(() => {
        if (cvgRegionMap) cvgRegionMap.invalidateSize();
        if (cvgEventMap && typeof cvgEventMap.resize === 'function') cvgEventMap.resize();
      }, 120);
      setTimeout(() => {
        if (cvgRegionMap) cvgRegionMap.invalidateSize();
        if (cvgEventMap && typeof cvgEventMap.resize === 'function') cvgEventMap.resize();
      }, 420);
    }
    function updateFsBtnState() {
      document.querySelectorAll('[data-cvg-fs-target]').forEach(btn => {
        const tgt = document.querySelector(btn.dataset.cvgFsTarget);
        if (!tgt) return;
        btn.classList.toggle('is-fs', isInFs(tgt));
      });
    }
    document.addEventListener('click', (ev) => {
      const btn = ev.target.closest('[data-cvg-fs-target]');
      if (!btn) return;
      const tgt = document.querySelector(btn.dataset.cvgFsTarget);
      if (!tgt) return;
      if (isInFs(tgt)) exitFs(tgt); else enterFs(tgt);
      // Reflect state after a tick (fullscreenchange will also re-sync).
      setTimeout(updateFsBtnState, 60);
      refreshMapsAfterFs();
    });
    // Zoom +/− buttons (custom cluster — leaflet zoomControl & maplibre nav are hidden)
    document.addEventListener('click', (ev) => {
      const btn = ev.target.closest('[data-cvg-zoom]');
      if (!btn) return;
      const which = btn.dataset.cvgMap;
      const dir   = btn.dataset.cvgZoom;
      if (which === 'region' && cvgRegionMap) {
        // Disable Leaflet's zoom animation — it stalls in this embed context.
        dir === 'in'
          ? cvgRegionMap.zoomIn(1,  { animate: false })
          : cvgRegionMap.zoomOut(1, { animate: false });
      } else if (which === 'world' && cvgEventMap) {
        dir === 'in'
          ? cvgEventMap.zoomIn({ duration: 200 })
          : cvgEventMap.zoomOut({ duration: 200 });
      }
    });
    document.addEventListener('fullscreenchange',       () => { updateFsBtnState(); refreshMapsAfterFs(); });
    document.addEventListener('webkitfullscreenchange', () => { updateFsBtnState(); refreshMapsAfterFs(); });
    // ESC fallback for the .cvg-fs-fallback class path
    document.addEventListener('keydown', (ev) => {
      if (ev.key !== 'Escape') return;
      document.querySelectorAll('.cvg-fs-fallback').forEach(el => el.classList.remove('cvg-fs-fallback'));
      updateFsBtnState();
      refreshMapsAfterFs();
    });

    updateAirCount();
    setInterval(updateAirCount, 4000);

    } /* end region map (Conventlab) */

    // ----- OSINT WORLD MAP (MapLibre · Convergens) -----
    const worldEl = document.getElementById('cvgWorldMap');
    if (worldEl && typeof maplibregl !== 'undefined') {
      const buildStyle = (variant) => ({
        version: 8,
        sources: {
          'carto': {
            type: 'raster',
            tiles: ['a','b','c','d'].map(s => 'https://' + s + '.basemaps.cartocdn.com/' + variant + '/{z}/{x}/{y}.png'),
            tileSize: 256,
            attribution: '© OSM · © CARTO'
          }
        },
        layers: [{ id: 'carto', type: 'raster', source: 'carto' }]
      });
      const isDarkNow = document.documentElement.dataset.theme === 'dark';
      try {
        cvgEventMap = new maplibregl.Map({
          container: worldEl,
          style: buildStyle(isDarkNow ? 'dark_all' : 'light_all'),
          center: [22, 25],
          zoom: 1.1,
          minZoom: 0.5, maxZoom: 12,
          attributionControl: { compact: true },
          projection: { type: 'globe' }
        });
        // Built-in zoom/compass nav replaced by the custom map-controls cluster below the map.
        // cvgEventMap.addControl(new maplibregl.NavigationControl({ visualizePitch: false }), 'top-right');
        cvgEventMap.__buildStyle = buildStyle;
        window.cvgEventMap = cvgEventMap;
        // ── Auto-rotation when in globe mode ──
        let rotating = false;            // auto-rotation OFF — keep pins anchored & stable
        let userPauseUntil = 0;          // ms timestamp — pause rotation until this
        const ROTATE_DEG_PER_SEC = 3.5;   // slow institutional spin
        let lastTs = performance.now();
        cvgEventMap.__rotate = {
          set: (v) => { rotating = v; },
          isOn: () => rotating,
          pauseFor: (ms) => { userPauseUntil = performance.now() + ms; }
        };
        function spinStep(now) {
          const dt = Math.min(0.1, (now - lastTs) / 1000);
          lastTs = now;
          if (rotating && now >= userPauseUntil && cvgEventMap) {
            const c = cvgEventMap.getCenter();
            cvgEventMap.jumpTo({ center: [c.lng - ROTATE_DEG_PER_SEC * dt, c.lat] });
          }
          requestAnimationFrame(spinStep);
        }
        // Pause rotation when user interacts
        ['mousedown','touchstart','wheel','dragstart','zoomstart'].forEach(ev => {
          cvgEventMap.on(ev, () => cvgEventMap.__rotate.pauseFor(8000));
        });
        cvgEventMap.on('load', () => {
          // Ensure globe projection is active (default 3D view)
          try { cvgEventMap.setProjection && cvgEventMap.setProjection({ type: 'globe' }); } catch(e) {}
          // Add atmospheric fog/sky for the globe (improves 3D feel)
          try {
            cvgEventMap.setFog && cvgEventMap.setFog({
              'horizon-blend': 0.04,
              'color': isDarkNow ? 'rgba(15,30,60,0.7)' : 'rgba(210,225,245,0.6)',
              'high-color': isDarkNow ? '#0a1224' : '#cfe0f5',
              'space-color': isDarkNow ? '#03050d' : '#eef3f9',
              'star-intensity': isDarkNow ? 0.15 : 0
            });
          } catch(e) { /* older MapLibre — no fog */ }

          Object.entries(cvgEvents).forEach(([k, e]) => {
            if (!e.ll) return;
            const el = document.createElement('div');
            el.className = 'cvg-event-marker';
            el.style.setProperty('--mc', e.c);
            el.innerHTML = '<span class="m-dot"></span><span class="m-tag">' + (e.lbl || k.toUpperCase()) + '</span>';
            if (e.cc) el.dataset.cc = e.cc;
            if (e.country) el.classList.add('cvg-country-node');
            el.addEventListener('click', (ev) => { ev.stopPropagation(); cvgShowEvent(k); });
            const marker = new maplibregl.Marker({ element: el, anchor: 'left' })
              .setLngLat([e.ll[1], e.ll[0]])
              .addTo(cvgEventMap);
            cvgEventMarkers[k] = marker;
          });
          refreshMarkerVisibility();
          // Kick off rotation loop after first paint
          lastTs = performance.now();
          requestAnimationFrame(spinStep);
        });
      } catch (err) {
        console.warn('MapLibre init failed', err);
      }
    }

    cvgMapsReady = true;
    refreshMarkerVisibility();
  }

  // Theme change → swap tile layers if maps already exist
  const themeObserver = new MutationObserver(() => {
    if (!cvgMapsReady) return;
    const url = tileUrl();
    if (cvgRegionTile) cvgRegionTile.setUrl(url);
    if (cvgEventMap && cvgEventMap.__buildStyle) {
      const isDarkNow = document.documentElement.dataset.theme === 'dark';
      try {
        cvgEventMap.setStyle(cvgEventMap.__buildStyle(isDarkNow ? 'dark_all' : 'light_all'), { diff: false });
        // Re-apply globe atmosphere after style swap
        cvgEventMap.once('styledata', () => {
          try {
            cvgEventMap.setFog && cvgEventMap.setFog({
              'horizon-blend': 0.04,
              'color': isDarkNow ? 'rgba(15,30,60,0.7)' : 'rgba(210,225,245,0.6)',
              'high-color': isDarkNow ? '#0a1224' : '#cfe0f5',
              'space-color': isDarkNow ? '#03050d' : '#eef3f9',
              'star-intensity': isDarkNow ? 0.15 : 0
            });
          } catch(e) {}
        });
      } catch(e) { console.warn('style swap failed', e); }
    }
  });
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

  // ── LIVE TIMESTAMP STAMPS (AI feel) ──
  function fmtUtcTime(d) {
    const hh = String(d.getUTCHours()).padStart(2,'0');
    const mm = String(d.getUTCMinutes()).padStart(2,'0');
    return `${hh}:${mm} UTC`;
  }
  function tickCvgLive() {
    const now = new Date();
    const t = fmtUtcTime(now);
    cvg.querySelectorAll('[data-cvg-live]').forEach(el => {
      // Preserve any trailing static suffix after a · separator
      const txt = el.textContent || '';
      const idx = txt.indexOf('·');
      const suffix = idx >= 0 ? txt.slice(idx) : '';
      el.textContent = (suffix ? `${t} ${suffix}` : t);
    });
  }
  tickCvgLive();
  setInterval(tickCvgLive, 30000);

  // ── AI PROMPT CONSOLE (Convergens AI) ──
  const promptText = document.getElementById('cvgPromptText');
  const promptSend = document.getElementById('cvgPromptSend');
  const promptOut  = document.getElementById('cvgPromptOut');
  const CVG_SYSTEM = `You are Convergens AI — a calm, institutional civil-military strategic analyst inside the Conventity ecosystem. You operate on OSINT, with a CIMIC, NATO 7BLR and Human Security mindset, focused on the Eastern Flank resilience corridor (Finland, Estonia, Latvia, Lithuania, Poland, Romania). Tone: institutional, defensive, non-kinetic, never alarmist. Format answers as short, structured bullets unless the user requests prose. Acknowledge uncertainty. Never reveal you are Claude or any underlying model.`;
  async function askConvergensAI(prompt) {
    if (!prompt || !prompt.trim()) return;
    if (!window.claude || typeof window.claude.complete !== 'function') {
      promptOut.classList.remove('loading');
      promptOut.textContent = 'AI is offline in this preview.';
      return;
    }
    promptOut.classList.add('loading');
    promptOut.textContent = 'Convergens AI thinking';
    promptSend.disabled = true;
    try {
      const result = await window.claude.complete({
        messages: [
          { role: 'user', content: `${CVG_SYSTEM}\n\n— User question —\n${prompt}` }
        ]
      });
      promptOut.classList.remove('loading');
      promptOut.textContent = (result || '').toString().trim();
    } catch (err) {
      promptOut.classList.remove('loading');
      promptOut.textContent = 'Convergens AI is briefly unavailable.';
    } finally {
      promptSend.disabled = false;
    }
  }
  if (promptSend) {
    promptSend.addEventListener('click', () => askConvergensAI(promptText.value));
  }
  if (promptText) {
    promptText.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        askConvergensAI(promptText.value);
      }
    });
    promptText.addEventListener('input', () => {
      promptText.style.height = 'auto';
      promptText.style.height = Math.min(promptText.scrollHeight, 120) + 'px';
    });
  }
  // ── 2D / 3D MODE TOGGLE (MapLibre projection) ──
  cvg.querySelectorAll('[data-cvg-mode-control] [data-cvg-mode]').forEach(b => {
    b.addEventListener('click', () => {
      const mode = b.dataset.cvgMode;
      cvg.querySelectorAll('[data-cvg-mode-control] [data-cvg-mode]').forEach(x => x.classList.toggle('on', x === b));
      if (!cvgEventMap || typeof cvgEventMap.setProjection !== 'function') return;
      try {
        cvgEventMap.setProjection({ type: mode === '3d' ? 'globe' : 'mercator' });
      } catch(e) {
        try { cvgEventMap.setProjection(mode === '3d' ? 'globe' : 'mercator'); } catch(e2) {}
      }
      // Adjust framing for each projection + toggle rotation
      if (mode === '3d') {
        cvgEventMap.easeTo({ zoom: 1.1, center: [cvgEventMap.getCenter().lng, 25], duration: 800 });
        if (cvgEventMap.__rotate) cvgEventMap.__rotate.set(true);
      } else {
        cvgEventMap.easeTo({ zoom: 1.8, center: [22, 30], duration: 800 });
        if (cvgEventMap.__rotate) cvgEventMap.__rotate.set(false);
      }
    });
  });

  // ── World map view toggle (events / heat / timeline) — visual only ──
  cvg.querySelectorAll('.cvg-worldmap .map-meta [data-cvg-view]').forEach(b => {
    b.addEventListener('click', () => {
      cvg.querySelectorAll('.cvg-worldmap .map-meta [data-cvg-view]').forEach(x => x.classList.toggle('on', x === b));
    });
  });

  // ── Event action buttons (Add note / Open profile / Export brief) ──
  cvg.querySelectorAll('[data-cvg-act]').forEach(b => {
    b.addEventListener('click', () => {
      const k = b.dataset.cvgAct;
      const msg = k === 'note' ? 'Note saved to mission journal.' :
                  k === 'profile' ? 'Opening country profile…' :
                  'Brief queued for export (PDF).';
      const orig = b.textContent;
      b.textContent = msg;
      setTimeout(() => { b.textContent = orig; }, 1800);
    });
  });

    cvg.querySelectorAll('[data-cvg-suggest]').forEach(b => {
    b.addEventListener('click', () => {
      const q = b.dataset.cvgSuggest;
      promptText.value = q;
      promptText.dispatchEvent(new Event('input'));
      askConvergensAI(q);
    });
  });

  // ── BOOT: open via platform-shell, so init the maps once the overlay is in DOM ──
  function bootCvgEngine(){
    if (!document.getElementById('cvgLeafletRegion') && !document.getElementById('cvgWorldMap')) return;
    setTimeout(function(){
      try { initCvgMaps(); } catch(e){ console.warn('cvg engine init', e); }
      if (cvgRegionMap && cvgRegionMap.invalidateSize) cvgRegionMap.invalidateSize();
      if (window.cvgEventMap && typeof window.cvgEventMap.resize === 'function') window.cvgEventMap.resize();
    }, 140);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bootCvgEngine);
  else bootCvgEngine();
})();
