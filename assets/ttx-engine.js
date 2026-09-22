/* ============================================================
   EFDI TTX Wargamer — interactive engine
   ------------------------------------------------------------
   State machine + sim clock + schematic board + DCMP logging +
   friction register + outbrief outputs + AI synthesis.
   Consumes window.TTX (ttx-data.js). Persists to localStorage.
   ============================================================ */
(function () {
  'use strict';
  if (!window.TTX) return;
  const D = window.TTX;
  const SK = 'ttx-session-v1';

  /* ---------- helpers ---------- */
  const $  = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const esc = s => String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const catOf = id => D.FRICTION_CATS.find(c => c.id === id) || D.FRICTION_CATS[0];
  const sevOf = id => D.SEVERITIES.find(s => s.id === id) || D.SEVERITIES[0];
  const laneOf = id => D.LANES.find(l => l.id === id) || D.LANES[0];

  function fmtT(sec, withH) {
    sec = Math.max(0, Math.floor(sec));
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    const pad = n => String(n).padStart(2, '0');
    return 'T+' + (withH ? pad(h) + ':' : '') + pad(withH ? m : Math.floor(sec / 60)) + ':' + pad(s);
  }
  const mmss = sec => { sec = Math.max(0, Math.floor(sec)); return String(Math.floor(sec/60)).padStart(2,'0')+':'+String(sec%60).padStart(2,'0'); };

  /* ---------- state ---------- */
  let st = null;
  function fresh() {
    return {
      variant: null, running: false, elapsed: 0, speed: 4,
      current: 0, stamps: new Array(11).fill(null),
      eq: {}, frictions: D.SEED_FRICTIONS.map(f => Object.assign({}, f)),
      events: [], outcome: null, redcell: false, started: false
    };
  }
  function load() {
    try { const r = JSON.parse(localStorage.getItem(SK)); if (r && r.stamps) return r; } catch (_) {}
    return fresh();
  }
  function save() { try { localStorage.setItem(SK, JSON.stringify(st)); } catch (_) {} }

  /* ---------- events ---------- */
  function addEvent(html, type) {
    st.events.unshift({ at: st.elapsed, html, type: type || 'info' });
    if (st.events.length > 200) st.events.pop();
    renderEvents(); save();
  }

  /* ============================================================
     CLOCK
     ============================================================ */
  let timer = null;
  function startClock() { if (timer) return; timer = setInterval(tick, 1000); }
  function tick() {
    if (!st.running || st.outcome) return;
    st.elapsed += st.speed;
    evalProgress();
    tickUpdate();
    if (st.elapsed % 4 === 0) save();
  }
  function variant() { return st.variant ? D.VARIANTS[st.variant] : null; }
  function progress() { const v = variant(); return v ? Math.min(1, st.elapsed / v.timeToTarget) : 0; }

  function evalProgress() {
    const v = variant(); if (!v || st.outcome) return;
    const engageDone = st.stamps[v.interceptStage] != null;
    const p = progress();
    // Red Cell warning: drone past 70% with engage not done
    const warn = !engageDone && p >= 0.70 && p < 1;
    if (warn && !st.redcell) {
      st.redcell = true;
      addEvent('<b>RED CELL</b> exploits the delay — drone tracker advanced toward target.', 'fr');
    }
    if (engageDone && !st.outcome) {
      st.outcome = 'intercept'; st.running = false; st.redcell = false;
      addEvent('<b>INTERCEPT</b> — ' + esc(v.effector) + ' kill confirmed at the engagement geometry.', 'win');
      renderControl(); renderBoardHead();
    } else if (p >= 1 && !engageDone && !st.outcome) {
      st.outcome = 'leaker'; st.running = false;
      addEvent('<b>LEAKER</b> — OWAD reached ' + esc(v.board.target.label) + '. Decision window closed. Losing is learning.', 'fr');
      renderControl(); renderBoardHead();
    }
  }

  /* ============================================================
     RENDER · top-level pane switching
     ============================================================ */
  function setTab(t) {
    $$('#ttxTabs button').forEach(b => b.classList.toggle('on', b.dataset.ttxTab === t));
    ['brief','play','register','outputs'].forEach(p =>
      $('#ttxPane' + p[0].toUpperCase() + p.slice(1)).classList.toggle('on', p === t));
    if (t === 'play') renderPlay();
    if (t === 'register') renderRegister();
    if (t === 'outputs') renderOutputs();
    if (t === 'brief') renderBrief();
    window.scrollTo(0, 0);
  }

  /* ============================================================
     BRIEF
     ============================================================ */
  function renderBrief() {
    const m = D.META;
    const variants = ['A','B','C'].map(k => {
      const v = D.VARIANTS[k];
      const flow = v.flow.map((n,i) =>
        `<span class="node">${esc(n)}</span>` + (i < v.flow.length-1 ? '<span class="ar">→</span>' : '')).join('');
      const active = st.variant === k ? ' active' : '';
      return `<button class="ttx-vcard${active}" data-load-variant="${k}">
        <div class="vid">${k}</div>
        <div class="vtag">${esc(v.tag)} · ${esc(v.dcmp)}</div>
        <h3>${esc(v.name)}</h3>
        <p>${esc(v.subtitle)}</p>
        <div class="vflow">${flow}</div>
        <span class="vload">${st.variant===k?'Resume in console':'Load into console'}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M13 5l7 7-7 7"/></svg></span>
      </button>`;
    }).join('');

    const lanes = D.LANES.map(l =>
      `<div class="ttx-lane" style="--lc:${l.color}"><div class="ln">${esc(l.name)} Lane</div>
       <h4>${esc(l.name)}</h4><p>${esc(l.desc)}</p></div>`).join('');

    const agenda = D.AGENDA.map(([t,ti,td]) => {
      const isVar = /Variant/.test(ti);
      return `<div class="row${isVar?' var':''}"><div class="tm">${esc(t)}</div>
        <div><div class="ti">${esc(ti)}</div><div class="td">${esc(td)}</div></div></div>`;
    }).join('');

    const meta = [
      ['Location', m.location], ['Date', m.date], ['Sponsors', m.sponsors],
      ['Leads', m.leads], ['Informs', m.informs]
    ].map(([k,v]) => `<div><div class="k">${esc(k)}</div><div class="v">${esc(v)}</div></div>`).join('');

    $('#ttxPaneBrief').innerHTML = `
      <div class="ttx-hero">
        <span class="eyebrow"><span class="live-dot" style="width:7px;height:7px;border-radius:50%;background:var(--tc);display:inline-block"></span> EFDI DATA BACKBONE ACCELERATOR · TTX</span>
        <h1>${esc(m.title)}</h1>
        <div class="kind">${esc(m.kind)} · ${esc(m.method)}</div>
        <div class="ttx-rq">
          <div class="lbl">Sponsor's Central Research Question</div>
          <p>${esc(m.question)}</p>
        </div>
        <div class="ttx-meta-grid">${meta}</div>
      </div>

      <div class="ttx-h"><span class="num">01</span><h2>Select today's variant</h2><span class="sub">3 VARIANTS · LOAD → PLAY</span></div>
      <div class="ttx-variants">${variants}</div>

      <div class="ttx-h"><span class="num">02</span><h2>Three player lanes</h2><span class="sub">STAY IN LANE</span></div>
      <div class="ttx-lanes">${lanes}</div>

      <div class="ttx-h"><span class="num">03</span><h2>1-day wargame agenda</h2><span class="sub">STRICTLY ENFORCED</span></div>
      <div class="ttx-agenda">${agenda}</div>

      <div class="ttx-h"><span class="num">04</span><h2>Ask the facilitator AI</h2><span class="sub">APPLEGET METHOD</span></div>
      <div class="cvg-prompt ttx-ai-wrap" data-plt-persona="You are the EFDI TTX facilitator AI, trained on The Craft of Wargaming (Appleget, Burks & Cameron). You run a rigorous analytic wargame on cross-border sensor-to-shooter against OWADs in the Suwalki corridor (LT/PL/NATO). Keep players in lane (Policy, Legal, Technical), prevent BOGGSAT, enforce the Parking Lot technique, drive an aggressive Red Cell, and tie every decision to an Essential Question, a friction category (Technical/Legal/Policy/Operational/Procedural) and a severity. Tone: institutional, structured, adversarial-but-fair.">
        <div class="cvg-prompt-head">
          <div class="ttl"><span class="cvg-ai-badge" style="font-size:9px;padding:2px 7px;"><span class="live-dot"></span> AI</span> Facilitator assistant</div>
          <div class="cvg-prompt-suggest">
            <button data-plt-suggest="Give me an Appleget-style facilitator prompt for the Decide gate in Variant B.">Prompt for the Decide gate (B)</button><button data-plt-suggest="A lane keeps drifting into procurement budgets. Script the Parking Lot intervention.">Parking Lot intervention</button><button data-plt-suggest="List the three highest-risk seams to validate at the September LIVEX.">Top seams for LIVEX</button>
          </div>
        </div>
        <div class="cvg-prompt-input">
          <textarea class="plt-prompt-text" rows="1" placeholder="Ask the facilitator AI — prompts, adjudication calls, friction synthesis…"></textarea>
          <button class="cvg-prompt-send plt-prompt-send">ASK<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M13 5l7 7-7 7"/></svg></button>
        </div>
        <div class="cvg-prompt-out plt-prompt-out"></div>
      </div>`;

    if (window.ConventityShell) window.ConventityShell.initPrompts();
  }

  /* ============================================================
     PLAY
     ============================================================ */
  function renderPlay() {
    const v = variant();
    if (!v) {
      $('#ttxPanePlay').innerHTML = `
        <div class="ttx-hero" style="text-align:center">
          <span class="eyebrow" style="justify-content:center">NO VARIANT LOADED</span>
          <h1>Load a scenario to begin play</h1>
          <div class="kind">Pick Variant A, B or C from the Brief tab, then run the targeting chain.</div>
          <div style="margin-top:22px"><button class="ttx-btn primary" data-goto-brief>Go to Brief → select variant</button></div>
        </div>`;
      return;
    }
    $('#ttxPanePlay').innerHTML = `
      <div class="ttx-control" id="ttxControl"></div>
      <div class="ttx-redcell" id="ttxRedcell">
        <span class="rc-ic"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/></svg></span>
        <div class="rc-t" id="ttxRedcellTxt">Red Cell active</div>
        <span class="rc-pill" id="ttxRedcellPill">EXPLOITING DELAY</span>
      </div>
      <div class="ttx-rail" id="ttxRail"></div>
      <div class="ttx-play-grid">
        <div class="ttx-stage" id="ttxStage"></div>
        <div class="ttx-side">
          <div class="ttx-board-wrap">
            <div class="ttx-board-hd"><span class="t">SUWAŁKI CORRIDOR · GAME BOARD</span><span class="st live" id="ttxBoardSt">TRACKING</span></div>
            <div id="ttxBoardHost"></div>
          </div>
          <div class="ttx-events">
            <div class="ttx-events-hd"><span class="t">Recorder log · DCMP</span><button class="ttx-btn sm" id="ttxClearLog">Clear</button></div>
            <div class="ttx-events-list" id="ttxEventsList"></div>
          </div>
        </div>
      </div>`;
    renderControl(); renderRail(); renderStage(); renderBoard(); renderEvents(); renderRedcell();
  }

  function renderControl() {
    const host = $('#ttxControl'); if (!host) return;
    const v = variant();
    const flow = v.flow.map((n,i) =>
      `<span class="node">${esc(n)}</span>` + (i<v.flow.length-1?'<span class="ar">→</span>':'')).join('');
    const out = st.outcome;
    const clkClass = (st.running && !out) ? ' run' : '';
    const playLabel = out ? 'Finished' : (st.running ? 'Pause' : (st.started ? 'Resume' : 'Inject T+00:00'));
    const playIcon = st.running && !out
      ? '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>'
      : '<svg viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>';
    host.innerHTML = `
      <div class="ttx-clock">
        <div class="big${clkClass}" id="ttxBigClock">${fmtT(st.elapsed, true)}</div>
        <div class="lbl">Mission clock · from inject</div>
      </div>
      <div class="ttx-ctr-mid">
        <div class="ttx-ctr-flow"><span class="vt">VARIANT ${v.id}</span>${flow}</div>
        <div class="ttx-window">
          <span class="wk">Decision window</span>
          <div class="bar"><i id="ttxWinFill"></i><span class="mk" style="left:${(v.board.intercept*100).toFixed(0)}%"></span></div>
          <span class="wv" id="ttxWinVal">—</span>
        </div>
      </div>
      <div class="ttx-ctr-actions">
        <button class="ttx-btn primary" id="ttxPlayBtn" ${out?'disabled style="opacity:.5;cursor:default"':''}>${playIcon}${playLabel}</button>
        <div class="ttx-speed" id="ttxSpeed">
          ${[1,4,10].map(s=>`<button data-speed="${s}" class="${st.speed===s?'on':''}">${s}×</button>`).join('')}
        </div>
        <button class="ttx-btn danger" id="ttxRedBtn" title="Red Cell penalty — advance drone 60s">RED +60s</button>
        <button class="ttx-btn" id="ttxResetBtn" title="Reset this exercise">RESET</button>
      </div>`;
    tickUpdate();
  }

  function renderRail() {
    const host = $('#ttxRail'); if (!host) return;
    host.innerHTML = D.STAGES.map((s,i) => {
      const done = st.stamps[i] != null;
      const active = st.current === i;
      const cls = 'ttx-node' + (done?' done':'') + (active?' active':'');
      const stamp = done ? `<span class="stamp">${mmss(st.stamps[i])}</span>` : '';
      return `<button class="${cls}" data-stage="${i}">${stamp}
        <span class="dot">${done?'<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>':s.n}</span>
        <span class="nm">${esc(s.name)}</span></button>`;
    }).join('');
  }

  function renderStage() {
    const host = $('#ttxStage'); if (!host) return;
    const i = st.current, s = D.STAGES[i], v = variant();
    const lane = laneOf(s.lane);
    const done = st.stamps[i] != null;
    const prompt = v.prompts[i];

    const promptHtml = prompt
      ? `<div class="ttx-prompt"><div class="pk"><svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M3 11l18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/></svg> Facilitator prompt · read aloud</div><p>${esc(prompt)}</p></div>`
      : `<div class="ttx-prompt empty"><div class="pk">No scripted prompt at this stage</div><p>Run the lane checks and capture each Essential Question, then advance the marker.</p></div>`;

    const eqs = s.eqs.map(eq => {
      const a = st.eq[eq.id];
      const logged = a && a.at != null;
      return `<div class="ttx-eq${logged?' logged':''}" data-eq="${eq.id}">
        <div class="ttx-eq-hd"><span class="id">${esc(eq.id)}</span><span class="q">${esc(eq.q)}</span></div>
        <div class="ttx-eq-bd">
          <div class="metric"><svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/></svg> Metric: <b>${esc(eq.metric)}</b></div>
          <div class="ttx-eq-row">
            <textarea data-eq-input="${eq.id}" placeholder="Record player rationale / value…">${esc(a?a.text:'')}</textarea>
            <button class="ttx-btn sm" data-eq-log="${eq.id}">${logged?'Update':'Log'}</button>
          </div>
          <div class="ttx-eq-stamp">Logged at ${a&&a.at!=null?fmtT(a.at):''}</div>
        </div>
      </div>`;
    }).join('');

    host.innerHTML = `
      <div class="ttx-stage-hd">
        <span class="sn">STAGE ${esc(s.n)}</span>
        <h3>${esc(s.name)}</h3>
        <span class="ph">${esc(s.phase)}</span>
        <span class="lane" style="color:${lane.color};background:color-mix(in srgb,${lane.color} 13%,transparent)">${esc(lane.name)} lane</span>
        <span class="fl">${esc(s.flow)}</span>
      </div>
      ${promptHtml}
      <div class="ttx-eqs">${eqs}</div>
      <div class="ttx-stage-foot">
        <button class="ttx-btn" id="ttxFrBtn"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/></svg> Log friction</button>
        <button class="ttx-btn primary" id="ttxAdvBtn">
          ${done ? 'Re-stamp stage' : 'Advance marker'}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
        </button>
        <span style="margin-left:auto;align-self:center;font-family:'JetBrains Mono',monospace;font-size:10px;color:var(--muted);letter-spacing:.08em">
          ${esc(s.frictionCat.toUpperCase())} FRICTION ANTICIPATED</span>
      </div>`;
  }

  /* ---------- board ---------- */
  function renderBoardHead() {
    const el = $('#ttxBoardSt'); if (!el) return;
    if (st.outcome === 'intercept') { el.className = 'st kill'; el.textContent = 'KILL CONFIRMED'; }
    else if (st.outcome === 'leaker') { el.className = 'st hit'; el.textContent = 'LEAKER · STRUCK'; }
    else { el.className = 'st live'; el.textContent = st.running ? 'INBOUND' : 'TRACKING'; }
  }

  function pointOnPath(path, f) {
    if (path.length < 2) return { x: path[0][0], y: path[0][1] };
    const segs = [], tot = (() => { let t=0; for (let i=1;i<path.length;i++){ const dx=path[i][0]-path[i-1][0],dy=path[i][1]-path[i-1][1]; const d=Math.hypot(dx,dy); segs.push(d); t+=d; } return t; })();
    let target = f * tot, acc = 0;
    for (let i=1;i<path.length;i++) {
      if (acc + segs[i-1] >= target) {
        const lf = segs[i-1] ? (target-acc)/segs[i-1] : 0;
        return { x: path[i-1][0]+(path[i][0]-path[i-1][0])*lf, y: path[i-1][1]+(path[i][1]-path[i-1][1])*lf };
      }
      acc += segs[i-1];
    }
    return { x: path[path.length-1][0], y: path[path.length-1][1] };
  }

  function renderBoard() {
    const host = $('#ttxBoardHost'); if (!host) return;
    const v = variant(), b = v.board;
    const pathD = 'M ' + b.path.map(p => p[0]+' '+p[1]).join(' L ');
    const shooters = b.shooters.map(sh => {
      const col = sh.side === 'blue' ? '#2A6FDB' : '#C8A24B';
      return `<g>
        <circle cx="${sh.x}" cy="${sh.y}" r="38" fill="none" stroke="${col}" stroke-opacity=".18" stroke-dasharray="3 5"/>
        <circle cx="${sh.x}" cy="${sh.y}" r="22" fill="none" stroke="${col}" stroke-opacity=".28"/>
        <path d="M${sh.x} ${sh.y-8} L${sh.x+7} ${sh.y+6} L${sh.x-7} ${sh.y+6} Z" fill="${col}"/>
        <text x="${sh.x}" y="${sh.y+20}" text-anchor="middle" font-family="JetBrains Mono,monospace" font-size="8" font-weight="700" fill="${col}">${esc(sh.label)}</text>
      </g>`;
    }).join('');

    host.innerHTML = `<svg class="ttx-board" viewBox="0 0 440 360" role="img" aria-label="Suwałki corridor schematic">
      <defs>
        <pattern id="ttxGrid" width="40" height="40" patternUnits="userSpaceOnUse">
          <path d="M40 0H0V40" fill="none" stroke="var(--line)" stroke-width="1" stroke-opacity=".5"/>
        </pattern>
        <radialGradient id="ttxTgt" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#DC2626" stop-opacity=".5"/><stop offset="100%" stop-color="#DC2626" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <rect x="0" y="0" width="440" height="360" fill="url(#ttxGrid)"/>
      <!-- corner blocks -->
      <g opacity=".5">
        <rect x="358" y="40" width="82" height="320" fill="color-mix(in srgb,#DC2626 7%,transparent)"/>
        <text x="399" y="200" text-anchor="middle" font-family="JetBrains Mono,monospace" font-size="9" font-weight="700" fill="#B91C1C" transform="rotate(90 399 200)">BELARUS</text>
        <rect x="0" y="270" width="120" height="90" fill="color-mix(in srgb,#DC2626 7%,transparent)"/>
        <text x="60" y="320" text-anchor="middle" font-family="JetBrains Mono,monospace" font-size="8.5" font-weight="700" fill="#B91C1C">KALININGRAD</text>
      </g>
      <!-- sovereignty border -->
      <path d="M0 196 L120 200 L160 232 L358 224" fill="none" stroke="var(--ink)" stroke-opacity=".35" stroke-width="1.6" stroke-dasharray="7 5"/>
      <text x="20" y="60" font-family="JetBrains Mono,monospace" font-size="10" font-weight="700" fill="#2A6FDB" opacity=".7">LITHUANIA · LT</text>
      <text x="20" y="345" font-family="JetBrains Mono,monospace" font-size="10" font-weight="700" fill="#2A6FDB" opacity=".7">POLAND · PL</text>
      <text x="172" y="218" text-anchor="middle" font-family="JetBrains Mono,monospace" font-size="7.5" letter-spacing="1" fill="var(--muted)">SUWAŁKI GAP</text>
      <!-- AOI label -->
      <text x="420" y="20" text-anchor="end" font-family="JetBrains Mono,monospace" font-size="8.5" letter-spacing="1.5" fill="var(--tc)" font-weight="700">${esc(b.airspace)}</text>
      <!-- shooters -->
      ${shooters}
      <!-- drone path -->
      <path d="${pathD}" fill="none" stroke="#DC2626" stroke-opacity=".4" stroke-width="1.6" stroke-dasharray="5 5"/>
      <!-- target -->
      <circle cx="${b.target.x}" cy="${b.target.y}" r="26" fill="url(#ttxTgt)"/>
      <g id="ttxTargetG">
        <circle cx="${b.target.x}" cy="${b.target.y}" r="9" fill="none" stroke="#DC2626" stroke-width="1.6"/>
        <circle cx="${b.target.x}" cy="${b.target.y}" r="3" fill="#DC2626"/>
      </g>
      <text x="${b.target.x}" y="${b.target.y-14}" text-anchor="middle" font-family="JetBrains Mono,monospace" font-size="8" font-weight="700" fill="#B91C1C">${esc(b.target.label)}</text>
      <!-- drone marker -->
      <g id="ttxDrone"></g>
      <!-- intercept burst -->
      <g id="ttxBurst"></g>
    </svg>`;
    updateBoard();
    renderBoardHead();
  }

  function updateBoard() {
    const host = $('#ttxDrone'); if (!host) return;
    const v = variant(), b = v.board;
    let f = progress();
    if (st.outcome === 'intercept') f = Math.min(f, b.intercept);
    const p = pointOnPath(b.path, f);
    host.innerHTML = `
      <circle cx="${p.x}" cy="${p.y}" r="13" fill="none" stroke="#DC2626" stroke-opacity=".3"/>
      <path d="M${p.x} ${p.y-6} L${p.x+5} ${p.y} L${p.x} ${p.y+6} L${p.x-5} ${p.y} Z" fill="#DC2626" stroke="#fff" stroke-width="1"/>
      <text x="${p.x}" y="${p.y-12}" text-anchor="middle" font-family="JetBrains Mono,monospace" font-size="7.5" font-weight="700" fill="#B91C1C">OWAD</text>`;
    const burst = $('#ttxBurst');
    if (burst) {
      if (st.outcome === 'intercept') {
        const ip = pointOnPath(b.path, b.intercept);
        burst.innerHTML = `<g>
          <circle cx="${ip.x}" cy="${ip.y}" r="16" fill="none" stroke="var(--tc)" stroke-width="2"/>
          ${[0,45,90,135,180,225,270,315].map(a=>{const r=a*Math.PI/180;return `<line x1="${ip.x+8*Math.cos(r)}" y1="${ip.y+8*Math.sin(r)}" x2="${ip.x+18*Math.cos(r)}" y2="${ip.y+18*Math.sin(r)}" stroke="var(--tc)" stroke-width="2" stroke-linecap="round"/>`}).join('')}
        </g>`;
      } else if (st.outcome === 'leaker') {
        burst.innerHTML = `<g>
          <circle cx="${b.target.x}" cy="${b.target.y}" r="18" fill="none" stroke="#DC2626" stroke-width="2.4"/>
          <circle cx="${b.target.x}" cy="${b.target.y}" r="26" fill="none" stroke="#DC2626" stroke-width="1.4" stroke-opacity=".5"/>
        </g>`;
      } else burst.innerHTML = '';
    }
  }

  /* ---------- events / log ---------- */
  function renderEvents() {
    const host = $('#ttxEventsList'); if (!host) return;
    if (!st.events.length) { host.innerHTML = `<div class="ttx-ev-empty">No entries yet — inject the scenario and start logging decisions, EQ answers and frictions.</div>`; return; }
    host.innerHTML = st.events.map(e =>
      `<div class="ttx-ev ${e.type==='fr'?'fr':''}"><span class="tt">${fmtT(e.at)}</span><span class="tx">${e.html}</span></div>`).join('');
  }

  function renderRedcell() {
    const el = $('#ttxRedcell'); if (!el) return;
    if (st.outcome === 'leaker') {
      el.classList.add('on');
      $('#ttxRedcellTxt').innerHTML = 'Leaker — decision window closed before intercept.<span>Log the deadlock as high-severity friction. Losing is learning, and learning is winning.</span>';
      $('#ttxRedcellPill').textContent = 'TARGET STRUCK';
    } else if (st.redcell && !st.outcome) {
      el.classList.add('on');
      $('#ttxRedcellTxt').innerHTML = 'Red Cell is exploiting the delay.<span>Blue is slow at a gate — the drone tracker is advancing. Force a decision or log the friction.</span>';
      $('#ttxRedcellPill').textContent = 'EXPLOITING DELAY';
    } else el.classList.remove('on');
  }

  /* ---------- per-second surgical updates ---------- */
  function tickUpdate() {
    const v = variant();
    $('#ttxBarClock') && ($('#ttxBarClock').textContent = fmtT(st.elapsed, true));
    const bc = $('#ttxBigClock'); if (bc) { bc.textContent = fmtT(st.elapsed, true); bc.classList.toggle('run', st.running && !st.outcome); }
    if (v) {
      const p = progress();
      const fill = $('#ttxWinFill'); if (fill) fill.style.width = (p*100).toFixed(1)+'%';
      const wv = $('#ttxWinVal');
      if (wv) {
        if (st.outcome === 'intercept') wv.innerHTML = '<span style="color:var(--tc)">INTERCEPT</span>';
        else if (st.outcome === 'leaker') wv.innerHTML = '<span style="color:#DC2626">LEAKER</span>';
        else wv.textContent = mmss(Math.max(0, v.timeToTarget - st.elapsed)) + ' to tgt';
      }
      updateBoard();
    }
    renderRedcell();
    renderBoardHead();
  }

  /* ============================================================
     REGISTER
     ============================================================ */
  function sortedFrictions() {
    return st.frictions.slice().sort((a,b) => sevOf(b.sev).rank - sevOf(a.sev).rank || (a.id>b.id?1:-1));
  }
  function renderRegister() {
    const host = $('#ttxPaneRegister');
    const fr = sortedFrictions();
    const counts = { high: fr.filter(f=>f.sev==='high').length, med: fr.filter(f=>f.sev==='med').length, low: fr.filter(f=>f.sev==='low').length };
    const rows = fr.length ? fr.map(f => {
      const c = catOf(f.cat), sv = sevOf(f.sev), s = D.STAGES[f.stage];
      return `<tr>
        <td><span class="ttx-reg-id">${esc(f.id)}</span>${f.seed?'<span class="seed">SEED</span>':''}</td>
        <td><div style="font-weight:700;color:var(--ink)">${esc(s?s.name:'—')}</div>
            <span class="ttx-tag" style="color:${c.color};background:color-mix(in srgb,${c.color} 12%,transparent);margin-top:5px"><span class="d" style="background:${c.color}"></span>${esc(c.name)}</span></td>
        <td>${esc(f.desc)}</td>
        <td><span class="ttx-sev" style="color:${sv.color};background:color-mix(in srgb,${sv.color} 13%,transparent)">${esc(sv.name)}</span></td>
        <td class="ttx-reg-mit">${esc(f.mitigation||'—')}</td>
        <td>${f.seed?'':`<button class="ttx-reg-del" data-del-fr="${esc(f.id)}" title="Remove"><svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/></svg></button>`}</td>
      </tr>`;
    }).join('') : `<tr><td colspan="6"><div class="ttx-reg-empty">No frictions logged. Open Play, run a stage, and tap <b>Log friction</b>.</div></td></tr>`;

    host.innerHTML = `
      <div class="ttx-h"><span class="num">R</span><h2>Prioritised friction register</h2><span class="sub">OWNERS · MITIGATIONS → LIVEX</span></div>
      <div class="ttx-reg-bar">
        <div class="ttx-reg-stat">
          <span class="s"><b>${fr.length}</b> total</span>
          <span class="s" style="color:#DC2626"><b style="color:#DC2626">${counts.high}</b> high</span>
          <span class="s" style="color:#B7820E"><b style="color:#EAB308">${counts.med}</b> medium</span>
          <span class="s" style="color:#16A34A"><b style="color:#16A34A">${counts.low}</b> low</span>
        </div>
        <button class="ttx-btn" id="ttxAddFr" style="margin-left:auto"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg> Add friction</button>
        <button class="ttx-btn" id="ttxAiSynth"><span class="cvg-ai-badge" style="font-size:9px;padding:1px 6px"><span class="live-dot"></span>AI</span> Synthesise</button>
      </div>
      <div id="ttxAiSynthOut" class="cvg-prompt-out" style="margin:0 0 16px;display:none"></div>
      <table class="ttx-reg-table">
        <thead><tr><th>ID</th><th>Phase / Lane</th><th>Description &amp; root cause</th><th>Severity</th><th>Proposed LIVEX mitigation</th><th></th></tr></thead>
        <tbody>${rows}</tbody>
      </table>`;
  }

  /* ============================================================
     OUTPUTS
     ============================================================ */
  function renderOutputs() {
    const host = $('#ttxPaneOutputs'), v = variant();
    if (!v) {
      host.innerHTML = `<div class="ttx-hero" style="text-align:center"><span class="eyebrow" style="justify-content:center">NO SESSION</span>
        <h1>Run a variant to generate outputs</h1><div class="kind">The Quick Look, timeline analysis and roadmap populate from live play.</div>
        <div style="margin-top:22px"><button class="ttx-btn primary" data-goto-brief>Go to Brief</button></div></div>`;
      return;
    }
    const fr = sortedFrictions();
    const high = fr.filter(f=>f.sev==='high');
    const completed = st.stamps.filter(x=>x!=null).length;
    const total = st.outcome === 'intercept' ? st.stamps[v.interceptStage] : (st.outcome==='leaker'? v.timeToTarget : st.elapsed);

    // timeline: per-stage delta
    let prev = 0; const tl = [];
    for (let i=0;i<11;i++){ const at = st.stamps[i]; if (at!=null){ tl.push({i, dur: Math.max(0, at-prev), at, done:true}); prev = at; } else tl.push({i, dur:0, at:null, done:false}); }
    const maxDur = Math.max(1, ...tl.filter(t=>t.done).map(t=>t.dur));
    const tlSum = tl.filter(t=>t.done).reduce((a,t)=>a+t.dur,0);

    const outcomeCard = st.outcome==='intercept'
      ? `<div class="v good">INTERCEPT</div><div class="k">Engagement outcome</div>`
      : st.outcome==='leaker'
      ? `<div class="v bad">LEAKER</div><div class="k">Window closed first</div>`
      : `<div class="v tc">IN PLAY</div><div class="k">Stage ${completed}/11</div>`;

    const qlList = (high.length ? high : fr).slice(0,5).map(f => {
      const sv = sevOf(f.sev), c = catOf(f.cat);
      return `<li><span class="lt">${esc(f.id)}</span><span><b style="color:${sv.color}">${esc(sv.name)}</b> · ${esc(c.name)} — ${esc(f.desc)}</span></li>`;
    }).join('') || '<li><span>No frictions logged yet.</span></li>';

    const tlRows = tl.map(t => {
      const s = D.STAGES[t.i];
      const w = t.done ? Math.max(4,(t.dur/maxDur)*100) : 100;
      return `<div class="ttx-tl-row">
        <div class="nm"><span class="n">${s.n}</span>${esc(s.name)}</div>
        <div class="ttx-tl-bar ${t.done?'':'pending'}"><i style="width:${w}%"></i></div>
        <div class="vv">${t.done?mmss(t.dur):'—'}</div></div>`;
    }).join('');

    const windowClosed = st.outcome==='leaker';
    const tlNote = windowClosed
      ? `Cumulative targeting latency exceeded the OWAD time-to-target (${mmss(v.timeToTarget)}). The decision window closed during <b>${esc(D.STAGES[firstPending()].name)}</b> — a leaker. This is the seam to fix.`
      : st.outcome==='intercept'
      ? `Intercept achieved with ${mmss(Math.max(0,v.timeToTarget - tlSum))} of margin against the ${mmss(v.timeToTarget)} time-to-target.`
      : `Targeting chain in progress — ${completed} of 11 stages stamped.`;

    const roadmap = D.ROADMAP.map(r =>
      `<div class="step" style="--rc:${r.color}"><div class="hz">${esc(r.horizon)}</div><div class="tg">${esc(r.tag)}</div><p>${esc(r.body)}</p></div>`).join('');

    host.innerHTML = `
      <div class="ttx-h"><span class="num">O</span><h2>Senior leader outbrief</h2><span class="sub">VARIANT ${v.id} · QUICK LOOK</span></div>
      <div class="ttx-out-grid">
        <div class="ttx-card">
          <div class="ttx-card-hd"><span class="ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M9 13h6M9 17h6"/></svg></span><h3>Quick Look Report</h3></div>
          <div class="ttx-ql">
            <div class="stat-row">
              <div class="stat"><div class="v tc">${fmtT(total).replace('T+','')}</div><div class="k">Total targeting time</div></div>
              <div class="stat">${outcomeCard}</div>
              <div class="stat"><div class="v ${high.length?'bad':''}">${high.length}</div><div class="k">High-severity seams</div></div>
            </div>
            <div style="font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:.12em;color:var(--muted);text-transform:uppercase;margin-bottom:4px">Top frictions for consensus</div>
            <ul>${qlList}</ul>
            <p style="font-size:12.5px;color:var(--muted);margin-top:16px;line-height:1.5">Moderated hotwash — confirm with delegation heads that these represent the consensus of today's play before departure.</p>
            <div style="margin-top:14px;display:flex;gap:9px;flex-wrap:wrap">
              <button class="ttx-btn" id="ttxAiQuick"><span class="cvg-ai-badge" style="font-size:9px;padding:1px 6px"><span class="live-dot"></span>AI</span> Draft narrative</button>
              <button class="ttx-btn" id="ttxExport"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg> Export JSON</button>
            </div>
            <div id="ttxAiQuickOut" class="cvg-prompt-out" style="margin-top:14px;display:none"></div>
          </div>
        </div>
        <div class="ttx-card">
          <div class="ttx-card-hd"><span class="ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/></svg></span><h3>Timeline analysis</h3></div>
          <div class="ttx-tl">${tlRows}</div>
          <div class="ttx-tl-total"><span class="k">Cumulative latency · Detect → ${st.outcome==='intercept'?'Engage':'now'}</span><span class="v">${mmss(tlSum)}</span></div>
          <div class="ttx-tl-note ${windowClosed?'bad':''}">${tlNote}</div>
        </div>
      </div>
      <div class="ttx-h"><span class="num">R</span><h2>90 / 180 / 365-day roadmap</h2><span class="sub">TOWARD MULTINATIONAL S2S</span></div>
      <div class="ttx-road">${roadmap}</div>`;
  }
  function firstPending() { for (let i=0;i<11;i++) if (st.stamps[i]==null) return i; return 10; }

  /* ============================================================
     ACTIONS
     ============================================================ */
  function loadVariant(k) {
    if (st.variant !== k) {
      const wasStarted = st.started;
      if (st.started && !confirmReset(k)) return;
      st = fresh(); st.variant = k;
      addEvent('Variant <b>' + k + ' · ' + esc(D.VARIANTS[k].name) + '</b> loaded. Brief players and inject when ready.', 'info');
    }
    save(); updateBar(); setTab('play');
  }
  let pendingVariant = null;
  function confirmReset() { return true; } // loadVariant only resets if different; we reset cleanly

  function togglePlay() {
    if (st.outcome) return;
    if (!st.started) { st.started = true; addEvent('<b>INJECT</b> · T+00:00:00 — clock running. Find–Fix phase begins.', 'win'); }
    st.running = !st.running;
    addEvent(st.running ? 'Clock <b>running</b> (' + st.speed + '×).' : 'Clock <b>paused</b> at ' + fmtT(st.elapsed,true) + '.', 'info');
    renderControl(); save();
  }
  function setSpeed(s) { st.speed = s; renderControl(); save(); }
  function redPenalty() {
    if (st.outcome) return;
    st.elapsed += 60; evalProgress(); addEvent('<b>RED CELL +60s</b> — deadlock penalty; drone advanced.', 'fr'); tickUpdate(); save();
  }
  function resetExercise() {
    const k = st.variant;
    st = fresh(); st.variant = k;
    if (k) addEvent('Exercise reset · Variant <b>' + k + '</b> re-armed at T+00:00.', 'info');
    updateBar(); renderPlay(); save();
  }
  function selectStage(i) { st.current = i; renderRail(); renderStage(); save(); }
  function advanceStage() {
    const i = st.current;
    const first = st.stamps[i] == null;
    st.stamps[i] = st.elapsed;
    const s = D.STAGES[i];
    addEvent((first?'Stage <b>':'Re-stamped stage <b>') + esc(s.n)+' '+esc(s.name) + '</b> complete at ' + fmtT(st.elapsed) + '.', 'win');
    evalProgress();
    if (first && i < 10 && !st.outcome) st.current = i + 1;
    renderRail(); renderStage(); renderControl(); save();
  }
  function logEq(id) {
    const inp = $('[data-eq-input="'+id+'"]'); if (!inp) return;
    const text = inp.value.trim();
    const wasLogged = st.eq[id] && st.eq[id].at != null;
    st.eq[id] = { text, at: st.elapsed };
    addEvent((wasLogged?'Updated ':'Logged ') + '<b>'+esc(id)+'</b> at '+fmtT(st.elapsed)+(text?' — '+esc(text.slice(0,60))+(text.length>60?'…':''):''), 'info');
    renderStage();
  }

  /* ---------- friction modal ---------- */
  let modalSel = { cat: 'technical', sev: 'med' };
  function openFriction() {
    const s = D.STAGES[st.current];
    modalSel = { cat: s ? s.frictionCat : 'technical', sev: 'med' };
    $('#ttxModalSub').innerHTML = 'Stage <b>'+esc(s.n)+' '+esc(s.name)+'</b> · timestamped '+fmtT(st.elapsed)+' from inject.';
    $('#ttxModalCats').innerHTML = D.FRICTION_CATS.map(c =>
      `<button data-mcat="${c.id}" class="${c.id===modalSel.cat?'on':''}" style="--cc:${c.color}"><span class="d" style="background:${c.color}"></span>${esc(c.name)}</button>`).join('');
    $('#ttxModalSevs').innerHTML = D.SEVERITIES.map(s2 =>
      `<button data-msev="${s2.id}" class="${s2.id===modalSel.sev?'on':''}" style="--cc:${s2.color}"><span class="d" style="background:${s2.color}"></span>${esc(s2.name)}</button>`).join('');
    $('#ttxModalDesc').value = ''; $('#ttxModalMit').value = '';
    $('#ttxModalBg').classList.add('on');
  }
  function closeFriction() { $('#ttxModalBg').classList.remove('on'); }
  function saveFrictionEntry() {
    const desc = $('#ttxModalDesc').value.trim();
    if (!desc) { $('#ttxModalDesc').focus(); $('#ttxModalDesc').style.borderColor = '#DC2626'; return; }
    const n = st.frictions.filter(f=>!f.seed).length + 1;
    const id = 'FR-' + String(D.SEED_FRICTIONS.length + n).padStart(2,'0');
    st.frictions.push({ id, stage: st.current, lane: D.STAGES[st.current].lane,
      cat: modalSel.cat, sev: modalSel.sev, desc, mitigation: $('#ttxModalMit').value.trim(), at: st.elapsed, seed: false });
    addEvent('<b>FRICTION '+id+'</b> ('+esc(catOf(modalSel.cat).name)+' · '+esc(sevOf(modalSel.sev).name)+') — '+esc(desc.slice(0,70))+(desc.length>70?'…':''), 'fr');
    closeFriction(); updateBar();
    if ($('#ttxPaneRegister').classList.contains('on')) renderRegister();
    save();
  }
  function delFriction(id) {
    st.frictions = st.frictions.filter(f => f.id !== id);
    updateBar(); renderRegister(); save();
  }

  /* ---------- AI ---------- */
  async function aiCall(prompt, outEl, label) {
    if (!outEl) return;
    outEl.style.display = 'block';
    if (!window.claude || typeof window.claude.complete !== 'function') {
      outEl.classList.remove('loading'); outEl.textContent = 'AI is offline in this preview. (Connect an LLM endpoint to enable synthesis.)'; return;
    }
    outEl.classList.add('loading'); outEl.textContent = label || 'thinking';
    try {
      const r = await window.claude.complete({ messages: [{ role:'user', content: prompt }] });
      outEl.classList.remove('loading'); outEl.textContent = (r||'').toString().trim() || 'No response.';
    } catch(_) { outEl.classList.remove('loading'); outEl.textContent = 'AI briefly unavailable.'; }
  }
  function frictionDump() {
    return sortedFrictions().map(f => `${f.id} [${catOf(f.cat).name}/${sevOf(f.sev).name}] stage ${D.STAGES[f.stage].name}: ${f.desc}${f.mitigation?' (mitigation: '+f.mitigation+')':''}`).join('\n');
  }
  function aiSynth() {
    const v = variant();
    aiCall(
      'You are the EFDI TTX analysis group. Synthesise this friction register from Variant '+(v?v.id+' '+v.name:'?')+' into a tight prioritised summary for the senior leader outbrief: group by severity, name the single critical seam, and propose what to validate at the September LIVEX. Be institutional and concise.\n\nFRICTIONS:\n'+frictionDump(),
      $('#ttxAiSynthOut'), 'synthesising register…');
  }
  function aiQuick() {
    const v = variant();
    const completed = st.stamps.filter(x=>x!=null).length;
    aiCall(
      'Draft a 4-5 sentence Quick Look Report narrative (moderated hotwash style) for delegation heads. Variant '+(v?v.id+' '+v.name:'?')+'. Outcome: '+(st.outcome||'in play')+'. Stages stamped: '+completed+'/11. Total targeting time: '+fmtT(st.elapsed)+'. Keep it institutional and decision-focused.\n\nFRICTIONS:\n'+frictionDump(),
      $('#ttxAiQuickOut'), 'drafting narrative…');
  }
  function exportJson() {
    const blob = new Blob([JSON.stringify({ exercise: D.META.title, variant: st.variant, elapsed: st.elapsed, outcome: st.outcome, stamps: st.stamps, eq: st.eq, frictions: st.frictions, events: st.events }, null, 2)], { type:'application/json' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob);
    a.download = 'EFDI-TTX-Variant-'+(st.variant||'X')+'-quicklook.json'; a.click();
    setTimeout(()=>URL.revokeObjectURL(a.href), 2000);
  }

  /* ---------- bar ---------- */
  function updateBar() {
    const v = variant();
    $('#ttxBarVariant').textContent = v ? 'VARIANT '+v.id : 'NO VARIANT';
    $('#ttxBarClock').textContent = fmtT(st.elapsed, true);
    const rc = $('#ttxRegCnt'); if (rc) rc.textContent = st.frictions.length;
  }

  /* ============================================================
     WIRING
     ============================================================ */
  function wire() {
    // tabs
    document.addEventListener('click', e => {
      const tab = e.target.closest('[data-ttx-tab]'); if (tab) { setTab(tab.dataset.ttxTab); return; }
      const gb = e.target.closest('[data-goto-brief]'); if (gb) { setTab('brief'); return; }
      const lv = e.target.closest('[data-load-variant]'); if (lv) { loadVariant(lv.dataset.loadVariant); return; }
      const sn = e.target.closest('[data-stage]'); if (sn) { selectStage(+sn.dataset.stage); return; }
      // control buttons
      if (e.target.closest('#ttxPlayBtn')) { togglePlay(); return; }
      if (e.target.closest('#ttxResetBtn')) { resetExercise(); return; }
      if (e.target.closest('#ttxRedBtn')) { redPenalty(); return; }
      if (e.target.closest('#ttxAdvBtn')) { advanceStage(); return; }
      if (e.target.closest('#ttxFrBtn')) { openFriction(); return; }
      if (e.target.closest('#ttxClearLog')) { st.events=[]; renderEvents(); save(); return; }
      const sp = e.target.closest('[data-speed]'); if (sp) { setSpeed(+sp.dataset.speed); return; }
      const el = e.target.closest('[data-eq-log]'); if (el) { logEq(el.dataset.eqLog); return; }
      // register
      if (e.target.closest('#ttxAddFr')) { openFriction(); return; }
      if (e.target.closest('#ttxAiSynth')) { aiSynth(); return; }
      const df = e.target.closest('[data-del-fr]'); if (df) { delFriction(df.dataset.delFr); return; }
      // outputs
      if (e.target.closest('#ttxAiQuick')) { aiQuick(); return; }
      if (e.target.closest('#ttxExport')) { exportJson(); return; }
      // modal
      const mc = e.target.closest('[data-mcat]'); if (mc) { modalSel.cat = mc.dataset.mcat; $$('#ttxModalCats button').forEach(b=>b.classList.toggle('on', b===mc)); return; }
      const ms = e.target.closest('[data-msev]'); if (ms) { modalSel.sev = ms.dataset.msev; $$('#ttxModalSevs button').forEach(b=>b.classList.toggle('on', b===ms)); return; }
      if (e.target.closest('#ttxModalSave')) { saveFrictionEntry(); return; }
      if (e.target.closest('#ttxModalCancel') || e.target === $('#ttxModalBg')) { closeFriction(); return; }
    });
    // EQ input persistence (live, no re-render)
    document.addEventListener('input', e => {
      const t = e.target.closest('[data-eq-input]'); if (!t) return;
      const id = t.dataset.eqInput;
      const prev = st.eq[id] || {};
      st.eq[id] = { text: t.value, at: prev.at != null ? prev.at : null };
      save();
    });
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape' && $('#ttxModalBg').classList.contains('on')) closeFriction();
    });
  }

  /* ---------- boot ---------- */
  function boot() {
    st = load();
    wire(); updateBar(); renderBrief(); startClock();
    // restore running clock state but keep paused on reload for safety
    st.running = false; save();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
