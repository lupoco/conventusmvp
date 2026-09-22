/* ============================================================
   CONVENTITY — ROUTE REGISTRY  (single source of truth)

   This is the ONE place that knows every page, its title,
   which platform it belongs to, and its parent. nav.js reads
   this to build the header, breadcrumb, sub-nav and the
   "back to parent" link on every page — so links can never
   point at a page that isn't registered here.

   HOW TO EDIT
   -----------
   • Wrong file path?  Fix it here once → fixed everywhere.
   • New page?         Add an entry under `pages`.
   • Not built yet?    Set `comingSoon: true` → it renders as a
                       muted "soon" badge instead of a dead link.
   • Login-only page?  Set `authOnly: true` → hidden until the
                       user is signed in.

   A page identifies itself to nav.js with:
     <header id="cv-nav" data-platform="conventus" data-page="overview"></header>
   The lookup key is  `${data-platform}/${data-page}`.
   ============================================================ */

window.CV_ROUTES = {

  /* ---- Auth entry points (shared across the ecosystem) --- */
  auth: {
    login:  '/login.html',
    signup: '/login.html?mode=signup',
    /* Where the user chip dropdown points once signed in.   */
    dashboard: '/dashboard/index.html',
    settings:  '/settings.html',
    /* signOut redirects here after clearing the session.    */
    afterSignOut: '/index.html',
  },

  /* ---- Platform metadata --------------------------------
     `home` is the platform landing page. `order` sets the
     left-to-right order in the top-bar platform switcher.
     Set `comingSoon: true` to grey a platform out.          */
  platforms: {
    conventity: { name: 'Conventity', home: '/index.html',                       order: 0, isRoot: true },
    convexus:   { name: 'Convexus',   home: '/platforms/convexus/index.html',    order: 1 },
    convergens: { name: 'Convergens', home: '/platforms/convergens/index.html',  order: 2 },
    conventus:  { name: 'Conventus',  home: '/platforms/conventus/index.html',   order: 3 },
    consultus:  { name: 'Consultus',  home: '/platforms/consultus/index.html',   order: 4 },
    conventlab: { name: 'ConventLab', home: '/platforms/conventlab/index.html',  order: 5 },
    connectus:  { name: 'Connectus',  home: '/platforms/connectus/index.html',   order: 6, comingSoon: true },
  },

  /* ---- Pages --------------------------------------------
     key: "<platform>/<page>"
       path        absolute URL (root-relative, always leading /)
       title       label shown in breadcrumb / sub-nav
       platform    owning platform key
       parent      key of the parent page (null = platform root)
       nav         true → appears in the platform sub-nav bar
       authOnly    true → hidden until signed in
       comingSoon  true → rendered as a disabled "soon" badge
     ------------------------------------------------------- */
  pages: {

    /* ===== Conventity root ===== */
    'conventity/home': {
      path: '/index.html', title: 'Home', platform: 'conventity',
      parent: null, nav: false,
    },
    'conventity/settings': {
      path: '/settings.html', title: 'Settings', platform: 'conventity',
      parent: 'conventity/home', nav: false, authOnly: false,
    },
    'conventity/verified': {
      path: '/verified-directory.html', title: 'Verified capabilities', platform: 'conventity',
      parent: 'conventity/home', nav: false,
    },
    'conventity/verified-proof': {
      path: '/verified.html', title: 'Verified proof', platform: 'conventity',
      parent: 'conventity/verified', nav: false,
    },

    /* ===== Convexus ===== */
    'convexus/home': {
      path: '/platforms/convexus/index.html', title: 'Convexus', platform: 'convexus',
      parent: null, nav: false,
    },
    'convexus/pool': {
      path: '/platforms/convexus/index.html', title: 'Pool', platform: 'convexus',
      parent: 'convexus/home', nav: true,
    },
    'convexus/catalog': {
      path: '/platforms/convexus/catalog.html', title: 'Catalog', platform: 'convexus',
      parent: 'convexus/home', nav: true, comingSoon: true,
    },
    'convexus/new': {
      path: '/platforms/convexus/new.html', title: 'Add profile', platform: 'convexus',
      parent: 'convexus/home', nav: true, authOnly: true,
    },
    'convexus/engagement': {
      path: '/platforms/convexus/convexus-engagement.html', title: 'Engagement', platform: 'convexus',
      parent: 'convexus/home', nav: true,
    },
    'convexus/engagement-triage': {
      path: '/platforms/convexus/convexus-engagement-triage.html', title: 'Engagement · Triage', platform: 'convexus',
      parent: 'convexus/engagement', nav: false, authOnly: true,
    },
    'convexus/selection-setup': {
      path: '/convexus-selection-setup.html', title: 'Selection · Setup', platform: 'convexus',
      parent: 'convexus/home', nav: false, authOnly: true,
    },
    'convexus/selection-apply': {
      path: '/convexus-selection-apply.html', title: 'Selection · Apply', platform: 'convexus',
      parent: 'convexus/selection-setup', nav: false,
    },

    /* ===== Convergens ===== */
    'convergens/home': {
      path: '/platforms/convergens/index.html', title: 'Convergens', platform: 'convergens',
      parent: null, nav: false,
    },

    /* ===== Conventus  (most developed — full sub-nav) ===== */
    'conventus/home': {
      path: '/platforms/conventus/index.html', title: 'Conventus', platform: 'conventus',
      parent: null, nav: false,
    },
    'conventus/overview': {
      path: '/platforms/conventus/overview.html', title: 'Overview', platform: 'conventus',
      parent: 'conventus/home', nav: true, authOnly: true,
    },
    'conventus/create': {
      path: '/platforms/conventus/new-event.html', title: 'Create event', platform: 'conventus',
      parent: 'conventus/overview', nav: true, authOnly: true,
    },
    'conventus/applications': {
      path: '/platforms/conventus/applications.html', title: 'Applications', platform: 'conventus',
      parent: 'conventus/overview', nav: true, authOnly: true,
    },
    'conventus/registration': {
      path: '/platforms/conventus/registration-link.html', title: 'Registration link', platform: 'conventus',
      parent: 'conventus/overview', nav: true, authOnly: true, comingSoon: true,
    },
    'conventus/event-setup': {
      path: '/sel-event-setup.html', title: 'Selection · Event setup', platform: 'conventus',
      parent: 'conventus/overview', nav: false, authOnly: true,
    },

    /* ===== Consultus ===== */
    'consultus/home': {
      path: '/platforms/consultus/index.html', title: 'Consultus', platform: 'consultus',
      parent: null, nav: false,
    },

    /* ===== ConventLab ===== */
    'conventlab/home': {
      path: '/platforms/conventlab/index.html', title: 'ConventLab', platform: 'conventlab',
      parent: null, nav: false,
    },

    /* ===== Connectus (not built yet) ===== */
    'connectus/home': {
      path: '/platforms/connectus/index.html', title: 'Connectus', platform: 'connectus',
      parent: null, nav: false, comingSoon: true,
    },
  },
};
