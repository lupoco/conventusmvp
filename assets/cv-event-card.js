/* ============================================================
   CONVENTITY — cv-event-card.js
   Tek kaynak etkinlik kartı bileşeni (Go & Test + Go & Meet
   ortak kullanır). Vanilla, bağımsız. window.CVEventCard.

   DURUM ELLE GİRİLMEZ — hesaplanır (§5.2):
     draft · reg_soon · reg_open · reg_closed · running · done

   Kullanım:
     CVEventCard.status(ev)              -> durum anahtarı (string)
     CVEventCard.html(ev, opts)          -> kart HTML'i (string)
   opts: { t:fn(key)->label, href, communityLabel, accent }
   Not: t() verilmezse İngilizce yedek etiketler kullanılır.
   Stil için tokens.css/base.css değişkenlerine yaslanır; kart
   kendi minimal CSS'ini bir kez enjekte eder (.cvec-*).
   ============================================================ */
(function (w) {
  'use strict';
  if (w.CVEventCard) return;

  var FALLBACK = {
    st_draft: 'Draft', st_reg_soon: 'Registration soon', st_reg_open: 'Registration open',
    st_reg_closed: 'Registration closed', st_running: 'In progress', st_done: 'Completed',
    ec_cap: 'seats', ec_apps: 'applications', ec_view: 'View'
  };
  function tf(opts, key) {
    if (opts && typeof opts.t === 'function') {
      var v = opts.t(key);
      if (v != null && v !== key) return v;
    }
    return FALLBACK[key] != null ? FALLBACK[key] : key;
  }

  function ms(v) { return v ? new Date(v).getTime() : null; }

  /* Durumu SADECE veriden hesapla. now enjekte edilebilir (test). */
  function status(ev, nowMs) {
    var now = nowMs || Date.now();
    if (!ev || !ev.published) return 'draft';
    var ro = ms(ev.reg_opens_at), rc = ms(ev.reg_closes_at);
    var st = ms(ev.start_date), en = ms(ev.end_date);
    if (en != null && now > en) return 'done';
    if (st != null && now >= st && (en == null || now <= en)) return 'running';
    if (ro != null && now < ro) return 'reg_soon';
    if (rc != null && now > rc) return 'reg_closed';
    // pencere açık ya da hiç tanımlı değil ama yayında:
    if (ro != null || rc != null) return 'reg_open';
    return 'reg_open';
  }

  var STATUS_TONE = {
    draft: 'muted', reg_soon: 'gold', reg_open: 'ok',
    reg_closed: 'muted', running: 'pf', done: 'muted'
  };

  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function fmtDate(v) {
    if (!v) return '';
    var d = new Date(v);
    return String(d.getDate()).padStart(2, '0') + '.' +
           String(d.getMonth() + 1).padStart(2, '0') + '.' + d.getFullYear();
  }
  function dateRange(ev) {
    var a = fmtDate(ev.start_date), b = fmtDate(ev.end_date);
    if (a && b && a !== b) return a + ' – ' + b;
    return a || b || '';
  }

  var STYLE_ID = 'cvec-style';
  function injectStyle() {
    if (document.getElementById(STYLE_ID)) return;
    var css =
    '.cvec{display:block;position:relative;background:var(--paper);border:1px solid var(--line);' +
      'border-radius:var(--r-lg,16px);padding:18px 18px 16px;text-decoration:none;color:inherit;' +
      'box-shadow:var(--shadow-1);transition:transform .18s var(--ease),border-color .18s var(--ease)}' +
    '.cvec:hover{transform:translateY(-2px);border-color:color-mix(in srgb,var(--accent,var(--pf)) 40%,var(--line));text-decoration:none}' +
    '.cvec::before{content:"";position:absolute;left:0;top:14px;bottom:14px;width:3px;border-radius:3px;background:var(--accent,var(--pf))}' +
    '.cvec-top{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:8px;padding-left:8px}' +
    '.cvec-code{font-family:var(--font-mono);font-size:10px;letter-spacing:.08em;color:var(--muted)}' +
    '.cvec-comm{font-family:var(--font-mono);font-size:10px;letter-spacing:.04em;color:var(--accent,var(--pf));' +
      'border:1px solid color-mix(in srgb,var(--accent,var(--pf)) 30%,transparent);border-radius:var(--r-pill,999px);padding:1px 8px}' +
    '.cvec-st{margin-left:auto;font-family:var(--font-mono);font-size:9.5px;font-weight:700;letter-spacing:.06em;' +
      'text-transform:uppercase;padding:2px 9px;border-radius:var(--r-pill,999px);border:1px solid}' +
    '.cvec-st.ok{color:var(--ok);border-color:color-mix(in srgb,var(--ok) 45%,transparent)}' +
    '.cvec-st.gold{color:var(--warn);border-color:color-mix(in srgb,var(--gold) 45%,transparent)}' +
    '.cvec-st.pf{color:var(--pf);border-color:color-mix(in srgb,var(--pf) 45%,transparent)}' +
    '.cvec-st.muted{color:var(--muted);border-color:var(--line-2)}' +
    '.cvec-title{font-family:var(--font-display);font-weight:400;font-size:1.3rem;line-height:1.15;' +
      'color:var(--ink);margin:2px 0 6px;padding-left:8px}' +
    '.cvec-meta{display:flex;gap:14px;flex-wrap:wrap;padding-left:8px;font-size:12.5px;color:var(--muted)}' +
    '.cvec-meta b{color:var(--ink-2);font-weight:600;font-variant-numeric:tabular-nums}';
    var el = document.createElement('style');
    el.id = STYLE_ID; el.textContent = css;
    document.head.appendChild(el);
  }

  function html(ev, opts) {
    opts = opts || {};
    injectStyle();
    var stKey = status(ev, opts.now);
    var tone = STATUS_TONE[stKey] || 'muted';
    var tag = opts.href ? 'a' : 'div';
    var hrefAttr = opts.href ? ' href="' + esc(opts.href) + '"' : '';
    var accent = opts.accent ? ' style="--accent:' + esc(opts.accent) + '"' : '';
    var parts = [];
    parts.push('<' + tag + ' class="cvec"' + hrefAttr + accent + '>');
    parts.push('<div class="cvec-top">');
    if (ev.code) parts.push('<span class="cvec-code">' + esc(ev.code) + '</span>');
    if (opts.communityLabel) parts.push('<span class="cvec-comm">' + esc(opts.communityLabel) + '</span>');
    parts.push('<span class="cvec-st ' + tone + '">' + esc(tf(opts, 'st_' + stKey)) + '</span>');
    parts.push('</div>');
    parts.push('<div class="cvec-title">' + esc(ev.title || ev.code || '') + '</div>');
    parts.push('<div class="cvec-meta">');
    var dr = dateRange(ev);
    if (dr) parts.push('<span>' + esc(dr) + '</span>');
    if (ev.location || ev.city) parts.push('<span>' + esc(ev.location || ev.city) + '</span>');
    if (ev.capacity != null) parts.push('<span><b>' + esc(ev.capacity) + '</b> ' + esc(tf(opts, 'ec_cap')) + '</span>');
    parts.push('</div>');
    parts.push('</' + tag + '>');
    return parts.join('');
  }

  w.CVEventCard = { status: status, html: html, STATUS_TONE: STATUS_TONE };
})(window);
