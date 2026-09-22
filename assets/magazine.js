/* ============================================================================
   The Convergence Brief — weekly open-source brief on dual-use technology &
   innovation. Standalone full-screen editorial experience. Representative
   content; everything framed as open-source, cleared for public release.
   window.openBrief() opens it; wired from the Resources menu.
   ============================================================================ */
(function(){
  'use strict';
  var built=false, brief, reader;

  var ISSUE = { no:'No. 14', week:'Week of 1 June 2026' };

  var CATS = {
    lead:'Lead', tech:'Technology & Innovation', events:'Events & Announcements',
    sme:'Expert Analysis', osint:'Open-Source Digest', trends:'Trend Radar', eco:'From the Ecosystem'
  };

  // ---- Representative articles (open-source, cleared for release) ----
  var ART = [
    { id:'lead', cat:'lead', kicker:'COUNTER-UAS', title:'Layered defence against uncrewed systems moves from idea to habit',
      dek:'Recurring, threat-informed experimentation is turning a patchwork of national counter-drone tools into a coherent, interoperable architecture spanning critical-infrastructure, civil and defence users.',
      author:'Convexus Magazine · Editorial', role:'Open-source synthesis', read:'6 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['Countering small uncrewed aerial systems is no longer treated as a single technology problem. The emerging consensus across open literature is that sensors, effectors and command-and-control must be integrated into a layered, continuously-tested defensive network rather than fielded in isolation.',
        'The pattern that keeps recurring is cadence: short, repeated cycles in which operators, agencies and industry bring systems into the same learning environment, test against realistic threats, and refine before the next round. Speed matters, but only when it produces capability that interoperates and endures.',
        'For planners, the practical takeaway is that adoption is becoming a habit, not an event. The organisations that win are those that can absorb a new effector or sensor, prove it in a shared data environment, and scale it without a multi-year programme.'],
      sources:['Public command transformation releases','Open exercise reporting','Industry briefings (unclassified)'] },

    { id:'edgeai', cat:'tech', kicker:'AUTONOMY', title:'Edge AI holds the line when the network does not',
      dek:'Inference that runs on-device — in denied, disrupted and degraded conditions — is quietly becoming a baseline requirement.',
      author:'Convexus Magazine', role:'Technology desk', read:'4 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['Connectivity is no longer assumed. The most resilient capabilities on display this quarter are those that keep functioning when the link drops: sensor fusion, target recognition and decision-support that run at the edge and reconcile when the network returns.',
        'The design implication is a shift in where intelligence lives — from the cloud to the node — and a premium on models small enough to run on constrained hardware without sacrificing reliability.'],
      sources:['Vendor technical notes','Open conference proceedings'] },

    { id:'pleo', cat:'tech', kicker:'SPACE', title:'Proliferated LEO sensing reaches operational tempo',
      dek:'All-weather, day-night coverage from many small satellites is changing the economics of persistent surveillance.',
      author:'Convexus Magazine', role:'Technology desk', read:'4 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['Distributed constellations are displacing the logic of a few exquisite assets. Resilience now comes from reconstitution — the ability to replace low-cost nodes quickly — rather than from hardening a small number of high-value targets.',
        'Commercial hosted payloads and dual-use data are lowering the cost of entry, opening participation to a wider set of commercial and government participants.'],
      sources:['Open space-domain reporting','Commercial provider disclosures'] },

    { id:'calendar', cat:'events', kicker:'CALENDAR', title:'What to watch: the interoperability season',
      dek:'A dense run of exercises and experiments will test data-sharing and decision speed through the autumn.',
      author:'Convexus Magazine', role:'Events desk', read:'3 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['The interoperability continuum runs hot from June: cross-sector interoperability testing in the summer, identity and data-sharing experiments in September, and digital-backbone trials in October. Expect counter-UAS and next-generation sensing efforts to demonstrate together.',
        'For industry, these are the windows where promising capability either proves it can integrate — or learns what it must fix.'],
      sources:['Public exercise announcements'] },

    { id:'challenge', cat:'events', kicker:'OPEN CALL', title:'Innovation challenge opens on energy resilience',
      dek:'Deployable, low-signature power for remote and forward sites is the focus of a new open call.',
      author:'Convexus Magazine', role:'Events desk', read:'2 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['A new challenge invites dual-use providers to demonstrate deployable microgrids, silent-watch power and cold-climate endurance. Submissions are open to providers across civil, industrial and defence sectors.',
        'Shortlisted teams move into a structured pilot pathway with measurable outcomes.'],
      sources:['Open innovation-accelerator notices'] },

    { id:'sme', cat:'sme', kicker:'EXPERT ANALYSIS', title:'Magazine depth, not just the first shot: the real test of attritable mass',
      dek:'A guest analysis on why the decoy-to-shooter ratio — not the platform — decides whether saturation works.',
      author:'Dr. A. Lindqvist', role:'Strategic foresight · guest contributor', read:'7 min', clr:'OSINT · CLEARED FOR RELEASE · OPINION',
      body:['The seductive image of attritable mass is the swarm. The decisive variable, however, is sustainment. A saturation strategy that exhausts an adversary magazine only works if your own production and replacement cadence can outlast the exchange.',
        'That reframes the question from “how capable is the platform?” to “how affordable, how interoperable, and how quickly can it be replaced during a protracted campaign?” The answers favour modular, high-volume options and burden-sharing — smaller players contributing decoys or electronic-warfare modules that support effectors fielded by larger ones.',
        'The governance dimension is unavoidable. Human-on-the-loop oversight is not a constraint to be engineered around; it is the condition under which the public will accept autonomous teaming at scale.',
        'None of this is settled. But the centre of gravity of the debate has moved — from the spectacle of the swarm to the unglamorous arithmetic of magazine depth.'],
      sources:['Author analysis','Open modelling & simulation literature'] },

    { id:'maritime', cat:'osint', kicker:'GREY ZONE', title:'Open-source digest: maritime signals worth tracking',
      dek:'AIS gaps, shadow-fleet behaviour and seabed-infrastructure activity dominate this week\u2019s open picture.',
      author:'Convexus Magazine', role:'OSINT desk', read:'5 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['This week\u2019s open-source picture is dominated by the maritime grey zone: recurring AIS anomalies near chokepoints, shadow-fleet patterns, and renewed attention to undersea-cable monitoring.',
        'Read with care — open signals indicate, they do not confirm. The value is in correlation: pairing AIS gaps with infrastructure exposure to flag where to look next.'],
      sources:['Open AIS aggregators','Public maritime reporting','Commercial SAR imagery (unclassified)'] },

    { id:'radar', cat:'trends', kicker:'TREND RADAR', title:'Five technologies to track this quarter',
      dek:'Where the open evidence suggests momentum is building.',
      author:'Convexus Magazine', role:'Analysis desk', read:'4 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['1 — Edge autonomy in denied environments. 2 — Proliferated LEO sensing and reconstitution. 3 — Cross-domain guards for partner data-sharing. 4 — Quantum-resilient positioning and timing. 5 — Hydrogen and solid-state power for silent watch.',
        'Each is moving from demonstration toward adoption; each still depends on interoperability and sustainment to deliver operational value.'],
      sources:['Aggregated open reporting','Convexus capability catalog signals'] },

    { id:'ecocat', cat:'eco', kicker:'FROM THE CATALOG', title:'Providers crossing into operational readiness',
      dek:'A read on which catalog capabilities are maturing toward TRL 7+ and opening procurement pathways.',
      author:'Convexus Magazine', role:'Ecosystem desk', read:'3 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['Several providers in the Convexus catalog have moved into operational readiness this quarter, with procurement and sales pathways now open. The common thread is validation in a realistic exercise — provenance the catalog records and surfaces.',
        'Browse the catalog and the always-on expo to see who is demonstrating live.'],
      sources:['Convexus capability catalog'] },

    { id:'expo', cat:'eco', kicker:'EXPO SPOTLIGHT', title:'This week on the expo floor',
      dek:'Sensing & ISR and energy-resilience pavilions are busiest; several booths are demoing live.',
      author:'Convexus Magazine', role:'Ecosystem desk', read:'2 min', clr:'OSINT · CLEARED FOR RELEASE',
      body:['The always-on expo continues to draw steady traffic. This week\u2019s most-visited pavilions are Sensing & ISR and Energy, with live demonstrations running across multiple booths.',
        'Enter the expo from Convexus to walk the pavilions and book a briefing.'],
      sources:['Convexus Expo activity'] }
  ];

  function esc(t){ return String(t).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];}); }
  function byCat(c){ return ART.filter(function(a){return a.cat===c;}); }

  function card(a, big){
    return '<button class="br-card'+(big?' big':'')+'" data-art="'+a.id+'">'+
      '<span class="br-kick">'+a.kicker+'</span>'+
      '<span class="br-ti">'+a.title+'</span>'+
      '<span class="br-dek">'+a.dek+'</span>'+
      '<span class="br-meta"><span class="br-clr">'+a.clr.split('·')[0].trim()+'</span> · '+a.read+' · '+a.author+'</span>'+
    '</button>';
  }

  function section(cat){
    var items=byCat(cat); if(!items.length) return '';
    return '<section class="br-sec"><div class="br-sec-h"><span class="br-sec-k">'+CATS[cat]+'</span></div>'+
      '<div class="br-grid">'+items.map(function(a){return card(a);}).join('')+'</div></section>';
  }

  function build(){
    if(built) return; built=true; injectStyle();
    brief=document.createElement('div'); brief.className='cvx-brief'; brief.id='convergenceBrief'; brief.setAttribute('aria-hidden','true');
    var lead=ART[0];
    brief.innerHTML =
      '<div class="br-bar">'+
        '<span class="br-brand">THE CONVEXUS MAGAZINE</span>'+
        '<span class="br-iss">'+ISSUE.no+' · '+ISSUE.week+'</span>'+
        '<button class="br-close" data-br-close aria-label="Close"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg></button>'+
      '</div>'+
      '<div class="br-scroll">'+
        '<header class="br-mast">'+
          '<div class="br-mast-k">WEEKLY · OPEN-SOURCE BRIEF ON DUAL-USE TECHNOLOGY &amp; INNOVATION</div>'+
          '<h1>Signal from the <em>open source.</em></h1>'+
          '<p>Developments, events and analysis from the technology and innovation world — synthesised from open sources and cleared for public release. Occasional expert contributions; nothing here is classified.</p>'+
        '</header>'+
        '<button class="br-lead" data-art="'+lead.id+'">'+
          '<div class="br-lead-l">'+
            '<span class="br-kick">'+lead.kicker+' · LEAD</span>'+
            '<h2>'+lead.title+'</h2>'+
            '<p>'+lead.dek+'</p>'+
            '<span class="br-meta"><span class="br-clr">'+lead.clr.split('·')[0].trim()+'</span> · '+lead.read+' · '+lead.author+'</span>'+
          '</div>'+
          '<image-slot id="brief-lead-img" shape="rounded" radius="14" class="br-lead-r" placeholder="Lead image — drop to upload"></image-slot>'+
        '</button>'+
        section('tech')+section('osint')+section('trends')+section('sme')+section('events')+section('eco')+
      '</div>'+
      '<div class="br-reader" id="briefReader" aria-hidden="true"></div>';
    document.body.appendChild(brief);
    reader=brief.querySelector('#briefReader');
    brief.querySelector('[data-br-close]').addEventListener('click', closeBrief);
    brief.querySelectorAll('[data-art]').forEach(function(b){ b.addEventListener('click', function(){ openArt(b.dataset.art); }); });
  }

  function openArt(id){
    var a=ART.find(function(x){return x.id===id;}); if(!a) return;
    reader.innerHTML =
      '<div class="br-rd-scroll">'+
        '<button class="br-back" data-rd-back>← Back to the issue</button>'+
        '<div class="br-rd-kick">'+a.kicker+' · '+(CATS[a.cat]||'')+'</div>'+
        '<h1 class="br-rd-ti">'+a.title+'</h1>'+
        '<p class="br-rd-dek">'+a.dek+'</p>'+
        '<div class="br-rd-meta"><span class="br-clr">'+a.clr+'</span><span>'+a.author+' · '+a.role+'</span><span>'+a.read+' read</span></div>'+
        '<image-slot id="brief-img-'+a.id+'" shape="rounded" radius="14" class="br-rd-img" placeholder="Article image — drop to upload"></image-slot>'+
        '<div class="br-rd-body">'+a.body.map(function(p){return '<p>'+p+'</p>';}).join('')+'</div>'+
        '<div class="br-rd-src"><div class="br-rd-src-k">SOURCES</div><ul>'+a.sources.map(function(s){return '<li>'+esc(s)+'</li>';}).join('')+'</ul>'+
          '<p class="br-rd-note">Compiled from open sources and reviewed for public release. Figures and attributions are illustrative.</p></div>'+
      '</div>';
    reader.classList.add('open'); reader.setAttribute('aria-hidden','false'); reader.scrollTop=0;
    reader.querySelector('[data-rd-back]').addEventListener('click', function(){ reader.classList.remove('open'); reader.setAttribute('aria-hidden','true'); });
  }

  function openBrief(){ build(); brief.classList.add('open'); brief.setAttribute('aria-hidden','false'); document.body.style.overflow='hidden'; }
  function closeBrief(){ brief.classList.remove('open'); brief.setAttribute('aria-hidden','true'); if(reader){ reader.classList.remove('open'); } document.body.style.overflow=''; }
  window.openBrief=openBrief;

  function wire(){ document.querySelectorAll('[data-open-brief]').forEach(function(b){ if(b.dataset.w) return; b.dataset.w='1'; b.addEventListener('click', function(e){ e.preventDefault(); openBrief(); }); }); }
  document.addEventListener('keydown', function(e){ if(e.key==='Escape' && brief && brief.classList.contains('open')){ if(reader.classList.contains('open')){ reader.classList.remove('open'); } else closeBrief(); } });
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded', wire); else wire();

  function injectStyle(){
    if(document.getElementById('cvx-brief-style')) return;
    var s=document.createElement('style'); s.id='cvx-brief-style';
    s.textContent = `
    .cvx-brief{ position:fixed; inset:0; z-index:710; background:var(--bg); color:var(--ink); display:none; overflow-y:auto; font-family:'Manrope',system-ui,sans-serif; }
    .cvx-brief.open{ display:block; }
    .br-bar{ position:sticky; top:0; z-index:6; display:flex; align-items:center; gap:14px; padding:14px 30px; background:color-mix(in srgb,var(--bg) 86%,transparent); backdrop-filter:blur(14px); border-bottom:1px solid var(--line); }
    .br-brand{ font-family:'JetBrains Mono',monospace; font-weight:800; letter-spacing:.18em; font-size:13px; color:var(--ink); }
    .br-iss{ font-family:'JetBrains Mono',monospace; font-size:10.5px; letter-spacing:.08em; color:var(--pf-convexus); }
    .br-close{ margin-left:auto; width:34px; height:34px; border-radius:9px; border:1px solid var(--line); background:var(--paper); color:var(--ink); cursor:pointer; display:grid; place-items:center; }
    .br-scroll{ max-width:1100px; margin:0 auto; padding:34px 30px 90px; }
    .br-mast{ text-align:center; max-width:680px; margin:0 auto 30px; padding-bottom:28px; border-bottom:2px solid var(--ink); }
    .br-mast-k{ font-family:'JetBrains Mono',monospace; font-size:9.5px; font-weight:700; letter-spacing:.18em; color:var(--muted); }
    .br-mast h1{ font-family:'Instrument Serif',serif; font-weight:400; font-size:clamp(40px,6vw,66px); line-height:1.02; margin:14px 0 0; letter-spacing:-.01em; }
    .br-mast h1 em{ font-style:italic; color:var(--pf-convexus); }
    .br-mast p{ font-size:14.5px; color:var(--ink-2); line-height:1.6; margin:14px auto 0; max-width:600px; }
    .br-lead{ display:grid; grid-template-columns:1.3fr 1fr; gap:24px; align-items:center; width:100%; text-align:left; font:inherit; cursor:pointer; background:var(--paper); border:1px solid var(--line); border-radius:18px; padding:26px; margin-bottom:38px; transition:border-color .15s, box-shadow .18s, transform .15s; }
    .br-lead:hover{ border-color:color-mix(in srgb,var(--pf-convexus) 50%,var(--line)); transform:translateY(-3px); box-shadow:0 26px 54px -34px color-mix(in srgb,var(--pf-convexus) 60%,transparent); }
    .br-lead h2{ font-family:'Instrument Serif',serif; font-weight:400; font-size:clamp(26px,3.4vw,40px); line-height:1.08; margin:12px 0 10px; letter-spacing:-.01em; color:var(--ink); }
    .br-lead p{ font-size:15px; color:var(--ink-2); line-height:1.55; margin:0 0 14px; }
    .br-lead-r{ width:100%; height:230px; display:block; }
    .br-kick{ display:inline-block; font-family:'JetBrains Mono',monospace; font-size:9px; font-weight:800; letter-spacing:.14em; color:var(--pf-convexus); }
    .br-meta{ display:block; font-family:'JetBrains Mono',monospace; font-size:9.5px; letter-spacing:.04em; color:var(--muted); }
    .br-clr{ color:#16A34A; font-weight:700; }
    .br-sec{ margin-top:34px; }
    .br-sec-h{ border-bottom:1px solid var(--ink); padding-bottom:8px; margin-bottom:16px; }
    .br-sec-k{ font-family:'JetBrains Mono',monospace; font-size:11px; font-weight:800; letter-spacing:.14em; color:var(--ink); text-transform:uppercase; }
    .br-grid{ display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:18px; }
    .br-card{ display:flex; flex-direction:column; gap:8px; text-align:left; font:inherit; cursor:pointer; background:none; border:0; border-top:2px solid transparent; padding:4px 0 0; transition:border-color .15s; }
    .br-card:hover{ border-top-color:var(--pf-convexus); }
    .br-card:hover .br-ti{ color:var(--pf-convexus); }
    .br-ti{ font-family:'Instrument Serif',serif; font-size:23px; font-weight:400; line-height:1.12; color:var(--ink); letter-spacing:-.01em; transition:color .15s; }
    .br-dek{ font-size:13.5px; color:var(--ink-2); line-height:1.5; }
    /* Reader */
    .br-reader{ position:fixed; inset:0; z-index:8; background:var(--bg); overflow-y:auto; display:none; }
    .br-reader.open{ display:block; }
    .br-rd-scroll{ max-width:720px; margin:0 auto; padding:34px 30px 100px; }
    .br-back{ font:inherit; font-size:12px; font-weight:700; color:var(--pf-convexus); background:none; border:0; cursor:pointer; padding:6px 0; margin-bottom:18px; }
    .br-rd-kick{ font-family:'JetBrains Mono',monospace; font-size:10px; font-weight:800; letter-spacing:.14em; color:var(--pf-convexus); }
    .br-rd-ti{ font-family:'Instrument Serif',serif; font-weight:400; font-size:clamp(32px,5vw,50px); line-height:1.05; margin:12px 0 14px; letter-spacing:-.01em; }
    .br-rd-dek{ font-size:18px; color:var(--ink-2); line-height:1.5; margin:0 0 18px; }
    .br-rd-meta{ display:flex; flex-wrap:wrap; gap:8px 18px; padding:14px 0; border-top:1px solid var(--line); border-bottom:1px solid var(--line); font-family:'JetBrains Mono',monospace; font-size:10px; letter-spacing:.04em; color:var(--muted); }
    .br-rd-img{ width:100%; height:300px; display:block; margin:22px 0; }
    .br-rd-body p{ font-size:16.5px; line-height:1.72; color:var(--ink); margin:0 0 18px; }
    .br-rd-body p:first-child::first-letter{ font-family:'Instrument Serif',serif; font-size:62px; line-height:.8; float:left; padding:6px 12px 0 0; color:var(--pf-convexus); }
    .br-rd-src{ margin-top:26px; padding-top:18px; border-top:1px solid var(--line); }
    .br-rd-src-k{ font-family:'JetBrains Mono',monospace; font-size:9.5px; font-weight:800; letter-spacing:.12em; color:var(--muted); margin-bottom:10px; }
    .br-rd-src ul{ list-style:none; margin:0; padding:0; display:flex; flex-direction:column; gap:6px; }
    .br-rd-src li{ position:relative; padding-left:16px; font-size:13px; color:var(--ink-2); }
    .br-rd-src li::before{ content:""; position:absolute; left:3px; top:8px; width:4px; height:4px; border-radius:50%; background:var(--pf-convexus); }
    .br-rd-note{ font-size:12px; color:var(--muted); font-style:italic; margin-top:14px; line-height:1.5; }
    @media(max-width:720px){ .br-lead{ grid-template-columns:1fr; } .br-lead-r{ height:180px; order:-1; } }
    `;
    document.head.appendChild(s);
  }
})();
