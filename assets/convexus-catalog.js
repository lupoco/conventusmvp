/* ============================================================================
   Convexus — Capability Catalog engine
   Representative (fictional) providers across the defence-innovation ecosystem.
   Scope: DIANA cohort · Startup · Research · Established industry.
   ============================================================================ */
(function(){
  'use strict';

  // ---- Taxonomy ----
  var TYPE_LABEL = { diana:'DIANA Cohort', startup:'Startup', research:'Research', industry:'Industry' };
  var TYPE_COLOR = { diana:'var(--pf-convexus)', startup:'#16A34A', research:'#C8A24B', industry:'#475569' };
  var TRL_BANDS = {
    research:    { label:'TRL 3–4 · Research',    test:function(t){ return t<=4; } },
    prototype:   { label:'TRL 5–6 · Prototype',   test:function(t){ return t>=5 && t<=6; } },
    operational: { label:'TRL 7–9 · Operational', test:function(t){ return t>=7; } }
  };
  function trlBand(t){ return t<=4 ? 'research' : (t<=6 ? 'prototype' : 'operational'); }

  // ---- Engagement pathways (derived from maturity & type) ----
  var PATHS = [['experimentation','EXP','Experimentation'],['procurement','PROC','Procurement'],['marketing','MKT','Marketing'],['sales','SALES','Sales']];
  function pathwaysFor(d){
    return {
      experimentation: d.trl<=7 ? 'open' : 'soon',
      procurement:     d.trl>=7 ? 'open' : (d.trl===6 ? 'soon' : 'closed'),
      marketing:       'open',
      sales:           (d.trl>=7 && d.type!=='research') ? 'open' : (d.trl===6 ? 'soon' : 'closed')
    };
  }
  function pathStrip(d){ var pf=pathwaysFor(d); return PATHS.map(function(p){ var st=pf[p[0]]; return '<span class="pth '+st+'" title="'+p[2]+': '+st+'">'+p[1]+'</span>'; }).join(''); }

  // ---- Marketplace helpers (ratings, reviews, announcements, website, local time) ----
  function hashId(s){ var h=0; for(var i=0;i<s.length;i++) h=(h*31+s.charCodeAt(i))>>>0; return h; }
  function stars(v){ var n=Math.round(v), s=''; for(var i=1;i<=5;i++) s+=(i<=n?'\u2605':'\u2606'); return '<span class="cvx-stars">'+s+'</span>'; }
  var TZ={ 'Sweden':'Europe/Stockholm','Estonia':'Europe/Tallinn','Norway':'Europe/Oslo','T\u00fcrkiye':'Europe/Istanbul','United Kingdom':'Europe/London','Netherlands':'Europe/Amsterdam','Germany':'Europe/Berlin','United States':'America/New_York','Canada':'America/Toronto','Italy':'Europe/Rome','Poland':'Europe/Warsaw','Finland':'Europe/Helsinki','Denmark':'Europe/Copenhagen','Portugal':'Europe/Lisbon','France':'Europe/Paris','Spain':'Europe/Madrid','Lithuania':'Europe/Vilnius','Czechia':'Europe/Prague','Greece':'Europe/Athens' };
  function localTime(country){ var tz=TZ[country]||'UTC'; try{ return { time:new Intl.DateTimeFormat('en-GB',{hour:'2-digit',minute:'2-digit',timeZone:tz}).format(new Date()), tz:tz }; }catch(e){ return {time:'\u2014',tz:tz}; } }
  var R_AUTH=['Programme office \u00b7 member nation','Capability planner \u00b7 multinational HQ','Exercise lead \u00b7 training centre','Acquisition cell \u00b7 ministry','Innovation hub \u00b7 accelerator','Operational user \u00b7 joint command'];
  var R_TEXT=['Performed reliably under realistic exercise conditions.','Strong interoperability with existing systems.','Responsive team and clear technical documentation.','Mature capability \u2014 integrated faster than expected.','Solid results in a contested test environment.','Credible roadmap to scale; good value.'];
  function marketInfo(d){ var h=hashId(d.id); var rating=4.2+(h%8)/10; var reviews=8+(h%42); var n=2+(h%2); var list=[]; for(var i=0;i<n;i++){ list.push({author:R_AUTH[(h+i*7)%R_AUTH.length], text:R_TEXT[(h+i*5)%R_TEXT.length], stars:Math.min(5,Math.max(4,Math.round(rating)-(i%2)))}); } return {rating:rating,reviews:reviews,verified:d.verified,list:list}; }
  var A_TAG=['UPDATE','LAUNCH','EVENT','AWARD','HIRING'];
  var A_TXT=['New capability release available for evaluation.','Joining the next experimentation cycle \u2014 partners welcome.','Live demonstration scheduled at an upcoming exercise.','Recognised in a recent innovation challenge.','Expanding the team \u2014 engineering & integration roles open.'];
  function announcements(d){ var h=hashId(d.id), ago=['2d','5d','1w','2w'], out=[]; for(var i=0;i<2;i++){ out.push({tag:A_TAG[(h+i*3)%A_TAG.length], text:A_TXT[(h+i*4)%A_TXT.length], ago:ago[(h+i)%ago.length]}); } return out; }
  function websiteOf(d){ return 'www.'+d.id+'-defence.eu'; }

  // ---- Dataset ----
  // Prefer live data fed from index.html (Supabase pool → window.CVX_DATA).
  // Falls back to the representative sample below only if no live data present.
  var DATA = (window.CVX_DATA && window.CVX_DATA.length) ? window.CVX_DATA : [
    { id:'northwind', name:'Northwind Vega', type:'diana', country:'Sweden', city:'Gothenburg', domain:'Sensing & ISR', challenge:'Sensing & Surveillance', trl:7, stage:'Series A', dual:true, verified:true, tested:true, cohort:'2025', site:'Imperial (UK)', desc:'Edge ISR sensor mesh delivering low-SWaP situational awareness in contested, comms-denied environments.', caps:['Edge ISR','Sensor fusion','Low-SWaP','Mesh'] },
    { id:'helex', name:'Helex Dynamics', type:'startup', country:'Estonia', city:'Tallinn', domain:'Cyber', challenge:'Secure Information Sharing', trl:6, stage:'Seed', dual:true, verified:true, tested:false, desc:'Zero-trust communications fabric enabling classified data sharing across Allied and partner networks.', caps:['Zero-trust','Cross-domain','Encryption','Allied'] },
    { id:'borealis', name:'Borealis Power', type:'diana', country:'Norway', city:'Trondheim', domain:'Energy', challenge:'Energy Resilience', trl:5, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2025', site:'NTNU (NO)', desc:'Deployable solid-state microgrid providing silent, resilient power for forward operating bases.', caps:['Microgrid','Solid-state','Silent watch','Deployable'] },
    { id:'tagra', name:'Tagra Robotics', type:'startup', country:'Türkiye', city:'Ankara', domain:'AI & Autonomy', challenge:'Sensing & Surveillance', trl:7, stage:'Series A', dual:true, verified:true, tested:true, desc:'Autonomous ground robotics for persistent perimeter awareness and route reconnaissance.', caps:['UGV','Autonomy','Perimeter','Recon'] },
    { id:'meridian', name:'Meridian Quantum', type:'research', country:'United Kingdom', city:'Bristol', domain:'Quantum', challenge:'Data & Computing', trl:4, stage:'Grant-funded', dual:true, verified:true, tested:false, desc:'Quantum-resilient positioning and timing that holds when GNSS is denied or spoofed.', caps:['PNT','Quantum sensing','Anti-spoof','Timing'] },
    { id:'aetherlink', name:'Aetherlink', type:'startup', country:'Netherlands', city:'Delft', domain:'Communications', challenge:'Secure Information Sharing', trl:6, stage:'Series A', dual:true, verified:true, tested:false, desc:'Resilient mesh radio with an adaptive anti-jam waveform for degraded electromagnetic conditions.', caps:['Mesh radio','Anti-jam','EW-resilient','Waveform'] },
    { id:'pellucid', name:'Pellucid Materials', type:'industry', country:'Germany', city:'Munich', domain:'Advanced Materials', challenge:'Critical Infrastructure', trl:8, stage:'Established', dual:true, verified:true, tested:true, desc:'Lightweight ballistic and structural composites for protection of platforms and infrastructure.', caps:['Composites','Ballistic','Lightweight','Protection'] },
    { id:'svalsat', name:'SvalSat Optics', type:'diana', country:'Norway', city:'Svalbard', domain:'Space', challenge:'Sensing & Surveillance', trl:6, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2024', site:'Andøya (NO)', desc:'Proliferated-LEO optical payloads for persistent maritime and high-latitude domain awareness.', caps:['pLEO','Optical','Maritime watch','Smallsat'] },
    { id:'larus', name:'Larus Maritime', type:'startup', country:'Portugal', city:'Lisbon', domain:'Maritime', challenge:'Sensing & Surveillance', trl:7, stage:'Series A', dual:true, verified:true, tested:true, desc:'Uncrewed surface vessels providing seabed-to-surface awareness across littoral and open water.', caps:['USV','Uncrewed','Seabed','Littoral'] },
    { id:'cinder', name:'Cinder Compute', type:'startup', country:'United States', city:'Austin', domain:'AI & Autonomy', challenge:'Data & Computing', trl:6, stage:'Series B', dual:true, verified:true, tested:false, desc:'Edge AI inference stack that keeps running in denied, disrupted and degraded comms conditions.', caps:['Edge AI','Inference','DDIL','On-device'] },
    { id:'voltaic', name:'Voltaic Grid', type:'industry', country:'Canada', city:'Ottawa', domain:'Energy', challenge:'Energy Resilience', trl:8, stage:'Established', dual:true, verified:true, tested:false, desc:'Grid-hardening interconnect controllers that maintain continuity under cyber and kinetic stress.', caps:['Grid hardening','Interconnect','Continuity','OT'] },
    { id:'nyx', name:'Nyx Sensors', type:'diana', country:'Italy', city:'Turin', domain:'Sensing & ISR', challenge:'Sensing & Surveillance', trl:5, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2025', site:'LeonardoLabs (IT)', desc:'Passive RF detection that surfaces low-observable threats without emitting.', caps:['Passive RF','Detection','Low-observable','EW'] },
    { id:'kestrel', name:'Kestrel Aerospace', type:'startup', country:'Poland', city:'Warsaw', domain:'AI & Autonomy', challenge:'Power & Propulsion', trl:6, stage:'Series A', dual:true, verified:true, tested:false, desc:'Attritable autonomous air vehicles for mass, decoy and ISR at low cost-per-effect.', caps:['Attritable','Autonomy','Decoy','Air'] },
    { id:'ferro', name:'Ferro Health', type:'research', country:'Finland', city:'Helsinki', domain:'Human Performance', challenge:'Health & Human Performance', trl:4, stage:'Grant-funded', dual:true, verified:true, tested:false, desc:'Cognitive-load and fatigue monitoring to sustain operator performance under pressure.', caps:['Cognitive load','Wearable','Fatigue','Performance'] },
    { id:'selene', name:'Selene Space', type:'diana', country:'United Kingdom', city:'Harwell', domain:'Space', challenge:'Sensing & Surveillance', trl:6, stage:'Series A', dual:true, verified:true, tested:true, cohort:'2024', site:'Harwell (UK)', desc:'SAR smallsat constellation delivering all-weather, day-night ISR over wide areas.', caps:['SAR','Smallsat','All-weather','Wide-area'] },
    { id:'tundra', name:'Tundra Comms', type:'startup', country:'Denmark', city:'Copenhagen', domain:'Communications', challenge:'Secure Information Sharing', trl:7, stage:'Series A', dual:true, verified:true, tested:false, desc:'Arctic-grade resilient SATCOM with assured connectivity at high latitudes.', caps:['SATCOM','Arctic','Resilient','Assured comms'] },
    { id:'argent', name:'Argent Cyber', type:'industry', country:'United States', city:'Reston', domain:'Cyber', challenge:'Secure Information Sharing', trl:8, stage:'Established', dual:true, verified:true, tested:true, desc:'OT/ICS intrusion detection protecting energy, water and transport critical infrastructure.', caps:['OT/ICS','Intrusion detection','Critical infra','SOC'] },
    { id:'halcyon', name:'Halcyon Energy', type:'diana', country:'Netherlands', city:'Eindhoven', domain:'Energy', challenge:'Energy Resilience', trl:5, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2025', site:'TU/e (NL)', desc:'Hydrogen fuel cells for long-duration silent watch and emissions-free forward power.', caps:['Hydrogen','Fuel cell','Silent watch','Long-duration'] },
    { id:'corvus', name:'Corvus Analytics', type:'startup', country:'Germany', city:'Berlin', domain:'AI & Autonomy', challenge:'Data & Computing', trl:6, stage:'Series A', dual:true, verified:true, tested:false, desc:'Multi-source OSINT fusion engine that turns open signals into structured, graded intelligence.', caps:['OSINT','Fusion','NLP','Intelligence'] },
    { id:'bastion', name:'Bastion Materials', type:'research', country:'France', city:'Toulouse', domain:'Advanced Materials', challenge:'Critical Infrastructure', trl:4, stage:'Grant-funded', dual:true, verified:true, tested:false, desc:'Self-healing protective coatings extending the survivability of exposed infrastructure.', caps:['Self-healing','Coatings','Corrosion','Survivability'] },
    { id:'ondine', name:'Ondine Subsea', type:'diana', country:'Portugal', city:'Porto', domain:'Maritime', challenge:'Critical Infrastructure', trl:6, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2024', site:'+ATLANTIC (PT)', desc:'Autonomous underwater vehicles for seabed infrastructure and undersea-cable monitoring.', caps:['AUV','Seabed','Cable monitoring','Subsea'] },
    { id:'vanta', name:'Vanta Optics', type:'startup', country:'Lithuania', city:'Vilnius', domain:'Sensing & ISR', challenge:'Sensing & Surveillance', trl:7, stage:'Series A', dual:true, verified:true, tested:true, desc:'Multispectral EO/IR gimbals for precise day-night targeting and recognition.', caps:['EO/IR','Multispectral','Gimbal','Targeting'] },
    { id:'pyralis', name:'Pyralis Defense', type:'industry', country:'Türkiye', city:'Istanbul', domain:'AI & Autonomy', challenge:'Power & Propulsion', trl:8, stage:'Established', dual:true, verified:true, tested:false, desc:'Loitering-munition autonomy stack with human-on-the-loop oversight and precision effects.', caps:['Loitering','Autonomy','Human-on-loop','Precision'] },
    { id:'glacier', name:'Glacier AI', type:'startup', country:'Canada', city:'Toronto', domain:'AI & Autonomy', challenge:'Data & Computing', trl:6, stage:'Series B', dual:true, verified:true, tested:false, desc:'Decision-support copilots that accelerate the command-and-control cycle without replacing judgement.', caps:['Decision support','C2','Copilot','LLM'] },
    { id:'aurora', name:'Aurora Quantum', type:'diana', country:'Denmark', city:'Aarhus', domain:'Quantum', challenge:'Data & Computing', trl:4, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2025', site:'DTU (DK)', desc:'Quantum key distribution securing tactical links against future decryption.', caps:['QKD','Quantum','Encryption','Tactical'] },
    { id:'stratus', name:'Stratus Power', type:'startup', country:'Spain', city:'Madrid', domain:'Energy', challenge:'Energy Resilience', trl:6, stage:'Series A', dual:true, verified:true, tested:false, desc:'Portable power and thermal-management systems for dismounted and expeditionary teams.', caps:['Portable power','Thermal','Expeditionary','Battery'] },
    { id:'talos', name:'Talos Robotics', type:'diana', country:'Greece', city:'Athens', domain:'AI & Autonomy', challenge:'Critical Infrastructure', trl:5, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2024', site:'Demokritos (GR)', desc:'EOD and inspection robotics for safe standoff handling of hazards and infrastructure checks.', caps:['EOD','Inspection','Robotics','Standoff'] },
    { id:'nimbus', name:'Nimbus Secure', type:'startup', country:'Norway', city:'Oslo', domain:'Cyber', challenge:'Secure Information Sharing', trl:7, stage:'Series A', dual:true, verified:true, tested:true, desc:'Cross-domain guard enabling safe data movement between classified and partner networks.', caps:['Cross-domain guard','Classified','Data diode','Assurance'] },
    { id:'hammerhead', name:'Hammerhead Marine', type:'industry', country:'United Kingdom', city:'Plymouth', domain:'Maritime', challenge:'Sensing & Surveillance', trl:8, stage:'Established', dual:true, verified:true, tested:true, desc:'Towed-array sonar systems for persistent undersea domain awareness.', caps:['Sonar','Towed array','ASW','Undersea'] },
    { id:'skybridge', name:'Skybridge Networks', type:'startup', country:'Italy', city:'Milan', domain:'Communications', challenge:'Secure Information Sharing', trl:6, stage:'Series A', dual:true, verified:true, tested:false, desc:'Airborne relay mesh that extends resilient comms beyond line of sight.', caps:['Airborne relay','BLOS','Mesh','Resilient comms'] },
    { id:'cryos', name:'Cryos Power', type:'diana', country:'Finland', city:'Oulu', domain:'Energy', challenge:'Energy Resilience', trl:5, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2025', site:'VTT (FI)', desc:'Cold-climate battery systems for sustained operations at extreme low temperatures.', caps:['Battery','Cold-climate','Endurance','Storage'] },
    { id:'obsidian', name:'Obsidian Cyber', type:'startup', country:'Czechia', city:'Prague', domain:'Cyber', challenge:'Secure Information Sharing', trl:7, stage:'Series A', dual:true, verified:true, tested:true, desc:'Active deception grids that trap, profile and slow intruders inside the network.', caps:['Deception','Honeynet','Threat intel','Active defence'] },
    { id:'lumen', name:'Lumen Optronics', type:'industry', country:'France', city:'Bordeaux', domain:'Sensing & ISR', challenge:'Sensing & Surveillance', trl:8, stage:'Established', dual:true, verified:true, tested:false, desc:'Long-range cooled thermal imaging for border and maritime surveillance.', caps:['Thermal','Long-range','EO/IR','Border'] },
    { id:'polaris', name:'Polaris Robotics', type:'startup', country:'Norway', city:'Bergen', domain:'AI & Autonomy', challenge:'Critical Infrastructure', trl:6, stage:'Series A', dual:true, verified:true, tested:false, desc:'Autonomous underwater inspection swarms for offshore and seabed infrastructure.', caps:['AUV swarm','Inspection','Offshore','Autonomy'] },
    { id:'verdane', name:'Verdane Materials', type:'research', country:'Sweden', city:'Lund', domain:'Advanced Materials', challenge:'Power & Propulsion', trl:4, stage:'Grant-funded', dual:true, verified:true, tested:false, desc:'High-energy-density solid propellants with improved safety margins.', caps:['Propellant','Energetics','Materials','Safety'] },
    { id:'echelon', name:'Echelon AI', type:'startup', country:'United States', city:'Denver', domain:'AI & Autonomy', challenge:'Data & Computing', trl:6, stage:'Series B', dual:true, verified:true, tested:false, desc:'Sensor-to-shooter data fabric that fuses multi-domain feeds into a single track.', caps:['Data fabric','Sensor-to-shooter','Multi-domain','Fusion'] },
    { id:'anvil', name:'Anvil Defense', type:'industry', country:'Poland', city:'Gdansk', domain:'Advanced Materials', challenge:'Critical Infrastructure', trl:8, stage:'Established', dual:true, verified:true, tested:true, desc:'Modular protective fortification systems for rapid hardening of key sites.', caps:['Fortification','Modular','Hardening','Protection'] },
    { id:'solace', name:'Solace Health', type:'diana', country:'Netherlands', city:'Utrecht', domain:'Human Performance', challenge:'Health & Human Performance', trl:5, stage:'Seed', dual:true, verified:false, tested:true, cohort:'2024', site:'UMC (NL)', desc:'Field medical triage AI supporting decision-making in mass-casualty events.', caps:['Triage','Medical AI','MASCAL','Decision support'] },
    { id:'tempest', name:'Tempest Aerospace', type:'startup', country:'Türkiye', city:'İzmir', domain:'AI & Autonomy', challenge:'Power & Propulsion', trl:7, stage:'Series A', dual:true, verified:true, tested:true, desc:'Swarming loitering systems with collaborative, human-on-the-loop autonomy.', caps:['Swarm','Loitering','Collaborative autonomy','Human-on-loop'] },
    { id:'kelvin', name:'Kelvin Quantum', type:'research', country:'United Kingdom', city:'Glasgow', domain:'Quantum', challenge:'Data & Computing', trl:4, stage:'Grant-funded', dual:true, verified:true, tested:false, desc:'Quantum gravimetry enabling subsurface and tunnel detection without GNSS.', caps:['Gravimetry','Quantum','Subsurface','PNT'] }
  ];

  // ---- State ----
  var ov, gridEl, detailEl, trayEl;
  var active = { type:'', domain:'', country:'', trl:'', path:'' };
  var query = '', sortMode = 'match', compact = false, need = '', needScores = {};
  var shortlist = [];
  try { shortlist = JSON.parse(localStorage.getItem('convexus-shortlist') || '[]'); } catch(e){ shortlist = []; }

  function saveShortlist(){ try { localStorage.setItem('convexus-shortlist', JSON.stringify(shortlist)); } catch(e){} }
  function initials(name){ return name.split(/\s+/).slice(0,2).map(function(w){ return w[0]; }).join('').toUpperCase(); }
  function uniq(key){ var s=[]; DATA.forEach(function(d){ if(s.indexOf(d[key])<0) s.push(d[key]); }); return s.sort(); }
  function esc(t){ return String(t).replace(/[&<>"]/g, function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; }); }

  // ---- Live stat row ----
  function renderStats(){
    var el = ov.querySelector('#cvxStats'); if(!el) return;
    var avg = Math.round(DATA.reduce(function(a,d){ return a+d.trl; },0)/DATA.length*10)/10;
    var cells = [[DATA.length,'Providers'],[uniq('domain').length,'Technology domains'],[uniq('country').length,'Nations'],[avg,'Avg. readiness (TRL)']];
    el.innerHTML = cells.map(function(c,i){ return '<div class="cvx-stat'+(i===0?' live':'')+'"><div class="v" data-to="'+c[0]+'">0</div><div class="k">'+c[1]+'</div></div>'; }).join('');
    var motion = !document.documentElement.classList.contains('motion-off');
    el.querySelectorAll('.v').forEach(function(v){
      var to = parseFloat(v.dataset.to), dec = to % 1 !== 0;
      if(!motion){ v.textContent = dec ? to.toFixed(1) : to; return; }
      var t0 = null;
      (function step(ts){ if(!t0) t0=ts; var p=Math.min(1,(ts-t0)/700); var cur=to*p; v.textContent = dec ? cur.toFixed(1) : Math.round(cur); if(p<1) requestAnimationFrame(step); })(performance.now());
    });
  }

  // ---- Match-to-need scoring (deterministic keyword/domain overlap) ----
  function haystack(d){ return (d.name+' '+d.desc+' '+d.domain+' '+d.challenge+' '+d.caps.join(' ')+' '+d.type).toLowerCase(); }
  function computeNeed(){
    needScores = {};
    if(!need.trim()){ return; }
    var toks = need.toLowerCase().split(/[^a-z0-9]+/).filter(function(t){ return t.length>2; });
    DATA.forEach(function(d){
      var hay = haystack(d), score = 0;
      toks.forEach(function(t){
        if(d.domain.toLowerCase().indexOf(t)>=0 || d.challenge.toLowerCase().indexOf(t)>=0) score += 3;
        else if(d.caps.join(' ').toLowerCase().indexOf(t)>=0) score += 2;
        else if(hay.indexOf(t)>=0) score += 1;
      });
      // coverage bonus + TRL readiness nudge
      var pct = score>0 ? Math.min(98, 58 + score*8 + (d.trl>=7?6:d.trl>=5?3:0)) : 0;
      needScores[d.id] = pct;
    });
  }

  // ---- Filtering ----
  function passes(d){
    if(query){
      var q = query.toLowerCase();
      if(haystack(d).indexOf(q)<0 && d.country.toLowerCase().indexOf(q)<0 && d.city.toLowerCase().indexOf(q)<0) return false;
    }
    if(active.type && d.type!==active.type) return false;
    if(active.domain && d.domain!==active.domain) return false;
    if(active.country && d.country!==active.country) return false;
    if(active.trl && trlBand(d.trl)!==active.trl) return false;
    if(active.path && pathwaysFor(d)[active.path]!=='open') return false;
    return true;
  }

  function sortFn(a,b){
    if(sortMode==='match' && need.trim()) return (needScores[b.id]||0)-(needScores[a.id]||0);
    if(sortMode==='trl') return b.trl-a.trl;
    if(sortMode==='name') return a.name.localeCompare(b.name);
    if(sortMode==='added') return DATA.indexOf(b)-DATA.indexOf(a);
    return a.name.localeCompare(b.name);
  }

  // ---- Render: single-row filter dropdowns ----
  function fillSel(id, allLabel, options){
    var s = ov.querySelector(id); if(!s) return;
    s.innerHTML = '<option value="">'+allLabel+'</option>' + options.map(function(o){ return '<option value="'+o[0]+'">'+o[1]+'</option>'; }).join('');
  }
  function populateFilters(){
    fillSel('#cvxfDomain','All domains', uniq('domain').map(function(v){ return [v,v]; }));
    fillSel('#cvxfType','All provider types', Object.keys(TYPE_LABEL).map(function(t){ return [t,TYPE_LABEL[t]]; }));
    fillSel('#cvxfPath','Any pathway open', PATHS.map(function(p){ return [p[0],p[2]+' open']; }));
    fillSel('#cvxfTrl','Any readiness', Object.keys(TRL_BANDS).map(function(k){ return [k,TRL_BANDS[k].label]; }));
    fillSel('#cvxfCountry','All nations', uniq('country').map(function(v){ return [v,v]; }));
  }

  // ---- Render: provenance badges ----
  function provBadges(d){
    var b = '';
    if(d.verified) b += '<span class="cvx-pb v">✓ Verified</span>';
    if(d.tested)   b += '<span class="cvx-pb t">◎ Tested</span>';
    if(d.dual)     b += '<span class="cvx-pb d">⇄ Dual-use</span>';
    return b;
  }

  // ---- Render: grid ----
  function card(d,i){ i=i||0;
    var ns = need.trim() ? (needScores[d.id]||0) : null;
    var matchHtml = ns!==null ? '<span class="cvx-match'+(ns>=80?' hi':ns>=65?' mid':'')+'">'+(ns>0?ns+'% match':'—')+'</span>' : '';
    var starred = shortlist.indexOf(d.id)>=0;
    return '<div class="cvx-card" data-id="'+d.id+'" tabindex="0" role="button" style="--tc:'+TYPE_COLOR[d.type]+';animation-delay:'+((i%10)*0.03)+'s">'+
      '<div class="cvx-card-top">'+
        '<span class="cvx-av" style="--tc:'+TYPE_COLOR[d.type]+'">'+initials(d.name)+'</span>'+
        '<div class="cvx-idblock"><span class="cvx-nm">'+d.name+'</span>'+
          '<span class="cvx-type" style="--tc:'+TYPE_COLOR[d.type]+'"><i></i>'+TYPE_LABEL[d.type]+'</span></div>'+
        matchHtml+
      '</div>'+
      '<div class="cvx-loc"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s-7-5.7-7-11a7 7 0 0114 0c0 5.3-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/></svg>'+d.city+' · '+d.country+'</div>'+
      '<p class="cvx-desc">'+d.desc+'</p>'+
      '<div class="cvx-tags"><span class="dom">'+d.domain+'</span><span class="ch">'+d.challenge+'</span></div>'+
      '<div class="cvx-meta"><span class="trl">TRL '+d.trl+'</span><span class="stage">'+d.stage+'</span><span class="rate">\u2605 '+marketInfo(d).rating.toFixed(1)+'</span></div>'+
      '<div class="cvx-prov">'+provBadges(d)+'</div>'+
      '<div class="cvx-paths">'+pathStrip(d)+'</div>'+
      '<div class="cvx-card-foot">'+
        '<button class="cvx-star'+(starred?' on':'')+'" data-star title="Shortlist">'+(starred?'★ Shortlisted':'☆ Shortlist')+'</button>'+
        '<span class="cvx-view">View profile →</span>'+
      '</div>'+
    '</div>';
  }
  function renderGrid(){
    var list = DATA.filter(passes).sort(sortFn);
    gridEl.classList.toggle('compact', compact);
    gridEl.innerHTML = list.map(function(d,i){ return card(d,i); }).join('');
    ov.querySelector('#cvxResults').textContent = list.length + ' of ' + DATA.length + ' providers';
    var lc=document.getElementById('cvxLaunchCount'); if(lc) lc.textContent=DATA.length;
    var sm=document.getElementById('cvxScreenMeta'); if(sm) sm.textContent=list.length+' / '+DATA.length+' providers';
    ov.querySelector('#cvxCount').textContent = DATA.length;
    var empty = ov.querySelector('#cvxEmpty'); if(empty) empty.hidden = list.length>0;
    gridEl.querySelectorAll('.cvx-card').forEach(function(c){
      c.addEventListener('click', function(e){
        if(e.target.closest('[data-star]')){ e.stopPropagation(); toggleStar(c.dataset.id); return; }
        openDetail(c.dataset.id);
      });
      c.addEventListener('keydown', function(e){ if(e.key==='Enter'){ openDetail(c.dataset.id); } });
    });
  }

  // ---- Shortlist ----
  function toggleStar(id){
    var i = shortlist.indexOf(id);
    if(i>=0) shortlist.splice(i,1); else shortlist.push(id);
    saveShortlist(); renderGrid(); renderTray();
    if(detailEl && detailEl.classList.contains('open') && detailEl.dataset.id===id) openDetail(id);
  }
  function renderTray(){
    if(!shortlist.length){ trayEl.classList.remove('open'); return; }
    trayEl.classList.add('open');
    trayEl.querySelector('#cvxTrayCount').textContent = shortlist.length;
    trayEl.querySelector('#cvxTrayNames').innerHTML = shortlist.map(function(id){
      var d = DATA.find(function(x){return x.id===id;});
      return d ? '<span class="cvx-tray-chip" data-rm="'+id+'">'+d.name+' ✕</span>' : '';
    }).join('');
    trayEl.querySelectorAll('[data-rm]').forEach(function(ch){
      ch.addEventListener('click', function(){ toggleStar(ch.dataset.rm); });
    });
  }

  // ---- Detail panel ----
  function openDetail(id){
    var d = DATA.find(function(x){return x.id===id;}); if(!d) return;
    var starred = shortlist.indexOf(id)>=0;
    var ns = need.trim() ? (needScores[d.id]||0) : null;
    var mk = marketInfo(d), web = websiteOf(d), lt = localTime(d.country);
    detailEl.dataset.id = id;
    detailEl.innerHTML =
      '<div class="cvx-dt-head" style="--tc:'+TYPE_COLOR[d.type]+'">'+
        '<button class="cvx-dt-close" data-dt-close aria-label="Close">✕</button>'+
        '<span class="cvx-av lg" style="--tc:'+TYPE_COLOR[d.type]+'">'+initials(d.name)+'</span>'+
        '<div><div class="cvx-dt-nm">'+d.name+'</div>'+
          '<div class="cvx-type" style="--tc:'+TYPE_COLOR[d.type]+'"><i></i>'+TYPE_LABEL[d.type]+'</div></div>'+
        (ns!==null?'<span class="cvx-match '+(ns>=80?'hi':ns>=65?'mid':'')+'" style="margin-left:auto">'+(ns>0?ns+'% match':'—')+'</span>':'')+
      '</div>'+
      '<div class="cvx-dt-body">'+
        '<p class="cvx-dt-desc">'+d.desc+'</p>'+
        '<div class="cvx-dt-grid">'+
          '<div><span class="k">Location</span><span class="v">'+d.city+' · '+d.country+'</span></div>'+
          '<div><span class="k">Domain</span><span class="v">'+d.domain+'</span></div>'+
          '<div><span class="k">Challenge area</span><span class="v">'+d.challenge+'</span></div>'+
          '<div><span class="k">Readiness</span><span class="v">TRL '+d.trl+' · '+TRL_BANDS[trlBand(d.trl)].label.split('·')[1].trim()+'</span></div>'+
          '<div><span class="k">Stage</span><span class="v">'+d.stage+'</span></div>'+
          (d.type==='diana'?'<div><span class="k">DIANA cohort</span><span class="v">'+d.cohort+' · '+d.site+'</span></div>':'')+
        '</div>'+
        '<div class="cvx-dt-k">Capabilities</div>'+
        '<div class="cvx-dt-caps">'+d.caps.map(function(c){return '<span>'+c+'</span>';}).join('')+'</div>'+
        '<div class="cvx-dt-k">Provenance</div>'+
        '<div class="cvx-prov lg">'+provBadges(d)+'</div>'+
        '<div class="cvx-dt-k">Engagement pathways</div>'+
        '<div class="cvx-dt-paths">'+PATHS.map(function(p){ var st=pathwaysFor(d)[p[0]]; return '<span class="pthrow '+st+'"><b>'+p[2]+'</b><i>'+st+'</i></span>'; }).join('')+'</div>'+
        '<div class="cvx-dt-k">Marketplace</div>'+
        '<div class="cvx-mkt-row"><span class="cvx-rate-lg">'+stars(mk.rating)+' <b>'+mk.rating.toFixed(1)+'</b> \u00b7 '+mk.reviews+' reviews</span>'+(mk.verified?'<span class="cvx-vp">\u2713 Verified</span>':'')+'</div>'+
        '<div class="cvx-mkt-row"><a class="cvx-web" href="https://'+web+'" target="_blank" rel="noopener">\u2197 '+web+'</a><span class="cvx-clock" data-tz="'+lt.tz+'">\u25f7 Local '+lt.time+'</span></div>'+
        '<div class="cvx-revs">'+mk.list.map(function(rv){ return '<div class="cvx-rev"><div class="rv-h"><span class="rv-a">'+rv.author+'</span>'+stars(rv.stars)+'</div><div class="rv-t">\u201c'+rv.text+'\u201d</div></div>'; }).join('')+'</div>'+
      '</div>'+
      '<div class="cvx-dt-foot">'+
        '<button class="cvx-star big'+(starred?' on':'')+'" data-dt-star>'+(starred?'★ Shortlisted':'☆ Add to shortlist')+'</button>'+
        '<button class="cvx-intro" data-dt-intro>Request intro</button>'+
      '</div>';
    detailEl.classList.add('open');
    detailEl.scrollTop = 0;
    detailEl.querySelector('[data-dt-close]').addEventListener('click', closeDetail);
    detailEl.querySelector('[data-dt-star]').addEventListener('click', function(){ toggleStar(id); });
    detailEl.querySelector('[data-dt-intro]').addEventListener('click', function(){
      this.textContent='Intro requested ✓'; this.classList.add('done'); this.disabled=true;
    });
  }
  function closeDetail(){ detailEl.classList.remove('open'); detailEl.dataset.id=''; }

  // ---- Compare (shortlist) view ----
  function openCompare(){
    if(!shortlist.length) return;
    var firms = shortlist.map(function(id){ return DATA.find(function(x){return x.id===id;}); }).filter(Boolean);
    var rows = [
      ['Type', function(d){ return TYPE_LABEL[d.type]; }],
      ['Location', function(d){ return d.city+' · '+d.country; }],
      ['Domain', function(d){ return d.domain; }],
      ['Challenge', function(d){ return d.challenge; }],
      ['TRL', function(d){ return 'TRL '+d.trl; }],
      ['Stage', function(d){ return d.stage; }],
      ['Provenance', function(d){ return (d.verified?'Verified ':'')+(d.tested?'· Tested ':'')+(d.dual?'· Dual-use':''); }]
    ];
    var head = '<th></th>'+firms.map(function(d){ return '<th>'+d.name+'</th>'; }).join('');
    var body = rows.map(function(r){
      return '<tr><td class="rk">'+r[0]+'</td>'+firms.map(function(d){ return '<td>'+r[1](d)+'</td>'; }).join('')+'</tr>';
    }).join('');
    detailEl.dataset.id='';
    detailEl.innerHTML =
      '<div class="cvx-dt-head"><button class="cvx-dt-close" data-dt-close aria-label="Close">✕</button>'+
        '<div class="cvx-dt-nm">Compare · '+firms.length+' shortlisted</div></div>'+
      '<div class="cvx-dt-body"><div class="cvx-cmp-wrap"><table class="cvx-cmp">'+
        '<thead><tr>'+head+'</tr></thead><tbody>'+body+'</tbody></table></div></div>';
    detailEl.classList.add('open','wide');
    detailEl.querySelector('[data-dt-close]').addEventListener('click', function(){ detailEl.classList.remove('wide'); closeDetail(); });
  }

  // ---- AI match insight ----
  function buildInsight(){
    var ins = ov.querySelector('#cvxInsight'); if(!ins) return;
    if(!need.trim()){ ins.hidden = true; return; }
    var matched = DATA.filter(function(d){ return (needScores[d.id]||0)>0; }).sort(function(a,b){ return needScores[b.id]-needScores[a.id]; });
    ins.hidden = false;
    if(!matched.length){
      ins.innerHTML = '<span class="ai-k">CONVEXUS AI</span>No strong matches for that need yet — try different terms (a domain, capability or challenge area).';
      return;
    }
    var top = matched.slice(0,5), tally = {};
    top.forEach(function(d){ tally[d.domain] = (tally[d.domain]||0)+1; });
    var doms = Object.keys(tally).sort(function(a,b){ return tally[b]-tally[a]; }).slice(0,2);
    var lead = matched[0];
    ins.innerHTML = '<span class="ai-k">CONVEXUS AI · MATCH RATIONALE</span>'+
      'Ranked <b>'+matched.length+'</b> providers for “<b>'+esc(need)+'</b>”. Strongest fits cluster in <b>'+doms.join('</b> and <b>')+'</b>. '+
      '<b>'+lead.name+'</b> leads at <b>'+needScores[lead.id]+'%</b> — '+lead.desc;
  }

  // ---- Wire toolbar / need bar ----
  function wire(){
    var search = ov.querySelector('#cvxSearch');
    if(search) search.addEventListener('input', function(){ query=this.value; renderGrid(); });
    var sort = ov.querySelector('#cvxSort');
    if(sort){ sort.value = sortMode; sort.addEventListener('change', function(){ sortMode=this.value; renderGrid(); }); }
    var dens = ov.querySelector('#cvxDensity');
    if(dens) dens.addEventListener('click', function(){ compact=!compact; this.classList.toggle('on',compact); this.textContent = compact?'Comfortable':'Compact'; renderGrid(); });
    var reset = ov.querySelector('#cvxReset');
    if(reset) reset.addEventListener('click', function(){ active={type:'',domain:'',country:'',trl:'',path:''}; query=''; if(search) search.value=''; ov.querySelectorAll('.cvx-sel').forEach(function(s){ s.value=''; }); renderGrid(); });
    var catBtn=document.getElementById('cvxCatBtn'), catScreen=document.getElementById('convexusCatalog');
    if(catBtn&&catScreen) catBtn.addEventListener('click', function(){ catScreen.classList.add('open'); catScreen.setAttribute('aria-hidden','false'); catScreen.scrollTop=0; });
    if(catScreen) catScreen.querySelectorAll('[data-cat-close]').forEach(function(b){ b.addEventListener('click', function(){ catScreen.classList.remove('open'); catScreen.setAttribute('aria-hidden','true'); }); });
    [['#cvxfDomain','domain'],['#cvxfType','type'],['#cvxfPath','path'],['#cvxfTrl','trl'],['#cvxfCountry','country']].forEach(function(pair){
      var s = ov.querySelector(pair[0]); if(s) s.addEventListener('change', function(){ active[pair[1]]=this.value; renderGrid(); });
    });
    var needInput = ov.querySelector('#cvxNeed'), needRun = ov.querySelector('#cvxNeedRun'), needClear = ov.querySelector('#cvxNeedClear');
    function runNeed(){ need = needInput.value; computeNeed(); sortMode='match'; if(sort) sort.value='match'; needClear.hidden = !need.trim(); renderGrid(); buildInsight(); }
    if(needRun) needRun.addEventListener('click', runNeed);
    if(needInput) needInput.addEventListener('keydown', function(e){ if(e.key==='Enter') runNeed(); });
    if(needClear) needClear.addEventListener('click', function(){ need=''; needInput.value=''; needClear.hidden=true; buildInsight(); renderGrid(); });
    ov.querySelectorAll('#cvxSugg button').forEach(function(b){ b.addEventListener('click', function(){ needInput.value=b.dataset.need; runNeed(); }); });
    var trayView = ov.querySelector('#cvxTrayView'), trayClear = ov.querySelector('#cvxTrayClear');
    if(trayView) trayView.addEventListener('click', openCompare);
    if(trayClear) trayClear.addEventListener('click', function(){ shortlist=[]; saveShortlist(); renderGrid(); renderTray(); });
  }

  function init(){
    ov = document.getElementById('convexusOverlay');
    if(!ov || ov.dataset.cvxInit) return;
    gridEl = ov.querySelector('#cvxGrid');
    detailEl = ov.querySelector('#cvxDetail');
    trayEl = ov.querySelector('#cvxTray');
    if(!gridEl || !detailEl || !trayEl) return;
    ov.dataset.cvxInit = '1';
    renderStats(); populateFilters(); wire(); renderGrid(); renderTray();
    window.CVX = { DATA:DATA, TYPE_LABEL:TYPE_LABEL, TYPE_COLOR:TYPE_COLOR, TRL_BANDS:TRL_BANDS, trlBand:trlBand, initials:initials, pathwaysFor:pathwaysFor, PATHS:PATHS, provBadges:provBadges, marketInfo:marketInfo, stars:stars, localTime:localTime, announcements:announcements, websiteOf:websiteOf };
    document.addEventListener('keydown', function(e){ if(e.key==='Escape' && detailEl.classList.contains('open')){ detailEl.classList.remove('wide'); closeDetail(); } });
  }

  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
