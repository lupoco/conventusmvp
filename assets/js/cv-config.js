/* ============================================================
   CONVENTITY (.com) — ORTAM YAPILANDIRMASI  ·  TEK KAYNAK

   Supabase URL + publishable anon anahtarı SADECE burada durur.
   Hiçbir sayfa, hiçbir asset bu iki değeri kendi içine gömmez.
   Ortam değiştirmek = bu dosyayı değiştirmek (17+ dosya değil).

   Local'de de aynı dosya kullanılır: local ↔ prod tek DB'ye
   bağlanıyoruz, dolayısıyla URL/key local'de de değişmez.

   anon key publishable'dır → istemcide durması normaldir,
   sızıntı değildir. Gerçek sınır RLS'tir.

   YÜKLEME SIRASI: her sayfanın <head>'inde, diğer TÜM JS'ten ÖNCE.
     <script src="/assets/js/cv-config.js"></script>
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="/assets/cv-core.js"></script>
   ============================================================ */

/* conventity.com — PROD (Supabase projesi: conventity-prod). */
window.__CV_SUPABASE_URL = 'https://tstlireeidnpchadgjly.supabase.co';
window.__CV_ANON_KEY     = 'sb_publishable_RAr2pN-_WDwBwg_6w1sn-g_lgvCw67p';

/* ---- Görünür uyarı --------------------------------------------------
   Yapılandırma doldurulmadıysa SESSİZCE düşme: her Supabase çağrısı
   anlamsız bir ağ hatasına dönüşür ve teşhis saatler alır. Bunun yerine
   sayfanın üstüne bir şerit bas ve konsola yaz.                        */
(function (w, d) {
  'use strict';

  var PLACEHOLDER = /<PROD-(REF|PUBLISHABLE-KEY)>/;
  w.__CV_CONFIG_READY = !(PLACEHOLDER.test(w.__CV_SUPABASE_URL || '') ||
                          PLACEHOLDER.test(w.__CV_ANON_KEY || ''));
  if (w.__CV_CONFIG_READY) return;

  var MSG = 'cv-config.js doldurulmadi — Supabase URL/anon key hala yer tutucu. ' +
            'Supabase projesini acip /assets/js/cv-config.js icindeki iki degeri yazin.';
  try { console.error('[cv-config] ' + MSG); } catch (_) {}

  function banner() {
    if (!d.body || d.getElementById('cv-config-warning')) return;
    var el = d.createElement('div');
    el.id = 'cv-config-warning';
    el.setAttribute('role', 'alert');
    el.textContent = MSG;
    el.style.cssText = 'position:fixed;left:0;right:0;top:0;z-index:2147483647;' +
      'background:#C0392B;color:#fff;font:600 12px/1.5 ui-monospace,monospace;' +
      'padding:8px 14px;text-align:center';
    d.body.appendChild(el);
  }
  if (d.readyState !== 'loading') banner();
  else d.addEventListener('DOMContentLoaded', banner);
})(window, document);
