/* ============================================================
   CONNECTUS — signed-in app shell runtime
   Single source of prefs = CVPrefs (prefs.js) + i18n.js.
   Handles: theme segment, language toggle, "Me" menu, sign-out,
   and a language-change hook so JS-rendered content re-renders.
   Requires (in this order, in <head> where noted):
     prefs.js (sync, head) · i18n.js · this file.
   ============================================================ */
(function () {
  'use strict';
  var P = window.CVPrefs;
  function T(k, fb) { return (window.T ? window.T(k) : null) || fb || k; }

  /* ── THEME segment (reflect + set via CVPrefs) ── */
  function paintTheme() {
    var pref = P ? P.getTheme() : 'system';
    document.querySelectorAll('[data-theme-control] [data-theme-pref]').forEach(function (b) {
      var on = b.getAttribute('data-theme-pref') === pref;
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
      b.classList.toggle('on', on);
    });
  }
  document.querySelectorAll('[data-theme-control] [data-theme-pref]').forEach(function (b) {
    b.addEventListener('click', function () { if (P) P.setTheme(b.getAttribute('data-theme-pref')); paintTheme(); });
  });

  /* ── LANGUAGE toggle ── */
  function paintLang() {
    var cur = P ? P.getLang() : 'en';
    document.querySelectorAll('[data-lang-toggle]').forEach(function (b) {
      // show the language you will switch TO
      b.textContent = cur === 'tr' ? 'EN' : 'TR';
      b.setAttribute('aria-label', cur === 'tr' ? 'Switch to English' : 'Türkçeye geç');
      b.setAttribute('title', b.getAttribute('aria-label'));
    });
  }
  document.querySelectorAll('[data-lang-toggle]').forEach(function (b) {
    b.addEventListener('click', function () { if (P) P.toggleLang(); });
  });

  /* ── LANGUAGE change → re-apply static + notify pages to re-render ── */
  function onLangChange() {
    if (window.applyI18n) window.applyI18n(document.body);
    paintLang();
    // let each page re-render its JS-built content
    window.dispatchEvent(new CustomEvent('cn:langchange', { detail: { lang: P ? P.getLang() : 'en' } }));
  }
  if (P && typeof P.onChange === 'function') {
    P.onChange(function (what) { if (what === 'lang') onLangChange(); else if (what === 'theme') paintTheme(); });
  }

  /* ── "Me" menu (dropdown) ── */
  document.querySelectorAll('[data-menu]').forEach(function (wrap) {
    var btn = wrap.querySelector('[data-menu-btn]');
    var pop = wrap.querySelector('[data-menu-pop]');
    if (!btn || !pop) return;
    btn.addEventListener('click', function (e) {
      e.preventDefault(); e.stopPropagation();
      var open = wrap.classList.toggle('open');
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  });
  document.addEventListener('click', function (e) {
    document.querySelectorAll('[data-menu].open').forEach(function (wrap) {
      if (!wrap.contains(e.target)) { wrap.classList.remove('open');
        var b = wrap.querySelector('[data-menu-btn]'); if (b) b.setAttribute('aria-expanded', 'false'); }
    });
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') document.querySelectorAll('[data-menu].open').forEach(function (w) { w.classList.remove('open'); });
  });

  /* ── SIGN OUT ── */
  document.addEventListener('click', async function (e) {
    var so = e.target.closest('[data-signout]');
    if (!so) return;
    e.preventDefault();
    try {
      var sb = window.__cvSb || (window.supabase && window.__CV_SUPABASE_URL && window.__CV_ANON_KEY
        ? window.supabase.createClient(window.__CV_SUPABASE_URL, window.__CV_ANON_KEY, { auth: { persistSession: true } })
        : null);
      if (sb) { window.__cvSb = sb; await sb.auth.signOut(); }
    } catch (err) {}
    location.href = '/login.html';
  });

  /* Public hook: pages can register a re-render fn for language changes. */
  window.CNApp = {
    onLang: function (cb) { if (typeof cb === 'function') window.addEventListener('cn:langchange', function (e) { cb(e.detail.lang); }); },
    lang: function () { return P ? P.getLang() : 'en'; },
    T: T
  };

  /* initial paint */
  paintTheme(); paintLang();
  if (window.applyI18n) window.applyI18n(document.body);
})();
