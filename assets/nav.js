/* ============================================================
   CONVENTITY — NAV BUILDER  (v3: simplified)

   Top bar = brand + ONE platform switcher (dropdown) + theme
   + language + auth. Context bar = breadcrumb + section links.
   No separate back button (the breadcrumb + sections cover it)
   and no hamburger (the switcher dropdown works on every screen).

   Depends on routes.js (required); prefs.js + i18n.js optional.
   Never holds a Supabase key — reads window.__cvSb if present.

   Per page:
     <head> … tokens.css, nav.css, <script src="/assets/prefs.js"></script>
     <body> <header id="cv-nav" data-platform="conventus" data-page="overview"></header>
     …  i18n.js, routes.js, <script src="/assets/nav.js" defer></script>
   ============================================================ */

(function () {
  'use strict';

  var R = window.CV_ROUTES;
  var mount = document.getElementById('cv-nav');
  if (!R || !mount) return;

  var platformKey = mount.getAttribute('data-platform') || 'conventity';
  var pageKey     = mount.getAttribute('data-page') || 'home';
  var currentKey  = platformKey + '/' + pageKey;
  var current     = R.pages[currentKey] || null;
  var onPlatform  = platformKey !== 'conventity';

  // Detail pages that aren't in the registry (e.g. /applications/123)
  // declare their place with data-parent (a registry key) and an
  // optional data-title. This builds a synthetic "current" so the
  // breadcrumb, back chip and active-branch all still resolve.
  var dataParent = mount.getAttribute('data-parent');
  var dataTitle  = mount.getAttribute('data-title');
  if (!current && onPlatform) {
    current = {
      path: (location && location.pathname) || '',
      title: dataTitle || document.title || 'Page',
      platform: platformKey,
      parent: dataParent || (platformKey + '/home'),
      nav: false, _synthetic: true,
    };
  } else if (current && dataParent) {
    current = { path: current.path, title: current.title, platform: current.platform,
                parent: dataParent, nav: current.nav, authOnly: current.authOnly };
  }
  var parentKey = current ? current.parent : null;

  function t(key, fb) { return window.CVI18N ? window.CVI18N.t(key, fb) : (fb != null ? fb : key); }
  var hasPrefs = !!window.CVPrefs;

  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function initials(name) {
    var s = String(name || '').trim(); if (!s) return '?';
    var p = s.split(/[\s@._-]+/).filter(Boolean);
    return ((p[0] ? p[0][0] : s[0]) + (p[1] ? p[1][0] : '')).toUpperCase();
  }
  function routeTitle(key, page) { return t('route.' + key, page.title); }
  function crumbChain(key) {
    var chain = [], k = key, g = 0;
    while (k && R.pages[k] && g++ < 20) { chain.unshift({ key: k, page: R.pages[k] }); k = R.pages[k].parent; }
    return chain;
  }

  var plats = Object.keys(R.platforms)
    .map(function (k) { return { key: k, meta: R.platforms[k] }; })
    .sort(function (a, b) { return (a.meta.order || 0) - (b.meta.order || 0); });
  var conventityHome = (R.platforms.conventity && R.platforms.conventity.home) || '/index.html';

  /* Eş-merkezli C logosu — inline (CSS değişkenleriyle temalanır). Tek kaynak. */
  var LOGO = '<svg class="cv-brand__logo" viewBox="0 0 100 100" aria-hidden="true">' +
    '<path d="M 76.2 68.4 A 32 32 0 1 1 76.2 31.6" fill="none" stroke="var(--logo-outer)" stroke-width="6.5" stroke-linecap="round"/>' +
    '<path d="M 64.7 60.3 A 18 18 0 1 1 64.7 39.7" fill="none" stroke="var(--logo-inner)" stroke-width="5.5" stroke-linecap="round"/>' +
    '<circle cx="50" cy="50" r="4" fill="var(--logo-inner)"/></svg>';

  var ICON_MOON = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
  var ICON_SUN  = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>';

  function accentVar(key) { return 'var(--acc-' + key + ')'; }

  function switcherHTML() {
    var label = onPlatform ? (R.platforms[platformKey] && R.platforms[platformKey].name) : t('nav.platforms', 'Platforms');
    var items = plats.filter(function (p) { return !p.meta.isRoot; }).map(function (p) {
      var cur = p.key === platformKey, soon = !!p.meta.comingSoon;
      var cls = 'cv-switch__item' + (cur ? ' is-current' : '') + (soon ? ' is-soon' : '');
      var right = soon ? '<span class="cv-soon">' + esc(t('nav.soon', 'soon')) + '</span>'
                       : (cur ? '<span class="cv-check">&#10003;</span>' : '');
      return '<a class="' + cls + '" href="' + (soon ? '#' : esc(p.meta.home)) + '"' +
             (soon ? ' aria-disabled="true" tabindex="-1"' : '') + '>' +
             '<span class="cv-pdot" style="background:' + accentVar(p.key) + '"></span>' +
             esc(p.meta.name) + right + '</a>';
    }).join('');

    return '<div class="cv-switch" id="cvSwitch">' +
      '<button class="cv-switch__btn" id="cvSwitchBtn" aria-haspopup="true" aria-expanded="false">' +
        '<span class="cv-dot"></span>' + esc(label) + '<span class="cv-switch__caret">&#9662;</span>' +
      '</button>' +
      '<div class="cv-switch__menu" role="menu">' +
        '<div class="cv-switch__head">' + esc(t('nav.platforms', 'Platforms')) + '</div>' + items +
      '</div></div>';
  }

  function toolsHTML() {
    if (!hasPrefs) return '';
    var dark = window.CVPrefs.getResolvedTheme() === 'dark';
    var next = window.CVPrefs.getLang() === 'tr' ? 'EN' : 'TR';
    return '<div class="cv-tools">' +
      '<button class="cv-tool" id="cvTheme" aria-label="' + esc(t('nav.theme', 'Theme')) + '">' + (dark ? ICON_SUN : ICON_MOON) + '</button>' +
      '<button class="cv-tool cv-tool--lang" id="cvLang" aria-label="' + esc(t('nav.lang', 'Language')) + '">' + next + '</button>' +
    '</div>';
  }

  function build() {
    var topHTML =
      '<div class="cv-top"><div class="cv-top__inner">' +
        '<a class="cv-brand" href="' + esc(conventityHome) + '">' +
          LOGO + '<span class="cv-brand__label">Conventity</span></a>' +
        '<span class="cv-sep"></span>' +
        switcherHTML() +
        '<div class="cv-right">' + toolsHTML() + '<div class="cv-auth" id="cvAuth"></div></div>' +
      '</div></div>';

    var contextHTML = '';
    var isRootHome = platformKey === 'conventity' && pageKey === 'home';
    if (!isRootHome && current) {
      var sep = '<span class="cv-crumb__sep">/</span>';
      var curTitle = current._synthetic ? current.title : routeTitle(currentKey, current);

      // Full breadcrumb: Conventity / <ancestors...> / <here>
      var ancestors = parentKey ? crumbChain(parentKey) : [];
      var crumbs = '<a href="' + esc(conventityHome) + '">Conventity</a>';
      ancestors.forEach(function (c) {
        crumbs += sep + '<a href="' + esc(c.page.path) + '">' + esc(routeTitle(c.key, c.page)) + '</a>';
      });
      crumbs += sep + '<span class="cv-crumb--here">' + esc(curTitle) + '</span>';

      // Collapsed mobile chip: "← <immediate parent>" (or Conventity at
      // the platform root). Deterministic — always a registered target,
      // never a blank page.
      var backHref, backLabel;
      if (parentKey && R.pages[parentKey]) {
        backHref = R.pages[parentKey].path; backLabel = routeTitle(parentKey, R.pages[parentKey]);
      } else {
        backHref = conventityHome; backLabel = 'Conventity';
      }
      var backChip = '<a class="cv-back" href="' + esc(backHref) + '">' +
        '<span class="cv-back__arrow">&larr;</span>' + esc(backLabel) + '</a>';

      // Active section = the NEAREST section (nav item) at or above the
      // current page — a single highlight, even for deep detail pages.
      var navKeys = {};
      Object.keys(R.pages).forEach(function (k) {
        if (R.pages[k].platform === platformKey && R.pages[k].nav) navKeys[k] = 1;
      });
      var chainUp = [];
      if (R.pages[currentKey]) chainUp.push(currentKey);
      var pk = parentKey;
      while (pk && R.pages[pk]) { chainUp.push(pk); pk = R.pages[pk].parent; }
      var activeSectionKey = null;
      for (var ci = 0; ci < chainUp.length; ci++) {
        if (navKeys[chainUp[ci]]) { activeSectionKey = chainUp[ci]; break; }
      }

      var subHTML = Object.keys(R.pages)
        .map(function (k) { return { key: k, page: R.pages[k] }; })
        .filter(function (x) { return x.page.platform === platformKey && x.page.nav; })
        .map(function (x) {
          var active = x.key === activeSectionKey ? 'is-active' : '';
          var authAttr = x.page.authOnly ? ' data-authonly="1" hidden' : '';
          return '<a class="' + active + '" href="' + esc(x.page.path) + '"' + authAttr + '>' +
                 esc(routeTitle(x.key, x.page)) + '</a>';
        }).join('');

      contextHTML =
        '<div class="cv-context"><div class="cv-context__inner">' +
          backChip +
          '<div class="cv-crumbs">' + crumbs + '</div>' +
          '<nav class="cv-subnav" aria-label="' + esc(t('nav.sections', 'Sections')) + '">' + subHTML + '</nav>' +
        '</div></div>';
    }

    mount.className = 'cv-nav';
    mount.setAttribute('data-platform', platformKey);
    mount.innerHTML = topHTML + contextHTML;

    document.body.classList.add('cv-has-nav');
    document.body.classList.toggle('cv-no-subnav', !contextHTML);

    wireSwitcher();
    wireToggles();
    applyAuth();
  }

  function wireSwitcher() {
    var sw = document.getElementById('cvSwitch');
    var btn = document.getElementById('cvSwitchBtn');
    if (!sw || !btn) return;
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var open = sw.classList.toggle('is-open');
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    document.addEventListener('click', function () { sw.classList.remove('is-open'); });
  }

  function wireToggles() {
    if (!hasPrefs) return;
    var th = document.getElementById('cvTheme');
    if (th) th.addEventListener('click', function () { window.CVPrefs.toggleTheme(); });
    var lg = document.getElementById('cvLang');
    if (lg) lg.addEventListener('click', function () { window.CVPrefs.toggleLang(); });
  }

  /* ---- auth ---- */
  var authState = { signedIn: false, label: '' };

  function renderAuth(box) {
    if (authState.signedIn) {
      box.innerHTML =
        '<div class="cv-user">' +
          '<button class="cv-user__btn" id="cvUserBtn" aria-haspopup="true" aria-expanded="false">' +
            '<span class="cv-user__avatar">' + esc(initials(authState.label)) + '</span>' +
            '<span class="cv-user__name">' + esc(authState.label) + '</span>' +
            '<span class="cv-user__caret">&#9662;</span>' +
          '</button>' +
          '<div class="cv-menu" id="cvUserMenu" role="menu">' +
            '<a href="' + esc(R.auth.dashboard) + '" role="menuitem">' + esc(t('nav.dashboard', 'Dashboard')) + '</a>' +
            '<a href="' + esc(R.auth.settings) + '" role="menuitem">' + esc(t('nav.settings', 'Settings')) + '</a>' +
            '<div class="cv-menu__sep"></div>' +
            '<button class="cv-menu__signout" id="cvSignOut" role="menuitem">' + esc(t('nav.signout', 'Sign out')) + '</button>' +
          '</div>' +
        '</div>';
      var b = document.getElementById('cvUserBtn'), m = document.getElementById('cvUserMenu');
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        var open = m.classList.toggle('is-open');
        b.setAttribute('aria-expanded', open ? 'true' : 'false');
      });
      document.addEventListener('click', function () { m.classList.remove('is-open'); });
      document.getElementById('cvSignOut').addEventListener('click', doSignOut);
    } else {
      box.innerHTML =
        '<a class="cv-btn cv-btn--ghost" href="' + esc(R.auth.login) + '">' + esc(t('nav.login', 'Log in')) + '</a>' +
        '<a class="cv-btn cv-btn--solid" href="' + esc(R.auth.signup) + '">' + esc(t('nav.signup', 'Create account')) + '</a>';
    }
  }

  function applyAuth() {
    var box = document.getElementById('cvAuth'); if (box) renderAuth(box);
    document.querySelectorAll('[data-authonly]').forEach(function (n) {
      if (authState.signedIn) n.removeAttribute('hidden'); else n.setAttribute('hidden', '');
    });
  }
  function doSignOut() {
    function go() { window.location.href = R.auth.afterSignOut; }
    try { (window.__cvSb && window.__cvSb.auth) ? window.__cvSb.auth.signOut().then(go).catch(go) : go(); }
    catch (e) { go(); }
  }
  function setAuth(s, l) { authState = { signedIn: s, label: l || '' }; applyAuth(); }

  /* ---- init ---- */
  build();

  (function checkSession() {
    var sb = window.__cvSb;
    if (!sb || !sb.auth || typeof sb.auth.getUser !== 'function') return;
    sb.auth.getUser().then(function (res) {
      var u = res && res.data && res.data.user; if (!u) return;
      var m = u.user_metadata || {};
      setAuth(true, m.username || m.full_name || m.name || u.email || t('nav.account', 'Account'));
    }).catch(function () {});
    if (typeof sb.auth.onAuthStateChange === 'function') {
      sb.auth.onAuthStateChange(function (_e, session) {
        if (session && session.user) {
          var m = session.user.user_metadata || {};
          setAuth(true, m.username || m.full_name || m.name || session.user.email || t('nav.account', 'Account'));
        } else { setAuth(false, ''); }
      });
    }
  })();

  if (hasPrefs) {
    window.CVPrefs.onChange(function (what) {
      if (what === 'lang') {
        build();
        if (window.CVI18N) window.CVI18N.apply(document.body);
      } else if (what === 'theme') {
        var th = document.getElementById('cvTheme');
        if (th) th.innerHTML = window.CVPrefs.getResolvedTheme() === 'dark' ? ICON_SUN : ICON_MOON;
      }
    });
  }

  /* ---- paylaşılan footer (tek kaynak) ---- */
  function buildFooter() {
    if (document.querySelector('.cv-footer')) return;
    var year = (document.documentElement.getAttribute('data-year')) || '2026';
    var f = document.createElement('footer');
    f.className = 'cv-footer';
    f.innerHTML =
      '<div class="cv-footer__inner">' +
        '<a class="cv-brand cv-footer__brand" href="' + esc(conventityHome) + '">' +
          LOGO + '<span class="cv-brand__label">Conventity</span></a>' +
        '<nav class="cv-footer__links" aria-label="Footer">' +
          '<a href="/verified-directory.html">' + esc(t('nav.verified', 'Verified')) + '</a>' +
          '<a href="/legal/data-protection.html">' + esc(t('nav.privacy', 'Privacy')) + '</a>' +
          '<a href="/legal/terms.html">' + esc(t('nav.terms', 'Terms')) + '</a>' +
          '<a href="/legal/security.html">' + esc(t('nav.security', 'Security')) + '</a>' +
        '</nav>' +
        '<div class="cv-footer__copy">© ' + esc(year) + ' Conventity · Lupoco A.Ş.</div>' +
      '</div>';
    document.body.appendChild(f);
  }
  buildFooter();

  window.CVNav = { rebuild: build };
})();
