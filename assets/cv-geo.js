/* =====================================================================
   cv-geo.js  ·  Conventity / Conventus
   ---------------------------------------------------------------------
   Country -> City cascading, searchable selector. Embedded curated
   dataset (NATO members + key partners), so it works fully offline /
   air-gapped. No dependencies, pure vanilla JS. Global: window.CVGeo
   - Country is picked from the list (ISO alpha-2 stored)
   - City suggests from the country, but free text is allowed (venues/bases)
   - Inherits the Conventity skin via CSS vars (auto dark-mode)
   - TR / EN via localStorage 'cv-lang'; diacritic-insensitive search

   INTEGRATION (one line):
     <script src="/assets/cv-geo.js" defer></script>

   USAGE (a single mount point renders both fields):
     <div data-cv-geo
          data-country-name="host_country"   (hidden input -> ISO code e.g. "TR")
          data-city-name="host_city"          (hidden input -> city text)
          data-country="TR" data-city="İzmir" (optional seed values)
          data-store-country="code|name">     (what the country hidden field holds; default "code")
     </div>

   EVENTS (dispatched on the mount element):
     'cv:geochange' -> detail { country:{code,name}|null, city:'' }

   PROGRAMMATIC:
     CVGeo.attach(el, opts)      CVGeo.scan(root)
     CVGeo.data                  the country array
     CVGeo.citiesOf('TR')        -> ['Ankara', ...]
     CVGeo.setLang('tr'|'en')
   ===================================================================== */
(function () {
  'use strict';
  if (window.CVGeo) return; // idempotent

  /* ---------- curated dataset (g: 'm'=NATO member, 'p'=partner) ------- */
  var GEO = [
    // ---- NATO members (32) ----
    {c:'AL',en:'Albania',tr:'Arnavutluk',g:'m',cities:['Tirana','Durrës','Vlorë']},
    {c:'BE',en:'Belgium',tr:'Belçika',g:'m',cities:['Brussels','Antwerp','Mons','Ghent','Liège']},
    {c:'BG',en:'Bulgaria',tr:'Bulgaristan',g:'m',cities:['Sofia','Plovdiv','Varna','Burgas']},
    {c:'CA',en:'Canada',tr:'Kanada',g:'m',cities:['Ottawa','Toronto','Montreal','Halifax','Kingston','Calgary']},
    {c:'HR',en:'Croatia',tr:'Hırvatistan',g:'m',cities:['Zagreb','Split','Rijeka','Zadar']},
    {c:'CZ',en:'Czechia',tr:'Çekya',g:'m',cities:['Prague','Brno','Ostrava','Pardubice']},
    {c:'DK',en:'Denmark',tr:'Danimarka',g:'m',cities:['Copenhagen','Aarhus','Aalborg','Odense']},
    {c:'EE',en:'Estonia',tr:'Estonya',g:'m',cities:['Tallinn','Tartu','Ämari','Narva']},
    {c:'FI',en:'Finland',tr:'Finlandiya',g:'m',cities:['Helsinki','Tampere','Turku','Rovaniemi']},
    {c:'FR',en:'France',tr:'Fransa',g:'m',cities:['Paris','Toulouse','Lyon','Marseille','Bordeaux','Brest']},
    {c:'DE',en:'Germany',tr:'Almanya',g:'m',cities:['Berlin','Munich','Ramstein','Cologne','Hamburg','Stuttgart','Bonn']},
    {c:'GR',en:'Greece',tr:'Yunanistan',g:'m',cities:['Athens','Thessaloniki','Larissa','Souda Bay','Patras']},
    {c:'HU',en:'Hungary',tr:'Macaristan',g:'m',cities:['Budapest','Debrecen','Pápa','Szeged']},
    {c:'IS',en:'Iceland',tr:'İzlanda',g:'m',cities:['Reykjavík','Keflavík','Akureyri']},
    {c:'IT',en:'Italy',tr:'İtalya',g:'m',cities:['Rome','Naples','Milan','Sigonella','Aviano','Turin','Vicenza']},
    {c:'LV',en:'Latvia',tr:'Letonya',g:'m',cities:['Riga','Ādaži','Liepāja','Daugavpils']},
    {c:'LT',en:'Lithuania',tr:'Litvanya',g:'m',cities:['Vilnius','Kaunas','Šiauliai','Klaipėda']},
    {c:'LU',en:'Luxembourg',tr:'Lüksemburg',g:'m',cities:['Luxembourg City']},
    {c:'ME',en:'Montenegro',tr:'Karadağ',g:'m',cities:['Podgorica','Nikšić','Bar']},
    {c:'NL',en:'Netherlands',tr:'Hollanda',g:'m',cities:['The Hague','Amsterdam','Rotterdam','Eindhoven','Brunssum']},
    {c:'MK',en:'North Macedonia',tr:'Kuzey Makedonya',g:'m',cities:['Skopje','Bitola','Kumanovo']},
    {c:'NO',en:'Norway',tr:'Norveç',g:'m',cities:['Oslo','Bergen','Stavanger','Bodø','Trondheim']},
    {c:'PL',en:'Poland',tr:'Polonya',g:'m',cities:['Warsaw','Kraków','Gdańsk','Poznań','Wrocław','Szczecin']},
    {c:'PT',en:'Portugal',tr:'Portekiz',g:'m',cities:['Lisbon','Porto','Lajes','Coimbra']},
    {c:'RO',en:'Romania',tr:'Romanya',g:'m',cities:['Bucharest','Constanța','Cluj-Napoca','Deveselu','Timișoara']},
    {c:'SK',en:'Slovakia',tr:'Slovakya',g:'m',cities:['Bratislava','Košice','Sliač']},
    {c:'SI',en:'Slovenia',tr:'Slovenya',g:'m',cities:['Ljubljana','Maribor','Cerklje']},
    {c:'ES',en:'Spain',tr:'İspanya',g:'m',cities:['Madrid','Barcelona','Rota','Valencia','Zaragoza','Sevilla']},
    {c:'SE',en:'Sweden',tr:'İsveç',g:'m',cities:['Stockholm','Gothenburg','Malmö','Luleå','Uppsala']},
    {c:'TR',en:'Türkiye',tr:'Türkiye',g:'m',cities:['Ankara','İstanbul','İzmir','Antalya','Konya','Eskişehir','İncirlik','Bursa']},
    {c:'GB',en:'United Kingdom',tr:'Birleşik Krallık',g:'m',cities:['London','Northwood','Portsmouth','Bristol','Edinburgh','Cardiff','Brize Norton']},
    {c:'US',en:'United States',tr:'ABD',g:'m',cities:['Washington DC','Norfolk','Tampa','San Diego','Colorado Springs','Boston','Huntsville','Arlington']},
    // ---- Key partners ----
    {c:'AU',en:'Australia',tr:'Avustralya',g:'p',cities:['Canberra','Sydney','Melbourne','Brisbane','Perth']},
    {c:'JP',en:'Japan',tr:'Japonya',g:'p',cities:['Tokyo','Yokosuka','Osaka','Nagoya']},
    {c:'KR',en:'South Korea',tr:'Güney Kore',g:'p',cities:['Seoul','Busan','Pyeongtaek','Daejeon']},
    {c:'NZ',en:'New Zealand',tr:'Yeni Zelanda',g:'p',cities:['Wellington','Auckland','Christchurch']},
    {c:'UA',en:'Ukraine',tr:'Ukrayna',g:'p',cities:['Kyiv','Lviv','Odesa','Kharkiv','Dnipro']},
    {c:'GE',en:'Georgia',tr:'Gürcistan',g:'p',cities:['Tbilisi','Batumi','Kutaisi']},
    {c:'AT',en:'Austria',tr:'Avusturya',g:'p',cities:['Vienna','Graz','Linz','Salzburg']},
    {c:'IE',en:'Ireland',tr:'İrlanda',g:'p',cities:['Dublin','Cork','Galway']},
    {c:'CH',en:'Switzerland',tr:'İsviçre',g:'p',cities:['Bern','Zürich','Geneva','Lausanne']},
    {c:'BA',en:'Bosnia and Herzegovina',tr:'Bosna-Hersek',g:'p',cities:['Sarajevo','Banja Luka','Mostar','Tuzla']},
    {c:'MD',en:'Moldova',tr:'Moldova',g:'p',cities:['Chișinău','Bălți','Tiraspol']},
    {c:'RS',en:'Serbia',tr:'Sırbistan',g:'p',cities:['Belgrade','Novi Sad','Niš']}
  ];
  var BY_CODE = {}; GEO.forEach(function (x) { BY_CODE[x.c] = x; });

  /* ---------- i18n ---------------------------------------------------- */
  var I18N = {
    en: { country:'Country', city:'City', searchCountry:'Search country…',
          searchCity:'Search or type city…', members:'NATO Members',
          partners:'Partners', none:'No matches' },
    tr: { country:'Ülke', city:'Şehir', searchCountry:'Ülke ara…',
          searchCity:'Şehir ara veya yaz…', members:'NATO Üyeleri',
          partners:'Ortaklar', none:'Eşleşme yok' }
  };
  function lang() {
    var l = (localStorage.getItem('cv-lang') || document.documentElement.lang || 'en').toLowerCase();
    return I18N[l] ? l : 'en';
  }
  function L() { return I18N[lang()]; }
  function cname(x) { return lang() === 'tr' ? x.tr : x.en; }

  /* ---------- diacritic-insensitive fold ----------------------------- */
  function fold(s) {
    s = String(s == null ? '' : s).toLowerCase()
      .replace(/ı/g, 'i').replace(/i̇/g, 'i').replace(/ş/g, 's').replace(/ğ/g, 'g')
      .replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ç/g, 'c');
    try { s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); } catch (e) {}
    return s.trim();
  }

  /* ---------- one-time style injection ------------------------------- */
  function injectCSS() {
    if (document.getElementById('cv-geo-css')) return;
    var s = document.createElement('style');
    s.id = 'cv-geo-css';
    s.textContent = [
      ".cvgeo{display:grid;grid-template-columns:1fr 1fr;gap:12px;font-family:'Manrope',system-ui,sans-serif}",
      '@media(max-width:520px){.cvgeo{grid-template-columns:1fr}}',
      '.cvgeo-f{position:relative;min-width:0}',
      '.cvgeo-l{display:block;font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;',
      '  color:var(--muted,#5A6486);margin-bottom:5px}',
      '.cvgeo-in{width:100%;padding:10px 30px 10px 12px;font:inherit;font-size:13.5px;',
      '  color:var(--ink,#0E2148);background:var(--paper,#fff);border:1px solid var(--line2,#D6CFBE);',
      '  border-radius:11px;outline:none;transition:border-color .12s,box-shadow .12s}',
      '.cvgeo-in::placeholder{color:var(--muted,#5A6486);opacity:.7}',
      '.cvgeo-in:focus{border-color:var(--pf,#004990);box-shadow:0 0 0 3px color-mix(in srgb,var(--pf,#004990) 16%,transparent)}',
      '.cvgeo-in:disabled{opacity:.5;cursor:not-allowed;background:var(--paper2,#FAF7F1)}',
      '.cvgeo-car{position:absolute;right:11px;bottom:11px;pointer-events:none;color:var(--muted,#5A6486);font-size:11px}',
      '.cvgeo-list{position:absolute;z-index:9998;left:0;right:0;top:calc(100% + 4px);max-height:260px;overflow:auto;',
      '  background:var(--paper,#fff);border:1px solid var(--line2,#D6CFBE);border-radius:12px;',
      '  box-shadow:0 12px 30px rgba(14,33,72,.16);padding:5px;display:none}',
      '.cvgeo-list.cvgeo-show{display:block}',
      '.cvgeo-h{font-size:10px;font-weight:800;letter-spacing:.09em;text-transform:uppercase;',
      "  color:var(--gold,#B8892B);padding:8px 9px 4px;font-family:'JetBrains Mono',ui-monospace,monospace}",
      '.cvgeo-o{display:flex;align-items:center;gap:8px;padding:8px 9px;border-radius:8px;cursor:pointer;font-size:13px;',
      '  color:var(--ink,#0E2148)}',
      '.cvgeo-o:hover,.cvgeo-o.cvgeo-hi{background:var(--paper2,#FAF7F1)}',
      '.cvgeo-code{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:10.5px;font-weight:600;',
      '  color:var(--muted,#5A6486);border:1px solid var(--line,#E5DFD2);border-radius:6px;padding:1px 5px;margin-left:auto}',
      '.cvgeo-none{padding:12px 10px;font-size:12.5px;color:var(--muted,#5A6486);text-align:center}'
    ].join('');
    document.head.appendChild(s);
  }

  /* ---------- searchable combobox ------------------------------------ */
  function Combo(field, cfg) {
    this.field = field;                 // .cvgeo-f wrapper
    this.input = field.querySelector('.cvgeo-in');
    this.list = field.querySelector('.cvgeo-list');
    this.getItems = cfg.getItems;       // () -> [{key, label, code?, group?}]
    this.onPick = cfg.onPick;           // (item) -> void
    this.onType = cfg.onType || null;   // (text) -> void  (free-text fields)
    this.value = null;                  // selected item key
    this.hi = -1;
    this._bind();
  }
  Combo.prototype._bind = function () {
    var self = this, inp = this.input;
    inp.addEventListener('focus', function () { self.open(); });
    inp.addEventListener('click', function () { self.open(); });
    inp.addEventListener('input', function () {
      self.render(inp.value);
      if (self.onType) self.onType(inp.value);
    });
    inp.addEventListener('keydown', function (e) { self._key(e); });
    inp.addEventListener('blur', function () { setTimeout(function () { self.close(); }, 140); });
  };
  Combo.prototype._key = function (e) {
    var opts = this.list.querySelectorAll('.cvgeo-o');
    if (e.key === 'ArrowDown') { e.preventDefault(); this.hi = Math.min(this.hi + 1, opts.length - 1); this._paint(opts); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); this.hi = Math.max(this.hi - 1, 0); this._paint(opts); }
    else if (e.key === 'Enter') { if (this.hi >= 0 && opts[this.hi]) { e.preventDefault(); opts[this.hi].click(); } }
    else if (e.key === 'Escape') { this.close(); }
  };
  Combo.prototype._paint = function (opts) {
    for (var i = 0; i < opts.length; i++) opts[i].classList.toggle('cvgeo-hi', i === this.hi);
    if (opts[this.hi]) opts[this.hi].scrollIntoView({ block: 'nearest' });
  };
  Combo.prototype.open = function () { this.render(this.input.value); this.list.classList.add('cvgeo-show'); };
  Combo.prototype.close = function () { this.list.classList.remove('cvgeo-show'); this.hi = -1; };
  Combo.prototype.render = function (q) {
    var self = this, items = this.getItems() || [], t = L();
    var fq = fold(q);
    // if the query exactly equals the current selection label, show all
    var filtered = fq ? items.filter(function (it) { return it._search.indexOf(fq) !== -1; }) : items;
    this.hi = -1;
    if (!filtered.length) { this.list.innerHTML = '<div class="cvgeo-none">' + t.none + '</div>'; return; }
    var html = '', lastGroup = null;
    filtered.forEach(function (it) {
      if (it.group && it.group !== lastGroup) {
        html += '<div class="cvgeo-h">' + (it.group === 'm' ? t.members : t.partners) + '</div>';
        lastGroup = it.group;
      }
      html += '<div class="cvgeo-o" data-key="' + esc(it.key) + '">' + esc(it.label) +
              (it.code ? '<span class="cvgeo-code">' + esc(it.code) + '</span>' : '') + '</div>';
    });
    this.list.innerHTML = html;
    Array.prototype.forEach.call(this.list.querySelectorAll('.cvgeo-o'), function (o) {
      o.addEventListener('mousedown', function (e) { e.preventDefault(); }); // keep focus
      o.addEventListener('click', function () {
        var it = filtered.filter(function (x) { return String(x.key) === o.getAttribute('data-key'); })[0];
        if (it) { self.pick(it); }
      });
    });
  };
  Combo.prototype.pick = function (it) {
    this.value = it.key;
    this.input.value = it.label;
    this.close();
    this.onPick(it);
  };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (m) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[m];
    });
  }

  /* ---------- mount --------------------------------------------------- */
  function hiddenField(mount, name, seed) {
    if (!name) return null;
    var form = mount.form || mount.closest('form') || mount;
    var h = form.querySelector('input[type="hidden"][name="' + name + '"]');
    if (!h) { h = document.createElement('input'); h.type = 'hidden'; h.name = name; mount.appendChild(h); }
    if (seed != null && !h.value) h.value = seed;
    return h;
  }

  function Geo(mount) {
    var self = this;
    this.mount = mount;
    this.storeCountry = (mount.getAttribute('data-store-country') === 'name') ? 'name' : 'code';
    this.selCountry = null;   // GEO row
    this.city = '';

    var t = L();
    mount.classList.add('cvgeo');
    mount.innerHTML =
      '<div class="cvgeo-f" data-role="country">' +
        '<label class="cvgeo-l">' + esc(t.country) + '</label>' +
        '<input class="cvgeo-in" type="text" autocomplete="off" placeholder="' + esc(t.searchCountry) + '"/>' +
        '<span class="cvgeo-car">▾</span><div class="cvgeo-list"></div></div>' +
      '<div class="cvgeo-f" data-role="city">' +
        '<label class="cvgeo-l">' + esc(t.city) + '</label>' +
        '<input class="cvgeo-in" type="text" autocomplete="off" placeholder="' + esc(t.searchCity) + '" disabled/>' +
        '<span class="cvgeo-car">▾</span><div class="cvgeo-list"></div></div>';

    this.hCountry = hiddenField(mount, mount.getAttribute('data-country-name'));
    this.hCity = hiddenField(mount, mount.getAttribute('data-city-name'));

    // country combo
    this.countryCombo = new Combo(mount.querySelector('[data-role="country"]'), {
      getItems: function () {
        return GEO.map(function (x) {
          return { key: x.c, label: cname(x), code: x.c, group: x.g, _search: fold(cname(x) + ' ' + x.en + ' ' + x.c) };
        }).sort(function (a, b) {
          return a.group === b.group ? a.label.localeCompare(b.label) : (a.group === 'm' ? -1 : 1);
        });
      },
      onPick: function (it) { self.setCountry(BY_CODE[it.key]); }
    });

    // city combo (free text allowed)
    this.cityCombo = new Combo(mount.querySelector('[data-role="city"]'), {
      getItems: function () {
        if (!self.selCountry) return [];
        return self.selCountry.cities.map(function (c) { return { key: c, label: c, _search: fold(c) }; });
      },
      onPick: function (it) { self.setCity(it.label); },
      onType: function (txt) { self.setCity(txt); } // typed venue/base kept as-is
    });

    // seed
    var seedC = mount.getAttribute('data-country');
    if (seedC && BY_CODE[seedC]) { this.setCountry(BY_CODE[seedC]); }
    var seedCity = mount.getAttribute('data-city');
    if (seedCity && this.selCountry) { this.cityCombo.input.value = seedCity; this.setCity(seedCity); }
  }

  Geo.prototype.setCountry = function (row) {
    this.selCountry = row || null;
    this.countryCombo.input.value = row ? cname(row) : '';
    this.countryCombo.value = row ? row.c : null;
    if (this.hCountry) this.hCountry.value = row ? (this.storeCountry === 'name' ? row.en : row.c) : '';
    // reset city on country change
    var cityInput = this.cityCombo.input;
    cityInput.disabled = !row;
    cityInput.value = '';
    this.city = '';
    if (this.hCity) this.hCity.value = '';
    this.cityCombo.value = null;
    this._emit();
  };

  Geo.prototype.setCity = function (txt) {
    this.city = (txt || '').trim();
    if (this.hCity) this.hCity.value = this.city;
    this._emit();
  };

  Geo.prototype._emit = function () {
    this.mount.dispatchEvent(new CustomEvent('cv:geochange', {
      bubbles: true,
      detail: {
        country: this.selCountry ? { code: this.selCountry.c, name: this.selCountry.en } : null,
        city: this.city
      }
    }));
  };

  /* ---------- public API + auto-init --------------------------------- */
  function attach(el) {
    if (!el || el._cvgeo) return el && el._cvgeo;
    injectCSS();
    el._cvgeo = new Geo(el);
    return el._cvgeo;
  }
  function scan(root) {
    (root || document).querySelectorAll('[data-cv-geo]').forEach(function (el) {
      if (!el._cvgeo) attach(el);
    });
  }
  function citiesOf(code) { return BY_CODE[code] ? BY_CODE[code].cities.slice() : []; }
  function setLang(l) { if (I18N[l]) localStorage.setItem('cv-lang', l); }

  window.CVGeo = { attach: attach, scan: scan, data: GEO, citiesOf: citiesOf, setLang: setLang };

  function boot() {
    injectCSS();
    scan(document);
    if (window.MutationObserver) {
      new MutationObserver(function (m) {
        for (var i = 0; i < m.length; i++) if (m[i].addedNodes && m[i].addedNodes.length) { scan(document); break; }
      }).observe(document.body, { childList: true, subtree: true });
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
