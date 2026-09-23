/* ============================================================
   CONVENTITY — i18n  (TR / EN, dictionary method)

   How it works
   ------------
   • Mark any element:   <span data-i18n="key">fallback text</span>
   • Or an attribute:    <input data-i18n-attr="placeholder:key" />
                         (comma-separate multiple: "placeholder:a,title:b")
   • CVI18N.apply(root)  swaps text/attrs to the current language.
   • On language change it re-applies automatically (see nav.js hook).

   Adding text
   -----------
   Add a key under DICT with { tr, en }. Missing key → the element's
   existing text is left as-is (safe fallback). Proper nouns
   (platform names) are intentionally NOT translated.
   ============================================================ */

(function () {
  'use strict';

  var DICT = {
    /* ---- nav chrome ---- */
    'nav.login':     { tr: 'Giriş yap',      en: 'Log in' },
    'nav.signup':    { tr: 'Hesap oluştur',  en: 'Create account' },
    'nav.dashboard': { tr: 'Panel',          en: 'Dashboard' },
    'nav.settings':  { tr: 'Ayarlar',        en: 'Settings' },
    'nav.signout':   { tr: 'Çıkış yap',      en: 'Sign out' },
    'nav.account':   { tr: 'Hesap',          en: 'Account' },
    'nav.menu':      { tr: 'Menü',           en: 'Menu' },
    'nav.platforms': { tr: 'Platformlar',    en: 'Platforms' },
    'nav.sections':  { tr: 'Bölümler',       en: 'Sections' },
    'nav.theme':     { tr: 'Tema',           en: 'Theme' },
    'nav.lang':      { tr: 'Dil',            en: 'Language' },
    'nav.soon':      { tr: 'yakında',        en: 'soon' },
    'nav.verified':  { tr: 'Doğrulanmış',    en: 'Verified' },
    'nav.privacy':   { tr: 'Gizlilik',       en: 'Privacy' },
    'nav.terms':     { tr: 'Koşullar',       en: 'Terms' },
    'nav.security':  { tr: 'Güvenlik',       en: 'Security' },

    /* ---- route / section titles ---- */
    'route.conventus/overview':     { tr: 'Genel Bakış',      en: 'Overview' },
    'route.conventus/create':       { tr: 'Etkinlik oluştur', en: 'Create event' },
    'route.conventus/applications': { tr: 'Başvurular',       en: 'Applications' },
    'route.conventus/registration': { tr: 'Kayıt bağlantısı', en: 'Registration link' },
    'route.convexus/pool':          { tr: 'Havuz',            en: 'Pool' },
    'route.convexus/catalog':       { tr: 'Katalog',          en: 'Catalog' },
    'route.convexus/new':           { tr: 'Profil ekle',      en: 'Add profile' },
    'route.conventity/settings':    { tr: 'Ayarlar',          en: 'Settings' },

    /* ---- settings page ---- */
    'set.title':        { tr: 'Ayarlar',            en: 'Settings' },
    'set.lede':         { tr: 'Görünüm, dil ve hesap tercihlerin tek yerde.',
                          en: 'Appearance, language and account preferences in one place.' },
    'set.appearance':   { tr: 'Görünüm',            en: 'Appearance' },
    'set.appearance_d': { tr: 'Arayüzün açık mı koyu mu görüneceğini seç.',
                          en: 'Choose whether the interface looks light or dark.' },
    'set.theme.system': { tr: 'Sistem',             en: 'System' },
    'set.theme.light':  { tr: 'Açık',               en: 'Light' },
    'set.theme.dark':   { tr: 'Koyu',               en: 'Dark' },
    'set.language':     { tr: 'Dil',                en: 'Language' },
    'set.language_d':   { tr: 'Arayüz dilini seç. Tercih tarayıcında saklanır.',
                          en: 'Pick the interface language. Your choice is saved in your browser.' },
    'set.account':      { tr: 'Hesap',             en: 'Account' },
    'set.account_d':    { tr: 'Oturum ve hesap bilgilerin.',
                          en: 'Your session and account details.' },
    'set.signedin_as':  { tr: 'Giriş yapılan hesap',  en: 'Signed in as' },
    'set.signedout':    { tr: 'Şu an giriş yapılmadı.', en: 'You are not signed in.' },
    'set.signout':      { tr: 'Çıkış yap',          en: 'Sign out' },
    'set.login':        { tr: 'Giriş yap',          en: 'Log in' },

    /* ---- overview (example page) ---- */
    'ov.lede':     { tr: 'Etkinliklerin, başvuruların ve kayıt bağlantıların tek yerde. Etkinlik oluştur, bağlantısını paylaş, kimlerin başvurduğunu izle.',
                     en: 'Your events, applications and registration links in one place. Create an event, share its link, and track who applied.' },
    'ov.active':   { tr: 'Aktif etkinlik', en: 'Active events' },
    'ov.apps':     { tr: 'Başvurular',     en: 'Applications' },
    'ov.approved': { tr: 'Onaylanan',      en: 'Approved' },
    'ov.pending':  { tr: 'Bekleyen',       en: 'Pending' },

    /* ---- coming-soon (yakında) sayfaları ---- */
    'cs.title':       { tr: 'Kısa sürede burada.',        en: 'Coming shortly.' },
    'cs.badge':       { tr: 'Yakında',                    en: 'Coming soon' },
    'cs.back':        { tr: '← Ekosisteme dön',           en: '← Back to ecosystem' },
    'cs.meta_soon':   { tr: 'Yakında — Conventity',       en: 'Coming soon — Conventity' },
    'cs.brand':       { tr: 'Conventity',                 en: 'Conventity' },
    'cs.pf_connectus':  { tr: 'Connectus',  en: 'Connectus' },
    'cs.pf_conventlab': { tr: 'ConventLab', en: 'ConventLab' },
    'cs.pf_consultus':  { tr: 'Consultus',  en: 'Consultus' },
    'cs.pf_convexus':   { tr: 'Convexus',   en: 'Convexus' },
    'cs.pf_conventus':  { tr: 'Conventus',  en: 'Conventus' },
    'cs.pf_convergens': { tr: 'Convergens', en: 'Convergens' },
    'cs.connectus':   { tr: 'Bağlantı ve topluluk katmanı ekosisteme yakında katılıyor.',
                        en: 'The connection and community layer joins the ecosystem soon.' },
    'cs.conventlab':  { tr: 'Deney ve prototipleme atölyesi hazırlanıyor.',
                        en: 'The experimentation and prototyping lab is being prepared.' },
    'cs.consultus':   { tr: 'Danışmanlık ve uzman erişim katmanı yolda.',
                        en: 'The advisory and expert-access layer is on the way.' },

    /* ---- Connectus konsolu (Faz 1) ---- */
    'cn.meta':        { tr: 'Connectus · Conventity',        en: 'Connectus · Conventity' },
    'cn.eyebrow':     { tr: 'connectus · amaç-kilitli ağ',   en: 'connectus · purpose-locked network' },
    'cn.title':       { tr: 'Connectus',                     en: 'Connectus' },
    'cn.desc':        { tr: 'Provenans-destekli profiller, amaç-kilitli gruplar ve açıklanabilir eşleştirme. Her bağ bir çalışma bağlamına kilitli.',
                        en: 'Provenance-backed profiles, purpose-locked groups and explainable matching. Every connection is locked to a working context.' },
    'cn.signout':     { tr: 'Çıkış yap',                     en: 'Sign out' },
    'cn.tab_profile': { tr: 'Profil',      en: 'Profile' },
    'cn.tab_groups':  { tr: 'Gruplar',     en: 'Groups' },
    'cn.tab_feed':    { tr: 'Feed',        en: 'Feed' },
    'cn.tab_match':   { tr: 'Eşleştirme',  en: 'Matching' },
    'cn.tab_pool':    { tr: 'Havuz',       en: 'Pool' },
    'cn.eb_profile':  { tr: 'kimlik · provenans',            en: 'identity · provenance' },
    'cn.info_profile':{ tr: 'Kim olduğun ve ekosistemdeki doğrulanabilir izin — katılımlar ve kanıtlar.',
                        en: 'Who you are and your verifiable trail in the ecosystem — participations and evidence.' },
    'cn.pf_signedin': { tr: 'Oturum açık',                  en: 'Signed in' },
    'cn.pf_person':   { tr: 'Omurga kimliği',               en: 'Backbone identity' },
    'cn.pf_nolink':   { tr: 'Bu hesap henüz bir omurga kişisine (conventity_people) bağlı değil. Yönetici bağladığında provenans burada görünür.',
                        en: 'This account is not yet linked to a backbone person (conventity_people). Once an admin links it, your provenance appears here.' },
    'cn.pf_participation': { tr: 'Katılımlar',              en: 'Participations' },
    'cn.pf_evidence': { tr: 'Doğrulanmış kanıt',            en: 'Verified evidence' },
    'cn.pf_empty_part': { tr: 'Kayıtlı katılım yok.',       en: 'No participations on record.' },
    'cn.pf_empty_ev': { tr: 'Doğrulanmış katkı yok.',       en: 'No verified contributions yet.' },
    'cn.pf_open_proof': { tr: 'kanıtı aç →',                en: 'open proof →' },
    'cn.soon':        { tr: 'Bu bölüm sonraki fazda geliyor.', en: 'This section is coming in the next phase.' },
    'cn.soon_groups': { tr: 'Amaç-kilitli gruplar — kur, katıl, yönet. (Faz 2)', en: 'Purpose-locked groups — create, join, manage. (Phase 2)' },
    'cn.soon_feed':   { tr: 'Üyesi olduğun grupların amaç-kilitli akışı. (Faz 2)', en: 'Purpose-locked feed of your groups. (Phase 2)' },
    'cn.soon_match':  { tr: 'Açıklanabilir sıcak eşleştirme — her sonuç gerekçeli. (Faz 3)', en: 'Explainable warm matching — every result justified. (Phase 3)' },
    'cn.soon_pool':   { tr: 'SME & konuşmacı havuzu — etiketle ara, Conventus’a öner. (Faz 4)', en: 'SME & speaker pool — search by tag, suggest to Conventus. (Phase 4)' },
    'cn.loading':     { tr: 'Yükleniyor…',                  en: 'Loading…' },

    /* ---- Connectus Faz 2: Gruplar + Feed ---- */
    'cn.eb_groups':   { tr: 'amaç-kilitli · gruplar',       en: 'purpose-locked · groups' },
    'cn.info_groups': { tr: 'Her grup bir çalışma bağlamına kilitli. Kilitli grup yalnız üyelerine görünür.',
                        en: 'Every group is locked to a working context. A locked group is visible only to its members.' },
    'cn.g_create':    { tr: 'Grup kur',                     en: 'Create group' },
    'cn.g_name':      { tr: 'Grup adı',                     en: 'Group name' },
    'cn.g_name_ph':   { tr: 'ör. C-UAS çalışma hücresi',    en: 'e.g. C-UAS working cell' },
    'cn.g_purpose':   { tr: 'Amaç türü',                    en: 'Purpose type' },
    'cn.g_visibility':{ tr: 'Görünürlük',                   en: 'Visibility' },
    'cn.g_vis_locked':{ tr: 'Kilitli — yalnız üyeler',      en: 'Locked — members only' },
    'cn.g_vis_eco':   { tr: 'Ekosistem — herkes görür',     en: 'Ecosystem — visible to all' },
    'cn.pk_problem':  { tr: 'Talep (problem)',              en: 'Demand (problem)' },
    'cn.pk_activity': { tr: 'Faaliyet',                     en: 'Activity' },
    'cn.pk_challenge_area': { tr: 'Challenge area',         en: 'Challenge area' },
    'cn.pk_event':    { tr: 'Etkinlik',                     en: 'Event' },
    'cn.pk_org':      { tr: 'Kurum',                        en: 'Organization' },
    'cn.g_join':      { tr: 'Katıl',                        en: 'Join' },
    'cn.g_leave':     { tr: 'Ayrıl',                        en: 'Leave' },
    'cn.g_member':    { tr: 'üye',                          en: 'member' },
    'cn.g_moderator': { tr: 'moderatör',                    en: 'moderator' },
    'cn.g_empty':     { tr: 'Görünür grup yok. İlkini sen kur.', en: 'No visible groups. Create the first one.' },
    'cn.g_created':   { tr: 'Grup kuruldu.',                en: 'Group created.' },
    'cn.g_joined':    { tr: 'Gruba katıldın.',              en: 'Joined the group.' },
    'cn.g_left':      { tr: 'Gruptan ayrıldın.',            en: 'Left the group.' },
    'cn.g_name_req':  { tr: 'Grup adı gerekli.',            en: 'Group name is required.' },
    'cn.g_need_person': { tr: 'Grup kurmak veya katılmak için hesabın bir omurga kişisine (conventity_people) bağlı olmalı. Yönetici bağlayabilir.',
                        en: 'To create or join a group your account must be linked to a backbone person. An admin can link it.' },
    'cn.eb_feed':     { tr: 'amaç-kilitli · feed',          en: 'purpose-locked · feed' },
    'cn.info_feed':   { tr: 'Üyesi olduğun grupların akışı. Yalnız üyeler okur ve yazar.',
                        en: 'The feed of groups you belong to. Only members read and post.' },
    'cn.f_pick':      { tr: 'Grup seç',                     en: 'Select a group' },
    'cn.f_none':      { tr: 'Henüz bir grubun yok. Gruplar sekmesinden katıl ya da kur.',
                        en: 'You have no groups yet. Join or create one in the Groups tab.' },
    'cn.f_empty':     { tr: 'Bu grupta gönderi yok.',       en: 'No posts in this group.' },
    'cn.f_ph':        { tr: 'Bir şey paylaş…',              en: 'Share something…' },
    'cn.f_send':      { tr: 'Gönder',                       en: 'Send' },
    'cn.f_kind':      { tr: 'Tür',                          en: 'Type' },
    'cn.k_note':      { tr: 'Not',                          en: 'Note' },
    'cn.k_ask':       { tr: 'Talep',                        en: 'Ask' },
    'cn.k_offer':     { tr: 'Teklif',                       en: 'Offer' },
    'cn.k_announce':  { tr: 'Duyuru',                       en: 'Announce' },
    'cn.f_body_req':  { tr: 'Boş gönderi olmaz.',           en: 'Post cannot be empty.' },
    'cn.err_generic': { tr: 'İşlem başarısız. RLS izni veya bağlantı olabilir.', en: 'Action failed — could be an RLS permission or connection issue.' },

    /* ---- Connectus Faz 3: Eşleştirme ---- */
    'cn.eb_match':    { tr: 'açıklanabilir · eşleştirme',   en: 'explainable · matching' },
    'cn.info_match':  { tr: 'Bir bağlam gir (aranan uzmanlık etiketleri) → kural-tabanlı, açıklanabilir sıcak eşleştirme. Skor deterministik; AI değil.',
                        en: 'Enter a context (needed expertise tags) → rule-based, explainable warm matching. Score is deterministic; not AI.' },
    'cn.m_ctx':       { tr: 'Bağlam etiketleri (virgülle ayır)', en: 'Context tags (comma-separated)' },
    'cn.m_ctx_ph':    { tr: 'ör. c-uas, osint, logistics',  en: 'e.g. c-uas, osint, logistics' },
    'cn.m_run':       { tr: 'Eşleştir',                     en: 'Match' },
    'cn.m_need_ctx':  { tr: 'En az bir bağlam etiketi gir.', en: 'Enter at least one context tag.' },
    'cn.m_empty':     { tr: 'Bu bağlama uygun aday yok.',   en: 'No candidates match this context.' },
    'cn.m_no_pool':   { tr: 'Havuz henüz boş — kimse uzmanlık eklemedi. Havuz (Faz 4) dolunca eşleştirme sonuç verir.',
                        en: 'The pool is empty — no expertise added yet. Matching produces results once the Pool (Phase 4) fills.' },
    'cn.band_warm':   { tr: 'sıcak',                        en: 'warm' },
    'cn.band_possible': { tr: 'olası',                     en: 'possible' },
    'cn.band_cold':   { tr: 'zayıf',                        en: 'weak' },
    'cn.m_score':     { tr: 'skor',                         en: 'score' },
    'cn.m_r_tag':     { tr: 'ortak alan',                  en: 'shared areas' },
    'cn.m_r_ev':      { tr: 'kanıt',                        en: 'evidence' },
    'cn.m_r_part':    { tr: 'katılım',                     en: 'participations' },
    'cn.m_r_self':    { tr: 'öz-derece',                   en: 'self-rating' },
    'cn.m_suggest':   { tr: 'Conventus’a öner',            en: 'Suggest to Conventus' },
    'cn.m_suggest_soon': { tr: 'Öneri köprüsü Faz 4’te geliyor.', en: 'The suggestion bridge is coming in Phase 4.' },

    /* ---- Connectus Faz 4: Havuz (SME/konuşmacı) ---- */
    'cn.eb_pool':     { tr: 'sme & konuşmacı · havuz',     en: 'sme & speaker · pool' },
    'cn.info_pool':   { tr: 'Uzmanlığını etiketle; havuz aranabilir olsun. Eşleştirme bu havuzu kullanır.',
                        en: 'Tag your expertise so the pool is searchable. Matching uses this pool.' },
    'cn.p_add':       { tr: 'Uzmanlık ekle',               en: 'Add expertise' },
    'cn.p_tag':       { tr: 'Etiket',                       en: 'Tag' },
    'cn.p_tag_ph':    { tr: 'ör. osint',                    en: 'e.g. osint' },
    'cn.p_kind':      { tr: 'Tür',                          en: 'Type' },
    'cn.exk_sme':     { tr: 'SME (uzman)',                  en: 'SME (expert)' },
    'cn.exk_speaker': { tr: 'Konuşmacı',                    en: 'Speaker' },
    'cn.p_rated':     { tr: 'Öz-derece',                    en: 'Self-rating' },
    'cn.p_addbtn':    { tr: 'Ekle',                         en: 'Add' },
    'cn.p_mine':      { tr: 'Uzmanlıklarım',                en: 'My expertise' },
    'cn.p_mine_empty':{ tr: 'Henüz uzmanlık eklemedin.',    en: 'You have not added any expertise yet.' },
    'cn.p_search':    { tr: 'Havuzda ara (etiket)',         en: 'Search the pool (tag)' },
    'cn.p_search_ph': { tr: 'ör. c-uas',                    en: 'e.g. c-uas' },
    'cn.p_search_btn':{ tr: 'Ara',                          en: 'Search' },
    'cn.p_pool_empty':{ tr: 'Eşleşen kimse yok.',           en: 'No one matches.' },
    'cn.p_remove':    { tr: 'kaldır',                       en: 'remove' },
    'cn.p_added':     { tr: 'Uzmanlık eklendi.',            en: 'Expertise added.' },
    'cn.p_removed':   { tr: 'Kaldırıldı.',                  en: 'Removed.' },
    'cn.p_tag_req':   { tr: 'Etiket gerekli.',              en: 'Tag is required.' },

    /* ---- auth: ortak ---- */
    'a.brand_sub':   { tr: 'Geleceğin Ekosistemi',  en: 'Ecosystem for Future' },
    'a.back_home':   { tr: 'Ana sayfaya dön',       en: 'Back to home' },
    'a.or_with':     { tr: 'ya da şununla devam et', en: 'or continue with' },
    'a.pill_live':   { tr: 'Convergens · Canlı',    en: 'Convergens · Live' },
    'a.terms_pre':   { tr: 'Devam ederek şunları kabul edersin:', en: 'By continuing you agree to the' },
    'a.terms':       { tr: 'Kullanım Koşulları',    en: 'Terms of Service' },
    'a.and':         { tr: 've',                     en: 'and' },
    'a.privacy':     { tr: 'Gizlilik Politikası',   en: 'Privacy Policy' },
    'a.head1':       { tr: 'Kimliğin.',             en: 'Your identity.' },
    'a.head2':       { tr: 'Altı platform.',        en: 'Six platforms.' },
    'a.head_sub':    { tr: 'Tek hesap. Tüm ekosisteme erişim. Güvenli, birlikte çalışabilir, çift-kullanımlı — önemli olan için kurulmuş.',
                       en: 'One account. Full ecosystem access. Secure, interoperable, dual-use — built for what matters.' },
    'a.vma1_label':  { tr: 'Çift-Kullanım · Güvenli', en: 'Dual-Use · Secure' },
    'a.vma1_text':   { tr: '<em>Sivil ve askeri</em> tek yüzeyde. Rol-tabanlı. Denetime hazır.',
                       en: '<em>Civil &amp; military</em> on one surface. Role-based. Audit-ready.' },
    'a.vma2_label':  { tr: 'Birlikte çalışır · Her zaman açık', en: 'Interoperable · Always on' },
    'a.vma2_text':   { tr: '<em>Altı platform, tek omurga.</em> Bir kez bağlan, her yerde iş birliği yap.',
                       en: '<em>Six platforms, one backbone.</em> Connect once, collaborate everywhere.' },
    'a.vma3_label':  { tr: 'Yönetici denetimli · Erişim', en: 'Admin-controlled · Access' },
    'a.vma3_text':   { tr: 'Platform erişimi yöneticiler tarafından verilir. Onaylandığı an <em>haberin olur.</em>',
                       en: 'Platform access is granted by admins. <em>You are notified</em> the moment it is approved.' },

    /* ---- login ---- */
    'lg.meta':       { tr: 'Giriş · Conventity',    en: 'Sign in · Conventity' },
    'lg.title':      { tr: 'Giriş yap',             en: 'Sign in' },
    'lg.sub_pre':    { tr: 'Conventity’de yeni misin?', en: 'New to Conventity?' },
    'lg.sub_link':   { tr: 'Hesap oluştur',         en: 'Create an account' },
    'lg.lbl_id':     { tr: 'E-posta veya kullanıcı adı', en: 'Email or username' },
    'lg.ph_id':      { tr: 'ornek@site.com veya kullanıcı adı', en: 'you@example.com or username' },
    'lg.lbl_pass':   { tr: 'Parola',               en: 'Password' },
    'lg.ph_pass':    { tr: 'Parolan',              en: 'Your password' },
    'lg.remember':   { tr: 'Beni hatırla',         en: 'Remember me' },
    'lg.forgot':     { tr: 'Parolanı mı unuttun?', en: 'Forgot password?' },
    'lg.btn':        { tr: 'Giriş yap',            en: 'Sign in' },
    'lg.btn_wait':   { tr: 'Giriş yapılıyor…',     en: 'Signing in…' },
    'lg.err_empty':  { tr: 'Lütfen e-posta/kullanıcı adı ve parolanı gir.', en: 'Please enter your email/username and password.' },
    'lg.err_nouser': { tr: 'Kullanıcı adı bulunamadı.', en: 'Username not found.' },
    'rg.verify_box3': { tr: 'Conventity kapalı test aşamasında: e-postanı doğruladıktan sonra erişimini bir ekosistem yöneticisi onaylar. Açıldığında sana yazacağız.', en: 'Conventity is in closed preview: after you confirm your email, an ecosystem administrator approves your access. We will write to you once it is open.' },
    'lg.err_notmember': { tr: 'Üyeliğiniz henüz aktif değil. Conventity şu an yalnızca onaylı üyelere açık. Erişim için ekosistem yöneticisiyle iletişime geçin.', en: 'Your membership is not active yet. Conventity is currently open to approved members only. Contact the ecosystem administrator for access.' },

    /* ---- forgot-password ---- */
    'fp.meta':       { tr: 'Parola sıfırla · Conventity', en: 'Reset password · Conventity' },
    'fp.head1':      { tr: 'Güvenli erişim.',       en: 'Secure access.' },
    'fp.head2':      { tr: 'Tek kimlik.',           en: 'One identity.' },
    'fp.left_sub':   { tr: 'Tek hesabın tüm Conventity ekosistemini açar — altı platform, tek güvenilir kimlik.',
                       en: 'Your single account unlocks the entire Conventity ecosystem — six platforms, one trusted identity.' },
    'fp.vma1_label': { tr: 'Çift-Kullanım · Tasarımdan güvenli', en: 'Dual-Use · Secure by design' },
    'fp.vma1_text':  { tr: '<em>Sivil ve askeri</em> tek yüzeyde. Rol-tabanlı erişim. Denetime hazır.',
                       en: '<em>Civil &amp; military</em> on one surface. Role-based access. Audit-ready.' },
    'fp.vma2_label': { tr: 'Birlikte çalışır · Her zaman bağlı', en: 'Interoperable · Always connected' },
    'fp.vma2_text':  { tr: '<em>Altı platform, tek omurga.</em> Bir kez bağlan, her yerde iş birliği yap.',
                       en: '<em>Six platforms, one backbone.</em> Connect once, collaborate everywhere.' },
    'fp.vma3_label': { tr: 'İnovasyon · Doğrulanmış', en: 'Innovation · Validated' },
    'fp.vma3_text':  { tr: '<em>Sicil odaklı.</em> Pilotlardan canlı operasyona — dağıtımdan önce kanıtlanmış.',
                       en: '<em>Track-record driven.</em> From pilots to live operations — proven before deployment.' },
    'fp.step1':      { tr: 'İstek',                 en: 'Request' },
    'fp.step2':      { tr: 'E-postayı kontrol et',  en: 'Check email' },
    'fp.title':      { tr: 'Parolayı sıfırla',      en: 'Reset password' },
    'fp.sub_pre':    { tr: 'Hatırladın mı?',        en: 'Remembered it?' },
    'fp.sub_link':   { tr: 'Girişe dön',            en: 'Back to sign in' },
    'fp.lbl_email':  { tr: 'E-posta adresi',        en: 'Email address' },
    'fp.ph_email':   { tr: 'ornek@site.com',        en: 'you@example.com' },
    'fp.err':        { tr: 'Lütfen e-posta adresini gir.', en: 'Please enter your email address.' },
    'fp.btn':        { tr: 'Sıfırlama bağlantısı gönder', en: 'Send reset link' },
    'fp.btn_wait':   { tr: 'Gönderiliyor…',         en: 'Sending…' },
    'fp.cancel':     { tr: 'Vazgeç',                en: 'Cancel' },
    'fp.ok_title':   { tr: 'E-postanı kontrol et',  en: 'Check your email' },
    'fp.ok_sub':     { tr: 'Parola sıfırlama bağlantısını şuraya gönderdik:', en: 'We sent a password reset link to' },
    'fp.ok_info':    { tr: 'Yeni parola belirlemek için e-postandaki bağlantıya tıkla. Bağlantı 1 saat içinde geçerliliğini yitirir.',
                       en: 'Click the link in your email to set a new password. The link expires in 1 hour.' },
    'fp.ok_spam':    { tr: 'Görmüyor musun? Spam klasörüne bak.', en: "Don't see it? Check your spam folder." },
    'fp.back':       { tr: 'Girişe dön',            en: 'Back to sign in' },

    /* ---- reset password (recovery landing) ---- */
    'rp.meta':       { tr: 'Yeni parola · Conventity', en: 'New password · Conventity' },
    'rp.step1':      { tr: 'Bağlantı',              en: 'Reset link' },
    'rp.step2':      { tr: 'Yeni parola',           en: 'New password' },
    'rp.verifying':  { tr: 'Bağlantın doğrulanıyor…', en: 'Verifying your reset link…' },
    'rp.title':      { tr: 'Yeni parola belirle',   en: 'Set a new password' },
    'rp.sub':        { tr: 'Conventity hesabın için güçlü bir parola seç.', en: 'Choose a strong password for your Conventity account.' },
    'rp.lbl_pw':     { tr: 'Yeni parola',           en: 'New password' },
    'rp.ph_pw':      { tr: 'En az 8 karakter',      en: 'At least 8 characters' },
    'rp.lbl_pw2':    { tr: 'Parolayı doğrula',      en: 'Confirm password' },
    'rp.ph_pw2':     { tr: 'Parolayı tekrar gir',   en: 'Re-enter password' },
    'rp.btn':        { tr: 'Parolayı güncelle',     en: 'Update password' },
    'rp.btn_wait':   { tr: 'Güncelleniyor…',        en: 'Updating…' },
    'rp.err_empty':  { tr: 'Lütfen yeni bir parola gir.', en: 'Enter a new password.' },
    'rp.err_short':  { tr: 'Parola en az 8 karakter olmalı.', en: 'Password must be at least 8 characters.' },
    'rp.err_match':  { tr: 'Parolalar eşleşmiyor.', en: 'Passwords do not match.' },
    'rp.ok_title':   { tr: 'Parola güncellendi',    en: 'Password updated' },
    'rp.ok_sub':     { tr: 'Parolan değiştirildi. Artık yeni parolanla giriş yapabilirsin.', en: 'Your password has been changed. You can now sign in with your new password.' },
    'rp.ok_cta':     { tr: 'Girişe devam et',       en: 'Continue to sign in' },
    'rp.invalid_title': { tr: 'Bağlantı geçersiz veya süresi dolmuş', en: 'Link expired or invalid' },
    'rp.invalid_sub':   { tr: 'Bu parola sıfırlama bağlantısı artık geçerli değil. Yeni bir bağlantı iste.', en: 'This reset link is no longer valid. Please request a new one.' },
    'rp.invalid_cta':   { tr: 'Yeni bağlantı iste', en: 'Request new link' },

    /* ---- shared OAuth (login + register) ---- */
    'a.or':          { tr: 'veya',                  en: 'or' },
    'a.google':      { tr: 'Google ile devam et',   en: 'Continue with Google' },
    'a.linkedin':    { tr: 'LinkedIn ile devam et', en: 'Continue with LinkedIn' },
    'a.oauth_err':   { tr: 'Sağlayıcı ile giriş şu an kullanılamıyor.', en: 'Sign-in with this provider is unavailable right now.' },

    /* ---- register ---- */
    'rg.meta':        { tr: 'Hesap oluştur · Conventity', en: 'Create account · Conventity' },
    'rg.eyebrow':     { tr: 'Ekosisteme katıl',      en: 'Join the ecosystem' },
    'rg.head3':       { tr: 'Tek gelecek.',          en: 'One future.' },
    'rg.left_sub':    { tr: 'Bir kez kaydol. Tüm Conventity ekosistemine eriş — inovasyon pazarlarından güvenli operasyon ağlarına. Profilin her platformda seninle taşınır.',
                        en: 'Register once. Access the entire Conventity ecosystem — from innovation marketplaces to secure operational networks. Your profile travels with you across every platform.' },
    'rg.feat1_t':     { tr: 'Tasarımdan güvenli',    en: 'Secure by design' },
    'rg.feat1_s':     { tr: 'Rol-tabanlı erişim, denetim-farkında oturumlar, onaysız sıfır veri paylaşımı.',
                        en: 'Role-based access, audit-aware sessions, zero data sharing without consent.' },
    'rg.feat2_t':     { tr: 'Tek kimlik, altı platform', en: 'One identity, six platforms' },
    'rg.feat2_s':     { tr: 'Bireysel ya da kurumsal — tek hesabın tüm aktif platformları açar.',
                        en: 'Personal or corporate — your single account unlocks every active platform.' },
    'rg.feat3_t':     { tr: 'Yönetici denetimli erişim', en: 'Admin-controlled access' },
    'rg.feat3_s':     { tr: 'Bazı platformlar onay gerektirir. Erişim verildiği an haberin olur.',
                        en: "Some platforms require approval. You'll be notified the moment access is granted." },
    'rg.step1':       { tr: 'Kaydol',                en: 'Register' },
    'rg.step2':       { tr: 'Onayla',               en: 'Confirm' },
    'rg.title':       { tr: 'Hesap oluştur',        en: 'Create account' },
    'rg.sub_pre':     { tr: 'Zaten var mı?',        en: 'Already have one?' },
    'rg.sub_link':    { tr: 'Giriş yap',            en: 'Sign in' },
    'rg.type_personal':     { tr: 'Bireysel',       en: 'Personal' },
    'rg.type_personal_sub': { tr: 'Bireysel hesap', en: 'Individual account' },
    'rg.type_corporate':     { tr: 'Kurumsal',      en: 'Corporate' },
    'rg.type_corporate_sub': { tr: 'Şirket hesabı', en: 'Company account' },
    'rg.lbl_email':   { tr: 'E-posta',             en: 'Email' },
    'rg.lbl_email_biz': { tr: 'Kurumsal e-posta',  en: 'Business email' },
    'rg.ph_email':    { tr: 'ornek@site.com',       en: 'you@example.com' },
    'rg.ph_email_biz': { tr: 'ad@sirket.com',       en: 'name@company.com' },
    'rg.lbl_pass':    { tr: 'Parola',              en: 'Password' },
    'rg.ph_pass':     { tr: 'En az 8 karakter',    en: 'Min. 8 characters' },
    'rg.opt_personal': { tr: 'Ek bilgiler (isteğe bağlı)', en: 'Additional information (optional)' },
    'rg.opt_note_personal': { tr: 'Bu alanlar isteğe bağlıdır ve daha sonra profil ayarlarından tamamlanabilir.',
                        en: 'These fields are optional and can be completed later in your profile settings.' },
    'rg.lbl_username': { tr: 'Kullanıcı adı',       en: 'Username' },
    'rg.ph_username': { tr: 'kullanici_adin',       en: 'your_username' },
    'rg.hint_username': { tr: 'Yalnızca harf, rakam ve alt çizgi.', en: 'Letters, numbers and underscores only.' },
    'rg.lbl_country': { tr: 'Ülke',                en: 'Country' },
    'rg.ph_country':  { tr: 'Ülke seç…',           en: 'Select country...' },
    'rg.opt_corporate': { tr: 'Şirket bilgileri (isteğe bağlı)', en: 'Company information (optional)' },
    'rg.opt_note_corporate': { tr: 'Bu alanlar isteğe bağlıdır. Yönetici, tam erişim vermeden önce ek bilgi isteyebilir.',
                        en: 'These fields are optional. Admin may request additional information before granting full access.' },
    'rg.lbl_company': { tr: 'Şirket adı',          en: 'Company name' },
    'rg.ph_company':  { tr: 'Şirketinin adı',       en: 'Your company name' },
    'rg.lbl_industry': { tr: 'Sektör',             en: 'Industry / Sector' },
    'rg.ph_industry': { tr: 'Sektör seç…',         en: 'Select industry...' },
    'rg.ind_technology':    { tr: 'Teknoloji',      en: 'Technology' },
    'rg.ind_defence':       { tr: 'Savunma ve Güvenlik', en: 'Defence & Security' },
    'rg.ind_finance':       { tr: 'Finans ve Yatırım', en: 'Finance & Investment' },
    'rg.ind_energy':        { tr: 'Enerji',         en: 'Energy' },
    'rg.ind_healthcare':    { tr: 'Sağlık',         en: 'Healthcare' },
    'rg.ind_manufacturing': { tr: 'Üretim',         en: 'Manufacturing' },
    'rg.ind_consulting':    { tr: 'Danışmanlık',    en: 'Consulting' },
    'rg.ind_education':     { tr: 'Eğitim',         en: 'Education' },
    'rg.ind_media':         { tr: 'Medya ve İletişim', en: 'Media & Communications' },
    'rg.ind_other':         { tr: 'Diğer',          en: 'Other' },
    'rg.lbl_authperson': { tr: 'Yetkili kişi adı',  en: 'Authorized person name' },
    'rg.ph_authperson': { tr: 'Ad soyad',           en: 'Full name' },
    'rg.lbl_authtitle': { tr: 'Ünvan / Pozisyon',   en: 'Title / Position' },
    'rg.ph_authtitle': { tr: 'CEO, Direktör, Müdür…', en: 'CEO, Director, Manager...' },
    'rg.terms_label': { tr: '<a href="#" id="open-terms">Kullanım Koşulları</a>’nı ve <a href="#" id="open-privacy">Gizlilik Politikası</a>’nı okudum ve kabul ediyorum.',
                        en: 'I have read and agree to the <a href="#" id="open-terms">Terms of Service</a> and <a href="#" id="open-privacy">Privacy Policy</a>.' },
    'rg.kvkk_label':  { tr: 'Kişisel verilerimin <a href="#" id="open-kvkk">KVKK / GDPR Aydınlatma Metni</a>’ne uygun olarak işlenmesine onay veriyorum.',
                        en: 'I consent to the processing of my personal data in accordance with the <a href="#" id="open-kvkk">KVKK / GDPR Privacy Notice</a>.' },
    'rg.btn':         { tr: 'Hesap oluştur',        en: 'Create account' },
    'rg.btn_wait':    { tr: 'Oluşturuluyor…',       en: 'Creating…' },
    'rg.footer_note': { tr: 'Platforma özel erişim, kayıttan sonra yöneticiler tarafından yönetilir.',
                        en: 'Platform-specific access is managed by admins after registration.' },
    'rg.err_email':   { tr: 'E-posta gerekli.',     en: 'Email is required.' },
    'rg.err_pass':    { tr: 'Parola en az 8 karakter olmalı.', en: 'Password must be at least 8 characters.' },
    'rg.err_terms':   { tr: 'Lütfen Kullanım Koşulları’nı kabul et.', en: 'Please accept the Terms of Service.' },
    'rg.err_kvkk':    { tr: 'Lütfen Aydınlatma Metni’ni kabul et.', en: 'Please accept the Privacy Notice.' },
    'rg.verify_title': { tr: 'E-postanı kontrol et', en: 'Check your email' },
    'rg.verify_sent': { tr: 'Onay bağlantısını şuraya gönderdik:', en: 'We sent a confirmation link to' },
    'rg.terms_html':  {
      tr: '<h4>Kullanım Koşulları ve Gizlilik</h4><p>Conventity ("Platform"), Lupoco A.Ş. tarafından işletilir. Hesap oluşturarak aşağıdaki koşulları kabul edersin.</p><br/><p><strong>1. Üyelik:</strong> Hesap bilgilerinin gizliliğinden sen sorumlusun.</p><br/><p><strong>2. Veri Koruma (KVKK/GDPR):</strong> Kişisel verilerin 6698 sayılı KVKK ve GDPR uyarınca işlenir. Yalnız hizmet için gerekli veriyi toplarız.</p><br/><p><strong>3. Platform Erişimi:</strong> Bazı bölümlere erişim yönetici onayı gerektirir. Conventity erişimi dilediği an geri alma hakkını saklı tutar.</p><br/><p><strong>4. Kabul Edilebilir Kullanım:</strong> Platformu yasa dışı faaliyet, spam veya taciz için kullanmamayı kabul edersin.</p><br/><p><strong>5. Fikri Mülkiyet:</strong> Conventity içeriği telif hakkıyla korunur.</p><br/><p><strong>6. Uygulanacak Hukuk:</strong> Bu koşullar Türkiye Cumhuriyeti kanunlarına tabidir.</p><br/><p style="font-size:.7rem;color:var(--muted)">Sürüm 1.0</p>',
      en: '<h4>Terms of Service &amp; Privacy Policy</h4><p>Conventity ("Platform") is operated by Lupoco A.Ş. By creating an account, you agree to the following terms.</p><br/><p><strong>1. Membership:</strong> You are responsible for maintaining the confidentiality of your account credentials.</p><br/><p><strong>2. Data Protection (KVKK/GDPR):</strong> Your personal data is processed in accordance with Turkish Law No. 6698 (KVKK) and GDPR. We collect only the data necessary to provide our services.</p><br/><p><strong>3. Platform Access:</strong> Access to certain sections requires admin approval. Conventity reserves the right to revoke access at any time.</p><br/><p><strong>4. Acceptable Use:</strong> You agree not to use the platform for illegal activities, spam, or harassment.</p><br/><p><strong>5. Intellectual Property:</strong> All content on Conventity is protected by copyright.</p><br/><p><strong>6. Governing Law:</strong> These terms are governed by the laws of the Republic of Türkiye.</p><br/><p style="font-size:.7rem;color:var(--muted)">Version 1.0</p>' },
    'rg.kvkk_html':   {
      tr: '<h4>KVKK / GDPR Aydınlatma Metni</h4><p>Veri sorumlusu sıfatıyla Lupoco A.Ş., kişisel verilerini 6698 sayılı KVKK ve GDPR uyarınca işler.</p><br/><p><strong>Toplanan veri:</strong> E-posta adresi, IP adresi, platform kullanım verisi.</p><br/><p><strong>Amaç:</strong> Conventity platformunu sunmak, geliştirmek ve hesabını yönetmek.</p><br/><p><strong>Hukuki dayanak:</strong> Açık rızan ve sözleşmenin ifası.</p><br/><p><strong>Saklama:</strong> Veri, hesabın aktif olduğu sürece veya yasal gereklilik boyunca saklanır.</p><br/><p><strong>Haklarınız:</strong> Verilerine erişme, düzeltme, silme veya işlenmesini kısıtlama hakkına sahipsin.</p><br/><p style="font-size:.7rem;color:var(--muted)">Sürüm 1.0</p>',
      en: '<h4>KVKK / GDPR Privacy Notice</h4><p>As the data controller, Lupoco A.Ş. processes your personal data in accordance with Turkish Law No. 6698 (KVKK) and GDPR.</p><br/><p><strong>Data collected:</strong> Email address, IP address, platform usage data.</p><br/><p><strong>Purpose:</strong> To provide and improve the Conventity platform and manage your account.</p><br/><p><strong>Legal basis:</strong> Your explicit consent and the performance of a contract.</p><br/><p><strong>Retention:</strong> Data is retained for as long as your account is active or as required by law.</p><br/><p><strong>Your rights:</strong> You have the right to access, correct, delete, or restrict the processing of your data.</p><br/><p style="font-size:.7rem;color:var(--muted)">Version 1.0</p>' },
    'rg.verify_box1': { tr: 'Hesabını etkinleştirmek için e-postandaki bağlantıya tıkla. Onayladıktan sonra giriş yapabilirsin.',
                        en: 'Click the link in your email to activate your account. After confirming, you can sign in.' },
    'rg.verify_box2': { tr: 'Görmüyor musun? Spam klasörüne bak.', en: "Don't see it? Check your spam folder." },
    'rg.verify_goto': { tr: 'Girişe git',           en: 'Go to Sign in' },
    'rg.resend_pre':  { tr: 'Gelmedi mi?',          en: "Didn't receive it?" },
    'rg.resend_btn':  { tr: 'E-postayı tekrar gönder', en: 'Resend email' },
    'rg.resend_done': { tr: 'Onay e-postası tekrar gönderildi!', en: 'Confirmation email resent!' },
    'rg.modal_terms': { tr: 'Kullanım Koşulları ve Gizlilik', en: 'Terms of Service & Privacy Policy' },
    'rg.modal_privacy': { tr: 'Gizlilik Politikası', en: 'Privacy Policy' },
    'rg.modal_kvkk':  { tr: 'KVKK / GDPR Aydınlatma Metni', en: 'KVKK / GDPR Privacy Notice' },
    'rg.modal_close': { tr: 'Kapat',               en: 'Close' },

    /* ============ CONNECTUS — signed-in app ============ */
    /* nav */
    'cn.brand_sub':   { tr: '· ağ',                en: '· network' },
    'cn.nav.home':    { tr: 'Ana sayfa',           en: 'Home' },
    'cn.nav.network': { tr: 'Ağım',                en: 'Network' },
    'cn.nav.msg':     { tr: 'Mesajlar',            en: 'Messaging' },
    'cn.nav.alerts':  { tr: 'Bildirimler',         en: 'Alerts' },
    'cn.nav.me':      { tr: 'Ben',                 en: 'Me' },
    'cn.nav.search':  { tr: 'Kişi, uzmanlık, kurum ara…', en: 'Search people, expertise, orgs…' },
    'cn.me.view':     { tr: 'Profilimi gör',       en: 'View profile' },
    'cn.me.settings': { tr: 'Ayarlar',             en: 'Settings' },
    'cn.me.signout':  { tr: 'Çıkış yap',           en: 'Sign out' },
    'cn.foot.about':  { tr: 'Connectus hakkında →', en: 'About Connectus →' },
    /* provenance labels */
    'cn.prov.conn':   { tr: 'Bağlantı',            en: 'Conn.' },
    'cn.prov.events': { tr: 'Faaliyet',            en: 'Events' },
    'cn.prov.certs':  { tr: 'Kayıt',               en: 'Certs' },

    /* home */
    'cn.home.your_profile': { tr: 'Profilin',      en: 'Your profile' },
    'cn.home.connections':  { tr: 'Bağlantılar',   en: 'Connections' },
    'cn.home.groups':       { tr: 'Gruplar',       en: 'Groups' },
    'cn.home.footline':     { tr: 'Amaç-kilitli. Provenans-temelli.', en: 'Purpose-locked. Provenance-backed.' },
    'cn.cmp.select':  { tr: 'Paylaşmak için bir grup seç…', en: 'Select a group to post in…' },
    'cn.cmp.ph':      { tr: 'Gruplarınla bir güncelleme, talep ya da teklif paylaş…', en: 'Share an update, an ask, or an offer with your groups…' },
    'cn.kind.note':   { tr: 'Not',                 en: 'Note' },
    'cn.kind.ask':    { tr: 'Talep',               en: 'Ask' },
    'cn.kind.offer':  { tr: 'Teklif',              en: 'Offer' },
    'cn.kind.announce':{ tr: 'Duyuru',             en: 'Announce' },
    'cn.cmp.post':    { tr: 'Paylaş',              en: 'Post' },
    'cn.feed.loading':{ tr: 'Akışın yükleniyor…',  en: 'Loading your feed…' },
    'cn.feed.empty':  { tr: 'Henüz gönderi yok. Sağdan bir gruba katıl ve ilk güncellemeyi paylaş.', en: 'No posts yet. Join a group on the right and share the first update.' },
    'cn.feed.unavail':{ tr: 'Akış şu an kullanılamıyor.', en: 'Feed unavailable right now.' },
    'cn.post.endorse':{ tr: 'Onayla',              en: 'Endorse' },
    'cn.post.reply':  { tr: 'Yanıtla',             en: 'Reply' },
    'cn.post.refer':  { tr: 'İlet',                en: 'Refer' },
    'cn.post.comment_ph':{ tr: 'Bir yorum yaz…',   en: 'Write a comment…' },
    'cn.post.send':   { tr: 'Gönder',              en: 'Send' },
    'cn.grow.eb':     { tr: 'Ağını büyüt',         en: 'Grow your network' },
    'cn.grow.title':  { tr: 'Bağlanılacak kişiler', en: 'People to connect' },
    'cn.grow.finding':{ tr: 'İlgili kişiler bulunuyor…', en: 'Finding relevant people…' },
    'cn.grow.seeall': { tr: 'Tüm önerileri gör →', en: 'See all suggestions →' },
    'cn.grow.none':   { tr: 'Şimdilik yeni öneri yok.', en: 'No new suggestions right now.' },
    'cn.grow.unavail':{ tr: 'Öneriler kullanılamıyor.', en: 'Suggestions unavailable.' },
    'cn.grp.eb':      { tr: 'Amaç-kilitli',        en: 'Purpose-locked' },
    'cn.grp.title':   { tr: 'Katılınacak gruplar', en: 'Groups to join' },
    'cn.grp.loading': { tr: 'Gruplar yükleniyor…', en: 'Loading groups…' },
    'cn.grp.none':    { tr: 'Henüz grup yok.',     en: 'No groups yet.' },
    'cn.grp.join':    { tr: 'Katıl',               en: 'Join' },
    'cn.grp.member':  { tr: 'Üye',                 en: 'Member' },
    'cn.grp.unavail': { tr: 'Gruplar kullanılamıyor.', en: 'Groups unavailable.' },
    'cn.home.suggest_note': { tr: 'Öneriler kural-tabanlı ve açıklanabilir — her biri <b>neden</b>ini gösterir. AI önerir, insan karar verir.', en: 'Suggestions are rule-based and explainable — each shows <b>why</b>. AI advises; humans decide.' },
    'cn.connect':     { tr: '+ Bağlan',            en: '+ Connect' },
    'cn.pending':     { tr: 'Beklemede',           en: 'Pending' },
    'cn.members_word':{ tr: 'üye',                 en: 'members' },
    'cn.signin_connect':{ tr: 'Bağlanmak için giriş yap.', en: 'Sign in to connect.' },
    'cn.signin_join': { tr: 'Katılmak için giriş yap.', en: 'Sign in to join.' },

    /* profile */
    'cn.pf.about_eb':  { tr: 'Hakkında',           en: 'About' },
    'cn.pf.about_t':   { tr: 'Ekosistemde',        en: 'In the ecosystem' },
    'cn.pf.exp_eb':    { tr: 'Uzmanlık',           en: 'Expertise' },
    'cn.pf.exp_t':     { tr: 'Alanlar ve yetenekler', en: 'Areas & skills' },
    'cn.pf.prov_eb':   { tr: 'Provenans',          en: 'Provenance' },
    'cn.pf.prov_t':    { tr: 'Doğrulanmış kayıtlar ve belgeler', en: 'Verified records & credentials' },
    'cn.pf.prov_disc': { tr: 'Bunlar üyenin katıldığı faaliyetlerden gelen provenans kayıtlarıdır — taşınabilir kanıt, kişisel sertifika değil. AI önerir, insan karar verir.', en: 'These are provenance records from activities this member took part in — portable proof, not a personal certification. AI advises; humans decide.' },
    'cn.pf.track_eb':  { tr: 'Sicil',              en: 'Track record' },
    'cn.pf.track_t':   { tr: 'Faaliyetler',        en: 'Activities' },
    'cn.pf.edit':      { tr: 'Profili düzenle',    en: 'Edit profile' },
    'cn.pf.manage':    { tr: 'Ağı yönet',          en: 'Manage network' },
    'cn.pf.connect':   { tr: 'Bağlan',             en: 'Connect' },
    'cn.pf.message':   { tr: 'Mesaj',              en: 'Message' },
    'cn.pf.signin':    { tr: 'Giriş yap',          en: 'Sign in' },
    'cn.pf.notfound':  { tr: 'Profil bulunamadı',  en: 'Profile not found' },
    'cn.pf.notfound_s':{ tr: 'Bu üyenin henüz bir ekosistem profili yok ya da giriş yapman gerekiyor.', en: 'This member has no ecosystem profile yet, or you need to sign in.' },
    'cn.pf.member':    { tr: 'Ekosistem üyesi',    en: 'Ecosystem member' },
    'cn.pf.l_conn':    { tr: 'bağlantı',           en: 'connections' },
    'cn.pf.l_act':     { tr: 'faaliyet',           en: 'activities' },
    'cn.pf.l_rec':     { tr: 'kayıt',              en: 'records' },
    'cn.pf.no_rec':    { tr: 'Henüz bağlı provenans kaydı yok. Üye kanıtlı faaliyetlere katıldıkça kayıtlar burada görünür.', en: 'No provenance records linked yet. Records appear here as this member takes part in evidenced activities.' },
    'cn.pf.no_act':    { tr: 'Henüz kayıtlı faaliyet yok.', en: 'No activities recorded yet.' },
    'cn.pf.show_rec':  { tr: 'Kaydı gör',          en: 'Show record' },
    'cn.pf.no_areas':  { tr: 'Henüz uzmanlık kaydı yok.', en: 'No expertise recorded yet.' },
    'cn.pf.l_areas':   { tr: 'uzmanlık alanı',     en: 'areas of expertise' },

    /* network */
    'cn.nw.manage':    { tr: 'Ağımı yönet',        en: 'Manage my network' },
    'cn.nw.inv':       { tr: 'Davetler',           en: 'Invitations' },
    'cn.nw.events':    { tr: 'Faaliyetler',        en: 'Events & activities' },
    'cn.nw.side_foot': { tr: 'Amaç-kilitli bağlantılar. Her istek bir gerekçe belirtir.', en: 'Purpose-locked connections. Each request states a reason.' },
    'cn.nw.no_inv':    { tr: 'Bekleyen davet yok.', en: 'No pending invitations.' },
    'cn.nw.reason':    { tr: 'bağlanma gerekçesi',  en: 'reason to connect' },
    'cn.nw.ignore':    { tr: 'Yoksay',             en: 'Ignore' },
    'cn.nw.accept':    { tr: 'Kabul et',           en: 'Accept' },
    'cn.nw.pymk_t':    { tr: 'Ekosistemindeki kişiler', en: 'People in your ecosystem' },
    'cn.nw.pymk_s':    { tr: 'açıklanabilir · kural-tabanlı', en: 'explainable · rule-based' },
    'cn.nw.finding':   { tr: 'İlgili kişiler bulunuyor…', en: 'Finding relevant people…' },
    'cn.nw.no_sugg':   { tr: 'Şimdilik yeni öneri yok.', en: 'No new suggestions right now.' },
    'cn.nw.conn_t':    { tr: 'Bağlantıların',      en: 'Your connections' },
    'cn.nw.no_conn':   { tr: 'Henüz bağlantı yok — aşağıdaki kişilerle bağlan.', en: 'No connections yet — connect with people below.' },
    'cn.nw.results':   { tr: 'Sonuçlar:',          en: 'Results for' },
    'cn.nw.found':     { tr: 'bulundu',            en: 'found' },
    'cn.nw.no_match':  { tr: 'Eşleşme yok.',       en: 'No matches.' },
    'cn.nw.searching': { tr: 'Aranıyor…',          en: 'Searching…' },
    'cn.nw.unavail':   { tr: 'Ağ kullanılamıyor.', en: 'Network unavailable.' },

    /* organisation */
    'cn.org.cap_eb':   { tr: 'Kolektif yetkinlik', en: 'Collective capability' },
    'cn.org.cap_t':    { tr: 'Uzmanlık alanları',  en: 'Areas of expertise' },
    'cn.org.cap_disc': { tr: 'Bu kurumun üyelerinin ekosistemdeki doğrulanmış uzmanlığından derlenmiştir.', en: "Aggregated from the verified expertise of this organisation's members in the ecosystem." },
    'cn.org.prov_eb':  { tr: 'Provenans',          en: 'Provenance' },
    'cn.org.rec_t':    { tr: 'Kurum kayıtları',    en: 'Organisation records' },
    'cn.org.rec_disc': { tr: 'Kanıtlı faaliyetlerden taşınabilir kanıt. AI önerir, insan karar verir.', en: 'Portable proof from evidenced activities. AI advises; humans decide.' },
    'cn.org.ppl_eb':   { tr: 'Kişiler',            en: 'People' },
    'cn.org.mem_t':    { tr: 'Üyeler',             en: 'Members' },
    'cn.org.notfound': { tr: 'Kurum bulunamadı',   en: 'Organisation not found' },
    'cn.org.notfound_s':{ tr: 'Böyle bir kurum yok ya da giriş yapman gerekiyor.', en: 'No such organisation, or you need to sign in.' },
    'cn.org.no_exp':   { tr: 'Henüz uzmanlık kaydı yok.', en: 'No expertise recorded yet.' },
    'cn.org.no_rec':   { tr: 'Henüz kurum kaydı yok.', en: 'No organisation records yet.' },
    'cn.org.no_mem':   { tr: 'Bu kuruma bağlı üye yok.', en: 'No members linked to this organisation yet.' },
    'cn.org.l_mem':    { tr: 'üye',                en: 'members' },
    'cn.org.l_areas':  { tr: 'alan',               en: 'areas' },
    'cn.org.l_rec':    { tr: 'kayıt',              en: 'records' },
    'cn.org.activities':{ tr: 'faaliyet',          en: 'activities' },

    /* messaging */
    'cn.msg.title':    { tr: 'Mesajlar',           en: 'Messaging' },
    'cn.msg.loading':  { tr: 'Yükleniyor…',        en: 'Loading…' },
    'cn.msg.no_threads':{ tr: 'Henüz konuşma yok. Bir üyeyi açıp “Mesaj” seç.', en: 'No conversations yet. Open a member and choose “Message”.' },
    'cn.msg.select':   { tr: 'Bir konuşma seç ya da bir üyenin profilini açıp “Mesaj” de.', en: 'Select a conversation, or open a member\'s profile and choose “Message”.' },
    'cn.msg.write_ph': { tr: 'Bir mesaj yaz…',     en: 'Write a message…' },
    'cn.msg.send':     { tr: 'Gönder',             en: 'Send' },
    'cn.msg.view':     { tr: 'Profili gör',        en: 'View profile' },
    'cn.msg.none':     { tr: 'Henüz mesaj yok — bir merhaba de.', en: 'No messages yet — say hello.' },
    'cn.msg.you':      { tr: 'Sen: ',              en: 'You: ' },
    'cn.msg.unavail':  { tr: 'Mesajlar kullanılamıyor.', en: 'Messages unavailable.' },
    'cn.msg.cant_open':{ tr: 'Bu konuşma açılamadı.', en: 'Could not open this conversation.' },

    /* alerts / notifications */
    'cn.al.title':     { tr: 'Bildirimler',        en: 'Notifications' },
    'cn.al.empty':     { tr: 'Şimdilik bildirim yok.', en: 'Nothing new right now.' },
    'cn.al.loading':   { tr: 'Yükleniyor…',        en: 'Loading…' },
    'cn.al.invite':    { tr: 'bağlanmak istiyor',  en: 'wants to connect' },
    'cn.al.message':   { tr: 'sana mesaj gönderdi', en: 'sent you a message' },
    'cn.al.post':      { tr: 'grubunda yeni gönderi paylaştı', en: 'posted in a group you\'re in' },
    'cn.al.review':    { tr: 'Görüntüle',          en: 'Review' },
    'cn.al.open':      { tr: 'Aç',                 en: 'Open' },
    'cn.al.foot':      { tr: 'Davetlerden, okunmamış mesajlardan ve grup akışından türetilmiştir.', en: 'Derived from invitations, unread messages and group activity.' },

    'cn.signin_generic':{ tr: 'Devam etmek için giriş yap.', en: 'Sign in to continue.' },
  };

  function lang() { return (window.CVPrefs && window.CVPrefs.getLang()) || 'tr'; }

  function t(key, fallback) {
    var e = DICT[key];
    if (!e) return fallback != null ? fallback : key;
    return e[lang()] || e.en || (fallback != null ? fallback : key);
  }

  function apply(root) {
    root = root || document.body;
    if (!root) return;

    // textContent
    root.querySelectorAll('[data-i18n]').forEach(function (node) {
      var key = node.getAttribute('data-i18n');
      var val = t(key, null);
      if (val != null) node.textContent = val;
    });

    // attributes:  data-i18n-attr="placeholder:key,title:key2"
    root.querySelectorAll('[data-i18n-attr]').forEach(function (node) {
      node.getAttribute('data-i18n-attr').split(',').forEach(function (pair) {
        var bits = pair.split(':');
        if (bits.length === 2) {
          var v = t(bits[1].trim(), null);
          if (v != null) node.setAttribute(bits[0].trim(), v);
        }
      });
    });
  }

  /* ============================================================
     CANONİK API (§7): T() / Tf() / applyI18n() + data-i / data-ph
     ------------------------------------------------------------
     Executable JS'te sabit metin OLMAZ — hep T('anahtar').
     Statik HTML: data-i="anahtar" (innerHTML), data-ph="anahtar"
     (placeholder). Eksik anahtar → sessizce düşme, ⟦anahtar⟧
     işaretle (tarama betiğinin ve gözün yakalaması için).
     ============================================================ */
  function T(key) {
    var e = DICT[key];
    if (!e) return '⟦' + key + '⟧';           // ⟦key⟧
    return e[lang()] || e.en || ('⟦' + key + '⟧');
  }
  function Tf(key) {
    var s = T(key), a = arguments, i = 1;
    return s.replace(/%s/g, function () { return a[i] != null ? a[i++] : (i++, ''); });
  }
  function applyI18n(root) {
    root = root || document.body;
    if (!root) return;
    root.querySelectorAll('[data-i]').forEach(function (n) {
      n.innerHTML = T(n.getAttribute('data-i'));
    });
    root.querySelectorAll('[data-ph]').forEach(function (n) {
      n.setAttribute('placeholder', T(n.getAttribute('data-ph')));
    });
    // <html lang> her uygulamada güncellensin
    document.documentElement.setAttribute('lang', lang());
    // eski data-i18n konvansiyonu da çalışsın (settings.html)
    apply(root);
  }

  window.CVI18N = { t: t, apply: apply, dict: DICT };
  window.T = T; window.Tf = Tf; window.applyI18n = applyI18n;

  // Auto-apply once the DOM is ready.
  function boot() { applyI18n(document.body); }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else { boot(); }

  // Dil değişince otomatik yeniden uygula.
  if (window.CVPrefs && typeof window.CVPrefs.onChange === 'function') {
    window.CVPrefs.onChange(function (what) { if (what === 'lang') applyI18n(document.body); });
  }
})();
