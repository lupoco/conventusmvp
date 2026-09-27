// ============================================================
// notify-drain / render.js
//
// E-posta metnini ureten SAF modul. Deno API'si kullanmaz, disari istek
// atmaz — bu yuzden node ile dogrudan test edilebilir
// (scripts/test-notify-render.mjs). Duz JS: depoda build adimi yok, Deno da
// node da dogrudan okur.
//
// Metin burada, veritabaninda degil: merkezi bakim. Musteriye ozel sablon
// kopyasi yok; dil/metin tek yerden degisir.
// ============================================================

export const M = {
  tr: {
    reg_submitted:       { k: 'Kaydınız alındı — {{event_title}}',
      g: 'Kaydınız alındı ve organizatör incelemesine düştü. Sonuç e-posta ile bildirilecek. Bu aşamada bilgilerinizi düzenleyebilir veya kaydınızı iptal edebilirsiniz.' },
    reg_approved:        { k: 'Kaydınız onaylandı — {{event_title}}',
      g: 'Kaydınız onaylandı. Etkinlik girişinde doğrulama kodunuzu gösterin. Onay sonrası ad, pasaport ve rütbe bilgileri kilitlenir; değişiklik gerekiyorsa organizatöre yazın. Kaydınızı hâlâ iptal edebilirsiniz.' },
    reg_rejected:        { k: 'Kayıt sonucunuz — {{event_title}}',
      g: 'Kaydınız bu etkinlik için onaylanmadı. Gerekçe için organizatöre başvurabilirsiniz.' },
    reg_waitlisted:      { k: 'Bekleme listesindesiniz — {{event_title}}',
      g: 'Kaydınız bekleme listesine alındı. Yer açılırsa size haber verilecek.' },
    reg_cancelled:       { k: 'Kaydınız iptal edildi — {{event_title}}',
      g: 'Kaydınız iptal edildi. Ayrılan otel ve transfer talepleriniz de düşürüldü. Yeniden katılmak isterseniz organizatöre başvurun.' },
    mgr_new_registration:{ k: 'Yeni kayıt: {{participant_name}} — {{event_title}}',
      g: 'Etkinliğinize yeni bir kayıt başvurusu geldi. Yönetim sayfasından inceleyip karara bağlayabilirsiniz.' },
    mgr_cancellation:    { k: 'Kayıt iptali: {{participant_name}} — {{event_title}}',
      g: 'Bir katılımcı kaydını iptal etti. Kontenjan ve hizmet talepleri buna göre güncellendi.' },
    mgr_offer_submitted: { k: 'Onay bekleyen teklif: {{offer_title}} — {{event_title}}',
      g: 'Bir hizmet sağlayıcı etkinliğiniz için teklif sundu. Onaylarsanız katılımcılara görünür olur; reddederseniz sağlayıcı düzeltip yeniden gönderebilir. Teklifin içeriğini siz değiştiremezsiniz — onay, sağlayıcının yazdığı sözün onayıdır.' },
    offer_approved:      { k: 'Teklifiniz onaylandı: {{offer_title}}',
      g: 'Teklifiniz etkinlik yöneticisi tarafından onaylandı ve katılımcılara görünür oldu. Onay sonrası teklif metni kilitlenir; değişiklik gerekiyorsa yöneticiyle görüşün.' },
    offer_rejected:      { k: 'Teklifiniz onaylanmadı: {{offer_title}}',
      g: 'Teklifiniz bu etkinlik için onaylanmadı. Düzeltip yeniden gönderebilirsiniz; gerekçe için etkinlik yöneticisine yazın.' },
  },
  en: {
    reg_submitted:       { k: 'Registration received — {{event_title}}',
      g: 'Your registration has been received and is under review. You will be informed of the outcome by e-mail. You can still edit your details or cancel at this stage.' },
    reg_approved:        { k: 'Registration approved — {{event_title}}',
      g: 'Your registration has been approved. Show your confirmation code at the event entrance. After approval, name, passport and rank are locked; contact the organiser if a change is needed. You can still cancel.' },
    reg_rejected:        { k: 'Registration outcome — {{event_title}}',
      g: 'Your registration was not approved for this event. Please contact the organiser for details.' },
    reg_waitlisted:      { k: 'You are on the waiting list — {{event_title}}',
      g: 'Your registration has been waitlisted. We will let you know if a place opens up.' },
    reg_cancelled:       { k: 'Registration cancelled — {{event_title}}',
      g: 'Your registration has been cancelled. Any hotel and transfer requests were released as well. Contact the organiser if you wish to attend after all.' },
    mgr_new_registration:{ k: 'New registration: {{participant_name}} — {{event_title}}',
      g: 'A new registration request arrived for your event. You can review and decide from the management page.' },
    mgr_cancellation:    { k: 'Cancellation: {{participant_name}} — {{event_title}}',
      g: 'A participant cancelled their registration. Capacity and service requests were updated accordingly.' },
    mgr_offer_submitted: { k: 'Offer awaiting approval: {{offer_title}} — {{event_title}}',
      g: 'A service provider submitted an offer for your event. If you approve it, participants will see it; if you reject it, the provider can correct and resubmit. You cannot edit the offer text — approving it approves what the provider wrote.' },
    offer_approved:      { k: 'Your offer was approved: {{offer_title}}',
      g: 'The event manager approved your offer and it is now visible to participants. The text is locked after approval; contact the manager if a change is needed.' },
    offer_rejected:      { k: 'Your offer was not approved: {{offer_title}}',
      g: 'Your offer was not approved for this event. You can correct and resubmit it; contact the event manager for details.' },
  },
}

const ETIKET = {
  tr: { event:'Etkinlik', kod:'Etkinlik kodu', tarih:'Tarih', yer:'Yer', dkod:'Doğrulama kodu',
        kisi:'Katılımcı', kurum:'Kurum', teklif:'Teklif', saglayici:'Sağlayıcı', buton:'Etkinlik sayfasını aç',
        alt:'Bu ileti Conventity üzerinden gönderildi. Yanıtlamayın; sorularınız için etkinlik organizatörüne yazın.' },
  en: { event:'Event', kod:'Event code', tarih:'Dates', yer:'Location', dkod:'Confirmation code',
        kisi:'Participant', kurum:'Organisation', teklif:'Offer', saglayici:'Provider', buton:'Open the event page',
        alt:'Sent via Conventity. Please do not reply; contact the event organiser with any questions.' },
}

export function doldur(sablon, p) {
  return sablon.replace(/\{\{(\w+)\}\}/g, (_, k) => String(p[k] ?? ''))
}
function kac(s) {
  return String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')
}
function tarihAraligi(p, dil) {
  const a = p.start_date ? String(p.start_date) : '', b = p.end_date ? String(p.end_date) : ''
  const g = (s) => { const [y,m,d] = s.split('-'); return d ? `${d}.${m}.${y}` : s }
  if (a && b && a !== b) return `${g(a)} – ${g(b)}`
  return a ? g(a) : (dil === 'tr' ? '—' : '—')
}

export function govde(satir, BASE_URL) {
  const dil = (M[satir.lang] ? satir.lang : 'tr')
  const sab = M[dil][satir.kind]
  if (!sab) return null                       // bilinmeyen tur: gonderme, GORUNUR birak
  const p = satir.payload || {}
  const e = ETIKET[dil]
  const konu = doldur(sab.k, p)
  const giris = doldur(sab.g, p)
  const link = `${BASE_URL}/e/${encodeURIComponent(String(p.event_code || ''))}`

  const satirlar = [
    [e.event, p.event_title], [e.kod, p.event_code],
    [e.tarih, tarihAraligi(p, dil)], [e.yer, p.location],
  ]
  if (satir.kind.startsWith('offer_') || satir.kind === 'mgr_offer_submitted') {
    satirlar.push([e.teklif, p.offer_title], [e.saglayici, p.provider_name])
  } else if (satir.kind.startsWith('mgr_')) {
    satirlar.push([e.kisi, p.participant_name], [e.kurum, p.institution])
  } else if (p.confirmation_code && satir.kind === 'reg_approved') {
    satirlar.push([e.dkod, p.confirmation_code])
  }

  const metin = [konu, '', giris, '',
    ...satirlar.filter(([,v]) => v).map(([k,v]) => `${k}: ${v}`), '', link, '', e.alt].join('\n')

  const html = `<!doctype html><html><body style="margin:0;background:#F5F2EC;
padding:24px 12px;font:15px/1.6 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0E2148">
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"
 style="max-width:560px;margin:0 auto;background:#fff;border:1px solid #E5DFD2;border-radius:14px">
<tr><td style="padding:22px 26px;border-bottom:1px solid #E5DFD2">
  <div style="font:700 10px/1 ui-monospace,monospace;letter-spacing:.18em;color:#8A6D2F;text-transform:uppercase">CONVENTITY</div>
  <div style="margin-top:9px;font-size:19px;font-weight:700">${kac(konu)}</div>
</td></tr>
<tr><td style="padding:22px 26px">
  <p style="margin:0 0 18px">${kac(giris)}</p>
  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
  ${satirlar.filter(([,v]) => v).map(([k,v]) => `<tr>
    <td style="padding:7px 0;border-bottom:1px solid #F0EBE0;font-size:11px;letter-spacing:.1em;
        text-transform:uppercase;color:#5A6486;white-space:nowrap;vertical-align:top">${kac(k)}</td>
    <td style="padding:7px 0 7px 14px;border-bottom:1px solid #F0EBE0;font-weight:600">${kac(v)}</td>
  </tr>`).join('')}
  </table>
  <p style="margin:22px 0 0">
    <a href="${kac(link)}" style="display:inline-block;background:#06488A;color:#fff;
       text-decoration:none;padding:12px 20px;border-radius:9px;font-weight:700;font-size:14px">${kac(e.buton)}</a>
  </p>
</td></tr>
<tr><td style="padding:16px 26px;background:#FAF7F1;border-top:1px solid #E5DFD2;
    border-radius:0 0 14px 14px;font-size:12px;color:#5A6486">${kac(e.alt)}</td></tr>
</table></body></html>`

  return { konu, html, metin }
}

