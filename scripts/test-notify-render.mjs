/* notify-drain/render.ts — e-posta metni uretimi testi.
   Saf modul (render.js): Deno API'si yok, ag istegi yok, node ile dogrudan calisir.
   Ayrica demo/ornek-eposta.html'i AYNI KAYNAKTAN uretir — demoda gordugun
   metin ile canlida gidecek metin ayni olsun diye.
   Kullanim: node scripts/test-notify-render.mjs */
import fs from 'node:fs';
/* render.js duz JS: depoda build adimi yok, dogrudan import edilir. */
import { govde, M } from '../supabase/functions/notify-drain/render.js';

let fail=0;
const ok=(ad,k)=>{ console.log((k?'  OK  ':'  YOK ')+ad); if(!k) fail++; };
const BASE='https://conventity.com';

const P = {
  registration_id: 41, event_code:'LANDCOM-CONF-2026',
  event_title:'LANDCOM Interoperability Conference 2026',
  start_date:'2026-05-12', end_date:'2026-05-14', location:'Izmir, Turkiye',
  status:'approved', confirmation_code:'LC26-4F7A',
  participant_name:'Elif Demir', participant_email:'elif.demir@example.mil.tr',
  institution:'LANDCOM J5'
};
const TURLER = ['reg_submitted','reg_approved','reg_rejected','reg_waitlisted',
                'reg_cancelled','mgr_new_registration','mgr_cancellation'];

console.log('\n— her tur TR ve EN uretiyor —');
for (const t of TURLER){
  for (const dil of ['tr','en']){
    const r = govde({id:1,kind:t,to_email:'x@y.z',to_name:'X',lang:dil,payload:P,attempts:0}, BASE);
    if(!r){ ok(`${t}/${dil}`, false); continue; }
    const iyi = r.konu.length>5 && r.html.includes('<!doctype') && r.metin.length>40
             && !r.konu.includes('{{') && !r.html.includes('{{');
    ok(`${t}/${dil}`, iyi);
  }
}

console.log('\n— TR ve EN gercekten farkli (kopyala-yapistir degil) —');
const tr = govde({id:1,kind:'reg_approved',to_email:'x@y.z',to_name:null,lang:'tr',payload:P,attempts:0}, BASE);
const en = govde({id:1,kind:'reg_approved',to_email:'x@y.z',to_name:null,lang:'en',payload:P,attempts:0}, BASE);
ok('konular farkli', tr.konu !== en.konu);
ok('govdeler farkli', tr.metin !== en.metin);

console.log('\n— icerik dogru yerlestiriliyor —');
ok('etkinlik adi konuda', tr.konu.includes('LANDCOM Interoperability'));
ok('tarih GG.AA.YYYY', tr.metin.includes('12.05.2026') && tr.metin.includes('14.05.2026'));
ok('link etkinlik koduyla', tr.html.includes('/e/LANDCOM-CONF-2026'));
ok('onayda dogrulama kodu var', tr.metin.includes('LC26-4F7A'));

const bas = govde({id:1,kind:'reg_submitted',to_email:'x@y.z',to_name:null,lang:'tr',
                   payload:{...P,status:'submitted'},attempts:0}, BASE);
ok('basvuruda dogrulama kodu YOK', !bas.metin.includes('LC26-4F7A'));

const mgr = govde({id:1,kind:'mgr_new_registration',to_email:'x@y.z',to_name:null,lang:'tr',payload:P,attempts:0}, BASE);
ok('organizator postasinda katilimci adi', mgr.metin.includes('Elif Demir') && mgr.konu.includes('Elif Demir'));
ok('organizator postasinda kurum', mgr.metin.includes('LANDCOM J5'));

console.log('\n— HTML kacisi (XSS) —');
const kotu = govde({id:1,kind:'reg_approved',to_email:'x@y.z',to_name:null,lang:'tr',
  payload:{...P, event_title:'<script>alert(1)</script>', location:'"><img src=x onerror=alert(1)>'},attempts:0}, BASE);
/* Dogru olcut: payload'dan gelen ETIKET karakterleri ham kalmamali.
   "onerror=alert(1)" metninin govdede GORUNMESI zararsizdir — <td> icinde
   etkisiz metindir. Onu aramak yanlis alarm uretiyordu. */
ok('ham <script yok', !kotu.html.includes('<script'));
ok('ham <img yok', !kotu.html.includes('<img'));
ok('tirnak kacirildi', kotu.html.includes('&quot;') && kotu.html.includes('&lt;img'));
ok('href temiz', /<a href="https:\/\/conventity\.com\/e\/[^"<>]*"/.test(kotu.html));
/* Duz metin surumu text/plain'dir: orada ham "<" zararsizdir, KACIRILMASI
   yanlis olurdu (kullanici &quot; gorurdu). Dogru olcut: HTML varliklari
   duz metne sizmasin. */
ok('duz metinde HTML varligi yok', !/&(quot|lt|gt|amp);/.test(kotu.metin));

console.log('\n— eksik veri cokertmiyor —');
const bos = govde({id:1,kind:'reg_approved',to_email:'x@y.z',to_name:null,lang:'tr',payload:{},attempts:0}, BASE);
ok('bos payload ile uretiyor', !!bos && bos.html.includes('<!doctype'));
ok('bos alanlar yazdirilmiyor', !bos.html.includes('undefined') && !bos.html.includes('null'));

console.log('\n— bilinmeyen tur / dil —');
ok('bilinmeyen tur null doner', govde({id:1,kind:'yok_boyle',to_email:'x@y.z',to_name:null,lang:'tr',payload:P,attempts:0}, BASE) === null);
const fr = govde({id:1,kind:'reg_approved',to_email:'x@y.z',to_name:null,lang:'fr',payload:P,attempts:0}, BASE);
ok('bilinmeyen dil TR-ye duser', fr && fr.konu === tr.konu);

console.log('\n— TR/EN sozlukleri ayni turleri kapsiyor —');
ok('anahtarlar esit', JSON.stringify(Object.keys(M.tr).sort()) === JSON.stringify(Object.keys(M.en).sort()));

/* ---- demo icin GERCEK ciktiyi uret -------------------------------- */
const kartlar = TURLER.map(t=>{
  const r = govde({id:1,kind:t,to_email:'x@y.z',to_name:'X',lang:'tr',payload:P,attempts:0}, BASE);
  return { t, konu:r.konu, html:r.html };
});
const sayfa = `<!DOCTYPE html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Conventity · Bildirim e-postalari (onay icin)</title>
<style>
 body{margin:0;background:#F5F2EC;font:15px/1.6 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0E2148}
 .w{max-width:1000px;margin:0 auto;padding:28px 18px 60px}
 h1{font-size:26px;margin:0 0 6px} .alt{color:#5A6486;margin:0 0 6px;max-width:70ch}
 .not{background:#FBF3E4;border:1px solid #8A5A12;border-radius:10px;padding:12px 14px;
      font-size:13.5px;color:#5C3C0B;margin:16px 0 26px;max-width:70ch}
 .b{margin:30px 0 10px;display:flex;gap:10px;align-items:baseline;flex-wrap:wrap}
 .b h2{font-size:17px;margin:0}
 .k{font:700 10px/1 ui-monospace,monospace;letter-spacing:.14em;color:#8A6D2F;text-transform:uppercase}
 .ne{font-size:13px;color:#5A6486}
 iframe{width:100%;height:560px;border:1px solid #E5DFD2;border-radius:12px;background:#fff}
 @media(max-width:600px){iframe{height:640px}}
</style></head><body><div class="w">
<p style="margin:0 0 14px"><a href="akis-demo.html" style="color:#06488A;font-weight:600">&larr; Akis demosu</a>
 &nbsp;·&nbsp; <a href="beyaz-etiket-demo.html" style="color:#06488A;font-weight:600">Beyaz etiket</a></p>
<h1>Bildirim e-postalari</h1>
<p class="alt">Asagidakiler <b>gercek sablondan</b> uretildi — canlida gidecek metnin aynisi.
Uydurma ornek degil; <code>supabase/functions/notify-drain/render.js</code> tek kaynak.</p>
<div class="not">Metinleri okuyun. Degistirmek istediginiz bir cumle varsa soyleyin —
sablonu duzeltip bu sayfayi yeniden uretirim. Hicbir sey canliya gitmeden once.</div>
${kartlar.map(k=>`<div class="b"><span class="k">${k.t}</span><h2>${k.konu.replace(/&/g,'&amp;').replace(/</g,'&lt;')}</h2></div>
<div class="ne">Kime: ${k.t.startsWith('mgr_')?'etkinlik organizatoru':'katilimci'}</div>
<iframe title="${k.t}" srcdoc="${k.html.replace(/"/g,'&quot;')}"></iframe>`).join('\n')}
</div></body></html>`;
fs.mkdirSync('demo',{recursive:true});
fs.writeFileSync('demo/ornek-eposta.html', sayfa);
console.log('\ndemo/ornek-eposta.html uretildi ('+kartlar.length+' sablon)');

console.log(fail===0 ? '\n== TEST-NOTIFY-RENDER: HEPSI YESIL' : '\n== BASARISIZ: '+fail);
process.exit(fail?1:0);
