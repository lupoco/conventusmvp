/* ============================================================
   EFDI Data Backbone Accelerator TTX — Wargame Data
   ------------------------------------------------------------
   Source: EFDI TTX Participant Guide + Analytic Wargaming
   Framework (Vilnius, 10 Jun 2026 · LANDCOM / USAREUR-AF).
   Pure data — consumed by ttx-engine.js. No DOM here.
   ============================================================ */
window.TTX = (function () {
  'use strict';

  /* ---- Exercise meta -------------------------------------- */
  const META = {
    title: 'EFDI Data Backbone Accelerator',
    kind: 'Analytic Wargame · Tabletop Exercise',
    location: 'Vilnius, Lithuania · Kapsų 44',
    date: '10 June 2026',
    sponsors: 'LANDCOM / USAREUR-AF',
    leads: 'Brig. Gen. Chris Gent · Col. Joseph Bilbo',
    informs: 'EFDI LIVEX · September 2026',
    method: 'The Craft of Wargaming (Appleget, Burks & Cameron) · NPS analytic method · F2T2EA',
    question:
      'Can national and NATO systems, authorities and operators share and act on ' +
      'sensor-derived data fast enough, and with enough trust, to enable defensive action ' +
      'across national boundaries before One-Way Attack Drones (OWADs) reach their targets?',
    audience: [
      'Civilian MoD Policy Reps',
      'Land Forces / Joint Ops Planners',
      'J6 / CIO Technical Experts',
      'Legal Advisors',
      'Civil Aviation (Oro navigacija · PAŻP)',
      'Border Guard / Interior (LT · PL · USAREUR-AF)'
    ]
  };

  /* ---- Three player lanes --------------------------------- */
  const LANES = [
    { id: 'policy', name: 'Policy', color: '#2A6FDB',
      desc: 'Decision-making, notification timelines, public comms, escalation control.' },
    { id: 'legal', name: 'Legal', color: '#C8A24B',
      desc: 'ROE, host-nation consent, use-of-force authorisations, data-sharing permissions.' },
    { id: 'technical', name: 'Technical', color: '#4A8A8A',
      desc: 'ASTERIX · BALTNET · DUNAJ · Link 16 · sensor-to-effector latency · trust protocols.' }
  ];

  /* ---- Friction taxonomy (DCMP) --------------------------- */
  const FRICTION_CATS = [
    { id: 'technical',   name: 'Technical',   color: '#4A8A8A' },
    { id: 'legal',       name: 'Legal',       color: '#C8A24B' },
    { id: 'policy',      name: 'Policy',      color: '#2A6FDB' },
    { id: 'operational', name: 'Operational', color: '#D97757' },
    { id: 'procedural',  name: 'Procedural',  color: '#8B3DD6' }
  ];
  const SEVERITIES = [
    { id: 'low',  name: 'Low',    rank: 1, color: '#16A34A' },
    { id: 'med',  name: 'Medium', rank: 2, color: '#EAB308' },
    { id: 'high', name: 'High',   rank: 3, color: '#DC2626' }
  ];

  /* ---- 11-stage targeting chain (F2T2EA) + DCMP ----------- */
  /* Each stage: number, name, F2T2EA phase, data flow, lane focus,
     Essential Questions (each with the targeted data metric it captures),
     and the anticipated friction category from the DCMP table.        */
  const STAGES = [
    { n: '01', name: 'Detect', phase: 'Find', flow: 'Sensor → C2 → CRC',
      lane: 'technical', frictionCat: 'technical',
      eqs: [
        { id: 'EQ1.1', q: 'Which sensor type registered the first return?', metric: 'Initial detection timestamp · sensor platform type' },
        { id: 'EQ1.2', q: 'Is the detection owned by the military or the civil interior?', metric: 'Track ownership · originating authority' }
      ],
      frictionNote: 'Low-altitude, low-RCS radar gaps; passive RF / acoustic not fused across all nodes.' },

    { n: '02', name: 'Classify', phase: 'Fix', flow: 'CRC ID correlation',
      lane: 'technical', frictionCat: 'operational',
      eqs: [
        { id: 'EQ2.1', q: 'What criteria elevate a track from SUSPECT to HOSTILE?', metric: 'Combat-ID timestamp · elevation criteria' },
        { id: 'EQ2.2', q: 'What is the latency of Mode 5 IFF interrogation?', metric: 'IFF transaction-log status · interrogation latency' }
      ],
      frictionNote: 'Non-cooperative / low-RCS UAS lack IFF — manual classification slows the chain.' },

    { n: '03', name: 'Share', phase: 'Fix', flow: 'Sensor nation → FMN → shooter nation',
      lane: 'technical', frictionCat: 'policy',
      eqs: [
        { id: 'EQ3.1', q: 'Does the track classification (e.g. REL TO) allow automated sharing?', metric: 'Data-sharing latency · releasability decision' },
        { id: 'EQ3.2', q: 'What is the technical path from sensor nation to shooter nation?', metric: 'Inter-system exchange format · network path' }
      ],
      frictionNote: 'Classification release blocks; no direct LT↔PL link — route via CAOC Uedem.' },

    { n: '04', name: 'Validate', phase: 'Track', flow: 'Cross-CRC correlation',
      lane: 'technical', frictionCat: 'procedural',
      eqs: [
        { id: 'EQ4.1', q: 'What confidence threshold does the shooter nation require?', metric: 'Validation duration · confidence threshold' },
        { id: 'EQ4.2', q: 'Are the two nations\u2019 validation criteria harmonised?', metric: 'Corroboration sensor counts' }
      ],
      frictionNote: 'Discrepant national validation standards — duplicate tracks appear.' },

    { n: '05', name: 'Trust', phase: 'Track', flow: 'Zero-trust gateway',
      lane: 'policy', frictionCat: 'policy',
      eqs: [
        { id: 'EQ5.1', q: 'Will the shooter nation fire based on data it did not generate?', metric: 'Binary Trust / No-Trust decision' },
        { id: 'EQ5.2', q: 'How is data integrity authenticated?', metric: 'Cyber-integrity check latency' }
      ],
      frictionNote: 'Reluctance to execute kinetic actions on unverified foreign data.' },

    { n: '06', name: 'Decide', phase: 'Target', flow: 'CAOC → SNR / national authority',
      lane: 'legal', frictionCat: 'legal',
      eqs: [
        { id: 'EQ6.1', q: 'Who holds sovereign engagement authority?', metric: 'Decision-making duration' },
        { id: 'EQ6.2', q: 'How long does vertical military-political authorisation take?', metric: 'Hops in the vertical approval chain' }
      ],
      frictionNote: 'Non-delegable sovereign shoot authority; ministerial-level bottlenecks.' },

    { n: '07', name: 'Clear Airspace', phase: 'Target', flow: 'ACA ↔ civil ANSP',
      lane: 'policy', frictionCat: 'procedural',
      eqs: [
        { id: 'EQ7.1', q: 'How rapidly can civil airspace be closed or restricted?', metric: 'Airspace clearance duration' },
        { id: 'EQ7.2', q: 'Are the civil ANSPs (Oro navigacija & PAŻP) synchronised?', metric: 'NOTAM propagation latency' }
      ],
      frictionNote: 'No unified cross-border civil-military deconfliction playbook — manual coordination.' },

    { n: '08', name: 'Cue', phase: 'Engage', flow: 'C2 → fire control',
      lane: 'technical', frictionCat: 'operational',
      eqs: [
        { id: 'EQ8.1', q: 'Which effector tier is selected?', metric: 'Weapon-target pairing choice' },
        { id: 'EQ8.2', q: 'Does the cross-border handoff degrade fire-control geometry?', metric: 'Fire-control lock-on latency' }
      ],
      frictionNote: 'Extreme cost asymmetry (~700:1 interceptor-to-drone); cross-nation cueing unproven.' },

    { n: '09', name: 'Engage', phase: 'Engage', flow: 'Fire control → effector',
      lane: 'legal', frictionCat: 'operational',
      eqs: [
        { id: 'EQ9.1', q: 'Is the weapons release lawful?', metric: 'Intercept location' },
        { id: 'EQ9.2', q: 'Are firing units and QRA aircraft deconflicted across the border?', metric: 'Deconfliction response time' }
      ],
      frictionNote: 'Debris-fall risk over own or allied populated areas; cross-border effect unresolved.' },

    { n: '10', name: 'Assess', phase: 'Assess', flow: 'Effector → CRC → CAOC',
      lane: 'technical', frictionCat: 'procedural',
      eqs: [
        { id: 'EQ10.1', q: 'What is the BDA source (radar, visual, ground)?', metric: 'BDA confirmation time' },
        { id: 'EQ10.2', q: 'Where does the debris fall?', metric: 'Debris recovery location' }
      ],
      frictionNote: 'Dual-nation forensic recovery and chain-of-custody seams.' },

    { n: '11', name: 'Notify', phase: 'Assess', flow: 'CAOC → executive → public',
      lane: 'policy', frictionCat: 'policy',
      eqs: [
        { id: 'EQ11.1', q: 'How fast does executive-level notification occur?', metric: 'Notification completion time' },
        { id: 'EQ11.2', q: 'Does this trigger Article 4 or Article 5 consultations?', metric: 'Article 4 / 5 invocation decision' }
      ],
      frictionNote: 'Coordinated diplomatic messaging vs disjointed national narratives.' }
  ];

  /* ---- Three scenario variants ---------------------------- */
  /* timeToTarget = simulated seconds from inject (T+00:00) until the
     OWAD reaches its intended target. If the chain has not reached an
     intercept by then, Red Cell scores a LEAKER.
     prompts = Appleget-style facilitator prompts keyed by stage index.
     board   = schematic geometry (440×360 viewBox).                    */
  const VARIANTS = {
    A: {
      id: 'A', name: 'National Incursion', tag: 'Baseline Case',
      subtitle: 'One nation detects and engages an OWAD entirely within its own airspace.',
      dcmp: 'Phase 1 · National Baseline Timelines',
      flow: ['Belarus Border', 'OWAD enters LT', 'LT NASAMS engages'],
      effector: 'LT NASAMS / RBS-70 NG', authority: 'LT Aviation Law · permissive zone',
      timeToTarget: 600, decisionStage: 5, interceptStage: 8,
      prompts: {
        5: 'Minister, you have 5 minutes before the drone enters the weapon-engagement zone of the Vilnius suburbs. Do you authorise weapons release — knowing that debris may fall on civilian homes?',
        8: 'Confirm the RBS-70 NG / NASAMS probability-of-kill. Record total elapsed time from Detect to Engage.'
      },
      board: {
        airspace: 'LITHUANIAN AIRSPACE',
        target: { x: 150, y: 96, label: 'Vilnius suburbs' },
        shooters: [{ x: 176, y: 150, label: 'NASAMS', side: 'blue' }],
        path: [[372, 150], [300, 132], [232, 116], [168, 102]],
        intercept: 0.72
      }
    },
    B: {
      id: 'B', name: 'Cross-Border Sensor-to-Shooter', tag: 'Interoperability Case',
      subtitle: 'One nation\u2019s sensor detects; another nation\u2019s shooter engages in its own airspace. (LT detects → PL engages.)',
      dcmp: 'Phase 2 · Data Releasability & Latency',
      flow: ['LT Sensor', 'BALTNET', 'CAOC Uedem', 'DUNAJ', 'PL Shooter'],
      effector: 'PL Narew CAMM-ER', authority: 'PL Art. 18b · vertical approval',
      timeToTarget: 540, decisionStage: 5, interceptStage: 8,
      prompts: {
        2: 'Poland, you are receiving track data from a foreign source (Lithuania) via a NATO server. Do your systems automatically ingest it into IBCS — and do your operators trust it enough to fire?',
        4: 'No direct LT↔PL TDL exists. The track must route up to CAOC Uedem and back down to DUNAJ C2. Measure the simulated transfer latency of this NATO-mediated path.',
        5: 'General Klisz, issue the engagement rozkaz under Art. 18b. Record the vertical coordination time between the IBCS EOC and the Operational Commander.',
        8: 'Poland fires a Narew CAMM-ER, intercepting just inside the Polish border. Log the cross-border coordination lag.'
      },
      board: {
        airspace: 'SUWAŁKI CORRIDOR',
        target: { x: 150, y: 300, label: 'NE Poland' },
        shooters: [{ x: 178, y: 256, label: 'CAMM-ER', side: 'blue' }],
        path: [[372, 132], [318, 168], [262, 210], [206, 258], [164, 296]],
        intercept: 0.78
      }
    },
    C: {
      id: 'C', name: 'Engage Back Into Initiating Nation', tag: 'Sovereignty Stress Case',
      subtitle: 'One nation detects; an allied shooter engages the OWAD over the initiating nation\u2019s own soil — requiring host-nation consent and dual authorisation.',
      dcmp: 'Phase 3 · Dual Authorisation & Consent',
      flow: ['LT Sensor', 'Allied Shooter (PL / BAP QRA)', 'Fire into LT airspace'],
      effector: 'PL Patriot / BAP QRA', authority: 'Dual Key · LT consent + PL authority',
      timeToTarget: 660, decisionStage: 5, interceptStage: 8,
      prompts: {
        4: 'Explain how the Polish fire-control system maintains track custody over Lithuanian airspace using forwarded radar data over Link 16.',
        5: 'Lithuania — if Poland fires into your airspace and debris destroys a house in Lazdijai, who assumes liability? Without a pre-negotiated bilateral agreement, does the shooter stand down?',
        8: 'Intercept successful over LT soil. Border Guard (LT) coordinates debris recovery and chain of custody; MFA reps coordinate a single unified diplomatic response.'
      },
      board: {
        airspace: 'LITHUANIAN AIRSPACE · LAZDIJAI',
        target: { x: 150, y: 120, label: 'Lazdijai' },
        shooters: [{ x: 196, y: 250, label: 'PL Patriot', side: 'amber' }, { x: 250, y: 88, label: 'BAP QRA', side: 'amber' }],
        path: [[372, 150], [312, 138], [248, 128], [180, 126]],
        intercept: 0.70
      }
    }
  };

  /* ---- Pre-seeded friction register (from the Framework) --- */
  const SEED_FRICTIONS = [
    { id: 'FR-01', stage: 2, lane: 'technical', cat: 'technical', sev: 'high', seed: true,
      desc: 'No direct data link between LT ASCC and PL DUNAJ; data must route through CAOC Uedem, adding ~2 minutes of latency.',
      mitigation: 'Test a temporary direct tactical data gateway between LT and PL during the September LIVEX.' },
    { id: 'FR-02', stage: 5, lane: 'legal', cat: 'legal', sev: 'high', seed: true,
      desc: 'Use-of-force authority under PL Art. 18b cannot be delegated to NATO, requiring a vertical national approval loop.',
      mitigation: 'Establish a pre-authorised \u201cWeapons Free\u201d protocol for designated border sectors under agreed crisis conditions.' },
    { id: 'FR-03', stage: 6, lane: 'policy', cat: 'procedural', sev: 'med', seed: true,
      desc: 'Civil-military airspace deconfliction between Oro navigacija and PAŻP is manual and non-synchronised.',
      mitigation: 'Pre-stage and test synchronised NOTAM templates and airspace reservation procedures.' }
  ];

  /* ---- 1-day agenda --------------------------------------- */
  const AGENDA = [
    ['0830', 'Opening Remarks & Purpose', 'Strategic context; analytical contract & wargaming rules.'],
    ['0900', 'Scenario Brief & Assumptions', 'Crisis context, constraints, threat profiles; deploy pieces.'],
    ['0930', 'Variant A · National Incursion', 'Baseline case — DCMP Phase 1 national timelines.'],
    ['1045', 'Morning Coffee', 'Analysts consolidate Variant A data logs.'],
    ['1100', 'Variant B · Cross-Border S2S', 'Interoperability case — DCMP Phase 2 releasability & latency.'],
    ['1230', 'Hosted Lunch', 'Informal coordination; mid-game player interviews.'],
    ['1330', 'Variant C · Engage Back', 'Sovereignty stress case — DCMP Phase 3 dual authorisation.'],
    ['1500', 'Afternoon Coffee', 'Facilitators compile and rank the Friction Register.'],
    ['1515', 'Friction Consolidation', 'Prioritise critical seams; map to LIVEX validation goals.'],
    ['1600', 'Senior Leader Outbrief', 'Present Quick Look; establish 90/180/365-day roadmaps.']
  ];

  /* ---- 90 / 180 / 365 roadmap ----------------------------- */
  const ROADMAP = [
    { horizon: '90 Days', tag: 'Immediate', color: '#16A34A',
      body: 'Establish joint civil-military airspace deconfliction playbooks and pre-approved NOTAM templates.' },
    { horizon: '180 Days', tag: 'Mid-Term', color: '#EAB308',
      body: 'Conduct simulated dry-run data exchanges between BALTNET, DUNAJ and the Polish IBCS network.' },
    { horizon: '365 Days', tag: 'Long-Term', color: '#D97757',
      body: 'Secure inter-governmental treaties providing standing pre-authorisations for cross-border kinetic engagements — the \u201cdual-key\u201d solution.' }
  ];

  return { META, LANES, FRICTION_CATS, SEVERITIES, STAGES, VARIANTS, SEED_FRICTIONS, AGENDA, ROADMAP };
})();
