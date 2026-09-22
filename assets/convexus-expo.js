/* ============================================================================
   Convexus Expo — always-on digital fair (separate full-screen experience)
   Reads the shared catalog data from window.CVX (set by convexus-catalog.js).
   Pavilions + spotlight + live ticker + live-now booths + visitor counter
   + upcoming demos + booth detail (one-pager, downloads, demos, provenance).
   ============================================================================ */
(function(){
  'use strict';
  var built=false, expoEl, boothEl, visitors=0, spotIdx=0, spotTimer=null, visTimer=null;

  function cvx(){ return window.CVX || null; }
  function hash(s){ var h=0; for(var i=0;i<s.length;i++) h=(h*31+s.charCodeAt(i))>>>0; return h; }
  function esc(t){ return String(t).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];}); }

  // ---- Per-firm expo extras (deterministic) ----
  var DAYS=['Mon','Tue','Wed','Thu','Fri'];
  function extras(d){
    var h=hash(d.id), live=(h%4===0);
    return {
      live: live,
      demos: [
        { t:'Live capability demonstration', day:DAYS[h%5], time:(9+(h%6))+':00', live:live },
        { t:'Technical deep-dive webinar',    day:DAYS[(h+2)%5], time:(13+(h%4))+':30', live:false }
      ],
      downloads: ['Capability datasheet (PDF)','Interoperability brief (PDF)', d.tested?'Test &amp; evaluation summary (PDF)':'Concept overview (PDF)'],
      refs: (function(){ var r=[]; if(d.tested) r.push('Validated in an independent field trial (2025)'); if(d.verified) r.push('Reference customer in a regulated sector'); if(!r.length) r.push('Featured in an innovation challenge'); r.push('Listed in the Convexus capability catalog'); return r; })()
    };
  }

  // ---- Live activity ticker ----
  function tickerEvents(){
    var C=cvx(), D=C.DATA, out=[];
    D.forEach(function(d){
      var x=extras(d);
      if(x.live) out.push(['live', d.name+' is demonstrating now in the '+d.domain+' pavilion']);
    });
    // sample a spread of ambient events
    for(var i=0;i<D.length;i+=3){
      var d=D[i];
      out.push(['', (3+hash(d.id)%18)+' visitors viewing '+d.name]);
    }
    for(var j=1;j<D.length;j+=5){
      var e=D[j];
      out.push(['', e.name+' published a new datasheet']);
    }
    for(var k=2;k<D.length;k+=6){
      var f=D[k];
      out.push(['', f.name+' joined the '+f.challenge+' pavilion']);
    }
    // shuffle deterministically-ish
    return out.sort(function(a,b){ return (a[1].length%7)-(b[1].length%7); });
  }
  function renderTicker(){
    var evs=tickerEvents();
    var html=evs.map(function(e){ return '<span class="ev'+(e[0]==='live'?' live':'')+'">'+esc(e[1])+'</span>'; }).join('');
    expoEl.querySelector('#expoTicker').innerHTML = html+html; // duplicate for seamless loop
  }

  // ---- Spotlight ----
  function featured(){ var D=cvx().DATA; var f=D.filter(function(d){return d.verified&&d.tested;}); return f.length?f:D; }
  function renderSpotlight(){
    var C=cvx(), list=featured(), d=list[spotIdx%list.length], x=extras(d);
    var el=expoEl.querySelector('#expoSpot');
    el.innerHTML =
      '<div class="sp-main">'+
        '<div class="sp-k">★ PROVIDER OF THE WEEK</div>'+
        '<div class="sp-id"><span class="xa" style="--tc:'+C.TYPE_COLOR[d.type]+'">'+C.initials(d.name)+'</span>'+
          '<div><div class="sp-nm">'+d.name+'</div><div class="sp-ty" style="--tc:'+C.TYPE_COLOR[d.type]+'"><i></i>'+C.TYPE_LABEL[d.type]+' · '+d.city+', '+d.country+'</div></div>'+
          (x.live?'<span class="xlive">● LIVE</span>':'')+'</div>'+
        '<p class="sp-desc">'+d.desc+'</p>'+
        '<div class="sp-tags"><span>'+d.domain+'</span><span>'+d.challenge+'</span><span>TRL '+d.trl+'</span></div>'+
        '<button class="sp-go" data-booth="'+d.id+'">Enter booth →</button>'+
      '</div>'+
      '<div class="sp-side">'+
        '<div class="sp-side-k">NEXT AT THIS BOOTH</div>'+
        x.demos.map(function(dm){ return '<div class="sp-demo"><span class="dt">'+dm.day+' '+dm.time+(dm.live?' · <b>LIVE</b>':'')+'</span><span class="dn">'+dm.t+'</span></div>'; }).join('')+
      '</div>';
    el.querySelector('[data-booth]').addEventListener('click', function(){ openBooth(d.id); });
  }

  // ---- Upcoming demos ----
  function renderUpcoming(){
    var C=cvx(), items=[];
    C.DATA.forEach(function(d){ var x=extras(d); x.demos.forEach(function(dm){ items.push({d:d,dm:dm}); }); });
    items.sort(function(a,b){ return (b.dm.live?1:0)-(a.dm.live?1:0); });
    var html = items.slice(0,8).map(function(it){
      return '<button class="uc" data-booth="'+it.d.id+'">'+
        '<div class="uc-t">'+(it.dm.live?'<span class="xlive">● LIVE NOW</span>':'<span class="uc-dt">'+it.dm.day+' · '+it.dm.time+'</span>')+'</div>'+
        '<div class="uc-ti">'+it.dm.t+'</div>'+
        '<div class="uc-nm">'+it.d.name+'</div>'+
      '</button>';
    }).join('');
    var el=expoEl.querySelector('#expoUp'); el.innerHTML=html;
    el.querySelectorAll('[data-booth]').forEach(function(b){ b.addEventListener('click', function(){ openBooth(b.dataset.booth); }); });
  }

  // ---- Pavilions ----
  function renderPavilions(){
    var C=cvx(), D=C.DATA, byDom={};
    D.forEach(function(d){ (byDom[d.domain]=byDom[d.domain]||[]).push(d); });
    var doms=Object.keys(byDom).sort();
    var html=doms.map(function(dom){
      var firms=byDom[dom];
      var liveCt=firms.filter(function(d){return extras(d).live;}).length;
      var booths=firms.map(function(d){
        var x=extras(d);
        return '<button class="bc" data-booth="'+d.id+'" style="--tc:'+C.TYPE_COLOR[d.type]+'">'+
          '<div class="bc-top"><span class="xa" style="--tc:'+C.TYPE_COLOR[d.type]+'">'+C.initials(d.name)+'</span>'+
            (x.live?'<span class="xlive">● LIVE</span>':'')+'</div>'+
          '<div class="bc-nm">'+d.name+'</div>'+
          '<div class="bc-ty" style="--tc:'+C.TYPE_COLOR[d.type]+'"><i></i>'+C.TYPE_LABEL[d.type]+'</div>'+
          '<div class="bc-desc">'+d.desc+'</div>'+
          '<div class="bc-go">Enter booth →</div>'+
        '</button>';
      }).join('');
      return '<section class="expo-pav">'+
        '<div class="expo-pav-h"><span class="nm">'+dom+'</span><span class="ct">'+firms.length+' booths'+(liveCt?' · '+liveCt+' live':'')+'</span></div>'+
        '<div class="expo-booths">'+booths+'</div></section>';
    }).join('');
    var el=expoEl.querySelector('#expoPavs'); el.innerHTML=html;
    el.querySelectorAll('[data-booth]').forEach(function(b){ b.addEventListener('click', function(){ openBooth(b.dataset.booth); }); });
  }

  // ---- Booth detail ----
  function openBooth(id){
    var C=cvx(), d=C.DATA.find(function(x){return x.id===id;}); if(!d) return;
    var x=extras(d), pf=C.pathwaysFor(d), proc=pf.procurement==='open';
    var mk=C.marketInfo(d), lt=C.localTime(d.country), web=C.websiteOf(d), anns=C.announcements(d), rstars=C.stars(mk.rating);
    boothEl.innerHTML =
      '<div class="xb-head" style="--tc:'+C.TYPE_COLOR[d.type]+'">'+
        '<button class="xb-x" data-x>✕</button>'+
        '<span class="xa lg" style="--tc:'+C.TYPE_COLOR[d.type]+'">'+C.initials(d.name)+'</span>'+
        '<div><div class="xb-nm">'+d.name+(x.live?' <span class="xlive">● LIVE</span>':'')+'</div>'+
          '<div class="sp-ty" style="--tc:'+C.TYPE_COLOR[d.type]+'"><i></i>'+C.TYPE_LABEL[d.type]+' · '+d.city+', '+d.country+'</div>'+
          '<div class="xb-meta2"><span class="cvx-stars">'+rstars+'</span> <b>'+mk.rating.toFixed(1)+'</b> · '+mk.reviews+' reviews'+(mk.verified?' · <span class="xb-vp">✓ Verified</span>':'')+'</div></div>'+
      '</div>'+
      '<div class="xb-body">'+
        (proc?'<div class="xb-proc">✓ Procurement-ready · open to engagement</div>':'')+
        '<p class="xb-desc">'+d.desc+'</p>'+
        '<div class="xb-media"><image-slot id="firm-media-'+d.id+'" shape="rounded" radius="12" style="width:100%;height:152px;display:block" placeholder="Provider image — drop to upload"></image-slot><div class="xb-vid"><span class="pl">▶</span>Demo reel</div></div>'+
        '<div class="xb-links"><a class="xb-web" href="https://'+web+'" target="_blank" rel="noopener">↗ '+web+'</a><span class="xb-clock" data-tz="'+lt.tz+'">◷ Local time '+lt.time+'</span></div>'+
        '<div class="xb-k">Capabilities</div><div class="xb-caps">'+d.caps.map(function(c){return '<span>'+c+'</span>';}).join('')+'</div>'+
        '<div class="xb-k">Live demos &amp; webinars</div><div class="xb-demos">'+
          x.demos.map(function(dm){ return '<div class="xb-demo"><span class="dt">'+dm.day+' '+dm.time+'</span><span class="dn">'+dm.t+'</span>'+(dm.live?'<span class="xlive">● LIVE</span>':'<button class="xb-rsvp" data-rsvp>Remind me</button>')+'</div>'; }).join('')+
        '</div>'+
        '<div class="xb-k">One-pager &amp; materials</div><div class="xb-dls">'+
          x.downloads.map(function(f){ return '<button class="xb-dl" data-dl><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12M7 10l5 5 5-5M5 21h14"/></svg>'+f+'</button>'; }).join('')+
        '</div>'+
        '<div class="xb-k">Announcements &amp; updates</div><div class="xb-anns">'+anns.map(function(a){ return '<div class="xb-ann"><span class="an-tag">'+a.tag+'</span><span class="an-tx">'+a.text+'</span><span class="an-ago">'+a.ago+'</span></div>'; }).join('')+'</div>'+
        '<div class="xb-k">Provenance &amp; references</div>'+
        '<div class="xb-prov">'+C.provBadges(d)+'</div>'+
        '<ul class="xb-refs">'+x.refs.map(function(r){return '<li>'+r+'</li>';}).join('')+'</ul>'+
        '<div class="xb-k">Ratings &amp; reviews</div><div class="xb-rev-top">'+rstars+' <b>'+mk.rating.toFixed(1)+'</b> · '+mk.reviews+' reviews</div>'+
        '<div class="xb-revs">'+mk.list.map(function(rv){ return '<div class="xb-rev"><div class="rv-h"><span class="rv-a">'+rv.author+'</span><span class="rv-s cvx-stars">'+C.stars(rv.stars)+'</span></div><div class="rv-t">\u201c'+rv.text+'\u201d</div></div>'; }).join('')+'</div>'+
        '<div class="xb-k">Engagement pathways</div><div class="xb-paths">'+
          C.PATHS.map(function(p){ var st=pf[p[0]]; return '<span class="pp '+st+'"><b>'+p[2]+'</b><i>'+st+'</i></span>'; }).join('')+
        '</div>'+
      '</div>'+
      '<div class="xb-foot"><button class="xb-contact" data-contact>Request intro &amp; contact</button></div>';
    boothEl.classList.add('open'); boothEl.scrollTop=0;
    boothEl.querySelector('[data-x]').addEventListener('click', closeBooth);
    boothEl.querySelectorAll('[data-dl]').forEach(function(b){ b.addEventListener('click', function(){ b.classList.add('done'); b.lastChild.textContent=' Downloaded ✓'; }); });
    boothEl.querySelectorAll('[data-rsvp]').forEach(function(b){ b.addEventListener('click', function(){ b.textContent='Reminder set ✓'; b.disabled=true; }); });
    var ct=boothEl.querySelector('[data-contact]'); if(ct) ct.addEventListener('click', function(){ ct.textContent='Intro requested ✓'; ct.classList.add('done'); ct.disabled=true; });
  }
  function closeBooth(){ boothEl.classList.remove('open'); }

  // ---- Hero stat chips ----
  function renderChips(){
    var C=cvx(), D=C.DATA;
    var doms={}; D.forEach(function(d){ doms[d.domain]=1; });
    var liveCt=D.filter(function(d){return extras(d).live;}).length;
    expoEl.querySelector('#expoChips').innerHTML =
      chip(D.length,'Booths open')+chip(Object.keys(doms).length,'Pavilions')+
      chip(liveCt,'Live right now')+'<div class="expo-chip"><div class="v" id="expoVisChip">'+visitors+'</div><div class="k">Visitors today</div></div>';
  }
  function chip(v,k){ return '<div class="expo-chip"><div class="v">'+v+'</div><div class="k">'+k+'</div></div>'; }

  // ---- Build overlay ----
  function build(){
    if(built) return; built=true;
    injectStyle();
    expoEl=document.createElement('div'); expoEl.className='cvx-expo'; expoEl.id='convexusExpo'; expoEl.setAttribute('aria-hidden','true');
    expoEl.innerHTML =
      '<div class="expo-bar">'+
        '<span class="xb-brand"><svg width="22" height="22" viewBox="0 0 100 100" fill="none"><path d="M 76.2 68.4 A 32 32 0 1 1 76.2 31.6" stroke="var(--pf-convexus)" stroke-width="7" stroke-linecap="round"/><circle cx="50" cy="50" r="4" fill="var(--pf-convexus)"/></svg> CONVEXUS EXPO</span>'+
        '<span class="xb-live"><i></i> LIVE</span>'+
        '<span class="xb-vis">Visitors today · <b id="expoVis">0</b></span>'+
        '<button class="xb-close" data-expo-close aria-label="Close expo"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg></button>'+
      '</div>'+
      '<div class="expo-ticker"><div class="expo-ticker-track" id="expoTicker"></div></div>'+
      '<div class="expo-scroll">'+
        '<header class="expo-hero"><h1>The always-on <em>capability expo.</em></h1>'+
          '<p>A continuously living digital fair — every provider in the ecosystem has a booth. Walk the pavilions, catch a live demo, and open a pathway, any time.</p>'+
          '<div class="expo-chips" id="expoChips"></div></header>'+
        '<div class="expo-sec-h"><span class="expo-sec-k">SPOTLIGHT</span><h2>In focus this week</h2></div>'+
        '<div class="expo-spot" id="expoSpot"></div>'+
        '<div class="expo-sec-h"><span class="expo-sec-k">HAPPENING</span><h2>Upcoming &amp; live demos</h2></div>'+
        '<div class="expo-up" id="expoUp"></div>'+
        '<div class="expo-sec-h"><span class="expo-sec-k">PAVILIONS</span><h2>Walk the floor</h2></div>'+
        '<div id="expoPavs"></div>'+
      '</div>'+
      '<aside class="expo-booth" id="expoBooth" aria-label="Booth"></aside>';
    document.body.appendChild(expoEl);
    boothEl=expoEl.querySelector('#expoBooth');
    expoEl.querySelector('[data-expo-close]').addEventListener('click', closeExpo);
    visitors = 240 + (hash('expo')%170);
    renderChips(); renderTicker(); renderSpotlight(); renderUpcoming(); renderPavilions();
  }

  function tickVisitors(){
    visitors += 1 + Math.floor(Math.random()*3);
    var a=expoEl.querySelector('#expoVis'), b=expoEl.querySelector('#expoVisChip');
    if(a) a.textContent=visitors; if(b) b.textContent=visitors;
  }

  function openExpo(){
    if(!cvx()){ return; }
    build();
    expoEl.classList.add('open'); expoEl.setAttribute('aria-hidden','false');
    document.body.style.overflow='hidden';
    renderChips();
    var motion=!document.documentElement.classList.contains('motion-off');
    if(motion){
      visTimer=setInterval(tickVisitors, 4200);
      spotTimer=setInterval(function(){ spotIdx++; renderSpotlight(); }, 9000);
    }
  }
  function closeExpo(){
    expoEl.classList.remove('open'); expoEl.setAttribute('aria-hidden','true');
    closeBooth();
    document.body.style.overflow='';
    if(visTimer){ clearInterval(visTimer); visTimer=null; }
    if(spotTimer){ clearInterval(spotTimer); spotTimer=null; }
  }
  window.openConvexusExpo = openExpo;

  // Live local-time clocks (firm country) — refresh every 30s
  setInterval(function(){
    document.querySelectorAll('[data-tz]').forEach(function(el){
      try{ var t=new Intl.DateTimeFormat('en-GB',{hour:'2-digit',minute:'2-digit',timeZone:el.dataset.tz}).format(new Date());
        el.textContent = el.textContent.replace(/[0-9]{2}:[0-9]{2}\s*$/, t); }catch(e){}
    });
  }, 30000);

  function wireBtn(){
    var b=document.getElementById('cvxExpoBtn');
    if(b && !b.dataset.w){ b.dataset.w='1'; b.addEventListener('click', openExpo); }
  }
  document.addEventListener('keydown', function(e){ if(e.key==='Escape' && expoEl && expoEl.classList.contains('open')){ if(boothEl.classList.contains('open')) closeBooth(); else closeExpo(); } });
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded', wireBtn); else wireBtn();

  // ---- Styles ----
  function injectStyle(){
    if(document.getElementById('cvx-expo-style')) return;
    var s=document.createElement('style'); s.id='cvx-expo-style';
    s.textContent = `
    .cvx-expo{ position:fixed; inset:0; z-index:700; background:var(--bg); color:var(--ink); display:none; overflow-y:auto; font-family:'Manrope',system-ui,sans-serif; }
    .cvx-expo.open{ display:block; }
    .cvx-expo .xa{ width:38px;height:38px;flex:none;border-radius:10px;display:grid;place-items:center;font-family:'JetBrains Mono',monospace;font-weight:800;font-size:12px;color:var(--tc);background:color-mix(in srgb,var(--tc) 14%,var(--paper));border:1px solid color-mix(in srgb,var(--tc) 30%,var(--line)); }
    .cvx-expo .xa.lg{ width:52px;height:52px;font-size:16px;border-radius:13px; }
    .cvx-expo .xlive{ display:inline-flex;align-items:center;gap:5px;font-family:'JetBrains Mono',monospace;font-size:8.5px;font-weight:800;letter-spacing:.06em;color:#16A34A; }
    .expo-bar{ position:sticky; top:0; z-index:6; display:flex; align-items:center; gap:14px; padding:13px 26px; background:color-mix(in srgb,var(--bg) 86%,transparent); backdrop-filter:blur(14px); border-bottom:1px solid var(--line); }
    .expo-bar .xb-brand{ display:flex;align-items:center;gap:9px;font-family:'JetBrains Mono',monospace;font-weight:800;letter-spacing:.14em;font-size:13px;color:var(--ink); }
    .expo-bar .xb-live{ display:inline-flex;align-items:center;gap:6px;font-family:'JetBrains Mono',monospace;font-size:9.5px;font-weight:700;letter-spacing:.1em;color:#16A34A; }
    .expo-bar .xb-live i{ width:7px;height:7px;border-radius:50%;background:#16A34A;animation:expoBlink 1.6s infinite; }
    .expo-bar .xb-vis{ margin-left:auto;font-family:'JetBrains Mono',monospace;font-size:11px;color:var(--muted); }
    .expo-bar .xb-vis b{ color:var(--ink); }
    .expo-bar .xb-close{ width:34px;height:34px;border-radius:9px;border:1px solid var(--line);background:var(--paper);color:var(--ink);cursor:pointer;display:grid;place-items:center; }
    @keyframes expoBlink{0%,100%{opacity:1}50%{opacity:.3}}
    html.motion-off .expo-bar .xb-live i{animation:none}
    .expo-ticker{ overflow:hidden; border-bottom:1px solid var(--line); background:var(--paper); }
    .expo-ticker-track{ display:inline-flex; gap:34px; white-space:nowrap; padding:9px 26px; animation:expoMarq 92s linear infinite; }
    html.motion-off .expo-ticker-track{ animation:none; }
    @keyframes expoMarq{ from{transform:translateX(0)} to{transform:translateX(-50%)} }
    .expo-ticker .ev{ font-size:11.5px; color:var(--ink-2); display:inline-flex; align-items:center; gap:8px; }
    .expo-ticker .ev::before{ content:""; width:5px;height:5px;border-radius:50%;background:var(--pf-convexus); flex:none; }
    .expo-ticker .ev.live::before{ background:#16A34A; }
    .expo-scroll{ max-width:1280px; margin:0 auto; padding:32px 26px 90px; }
    .expo-hero h1{ font-family:'Instrument Serif',serif;font-weight:400;font-size:clamp(34px,5vw,54px);line-height:1.04;margin:0;letter-spacing:-.01em; }
    .expo-hero h1 em{ font-style:italic;color:var(--pf-convexus); }
    .expo-hero p{ font-size:15px;color:var(--ink-2);max-width:620px;margin:13px 0 0;line-height:1.55; }
    .expo-chips{ display:flex;flex-wrap:wrap;gap:11px;margin:22px 0 0; }
    .expo-chip{ position:relative;background:var(--paper);border:1px solid var(--line);border-radius:13px;padding:13px 17px;overflow:hidden; }
    .expo-chip::before{ content:"";position:absolute;left:0;top:0;height:2px;width:100%;background:linear-gradient(90deg,var(--pf-convexus),transparent); }
    .expo-chip .v{ font-family:'JetBrains Mono',monospace;font-size:21px;font-weight:800;color:var(--ink);line-height:1; }
    .expo-chip .k{ font-family:'JetBrains Mono',monospace;font-size:9px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted);margin-top:6px; }
    .expo-sec-h{ display:flex;align-items:baseline;gap:13px;margin:38px 0 15px; }
    .expo-sec-k{ font-family:'JetBrains Mono',monospace;font-size:9.5px;font-weight:800;letter-spacing:.14em;color:var(--pf-convexus); }
    .expo-sec-h h2{ font-size:21px;font-weight:800;margin:0;letter-spacing:-.01em;color:var(--ink); }
    .expo-spot{ display:grid;grid-template-columns:1.5fr 1fr;background:var(--paper);border:1px solid var(--line);border-radius:18px;overflow:hidden; }
    .sp-main{ padding:24px 26px;border-right:1px solid var(--line); }
    .sp-k{ font-family:'JetBrains Mono',monospace;font-size:9.5px;font-weight:800;letter-spacing:.12em;color:var(--pf-convexus);margin-bottom:14px; }
    .sp-id{ display:flex;align-items:center;gap:12px; }
    .sp-nm{ font-size:20px;font-weight:800;color:var(--ink);letter-spacing:-.01em; }
    .sp-ty{ display:inline-flex;align-items:center;gap:6px;font-family:'JetBrains Mono',monospace;font-size:9.5px;font-weight:700;letter-spacing:.04em;color:var(--tc);margin-top:3px; }
    .sp-ty i{ width:6px;height:6px;border-radius:50%;background:var(--tc); }
    .sp-id .xlive{ margin-left:auto; }
    .sp-desc{ font-size:14px;color:var(--ink-2);line-height:1.6;margin:15px 0; }
    .sp-tags{ display:flex;flex-wrap:wrap;gap:6px;margin-bottom:18px; }
    .sp-tags span{ font-size:11px;color:var(--ink-2);background:var(--paper-2);border:1px solid var(--line);border-radius:7px;padding:3px 10px; }
    .sp-go{ font:inherit;font-size:13px;font-weight:700;color:#fff;background:var(--pf-convexus);border:0;border-radius:10px;padding:11px 20px;cursor:pointer; }
    .sp-side{ padding:24px 22px;background:var(--paper-2);display:flex;flex-direction:column;gap:11px; }
    .sp-side-k{ font-family:'JetBrains Mono',monospace;font-size:9px;font-weight:800;letter-spacing:.1em;color:var(--muted); }
    .sp-demo{ display:flex;flex-direction:column;gap:2px;padding:11px 13px;background:var(--paper);border:1px solid var(--line);border-radius:10px; }
    .sp-demo .dt{ font-family:'JetBrains Mono',monospace;font-size:10px;font-weight:700;color:var(--pf-convexus); }
    .sp-demo .dt b{ color:#16A34A; }
    .sp-demo .dn{ font-size:12.5px;color:var(--ink-2); }
    .expo-up{ display:flex;gap:12px;overflow-x:auto;padding-bottom:8px; }
    .expo-up .uc{ flex:0 0 232px;text-align:left;font:inherit;cursor:pointer;background:var(--paper);border:1px solid var(--line);border-radius:13px;padding:15px;transition:border-color .15s,transform .15s; }
    .expo-up .uc:hover{ border-color:color-mix(in srgb,var(--pf-convexus) 45%,var(--line));transform:translateY(-3px); }
    .uc-dt{ font-family:'JetBrains Mono',monospace;font-size:10px;font-weight:700;color:var(--pf-convexus); }
    .uc-ti{ font-size:13.5px;font-weight:700;color:var(--ink);margin:8px 0 4px;line-height:1.3; }
    .uc-nm{ font-size:11.5px;color:var(--muted); }
    .expo-pav{ margin-top:20px; }
    .expo-pav-h{ display:flex;align-items:center;gap:11px;margin-bottom:12px;padding-bottom:9px;border-bottom:1px solid var(--line); }
    .expo-pav-h .nm{ font-size:15px;font-weight:800;color:var(--ink); }
    .expo-pav-h .ct{ font-family:'JetBrains Mono',monospace;font-size:10px;color:var(--muted); }
    .expo-booths{ display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px; }
    .bc{ position:relative;text-align:left;font:inherit;cursor:pointer;background:var(--paper);border:1px solid var(--line);border-radius:15px;padding:15px;display:flex;flex-direction:column;gap:8px;transition:border-color .18s,box-shadow .18s,transform .18s; }
    .bc::before{ content:"";position:absolute;left:15px;right:15px;top:-1px;height:2px;border-radius:2px;background:var(--tc);opacity:0;transition:opacity .18s; }
    .bc:hover{ border-color:color-mix(in srgb,var(--tc) 50%,var(--line));transform:translateY(-4px);box-shadow:0 22px 44px -28px color-mix(in srgb,var(--tc) 65%,transparent); }
    .bc:hover::before{ opacity:1; }
    .bc-top{ display:flex;align-items:flex-start;justify-content:space-between; }
    .bc-nm{ font-size:14.5px;font-weight:800;color:var(--ink);letter-spacing:-.01em; }
    .bc-ty{ display:inline-flex;align-items:center;gap:5px;font-family:'JetBrains Mono',monospace;font-size:8.5px;font-weight:700;letter-spacing:.04em;color:var(--tc); }
    .bc-ty i{ width:5px;height:5px;border-radius:50%;background:var(--tc); }
    .bc-desc{ font-size:11.5px;color:var(--ink-2);line-height:1.5; }
    .bc-go{ margin-top:auto;font-size:11px;font-weight:700;color:var(--pf-convexus); }
    .expo-booth{ position:fixed;top:0;right:0;bottom:0;width:470px;max-width:94vw;background:var(--paper);border-left:1px solid var(--line);box-shadow:-30px 0 60px -30px rgba(8,16,34,.4);z-index:720;transform:translateX(103%);transition:transform .28s cubic-bezier(.4,0,.1,1);overflow-y:auto;display:flex;flex-direction:column; }
    .expo-booth.open{ transform:translateX(0); }
    .xb-head{ position:sticky;top:0;display:flex;align-items:center;gap:13px;padding:20px 22px;background:var(--paper);border-bottom:1px solid var(--line); }
    .xb-x{ position:absolute;top:16px;right:18px;font:inherit;font-size:15px;color:var(--muted);background:none;border:0;cursor:pointer; }
    .xb-nm{ font-size:19px;font-weight:800;color:var(--ink);letter-spacing:-.015em;display:flex;align-items:center;gap:9px; }
    .xb-body{ padding:20px 22px;flex:1; }
    .xb-proc{ font-size:11.5px;font-weight:700;color:#16A34A;background:color-mix(in srgb,#16A34A 10%,var(--paper));border:1px solid color-mix(in srgb,#16A34A 28%,var(--line));border-radius:9px;padding:9px 13px;margin-bottom:14px; }
    .xb-desc{ font-size:14px;color:var(--ink-2);line-height:1.6;margin:0 0 6px; }
    .xb-k{ font-family:'JetBrains Mono',monospace;font-size:9px;font-weight:800;letter-spacing:.12em;color:var(--muted);text-transform:uppercase;margin:18px 0 9px; }
    .xb-caps{ display:flex;flex-wrap:wrap;gap:6px; }
    .xb-caps span{ font-size:11.5px;color:var(--ink-2);background:var(--paper-2);border:1px solid var(--line);border-radius:7px;padding:4px 10px; }
    .xb-demos{ display:flex;flex-direction:column;gap:7px; }
    .xb-demo{ display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid var(--line);border-radius:9px; }
    .xb-demo .dt{ font-family:'JetBrains Mono',monospace;font-size:10px;font-weight:700;color:var(--pf-convexus);flex:none;width:84px; }
    .xb-demo .dn{ font-size:12.5px;color:var(--ink-2);flex:1; }
    .xb-rsvp{ font:inherit;font-size:10.5px;font-weight:700;color:var(--pf-convexus);background:none;border:1px solid var(--line);border-radius:7px;padding:5px 10px;cursor:pointer; }
    .xb-dls{ display:flex;flex-direction:column;gap:7px; }
    .xb-dl{ display:flex;align-items:center;gap:9px;font:inherit;font-size:12.5px;font-weight:600;color:var(--ink-2);background:var(--paper-2);border:1px solid var(--line);border-radius:9px;padding:10px 13px;cursor:pointer;text-align:left; }
    .xb-dl svg{ width:15px;height:15px;color:var(--pf-convexus);flex:none; }
    .xb-dl.done{ color:#16A34A; }
    .xb-prov{ display:flex;flex-wrap:wrap;gap:5px;margin-bottom:10px; }
    .xb-prov .cvx-pb{ font-size:9px;font-weight:700;border-radius:5px;padding:2px 7px; }
    .xb-prov .cvx-pb.v{ color:#16A34A;background:color-mix(in srgb,#16A34A 11%,var(--paper));border:1px solid color-mix(in srgb,#16A34A 28%,var(--line)); }
    .xb-prov .cvx-pb.t{ color:var(--pf-convexus);background:color-mix(in srgb,var(--pf-convexus) 11%,var(--paper));border:1px solid color-mix(in srgb,var(--pf-convexus) 28%,var(--line)); }
    .xb-prov .cvx-pb.d{ color:var(--ink-2);background:var(--paper-2);border:1px solid var(--line); }
    .xb-refs{ list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:6px; }
    .xb-refs li{ position:relative;padding-left:16px;font-size:12px;color:var(--ink-2);line-height:1.45; }
    .xb-refs li::before{ content:"";position:absolute;left:3px;top:7px;width:4px;height:4px;border-radius:50%;background:var(--brand-gold); }
    .xb-paths{ display:flex;flex-direction:column;gap:6px; }
    .xb-paths .pp{ display:flex;align-items:center;justify-content:space-between;font-size:12.5px;padding:7px 11px;border:1px solid var(--line);border-radius:8px; }
    .xb-paths .pp b{ color:var(--ink);font-weight:700; }
    .xb-paths .pp i{ font-style:normal;font-family:'JetBrains Mono',monospace;font-size:9px;font-weight:700;letter-spacing:.08em;text-transform:uppercase; }
    .xb-paths .pp.open i{ color:#16A34A; } .xb-paths .pp.open{ border-color:color-mix(in srgb,#16A34A 30%,var(--line)); }
    .xb-paths .pp.soon i{ color:var(--brand-gold); } .xb-paths .pp.closed i{ color:var(--muted); }
    .xb-foot{ position:sticky;bottom:0;padding:15px 22px;background:var(--paper);border-top:1px solid var(--line); }
    .xb-contact{ width:100%;font:inherit;font-size:13px;font-weight:700;color:#fff;background:var(--pf-convexus);border:0;border-radius:10px;padding:12px;cursor:pointer; }
    .xb-contact.done{ background:var(--paper);color:#16A34A;border:1px solid color-mix(in srgb,#16A34A 40%,var(--line)); }
    @media(max-width:760px){ .expo-spot{ grid-template-columns:1fr; } .sp-main{ border-right:0;border-bottom:1px solid var(--line); } }
    .cvx-expo .cvx-stars{ color:var(--brand-gold); letter-spacing:1px; }
    .xb-meta2{ font-size:11px; color:var(--muted); margin-top:5px; }
    .xb-meta2 b{ color:var(--ink); }
    .xb-vp{ color:#16A34A; font-weight:800; }
    .xb-media{ display:grid; grid-template-columns:1fr 118px; gap:9px; margin:14px 0 10px; }
    .xb-vid{ display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; background:var(--paper-2); border:1px dashed var(--line-2); border-radius:12px; font-size:10px; color:var(--muted); cursor:pointer; }
    .xb-vid .pl{ width:30px;height:30px;border-radius:50%;display:grid;place-items:center;background:var(--pf-convexus);color:#fff;font-size:10px; }
    .xb-links{ display:flex; align-items:center; justify-content:space-between; gap:10px; flex-wrap:wrap; margin-bottom:4px; }
    .xb-web{ font-family:'JetBrains Mono',monospace; font-size:11.5px; font-weight:700; color:var(--pf-convexus); }
    .xb-clock{ font-family:'JetBrains Mono',monospace; font-size:11px; color:var(--muted); }
    .xb-anns{ display:flex; flex-direction:column; gap:7px; }
    .xb-ann{ display:flex; align-items:center; gap:10px; padding:9px 12px; background:var(--paper-2); border:1px solid var(--line); border-radius:9px; }
    .xb-ann .an-tag{ font-family:'JetBrains Mono',monospace; font-size:8px; font-weight:800; letter-spacing:.08em; color:var(--pf-convexus); background:color-mix(in srgb,var(--pf-convexus) 12%,var(--paper)); border-radius:5px; padding:3px 7px; flex:none; }
    .xb-ann .an-tx{ font-size:12px; color:var(--ink-2); flex:1; }
    .xb-ann .an-ago{ font-family:'JetBrains Mono',monospace; font-size:9.5px; color:var(--muted); flex:none; }
    .xb-rev-top{ font-size:13px; color:var(--ink-2); margin-bottom:9px; }
    .xb-rev-top b{ color:var(--ink); }
    .xb-revs{ display:flex; flex-direction:column; gap:8px; }
    .xb-rev{ background:var(--paper-2); border:1px solid var(--line); border-radius:10px; padding:11px 13px; }
    .xb-rev .rv-h{ display:flex; align-items:center; justify-content:space-between; gap:10px; margin-bottom:4px; }
    .xb-rev .rv-a{ font-size:11px; font-weight:700; color:var(--ink-2); }
    .xb-rev .rv-t{ font-size:12.5px; color:var(--ink-2); font-style:italic; line-height:1.5; }
    `;
    document.head.appendChild(s);
  }
})();
