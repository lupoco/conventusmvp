import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

/* Sahte PostgREST ucunu test kendisi baslatiyor — eskiden elle ayaga
   kaldirilmasi gerekiyordu ve test tek basina kosulamiyordu. */
const HERE = dirname(fileURLToPath(import.meta.url));
const mock = spawn(process.execPath, [join(HERE,'mock-rest-8098.mjs')],
  { stdio:'ignore', env:{...process.env, MOCK_QUIET:'1'} });
process.on('exit', ()=>{ try{ mock.kill(); }catch(_){} });
async function waitMock(){
  for(let i=0;i<40;i++){
    try{ await fetch('http://localhost:8098/__mode/201'); return true; }
    catch(_){ await new Promise(r=>setTimeout(r,150)); }
  }
  throw new Error('sahte REST ucu (8098) ayaga kalkmadi');
}
await waitMock();
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const errs = [];
const ctx = await b.newContext({ viewport: { width: 1280, height: 900 } });
const p = await ctx.newPage();
p.on('pageerror', e => errs.push('pageerror: ' + e.message));
// cv-config.js gercek supabase'i gosteriyor; testte sahte sunucuya yonlendir
await p.route('**/assets/js/cv-config.js', r => r.fulfill({
  contentType: 'application/javascript',
  body: "window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='sb_publishable_test';window.__CV_CONFIG_READY=true;"
}));
await p.addInitScript(() => { try{localStorage.setItem('cv-lang','tr');localStorage.setItem('cv-theme','light');}catch(e){} });

async function fill(name, mail, org, why) {
  await p.fill('#rqName', name); await p.fill('#rqMail', mail);
  await p.fill('#rqOrg', org);   await p.fill('#rqWhy', why);
}
async function setMode(m){ await p.request.get('http://localhost:8098/__mode/' + m); }

await p.goto('http://localhost:8099/under-construction.html', { waitUntil: 'load' });

console.log('form basta gizli mi      :', await p.locator('#reqForm').isHidden());
await p.click('#reqOpen');
console.log('butonla aciliyor mu      :', await p.locator('#reqForm').isVisible());
console.log('ilk alan odakta mi       :', await p.evaluate(() => document.activeElement.id === 'rqName'));

// 1) eksik/bozuk giris
await fill('A', 'bozuk', '', '');
await p.click('#rqSend'); await p.waitForTimeout(200);
console.log('1 bozuk giris            :', (await p.locator('#rqMsg').innerText()).slice(0,40));

// 2) basarili
await setMode('201');
await fill('Ayse Yilmaz', 'ayse@example.org', 'Ornek Kurum', 'MVP gormek istiyorum');
await p.click('#rqSend'); await p.waitForTimeout(400);
console.log('2 basarili               :', (await p.locator('#rqMsg').innerText()).slice(0,55));
console.log('  form temizlendi mi     :', (await p.inputValue('#rqName')) === '');

// 3) mukerrer (409)
await setMode('409');
await fill('Ayse Yilmaz', 'ayse@example.org', '', '');
await p.click('#rqSend'); await p.waitForTimeout(400);
console.log('3 mukerrer (409)         :', (await p.locator('#rqMsg').innerText()).slice(0,55));

// 4) sunucu hatasi (500) -> mailto yedegi
await setMode('500');
await fill('Test Kisi', 'test@example.org', '', '');
await p.click('#rqSend'); await p.waitForTimeout(400);
const t4 = await p.locator('#rqMsg').innerText();
console.log('4 sunucu hatasi          :', t4.slice(0,45));
console.log('  mailto yedegi var mi   :', await p.locator('#rqMsg a[href^="mailto:"]').count() === 1);

// 5) bot tuzagi doluysa gonderilmemeli
await setMode('201');
await fill('Bot', 'bot@example.org', '', '');
await p.fill('input[name=company_website]', 'spam');
/* Dolayli olcum yetmez ("mesaj degismedi" gonderimin basarisiz olmasiyla da
   olusur). Sahte uctaki POST sayacini once/sonra karsilastiriyoruz. */
const before = Number(await (await fetch('http://localhost:8098/__count')).text());
await p.click('#rqSend'); await p.waitForTimeout(400);
const after = Number(await (await fetch('http://localhost:8098/__count')).text());
console.log('5 bot tuzagi             : sunucuya giden POST', before, '->', after,
  after===before ? '✓ gonderim yok' : '✗ GONDERIM YAPILDI');
if(after!==before) errs.push('bot tuzagi dolu oldugu halde form gonderildi');

// 6) EN'e gecince form etiketleri cevriliyor mu
await p.click('#lang'); await p.waitForTimeout(150);
console.log('6 EN etiketi             :', await p.locator('label[data-i=fName]').innerText());

await p.screenshot({ path: '/var/tmp/form.png' });
await b.close();
try{ mock.kill(); }catch(_){}
console.log(errs.length ? 'HATA:\n' + errs.join('\n') : 'JS hatasi yok');
