/* ============================================================
   CONVENTITY — PREFERENCES  (theme + language)

   Loaded SYNCHRONOUSLY in <head> (no defer) so it sets
   data-theme / data-lang on <html> BEFORE the page paints —
   this is what prevents the light-then-dark "flash".

   Exposes window.CVPrefs. Persists to localStorage, which
   works on the real site (it is not available inside the
   in-chat artifact preview, only on your deployed pages).

   Theme values:  'system' (default) | 'light' | 'dark'
   Lang values:   'tr' (default) | 'en'
   ============================================================ */

(function () {
  'use strict';

  var TKEY = 'cv-theme', LKEY = 'cv-lang';
  var DEFAULT_THEME = 'system';   // change here to force a default
  var DEFAULT_LANG  = 'en';       // English-first (S3); toggle offers TR

  var root = document.documentElement;
  var subs = [];

  function ls(get, key, val) {
    try { return get ? localStorage.getItem(key) : localStorage.setItem(key, val); }
    catch (e) { return null; } // private mode / storage disabled → in-memory only
  }
  function lsDel(key) { try { localStorage.removeItem(key); } catch (e) {} }

  /* Legacy anahtar göçü — tek kaynağa (cv-theme / cv-lang) taşı.
     Eski sayfalar farklı anahtarlar kullanıyordu; ilk yüklemede
     tercihi kaybetmeden yeni anahtara aktar. */
  (function migrate() {
    if (!ls(true, TKEY)) {
      var legacyT = ls(true, 'conventity-theme-pref') || ls(true, 'conventity-theme');
      var legacyDark = ls(true, 'cn-dark'); // '1' = dark, '0' = light
      if (legacyT === 'light' || legacyT === 'dark' || legacyT === 'system') ls(false, TKEY, legacyT);
      else if (legacyDark === '1') ls(false, TKEY, 'dark');
      else if (legacyDark === '0') ls(false, TKEY, 'light');
    }
    if (!ls(true, LKEY)) {
      var legacyL = ls(true, 'conventity-lang');
      if (legacyL === 'tr' || legacyL === 'en') ls(false, LKEY, legacyL);
    }
    lsDel('conventity-theme-pref'); lsDel('conventity-theme');
    lsDel('cn-dark'); lsDel('conventity-lang');
  })();

  var theme = ls(true, TKEY) || DEFAULT_THEME;
  var lang  = ls(true, LKEY) || DEFAULT_LANG;

  function prefersDark() {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  function resolveTheme(t) { return t === 'system' ? (prefersDark() ? 'dark' : 'light') : t; }

  function applyTheme() {
    root.setAttribute('data-theme', resolveTheme(theme)); // the effective look
    root.setAttribute('data-theme-pref', theme);          // the raw preference
  }
  function applyLang() { root.setAttribute('data-lang', lang); }

  // Apply immediately (this is why the file must load in <head>, sync).
  applyTheme();
  applyLang();

  function emit(what) { subs.forEach(function (cb) { try { cb(what); } catch (e) {} }); }

  // React to OS theme changes while in 'system' mode.
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var onSys = function () { if (theme === 'system') { applyTheme(); emit('theme'); } };
    if (mq.addEventListener) mq.addEventListener('change', onSys);
    else if (mq.addListener) mq.addListener(onSys); // older browsers
  }

  window.CVPrefs = {
    getTheme:         function () { return theme; },                 // 'system'|'light'|'dark'
    getResolvedTheme: function () { return resolveTheme(theme); },   // 'light'|'dark'
    setTheme: function (t) {
      if (t !== 'system' && t !== 'light' && t !== 'dark') return;
      theme = t; ls(false, TKEY, t); applyTheme(); emit('theme');
    },
    // Quick toggle for the nav button: flips the *effective* look and
    // stores it explicitly (leaves 'system' behind on first click).
    toggleTheme: function () {
      this.setTheme(resolveTheme(theme) === 'dark' ? 'light' : 'dark');
    },

    getLang: function () { return lang; },                           // 'tr'|'en'
    setLang: function (l) {
      if (l !== 'tr' && l !== 'en') return;
      lang = l; ls(false, LKEY, l); applyLang(); emit('lang');
    },
    toggleLang: function () { this.setLang(lang === 'tr' ? 'en' : 'tr'); },

    onChange: function (cb) { if (typeof cb === 'function') subs.push(cb); },
  };
})();
