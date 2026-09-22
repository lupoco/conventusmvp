/* =====================================================================
   Convexus Selection Engine  v1.3
   Etkinlik bazlı firma eleme motoru — Conventus <-> Convexus köprüsü.

   Üç aşama:
     1) GATE      — binary eleme. Geçemeyen puanlamaya girmez.
     2) SCORE     — 0-100 liyakat puanı (bağımsız değerlendirme).
     3) PORTFOLIO — challenge area kapsama dengesi (bağımlı değerlendirme).

   Bağımlılık yok. Tarayıcıda <script src> ile, node'da require ile çalışır.
   ===================================================================== */
(function (root) {
  'use strict';

  /* ---------- sabit ağırlıklar (v1.0 — CA'26 üzerinde kalibre edildi) ---------- */
  var W = {
    need_per_match: 10,      // eşleşen her challenge area
    need_cap: 30,

    artifact: {              // "alaka TRL'i yener" ekseni
      ugv_platform: 30,
      mountable_subsystem: 20,
      embedded_software: 14,
      adjacent_platform: 12,
      ops_enabler: 8,
      unknown: 0,
      out_of_domain: 0
    },

    validation: {            // kanıt hiyerarşisi
      combat_fielded: 25,    // sahada, seri, muharebede
      combat_tested: 20,     // muharebede test edildi
      allied_exercise: 15,   // NATO/müttefik tatbikatı
      national_trial: 8,     // ulusal MoD denemesi/demo
      none: 0
    },

    trl: { 9: 10, 8: 8, 7: 6, 6: 4, 5: 1 },

    /* FAALİYET VE DEĞERLENDİRME EKSENİ (max 20)
       İlke: KATILIM TEK BAŞINA YETERLİ DEĞİL. Asıl puanı, o faaliyette
       alınan değerlendirme belirler. CWIX'e gidip vasat kalan bir firma
       ile öne çıkan firma aynı puanı alamaz.                          */
    engagement: {
      demonstrated: 8,   // sahada fiilen gösterim yaptı
      integrated:   6,   // başka bir sistemle entegre edilip test edildi
      participated: 3,   // katıldı, gösterim yok
      selected_only: 1,  // seçildi ama katılmadı / henüz katılmadı
      applied:      0
    },
    organiser_tier: {    // düzenleyenin ağırlığı
      nato_hq:       1.5,  // NATO HQ, ACT/SACT, SHAPE
      nato_command:  1.4,  // LANDCOM, JFC — EFDI/TFX pilotları
      nato_agency:   1.2,  // DIANA, NIF, NSPA, NCIA
      multinational: 1.1,  // EDA, Frontex, çok uluslu program
      national:      1.0,  // ulusal MoD tatbikatı/denemesi
      other:         0.8
    },
    assessment: {        // ASIL BELİRLEYİCİ
      excelled:      6,  // üstün değerlendirme, öne çıkarıldı
      met:           3,  // beklentiyi karşıladı
      partial:       0,
      did_not_meet: -5,  // CEZA — gitmemekten daha kötü
      not_assessed:  0,
      unknown:       0
    },
    activity_cap: 10,
    activity_decay: [1, 0.6, 0.3],  // en iyi kayıt tam, ikincisi %60, üçüncüsü %30

    fit: {               // faaliyet geçmişi ARTIK BURADA DEĞİL (çift sayım olurdu)
      host_nation: 2,    // ev sahibi ülke — lojistik avantaj
      c2_integration: 1  // C2/TAK entegrasyon kanıtı
    },
    fit_cap: 3
  };

  var BANDS = { must: 65, maybe: 38 };   // faaliyet ekseni BONUS'tur — eşik yükseltilmez

  var VAL_RANK = { none: 0, national_trial: 1, allied_exercise: 2, combat_tested: 3, combat_fielded: 4 };

  var HARD_BLOCKERS = [
    'incomplete_application',
    'export_restricted',
    'requires_backend',
    'infrastructure_dependent',
    'research_stage'
  ];

  /* Fallback metinler İNGİLİZCE ve nötr tutulur. Görüntüleme dili
     arayüzün işidir — motor dil bilmez. Kayıtlar append-only olduğu
     için, koda değil metne yazmak denetim izini tek dile hapseder.  */
  var BLOCKER_TEXT = {
    incomplete_application: 'Incomplete application — no assessable information',
    export_restricted: 'Export / classification restriction — cannot be demonstrated',
    requires_backend: 'Requires online backend — conflicts with DDIL/EW requirement',
    infrastructure_dependent: 'Depends on infrastructure not present at the exercise',
    research_stage: 'Research / consultancy stage — no deployable product'
  };

  /* ---------------------------- 1) GATE ---------------------------- */
  function gate(app, ev) {
    var fails = [];

    // G1 — hard blocker
    for (var i = 0; i < (app.blockers || []).length; i++) {
      var b = app.blockers[i];
      if (HARD_BLOCKERS.indexOf(b) >= 0) {
        fails.push({ code: 'G1_' + b.toUpperCase(), params: { blocker: b }, why: BLOCKER_TEXT[b] || b });
      }
    }

    // G2 — alan dışı: gösterimin öznesi olamaz
    if (app.artifact_class === 'out_of_domain' || app.artifact_class === 'unknown') {
      fails.push({ code: 'G2_DOMAIN', params: {}, why: 'No direct link to the exercise domain' });
    }

    // G3 — mutlak TRL tabanı
    var floor = ev.absolute_trl_floor != null ? ev.absolute_trl_floor : 5;
    if ((app.trl_demo || 0) < floor) {
      fails.push({
        code: 'G3_TRL_FLOOR', params: { trl: app.trl_demo, floor: floor },
        why: 'TRL ' + app.trl_demo + ' — below the absolute floor of ' + floor
      });
    }

    // G4 — etkinlik TRL eşiği; muafiyet: harici doğrulama VE doğrudan alan uyumu
    if ((app.trl_demo || 0) < ev.min_trl && (app.trl_demo || 0) >= floor) {
      var waived = VAL_RANK[effectiveValidation(app).tier] >= VAL_RANK.national_trial &&
                   app.domain_axis === ev.domain_axis;
      if (!waived) {
        fails.push({
          code: 'G4_TRL_MIN', params: { trl: app.trl_demo, min: ev.min_trl },
          why: 'TRL ' + app.trl_demo + ' < ' + ev.min_trl + ' with no waiver (external validation + domain match)'
        });
      }
    }

    return fails;
  }

  /* ------------------- BEYAN ↔ TEYİT ------------------- */
  /* Teyit edilmemiş beyan BİR KADEME AŞAĞI sayılır. Yalan söylemek
     serbest ama karşılığı yok; teyit ettirmek kazandırır. Tanıma
     belgesi ancak teyitli veriye dayanırsa savunulabilir.            */
  var VAL_CHAIN = ['none', 'national_trial', 'allied_exercise', 'combat_tested', 'combat_fielded'];
  function downgrade(tier) {
    var i = VAL_CHAIN.indexOf(tier);
    return i > 0 ? VAL_CHAIN[i - 1] : 'none';
  }
  function effectiveValidation(app) {
    if (app.validation_tier_verified) {
      return { tier: app.validation_tier_verified, verified: true,
               corrected: app.validation_tier_verified !== app.validation_tier };
    }
    return { tier: downgrade(app.validation_tier || 'none'), verified: false,
             claimed: app.validation_tier || 'none' };
  }

  /* ---------------- FAALİYET / DEĞERLENDİRME PUANI ---------------- */
  /* Bir kayıt = bir faaliyette bir katılım + orada alınan değerlendirme.
     Kayıt puanı = (katılım seviyesi × düzenleyen ağırlığı) + değerlendirme.
     Olumsuz değerlendirme TAM olarak düşülür (azalan ağırlığa tabi değil):
     bir tatbikatta başarısız olmak, hiç gitmemekten daha kötüdür.
     TEYİTSİZ kayıtta değerlendirme primi UYGULANMAZ — "CWIX'te öne çıktık"
     tam olarak teyit gerektiren türden bir iddiadır. Katılım seviyesi sayılır. */
  function activityRecordScore(rec) {
    var base = W.engagement[rec.engagement_level] || 0;
    var tier = W.organiser_tier[rec.organiser_tier] || 1.0;
    var asmt = rec.verified ? (W.assessment[rec.assessment_outcome] || 0)
                            : Math.min(W.assessment[rec.assessment_outcome] || 0, 0);
    return Math.round(base * tier) + asmt;
  }

  function activityScore(records) {
    var recs = (records || []).map(function (r) {
      return { rec: r, s: activityRecordScore(r) };
    });
    var pos = recs.filter(function (x) { return x.s > 0; }).sort(function (a, b) { return b.s - a.s; });
    var neg = recs.filter(function (x) { return x.s < 0; });

    var raw = 0, details = [];
    for (var i = 0; i < pos.length; i++) {
      var w = i < W.activity_decay.length ? W.activity_decay[i] : 0;
      var applied = pos[i].s * w;
      raw += applied;
      details.push({ rec: pos[i].rec, base: pos[i].s, weight: w, applied: Math.round(applied * 10) / 10 });
    }
    neg.forEach(function (x) {
      raw += x.s;
      details.push({ rec: x.rec, base: x.s, weight: 1, applied: x.s, penalty: true });
    });

    var total = Math.round(raw);
    var capped = total > W.activity_cap;
    if (capped) total = W.activity_cap;
    if (total < -10) total = -10;

    return { total: total, raw: Math.round(raw), capped: capped, details: details,
             best: pos[0] ? pos[0].rec : null, penalties: neg.map(function (x) { return x.rec; }) };
  }

  /* ---------------------------- 2) SCORE ---------------------------- */
  function score(app, ev) {
    var evNeeds = ev.needs.map(function (n) { return n.code; });
    var matched = (app.needs || []).filter(function (n) { return evNeeds.indexOf(n) >= 0; });

    var sNeed = Math.min(matched.length * W.need_per_match, W.need_cap);
    var sArt  = W.artifact[app.artifact_class] || 0;
    var eff   = effectiveValidation(app);
    var sVal  = W.validation[eff.tier] || 0;
    var sTrl  = W.trl[app.trl_demo] || 0;

    var act   = activityScore(app.activity_records);

    var sFit = 0;
    (app.fit || []).forEach(function (f) { sFit += (W.fit[f] || 0); });
    sFit = Math.min(sFit, W.fit_cap);

    var total = sNeed + sArt + sVal + sTrl + sFit + act.total;

    return {
      total: total,
      breakdown: { need: sNeed, artifact: sArt, validation: sVal, trl: sTrl, fit: sFit, activity: act.total },
      matched_needs: matched,
      activity: act,
      validation: eff
    };
  }

  function band(total) {
    if (total >= BANDS.must) return 'MUST';
    if (total >= BANDS.maybe) return 'MAYBE';
    return 'NO';
  }

  /* ------------------------- 3) PORTFOLIO --------------------------- */
  /* Bağımsız sıralama tek başına yanlış portföy üretir: en yüksek puanlılar
     hep platformlardır, uzmanlık alanları (ör. EW) boş kalır. Bu geçiş, her
     challenge area için asgari sayıda *uzman* (primary_need == area) garanti
     eder ve eksik alanları en yüksek puanlı MAYBE ile doldurur.            */
  /* Terfi sıralaması ham puanla YAPILMAZ. İki düzeltme gerekir:

     1) GÖSTERİLEBİLİRLİK: bir alanı ancak o alanı SAHADA TEK BAŞINA
        gösterebilen firma gerçekten kapatır. Sensör, üzerine oturacağı
        platform olmadan EW dayanıklılığını gösteremez.

     2) DERİNLİK > GENİŞLİK: uzman kontenjanı doldurulurken kanıt ağırlığı
        iki katına çıkar. Ham puan genişliği ödüllendirir (çok alan = çok
        puan); oysa uzman kontenjanı, o alanda KANITLANMIŞ yeteneği arar.
        Muharebede test edilmiş tek-alan uzmanı, iki alana yayılmış ama
        sadece ulusal denemesi olan adaydan önce gelir.                  */
  var DEMO_BONUS = 8;
  function standalone(app) {
    return app.artifact_class === 'ugv_platform' || app.artifact_class === 'adjacent_platform';
  }
  function portfolioRank(r) {
    var evidence = W.validation[(r.score.validation && r.score.validation.tier) || r.app.validation_tier] || 0;
    return r.score.total + (standalone(r.app) ? DEMO_BONUS : 0) + evidence;
  }

  function portfolio(rows, ev) {
    var minSpec = ev.min_specialists_per_need || 0;
    if (!minSpec) return [];

    var promotions = [];

    ev.needs.forEach(function (need) {
      var have = rows.filter(function (r) {
        return r.decision === 'MUST' && r.app.primary_need === need.code;
      }).length;

      var gap = minSpec - have;
      if (gap <= 0) return;

      var pool = rows
        .filter(function (r) {
          return r.decision === 'MAYBE' && r.app.primary_need === need.code && !r.gate_fails.length;
        })
        .sort(function (a, b) { return portfolioRank(b) - portfolioRank(a); });

      for (var i = 0; i < gap && i < pool.length; i++) {
        var r = pool[i];
        r.decision = 'MUST';
        r.promoted = true;
        r.promotion_params = { need: need.code, have: have, min: minSpec };
        r.promotion_reason = 'Specialist gap in ' + need.code + ' (' + have + '/' + minSpec +
                             ') — highest-scoring specialist promoted';
        promotions.push({
          id: r.app.id, name: r.app.name, need: need.code,
          score: r.score.total, rank: portfolioRank(r), standalone: standalone(r.app),
          runner_up: pool[i + 1] ? { name: pool[i + 1].app.name, score: pool[i + 1].score.total, rank: portfolioRank(pool[i + 1]) } : null
        });
        have++;
      }
    });

    return promotions;
  }

  /* --------------------------- REASON BADGES ------------------------ */
  /* Rozetler KOD + PARAMETRE olarak üretilir; metin sadece yedektir.
     Arayüz kodu seçili dile çevirir. Böylece append-only denetim izi
     dil-bağımsız kalır ve sonradan başka dilde okunabilir.           */
  function badges(r, ev) {
    var b = [], a = r.app;
    if (r.gate_fails.length) {
      return r.gate_fails.map(function (g) {
        return { kind: 'gate', code: g.code, params: g.params || {}, text: g.why };
      });
    }

    function add(kind, code, params, text) { b.push({ kind: kind, code: code, params: params || {}, text: text }); }

    if (a.artifact_class === 'ugv_platform')
      add('plus', 'PLATFORM_SUBJECT', {}, 'Platform — the subject of the demonstration');
    if (r.score.matched_needs.length === ev.needs.length)
      add('plus', 'COVERS_ALL', { n: ev.needs.length }, 'Covers all ' + ev.needs.length + ' challenge areas');
    var vv = r.score.validation || { tier: a.validation_tier, verified: false };
    if (!vv.verified && (a.validation_tier || 'none') !== 'none')
      add('minus', 'VAL_UNVERIFIED', { claimed: a.validation_tier },
          'Claim of "' + a.validation_tier + '" not verified — counted one tier lower');
    if (vv.corrected)
      add('minus', 'VAL_CORRECTED', { claimed: a.validation_tier, verified: vv.tier },
          'Verified as "' + vv.tier + '" (claimed "' + a.validation_tier + '")');
    if (a.validation_tier === 'combat_fielded')
      add('plus', 'VAL_FIELDED', {}, 'Fielded at scale in combat');
    if (a.validation_tier === 'combat_tested')
      add('plus', 'VAL_TESTED', {}, 'Tested in combat conditions');
    if (a.validation_tier === 'allied_exercise')
      add('plus', 'VAL_EXERCISE', {}, 'NATO / allied exercise history');
    if (a.validation_tier === 'none')
      add('minus', 'VAL_NONE', {}, 'No external validation');
    if (a.trl_demo >= 8)
      add('plus', 'TRL_MATURE', { trl: a.trl_demo }, 'TRL ' + a.trl_demo + ' — mature');
    if (a.trl_demo <= 6)
      add('minus', 'TRL_THRESHOLD', { trl: a.trl_demo }, 'TRL ' + a.trl_demo + ' — at the threshold');
    if ((a.fit || []).indexOf('host_nation') >= 0)
      add('plus', 'FIT_HOST', {}, 'Host nation company — logistics advantage');

    /* Faaliyet geçmişi rozetleri — puanın NEREDEN geldiğini görünür kılar */
    var act = r.score.activity || { total: 0, best: null, penalties: [] };
    if (act.best) {
      var bst = act.best, nm = bst.activity_name || bst.activity_code || '';
      if (bst.assessment_outcome === 'excelled')
        add('plus', 'ACT_EXCELLED', { activity: nm }, 'Excelled at ' + nm);
      else if (bst.assessment_outcome === 'met')
        add('plus', 'ACT_MET', { activity: nm }, 'Met expectations at ' + nm);
      else if (bst.engagement_level === 'demonstrated')
        add('plus', 'ACT_DEMONSTRATED', { activity: nm }, 'Demonstrated at ' + nm + ' — outcome not recorded');
      else
        add('plus', 'ACT_PARTICIPATED', { activity: nm }, 'Took part in ' + nm + ' — no demonstration recorded');
    } else if (!(a.activity_records || []).length) {
      add('minus', 'ACT_NONE', {}, 'No NATO / allied activity record');
    }
    (act.penalties || []).forEach(function (p) {
      add('minus', 'ACT_BELOW', { activity: p.activity_name || p.activity_code || '' },
          'Did not meet expectations at ' + (p.activity_name || p.activity_code || ''));
    });

    if (!a.integration_path)
      add('minus', 'NO_INTEGRATION', {}, 'No declared platform / C2 integration path');
    if (r.promoted)
      add('portfolio', 'PORTFOLIO_PROMOTION', r.promotion_params || {}, r.promotion_reason);
    return b;
  }

  /* ------------------------------ RUN ------------------------------- */
  function run(ev, applicants) {
    var rows = applicants.map(function (app) {
      var g = gate(app, ev);
      var s = g.length ? { total: 0, breakdown: {}, matched_needs: [] } : score(app, ev);
      return {
        app: app,
        gate_fails: g,
        score: s,
        decision: g.length ? 'NO' : band(s.total),
        promoted: false,
        promotion_reason: null
      };
    });

    var promos = portfolio(rows, ev);
    rows.forEach(function (r) { r.badges = badges(r, ev); });
    rows.sort(function (a, b) { return b.score.total - a.score.total; });

    return {
      rows: rows,
      promotions: promos,
      summary: {
        must: rows.filter(function (r) { return r.decision === 'MUST'; }).length,
        maybe: rows.filter(function (r) { return r.decision === 'MAYBE'; }).length,
        no: rows.filter(function (r) { return r.decision === 'NO'; }).length,
        gated: rows.filter(function (r) { return r.gate_fails.length; }).length
      }
    };
  }

  var API = { run: run, gate: gate, score: score, band: band, WEIGHTS: W, BANDS: BANDS, VERSION: '1.3' };

  if (typeof module !== 'undefined' && module.exports) module.exports = API;
  else root.CVSelection = API;
})(typeof window !== 'undefined' ? window : this);
