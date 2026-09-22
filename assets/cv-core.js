/* cv-core.js — Conventity paylaşılan çekirdek.
   Tek Supabase client + üyelik/yetki yardımcıları + kanonik rol/scope sözlüğü.
   TEK KAYNAK; sayfalar kendi kopyasını tutmak yerine bunu include eder.

   YÜKLEME SIRASI: cv-config.js ve supabase-js CDN'inden SONRA, sayfa
   scriptinden ÖNCE.
     <script src="/assets/js/cv-config.js"></script>
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="/assets/cv-core.js"></script>

   window'a sağladıkları:
     cvClient()             -> paylaşılan Supabase client (window.__cvSb)
     cvIsMember(client?)    -> Promise<bool>  fail-closed üyelik kontrolü
     cvGuardMember(client?) -> Promise<bool>  üye değilse signOut + /login.html?denied=1
     CV.roles / CV.scopes / CV.partRoles -> conventity_roles CHECK'ini yansıtan kanonik listeler
     CV.homeFor(role)       -> rol -> workspace yolu
*/
(function (w) {
  'use strict';

  /* Supabase URL + publishable anon anahtar: /assets/js/cv-config.js.
     cv-core kendi kopyasını TUTMAZ — ortam oradan okunur. */

  /* Tek paylaşılan client (lazy). __cvSb varsa onu döndürür, yoksa kurar.
     supabase-js henüz yüklenmediyse null döner (çağıran kontrol etmeli). */
  function cvClient() {
    if (w.__cvSb) return w.__cvSb;
    if (!w.supabase) return null;
    if (!w.__CV_SUPABASE_URL || !w.__CV_ANON_KEY) {
      // Sessiz fallback yok: cv-config.js yüklenmediyse bunu görünür kıl.
      try { console.error('[cv-core] /assets/js/cv-config.js yuklenmedi — Supabase URL/anon key yok.'); } catch (_) {}
      return null;
    }
    w.__cvSb = w.supabase.createClient(w.__CV_SUPABASE_URL, w.__CV_ANON_KEY, { auth: { persistSession: true } });
    return w.__cvSb;
  }

  /* fail-closed üyelik kontrolü: yalnız RPC açıkça true dönerse üye.
     Hata / boş / exception -> false (erişim yok). */
  async function cvIsMember(client) {
    var sb = client || cvClient();
    if (!sb) return false;
    try {
      var m = await sb.rpc('conventity_is_member');
      return !(m.error || m.data !== true);
    } catch (_) {
      return false;
    }
  }

  /* Üye değilse oturumu kapat ve login'e denied=1 ile geri yolla.
     Dönüş: true = üye/devam et, false = engellendi (çağıran return etmeli). */
  async function cvGuardMember(client) {
    var sb = client || cvClient();
    var ok = await cvIsMember(sb);
    if (!ok) {
      if (sb) { try { await sb.auth.signOut(); } catch (_) {} }
      w.location.replace('/login.html?denied=1');
      return false;
    }
    return true;
  }

  /* ---- Kanonik yetki sözlüğü — conventity_roles CHECK'ini yansıtır ----
     Değerler tek yerde burada; istemci sayfaları kendi alt/üst kümesini tutmaz. */
  var CV = {
    roles:     ['admin', 'organizer', 'vendor', 'member', 'owner', 'event_manager'],
    scopes:    ['ecosystem', 'convexus', 'conventus', 'conventlab', 'connectus', 'consultus', 'convergens', 'community', 'activity'],
    partRoles: ['participant', 'organizer', 'evaluator', 'observer', 'vendor'],
    // Genel rol konsolunda verilebilen platform-seviyesi kapsamlar (bağlamsal
    // community/activity hariç — onlar belirli bir id gerektirir).
    platformScopes: ['ecosystem', 'convexus', 'conventus', 'conventlab', 'connectus', 'consultus', 'convergens'],
    // Topluluk bağlamında atanabilen roller (vendor yok — topluluk rolü değil).
    communityRoles: ['member', 'organizer', 'event_manager', 'admin', 'owner'],
    homeFor: function (role) {
      switch (role) {
        case 'admin':
        case 'owner':
        case 'event_manager':
        case 'organizer': return '/platforms/conventus/event-studio.html';
        // gm-provider launch nav'ından çıkarıldı (yarım sayfa) — vendor'u
        // platform girişine yolla; portal açılınca burası geri döner.
        case 'vendor':    return '/platforms/conventus/index.html';
        default:          return '/index.html';
      }
    }
  };

  w.cvClient = cvClient;
  w.cvIsMember = cvIsMember;
  w.cvGuardMember = cvGuardMember;
  w.CV = w.CV || CV;
})(window);
