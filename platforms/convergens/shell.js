/* ============================================================
   shell.js — Convergens canonical shell helpers (shared)
   One nav, one footer, one data loader. LOCKED: the C mark and
   wordmark must never be abbreviated to "CVG" or text-only.
   ============================================================ */
(function (global) {
  const NS = "http://www.w3.org/2000/svg";
  const el = (t, a = {}) => { const e = document.createElementNS(NS, t); for (const k in a) e.setAttribute(k, a[k]); return e; };
  const css = (v) => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
  const resolve = (c) => (c && String(c).startsWith("var") ? css(c.slice(4, -1)) : c);

  // ---- theme: light / dark / system (Conventity-aligned) ----
  const THEME_KEY = "cvg-theme";
  const mq = window.matchMedia("(prefers-color-scheme: light)");
  const getPref = () => { try { return localStorage.getItem(THEME_KEY) || "dark"; } catch (e) { return "dark"; } };
  const applyTheme = (p) => document.documentElement.setAttribute("data-theme", p === "system" ? (mq.matches ? "light" : "dark") : p);
  applyTheme(getPref());                                  // apply immediately (pre-mount) to limit flash
  if (mq.addEventListener) mq.addEventListener("change", () => { if (getPref() === "system") applyTheme("system"); });
  const TICON = {
    light:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    dark:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></svg>',
    system: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></svg>'
  };
  const THEME_SEG = `<div class="theme-seg" role="group" aria-label="Theme">
    <button data-theme-pref="light" title="Light theme" aria-label="Light theme">${TICON.light}</button>
    <button data-theme-pref="dark" title="Dark theme" aria-label="Dark theme">${TICON.dark}</button>
    <button data-theme-pref="system" title="System theme" aria-label="System theme">${TICON.system}</button>
  </div>`;
  function wireTheme() {
    const pref = getPref();
    const btns = document.querySelectorAll(".theme-seg [data-theme-pref]");
    btns.forEach(b => {
      b.classList.toggle("on", b.dataset.themePref === pref);
      b.addEventListener("click", () => {
        try { localStorage.setItem(THEME_KEY, b.dataset.themePref); } catch (e) {}
        applyTheme(b.dataset.themePref);
        btns.forEach(x => x.classList.toggle("on", x === b));
      });
    });
  }

  // Single source of truth for navigation (Indicators deferred per scope).
  const LINKS = [
    { key: "overview",     label: "Overview",              href: "convergens-01-overview.html" },
    { key: "osint",        label: "OSINT Map",             href: "convergens-02-osint-map.html" },
    { key: "layers",       label: "CIMIC Layers",          href: "convergens-04-cimic-layers.html" },
    { key: "community",    label: "CIMIC Community",       href: "convergens-08-cimic-community.html" },
    { key: "humanitarian", label: "Humanitarian Response", href: "convergens-09-humanitarian-snapshot.html" }
  ];

  // Deploy sürümü — her deploy'da artır (önbellek teşhisi, CLAUDE.md konvansiyonu).
  const VERSION = "v1.0";

  // Canonical Conventity "C" mark — light arc + blue core (ecosystem identity).
  const LOGO = `
    <a class="logo" href="convergens-01-overview.html" aria-label="Convergens home">
      <svg viewBox="0 0 100 100" aria-hidden="true">
        <path d="M 76.2 68.4 A 32 32 0 1 1 76.2 31.6" fill="none" stroke="#E8ECF5" stroke-width="7" stroke-linecap="round"/>
        <circle cx="50" cy="50" r="12" fill="#2A6FDB"/>
      </svg>
      <span class="name">CON<b>VERGENS</b></span>
      <span class="ver">${VERSION}</span>
    </a>`;

  function navHTML(active) {
    const links = LINKS.map(l => `<a href="${l.href}" class="${l.key === active ? "active" : ""}">${l.label}</a>`).join("");
    return `<nav class="nav"><div class="nav-in">${LOGO}<div class="navlinks">${links}</div>${THEME_SEG}</div></nav>`;
  }

  function footerHTML(note) {
    return `<footer class="site"><div class="foot-in">
      <div><div class="b">CON<b>VERGENS</b> · Conventity</div>
      <div style="color:var(--mute);font-size:12px;margin-top:5px">Civil-only resilience awareness · Augment, not replace.</div></div>
      <div class="foot-meta"><span class="classif">UNCLASSIFIED · OPEN SOURCE</span><br>${note || "Cross-domain situational awareness."}</div>
    </div></footer>`;
  }

  // Inject header into #shell-nav and footer into #shell-footer if present.
  function mount(active, footerNote) {
    const n = document.getElementById("shell-nav");
    if (n) n.outerHTML = navHTML(active);
    const f = document.getElementById("shell-footer");
    if (f) f.outerHTML = footerHTML(footerNote);
    wireTheme();
  }

  // Fetch external JSON, fall back to embedded default. Returns {data, live}.
  async function loadData(file, fallback) {
    try {
      const r = await fetch(file, { cache: "no-store" });
      if (!r.ok) throw new Error("http " + r.status);
      return { data: await r.json(), live: true };
    } catch (e) {
      return { data: fallback, live: false };
    }
  }

  // small formatting helpers shared across pages
  const relAge = (h) => h < 1 ? "<1h" : h < 24 ? h + "h" : (Math.round(h / 24) + "d");

  global.CONV = { NS, VERSION, el, css, resolve, LINKS, navHTML, footerHTML, mount, loadData, relAge };
})(window);
