/* ============================================================
   CONVENTITY — Giriş kaydı istemci logger'ı (signin-log.js)

   Başarılı her girişi public.conventity_signin_log tablosuna yazar
   (Core → "Girişler" sekmesi buradan okur). İki yol:

   1) Parola girişi: login.html başarıdan sonra window.cvSigninLog('password')
      çağırır ve await eder (yönlendirmeden önce satır garanti yazılır).

   2) OAuth (Google/LinkedIn): yönlendirmeden ÖNCE
      localStorage['cv-signin-pending'] = 'google' | 'linkedin_oidc'
      set edilir. Sağlayıcı dönüşünde (SIGNED_IN) bu marker tüketilir,
      satır yazılır ve marker temizlenir. Marker yoksa — sıradan sayfa
      yenileme/oturum geri yükleme — HİÇBİR şey yazılmaz.

   Tablo yoksa / RLS reddederse sessizce yutulur (giriş akışını bozmaz).
   Bağımlılık: window.__cvSb (paylaşılan Supabase client) sayfada kurulu olmalı.
   ============================================================ */
(function () {
  'use strict';
  var sb = window.__cvSb;
  if (!sb || !sb.auth) return;

  var PENDING = 'cv-signin-pending';

  function insertRow(method) {
    return sb.auth.getUser().then(function (r) {
      var u = r && r.data && r.data.user;
      if (!u) return;
      var ok = ['password', 'google', 'linkedin_oidc', 'other'];
      var m = ok.indexOf(method) >= 0 ? method : 'other';
      return sb.from('conventity_signin_log').insert({
        auth_user_id: u.id,
        email: u.email || null,
        method: m,
        user_agent: (navigator.userAgent || '').slice(0, 300)
      }).then(function () {}, function () {}); /* hata = sessiz */
    }, function () {});
  }

  /* Parola girişi için açık çağrı (login.html await eder). */
  window.cvSigninLog = function (method) {
    try { return insertRow(method); } catch (e) { return Promise.resolve(); }
  };

  /* OAuth dönüşü: yalnız bekleyen bir marker varsa yaz. */
  try {
    sb.auth.onAuthStateChange(function (event, session) {
      if (event !== 'SIGNED_IN' || !session) return;
      var pend = null;
      try { pend = localStorage.getItem(PENDING); } catch (e) {}
      if (!pend) return;
      try { localStorage.removeItem(PENDING); } catch (e) {}
      insertRow(pend);
    });
  } catch (e) {}
})();
