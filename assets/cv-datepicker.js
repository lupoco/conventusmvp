/* =====================================================================
   cv-datepicker.js  ·  Conventity / Conventus
   ---------------------------------------------------------------------
   DD.MM.YYYY masked input + calendar popover. NATIVE date inputs banned.
   - Zero dependencies, pure vanilla JS, single global: window.CVDatePicker
   - Inherits the Conventity skin via CSS variables (auto dark-mode:
     the host flips --bg/--paper/--ink/... on body[data-dark], we follow)
   - TR / EN via localStorage 'cv-lang' (default 'en'), Monday-first weeks
   - Air-gap safe: no network, no CDN, no framework

   INTEGRATION (one line in <head> or before </body>):
     <script src="/assets/cv-datepicker.js" defer></script>

   USAGE (any text input — do NOT use <input type="date">):
     <input data-cv-date placeholder="DD.MM.YYYY" />

   OPTIONAL attributes:
     data-min="01.01.2026"      earliest selectable date
     data-max="31.12.2026"      latest selectable date
     data-iso-name="start_date" mirrors an ISO value (YYYY-MM-DD) into a
                                hidden <input name="start_date"> for DB/forms
     data-week-start="0"        0 = Monday (default), 6 = Sunday

   EVENTS (dispatched on the visible input):
     'cv:datechange' -> detail { display:'DD.MM.YYYY'|'', iso:'YYYY-MM-DD'|'', date:Date|null }

   PROGRAMMATIC:
     CVDatePicker.attach(el, opts)      enhance an input manually
     CVDatePicker.parse('DD.MM.YYYY')   -> Date | null
     CVDatePicker.formatDisplay(date)   -> 'DD.MM.YYYY'
     CVDatePicker.formatISO(date)       -> 'YYYY-MM-DD'
     CVDatePicker.setLang('tr'|'en')    switch language at runtime
   ===================================================================== */
(function () {
  'use strict';
  if (window.CVDatePicker) return; // idempotent — never double-init

  /* ---------- i18n ---------------------------------------------------- */
  var I18N = {
    en: {
      months: ['January','February','March','April','May','June',
               'July','August','September','October','November','December'],
      wd: ['Mo','Tu','We','Th','Fr','Sa','Su'],   // Monday-first
      today: 'Today', clear: 'Clear'
    },
    tr: {
      months: ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
               'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'],
      wd: ['Pt','Sa','Ça','Pe','Cu','Ct','Pz'],
      today: 'Bugün', clear: 'Temizle'
    }
  };
  function lang() {
    var l = (localStorage.getItem('cv-lang') || document.documentElement.lang || 'en').toLowerCase();
    return I18N[l] ? l : 'en';
  }
  function L() { return I18N[lang()]; }

  /* ---------- date helpers ------------------------------------------- */
  function pad2(n) { return (n < 10 ? '0' : '') + n; }
  function isLeap(y) { return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0; }
  function daysInMonth(y, m) { // m: 0-11
    return [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m];
  }
  function parse(str) { // 'DD.MM.YYYY' -> Date | null (strict)
    if (!str) return null;
    var m = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(String(str).trim());
    if (!m) return null;
    var d = +m[1], mo = +m[2], y = +m[3];
    if (mo < 1 || mo > 12) return null;
    if (d < 1 || d > daysInMonth(y, mo - 1)) return null;
    return new Date(y, mo - 1, d);
  }
  function formatDisplay(dt) {
    return dt ? pad2(dt.getDate()) + '.' + pad2(dt.getMonth() + 1) + '.' + dt.getFullYear() : '';
  }
  function formatISO(dt) {
    return dt ? dt.getFullYear() + '-' + pad2(dt.getMonth() + 1) + '-' + pad2(dt.getDate()) : '';
  }
  function sameDay(a, b) {
    return a && b && a.getFullYear() === b.getFullYear() &&
           a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }
  function atMidnight(dt) { return new Date(dt.getFullYear(), dt.getMonth(), dt.getDate()); }

  /* ---------- one-time style injection ------------------------------- */
  function injectCSS() {
    if (document.getElementById('cv-datepicker-css')) return;
    var s = document.createElement('style');
    s.id = 'cv-datepicker-css';
    s.textContent = [
      // Fallback palette matches the Conventity skin; host CSS vars win.
      '.cvdp-pop{position:absolute;z-index:9999;width:264px;padding:10px;',
      '  background:var(--paper,#fff);color:var(--ink,#0E2148);',
      '  border:1px solid var(--line2,#D6CFBE);border-radius:14px;',
      '  box-shadow:0 12px 34px rgba(14,33,72,.18);',
      "  font-family:'Manrope',system-ui,sans-serif;font-size:13px;",
      '  opacity:0;transform:translateY(-4px);pointer-events:none;',
      '  transition:opacity .12s ease,transform .12s ease}',
      '.cvdp-pop.cvdp-open{opacity:1;transform:translateY(0);pointer-events:auto}',
      '.cvdp-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}',
      '.cvdp-title{font-weight:700;font-size:13.5px;letter-spacing:.01em}',
      '.cvdp-nav{display:flex;gap:4px}',
      '.cvdp-btn{width:28px;height:28px;display:grid;place-items:center;cursor:pointer;',
      '  border:1px solid var(--line,#E5DFD2);border-radius:9px;background:var(--paper2,#FAF7F1);',
      '  color:var(--ink2,#1F2D55);transition:background .12s,border-color .12s}',
      '.cvdp-btn:hover{border-color:var(--pf,#004990);color:var(--pf,#004990)}',
      '.cvdp-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:2px}',
      '.cvdp-wd{text-align:center;font-size:10.5px;font-weight:700;color:var(--muted,#5A6486);',
      "  padding:4px 0;font-family:'JetBrains Mono',ui-monospace,monospace;letter-spacing:.02em}",
      '.cvdp-day{aspect-ratio:1/1;display:grid;place-items:center;cursor:pointer;border-radius:9px;',
      '  font-size:12.5px;color:var(--ink,#0E2148);border:1px solid transparent;',
      '  transition:background .1s,color .1s,border-color .1s}',
      '.cvdp-day:hover:not(.cvdp-off):not(.cvdp-dis){background:var(--paper2,#FAF7F1);border-color:var(--line2,#D6CFBE)}',
      '.cvdp-day.cvdp-off{color:var(--muted,#5A6486);opacity:.45}',
      '.cvdp-day.cvdp-dis{opacity:.28;cursor:not-allowed}',
      '.cvdp-day.cvdp-today{box-shadow:inset 0 0 0 1.5px var(--gold,#B8892B)}',
      '.cvdp-day.cvdp-sel{background:var(--pf,#004990);color:#fff;font-weight:700;border-color:var(--pf,#004990)}',
      '.cvdp-day.cvdp-sel:hover{background:var(--pf,#004990)}',
      '.cvdp-foot{display:flex;gap:6px;margin-top:8px}',
      '.cvdp-foot button{flex:1;padding:6px 0;cursor:pointer;font:inherit;font-size:11.5px;font-weight:600;',
      '  border:1px solid var(--line,#E5DFD2);border-radius:9px;background:var(--paper2,#FAF7F1);',
      '  color:var(--ink2,#1F2D55);transition:border-color .12s,color .12s}',
      '.cvdp-foot button:hover{border-color:var(--pf,#004990);color:var(--pf,#004990)}',
      // input state
      "input[data-cv-date]{font-family:'JetBrains Mono',ui-monospace,monospace;letter-spacing:.02em}",
      'input[data-cv-date].cvdp-invalid{border-color:var(--bad,#C0392B)!important;',
      '  box-shadow:0 0 0 2px color-mix(in srgb,var(--bad,#C0392B) 22%,transparent)}'
    ].join('');
    document.head.appendChild(s);
  }

  /* ---------- popover engine ----------------------------------------- */
  var openInstance = null; // only one popover open at a time

  function Picker(input, opts) {
    this.input = input;
    this.min = opts.min || parse(input.getAttribute('data-min'));
    this.max = opts.max || parse(input.getAttribute('data-max'));
    this.weekStart = (input.getAttribute('data-week-start') === '6') ? 6 : 0; // 0=Mon,6=Sun
    this.isoName = input.getAttribute('data-iso-name') || null;
    this.selected = parse(input.value) || null;
    this.view = this.selected ? new Date(this.selected) : new Date();
    this.pop = null;
    this._bind();
    if (this.selected) this._syncISO(this.selected); // seed hidden field from existing value
  }

  Picker.prototype._bind = function () {
    var self = this, el = this.input;
    el.setAttribute('inputmode', 'numeric');
    el.setAttribute('autocomplete', 'off');
    if (!el.getAttribute('placeholder')) el.setAttribute('placeholder', 'DD.MM.YYYY');
    el.setAttribute('maxlength', '10');

    el.addEventListener('input', function () { self._mask(); });
    el.addEventListener('blur', function () {
      setTimeout(function () { if (openInstance !== self) self._validate(); }, 120);
    });
    el.addEventListener('focus', function () { self.open(); });
    el.addEventListener('click', function () { self.open(); });
    el.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') self.close();
      if (e.key === 'Enter') { self._validate(); self.close(); }
    });
  };

  // Mask keystrokes into DD.MM.YYYY as the user types digits.
  Picker.prototype._mask = function () {
    var el = this.input, digits = el.value.replace(/\D/g, '').slice(0, 8), out = '';
    for (var i = 0; i < digits.length; i++) {
      if (i === 2 || i === 4) out += '.';
      out += digits[i];
    }
    el.value = out;
    el.classList.remove('cvdp-invalid');
    var dt = parse(out);
    if (dt && this._inRange(dt)) { this.selected = dt; this.view = new Date(dt); this._syncISO(dt); this._render(); }
  };

  Picker.prototype._inRange = function (dt) {
    var d = atMidnight(dt);
    if (this.min && d < atMidnight(this.min)) return false;
    if (this.max && d > atMidnight(this.max)) return false;
    return true;
  };

  Picker.prototype._validate = function () {
    var dt = parse(this.input.value);
    if (this.input.value && (!dt || !this._inRange(dt))) {
      this.input.classList.add('cvdp-invalid');
      this._commit(null, false);
    } else {
      this.input.classList.remove('cvdp-invalid');
      this._commit(dt, false);
    }
  };

  Picker.prototype._syncISO = function (dt) {
    if (!this.isoName) return;
    var form = this.input.form || document;
    var hidden = form.querySelector('input[type="hidden"][name="' + this.isoName + '"]');
    if (!hidden) {
      hidden = document.createElement('input');
      hidden.type = 'hidden';
      hidden.name = this.isoName;
      (this.input.form || this.input.parentNode).appendChild(hidden);
    }
    hidden.value = dt ? formatISO(dt) : '';
  };

  Picker.prototype._commit = function (dt, closeAfter) {
    this.selected = dt || null;
    this.input.value = formatDisplay(dt);
    this._syncISO(dt);
    this.input.dispatchEvent(new CustomEvent('cv:datechange', {
      bubbles: true,
      detail: { display: formatDisplay(dt), iso: formatISO(dt), date: dt || null }
    }));
    if (closeAfter) this.close();
  };

  Picker.prototype._buildPop = function () {
    this.pop = document.createElement('div');
    this.pop.className = 'cvdp-pop';
    this.pop.setAttribute('role', 'dialog');
    document.body.appendChild(this.pop);
    var self = this;
    this.pop.addEventListener('mousedown', function (e) { e.preventDefault(); }); // keep input focus
  };

  Picker.prototype._render = function () {
    if (!this.pop) return;
    var t = L(), self = this;
    var y = this.view.getFullYear(), m = this.view.getMonth();
    var today = atMidnight(new Date());

    // header
    var html = '<div class="cvdp-head">';
    html += '<div class="cvdp-title">' + t.months[m] + ' ' + y + '</div>';
    html += '<div class="cvdp-nav">' +
      '<div class="cvdp-btn" data-nav="-1" aria-label="prev">‹</div>' +
      '<div class="cvdp-btn" data-nav="1" aria-label="next">›</div></div></div>';

    // weekday row (respect week start)
    html += '<div class="cvdp-grid">';
    var wd = t.wd.slice();
    if (this.weekStart === 6) wd = [t.wd[6]].concat(t.wd.slice(0, 6));
    for (var w = 0; w < 7; w++) html += '<div class="cvdp-wd">' + wd[w] + '</div>';

    // leading blanks: JS getDay() 0=Sun..6=Sat
    var first = new Date(y, m, 1).getDay();          // 0..6 (Sun..Sat)
    var offset = this.weekStart === 6 ? first : (first + 6) % 7; // Mon-first shift
    var dim = daysInMonth(y, m);
    var prevDim = daysInMonth(m === 0 ? y - 1 : y, (m + 11) % 12);

    var cells = [];
    for (var i = 0; i < offset; i++) cells.push({ d: prevDim - offset + 1 + i, off: true, mo: m - 1 });
    for (var d = 1; d <= dim; d++) cells.push({ d: d, off: false, mo: m });
    while (cells.length % 7 !== 0 || cells.length < 42) cells.push({ d: cells.length - offset - dim + 1, off: true, mo: m + 1 });
    cells = cells.slice(0, 42);

    for (var c = 0; c < cells.length; c++) {
      var cell = cells[c];
      var actual; // reconstruct the real date: leading cells (c<7) = prev month, trailing = next
      if (!cell.off) actual = new Date(y, m, cell.d);
      else if (c < 7) actual = new Date(y, m - 1, cell.d);
      else actual = new Date(y, m + 1, cell.d);
      var dm = atMidnight(actual);
      var cls = 'cvdp-day' + (cell.off ? ' cvdp-off' : '');
      if (sameDay(dm, today)) cls += ' cvdp-today';
      if (this.selected && sameDay(dm, atMidnight(this.selected))) cls += ' cvdp-sel';
      var disabled = !this._inRange(actual);
      if (disabled) cls += ' cvdp-dis';
      html += '<div class="' + cls + '" data-iso="' + formatISO(actual) + '"' +
              (disabled ? '' : ' role="button" tabindex="-1"') + '>' + cell.d + '</div>';
    }
    html += '</div>';

    // footer
    html += '<div class="cvdp-foot">' +
      '<button data-act="today">' + t.today + '</button>' +
      '<button data-act="clear">' + t.clear + '</button></div>';

    this.pop.innerHTML = html;

    // wire header nav
    Array.prototype.forEach.call(this.pop.querySelectorAll('[data-nav]'), function (b) {
      b.addEventListener('click', function () {
        self.view = new Date(self.view.getFullYear(), self.view.getMonth() + (+b.getAttribute('data-nav')), 1);
        self._render();
      });
    });
    // wire days
    Array.prototype.forEach.call(this.pop.querySelectorAll('.cvdp-day:not(.cvdp-dis)'), function (cellEl) {
      cellEl.addEventListener('click', function () {
        var iso = cellEl.getAttribute('data-iso');
        var p = iso.split('-');
        self._commit(new Date(+p[0], +p[1] - 1, +p[2]), true);
      });
    });
    // wire footer
    var todayBtn = this.pop.querySelector('[data-act="today"]');
    var clearBtn = this.pop.querySelector('[data-act="clear"]');
    todayBtn.addEventListener('click', function () {
      var now = atMidnight(new Date());
      if (self._inRange(now)) self._commit(now, true);
      else { self.view = new Date(); self._render(); }
    });
    clearBtn.addEventListener('click', function () {
      self.input.classList.remove('cvdp-invalid');
      self._commit(null, true);
    });
  };

  Picker.prototype._place = function () {
    var r = this.input.getBoundingClientRect();
    var sx = window.pageXOffset, sy = window.pageYOffset;
    var popH = this.pop.offsetHeight || 300, vh = window.innerHeight;
    var top = r.bottom + sy + 6;
    if (r.bottom + popH + 8 > vh) top = r.top + sy - popH - 6; // flip up
    var left = r.left + sx;
    var maxLeft = sx + document.documentElement.clientWidth - this.pop.offsetWidth - 8;
    if (left > maxLeft) left = Math.max(sx + 8, maxLeft);
    this.pop.style.top = top + 'px';
    this.pop.style.left = left + 'px';
  };

  Picker.prototype.open = function () {
    if (openInstance && openInstance !== this) openInstance.close();
    if (openInstance === this) return;
    injectCSS();
    if (!this.pop) this._buildPop();
    this.view = this.selected ? new Date(this.selected) : new Date();
    this._render();
    this.pop.style.display = 'block';
    this._place();
    var self = this;
    requestAnimationFrame(function () { self.pop.classList.add('cvdp-open'); });
    openInstance = this;
    this._outside = function (e) {
      if (!self.pop.contains(e.target) && e.target !== self.input) self.close();
    };
    this._reposition = function () { if (openInstance === self) self._place(); };
    setTimeout(function () { document.addEventListener('mousedown', self._outside); }, 0);
    window.addEventListener('resize', this._reposition);
    window.addEventListener('scroll', this._reposition, true);
  };

  Picker.prototype.close = function () {
    if (!this.pop) return;
    var self = this;
    this.pop.classList.remove('cvdp-open');
    document.removeEventListener('mousedown', this._outside);
    window.removeEventListener('resize', this._reposition);
    window.removeEventListener('scroll', this._reposition, true);
    setTimeout(function () { if (self.pop) self.pop.style.display = 'none'; }, 130);
    if (openInstance === this) openInstance = null;
    this._validate();
  };

  /* ---------- public API + auto-init --------------------------------- */
  function attach(el, opts) {
    if (!el || el._cvdp) return el && el._cvdp;
    if (el.tagName === 'INPUT' && el.type === 'date') el.type = 'text'; // native banned
    el.setAttribute('data-cv-date', '');
    el._cvdp = new Picker(el, opts || {});
    return el._cvdp;
  }
  function scan(root) {
    (root || document).querySelectorAll('input[data-cv-date]').forEach(function (el) {
      if (!el._cvdp) attach(el);
    });
  }
  function setLang(l) {
    if (I18N[l]) localStorage.setItem('cv-lang', l);
    if (openInstance) openInstance._render();
  }

  window.CVDatePicker = {
    attach: attach, scan: scan, parse: parse,
    formatDisplay: formatDisplay, formatISO: formatISO, setLang: setLang
  };

  // auto-init on load + observe dynamically-added inputs
  function boot() {
    injectCSS();
    scan(document);
    if (window.MutationObserver) {
      new MutationObserver(function (muts) {
        for (var i = 0; i < muts.length; i++) {
          if (muts[i].addedNodes && muts[i].addedNodes.length) { scan(document); break; }
        }
      }).observe(document.body, { childList: true, subtree: true });
    }
    // react to language changes made elsewhere (storage event or cv-lang toggle)
    window.addEventListener('storage', function (e) { if (e.key === 'cv-lang' && openInstance) openInstance._render(); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
