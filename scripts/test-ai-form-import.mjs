/* event-manage.html → "Kayıt formu" sekmesi → PDF/Word aktarımı (sahte Supabase + sahte fonksiyon).
   En kritik iddia: yönetici "uygula"ya basana kadar HİÇBİR ŞEY yazılmaz.
   Kullanım: npx http-server -p 8099 -s .  &&  node scripts/test-ai-form-import.mjs */
import { chromium } from 'playwright';
import fs from 'node:fs';

/* Sandbox'ta chromium yolu farkli olabiliyor; ilk var olani kullan. */
const ADAYLAR = ['/opt/pw-browsers/chromium/chrome-linux/chrome',
                 '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
                 '/opt/pw-browsers/chromium'];
const exe = ADAYLAR.find(x => { try { return fs.statSync(x).isFile(); } catch { return false; } });
const b = await chromium.launch(exe ? { executablePath: exe } : {});
const p = await (await b.newContext({viewport:{width:1280,height:1100}})).newPage();
const errs=[]; let fail=0;
const ok=(ad,k)=>{ console.log((k?'  OK  ':'  YOK ')+ad); if(!k) fail++; };
p.on('pageerror', e=>errs.push('pageerror: '+e.message));
p.on('console', m=>{ if(m.type()==='error' && !/ERR_CERT|fonts\.g|jsdelivr|unpkg/.test(m.text())) errs.push('console: '+m.text()); });
p.on('dialog', d=>d.accept());

await p.route('**/assets/js/cv-config.js', r=>r.fulfill({contentType:'application/javascript',
  body:"window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='k';"}));

await p.route('**/supabase-js@2**', r=>r.fulfill({contentType:'application/javascript', body:`
window.__OPS=[];
const EV={id:7,code:'LANDCOM-CONF-2026',title:'LANDCOM Konferansı 2026',activity_id:'a-1',
  community_id:'c-1',published:true,registration_open:true,logistics:{},
  registration_field_defs:[{key:'first_name',label:'Ad',type:'text',required:true,visible:true,core:true}]};
let TYPES=[], TRACKS=[], CONS=[];
function data(t){ return t==='conventus_event_reg_types'?TYPES:t==='conventus_event_tracks'?TRACKS:t==='conventus_event_consents'?CONS:[]; }
function qb(table){
  const self={ _f:{},
    select(){return self;}, eq(c,v){ self._f[c]=v; return self;}, order(){return self;},
    maybeSingle(){ if(table==='conventus_managed_events') return Promise.resolve({data:EV,error:null});
                   if(table==='conventus_communities') return Promise.resolve({data:{name:'LANDCOM'},error:null});
                   return Promise.resolve({data:null,error:null}); },
    insert(row){ window.__OPS.push({op:'insert',table,row});
      const arr=data(table); (Array.isArray(row)?row:[row]).forEach((r,i)=>arr.push(Object.assign({id:900+i},r)));
      return Promise.resolve({data:null,error:null}); },
    update(patch){ self._patch=patch; return self; },
    delete(){ self._del=true; return self; },
    then(res){
      if(self._patch){ window.__OPS.push({op:'update',table,id:self._f.id,patch:self._patch});
        return Promise.resolve({data:null,error:null}).then(res); }
      if(self._del){ window.__OPS.push({op:'delete',table,id:self._f.id});
        return Promise.resolve({data:null,error:null}).then(res); }
      return Promise.resolve({data:data(table).slice(),error:null}).then(res);
    }
  };
  return self;
}
window.supabase={createClient(){return{ from:qb,
  rpc(){ return Promise.resolve({data:true,error:null}); },
  auth:{ getSession(){return Promise.resolve({data:{session:{user:{id:'u1',email:'org@example.org'},access_token:'tok'}}});},
         signOut(){return Promise.resolve({});}, onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};} } };}};
`}));

/* Sahte Edge Function — gercek fonksiyonun dondurdugu bicimin aynisi. */
let fnCagri = 0, fnGovde = null;
await p.route('**/functions/v1/form-import', async r=>{
  fnCagri++;
  try{ fnGovde = JSON.parse(r.request().postData()||'{}'); }catch{ fnGovde=null; }
  await r.fulfill({ status:200, contentType:'application/json', body: JSON.stringify({
    import_id: 55, model:'claude-sonnet-5',
    fields:[
      {key:'first_name', label:'Ad',           type:'text',  required:true,  visible:true, core:true,  options:[], source_line:'Ad / First name: ______'},
      {key:'last_name',  label:'Soyad',        type:'text',  required:true,  visible:true, core:true,  options:[], source_line:'Soyad: ______'},
      {key:'dietary',    label:'Beslenme notu',type:'select',required:false, visible:true, core:false, options:['Yok','Vejetaryen','Helal'], source_line:'Beslenme: ( ) Yok ( ) Vejetaryen ( ) Helal'},
      {key:'shuttle',    label:'Servis kullanacak mısınız?', type:'checkbox', required:false, visible:true, core:false, options:[], source_line:'Servis: [ ] Evet'}
    ],
    consents:[{key:'photo', body:'Fotoğraf çekilmesine izin veriyorum.', required:false}],
    notes:['Belgede imza alanı var; dijital formda karşılığı yok.']
  })});
});

/* CDN kutuphanesini YERELDEN besle: bu kutunun agi jsdelivr'i kesiyor.
   Kutuphanenin kendisi gercek — test ettigimiz sey bizim cozumleme kodumuz. */
const JSZIP_YOL = ['/tmp/node_modules/jszip/dist/jszip.min.js',
                   'node_modules/jszip/dist/jszip.min.js']
  .find(x => { try { return fs.statSync(x).isFile(); } catch { return false; } });
if (JSZIP_YOL) {
  const src = fs.readFileSync(JSZIP_YOL, 'utf8');
  await p.route('**/jszip@3.10.1/**', r=>r.fulfill({contentType:'application/javascript', body:src}));
} else {
  console.log('  (jszip yerelde yok — `npm i jszip@3.10.1` gerekir)');
}

await p.addInitScript(()=>{ try{localStorage.setItem('cv-lang','tr');}catch(e){} });
await p.goto('http://localhost:8099/platforms/conventus/event-manage.html?e=LANDCOM-CONF-2026&tab=form',{waitUntil:'load'});
await p.waitForTimeout(1100);

console.log('\n— aktarim karti —');
ok('kart var', await p.locator('#aiCard').count()===1);
ok('dosya secici var', await p.locator('#aiFile').count()===1);

console.log('\n— dosya secilmeden calistirilamaz —');
await p.click('#aiGo'); await p.waitForTimeout(250);
ok('uyari cikti', (await p.locator('#aiErr').innerText()).trim().length>0);
ok('fonksiyon cagrilmadi', fnCagri===0);

console.log('\n— desteklenmeyen tip reddedilir —');
await p.setInputFiles('#aiFile', { name:'form.txt', mimeType:'text/plain', buffer:Buffer.from('merhaba') });
await p.click('#aiGo'); await p.waitForTimeout(250);
ok('tip uyarisi', (await p.locator('#aiErr').innerText()).includes('PDF'));
ok('fonksiyon yine cagrilmadi', fnCagri===0);

console.log('\n— DOCX cozumlenir ve oneri gosterilir —');
/* Gercek bir DOCX uret: zip icinde word/document.xml. Kod yolunu
   sahte bir dosyayla degil, GERCEK cozumleme ile test ediyoruz. */
const { execSync } = await import('node:child_process');
const xml = `<?xml version="1.0"?><w:document xmlns:w="x"><w:body>
<w:p><w:r><w:t>LANDCOM Kayit Formu</w:t></w:r></w:p>
<w:p><w:r><w:t>Ad / First name: ______</w:t></w:r></w:p>
<w:p><w:r><w:t>Soyad: ______</w:t></w:r></w:p>
<w:p><w:r><w:t>Beslenme: ( ) Yok ( ) Vejetaryen ( ) Helal</w:t></w:r></w:p>
<w:p><w:r><w:t>Servis: [ ] Evet</w:t></w:r></w:p>
<w:p><w:r><w:t>Fotograf cekilmesine izin veriyorum.</w:t></w:r></w:p>
</w:body></w:document>`;
fs.mkdirSync('/tmp/dx/word',{recursive:true});
fs.writeFileSync('/tmp/dx/word/document.xml', xml);
fs.mkdirSync('/tmp/dx/_rels',{recursive:true});
fs.writeFileSync('/tmp/dx/[Content_Types].xml','<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>');
try { execSync('cd /tmp/dx && zip -qr /tmp/test-form.docx .'); } catch(e){ console.log('  (zip yok, atlaniyor)'); }
const docx = fs.readFileSync('/tmp/test-form.docx');

await p.setInputFiles('#aiFile', { name:'kayit-formu.docx',
  mimeType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document', buffer:docx });
await p.click('#aiGo');
await p.waitForSelector('#aiApply', { timeout:15000 }).catch(()=>{});
await p.waitForTimeout(400);

ok('fonksiyon cagrildi', fnCagri===1);
ok('activity_id gonderildi', fnGovde && fnGovde.activity_id==='a-1');
ok('DOCX metni gercekten cikarildi', !!(fnGovde && /Beslenme/.test(fnGovde.text||'')));
ok('dosya adi gonderildi', fnGovde && fnGovde.source_name==='kayit-formu.docx');
ok('oneri tablosu cizildi', await p.locator('#aiOut table tbody tr .ai-use').count()===4);
ok('model gosteriliyor', (await p.locator('#aiOut').innerText()).includes('claude-sonnet-5'));
ok('notlar gosteriliyor', (await p.locator('#aiOut').innerText()).includes('imza alani') ||
                          (await p.locator('#aiOut').innerText()).includes('imza'));

console.log('\n— KRITIK: uygulamadan once hicbir sey yazilmadi —');
let ops = await p.evaluate(()=>window.__OPS);
ok('yazma islemi yok', ops.filter(o=>o.op!=='select').length===0);

console.log('\n— cakisan anahtar varsayilan olarak SECILI DEGIL —');
/* first_name formda zaten var; ustune yazip yoneticiyi sasirtmamali. */
const ilkSecili = await p.locator('.ai-use[data-i="0"]').isChecked();
ok('first_name isaretli degil', ilkSecili===false);
ok('cakisma notu goruluyor', (await p.locator('#aiOut').innerText()).includes('first_name'));

console.log('\n— gecersiz anahtar GORUNUR uyari verir, yazma YAPILMAZ —');
await p.fill('.ai-key[data-i="1"]', '!!');          // last_name -> gecersiz
await p.click('#aiApply');
await p.waitForTimeout(500);
ops = await p.evaluate(()=>window.__OPS);
ok('uyari gosterildi', (await p.locator('#aiApplyErr').innerText()).trim().length>0);
ok('gecersiz satir adiyla anildi', (await p.locator('#aiApplyErr').innerText()).includes('Soyad'));
ok('hicbir sey yazilmadi', ops.filter(o=>o.op!=='select').length===0);

console.log('\n— duzeltilince uygulanir —');
await p.fill('.ai-key[data-i="1"]', 'last_name');
await p.click('#aiApply');
await p.waitForTimeout(700);
ops = await p.evaluate(()=>window.__OPS);
const upd = ops.filter(o=>o.op==='update' && o.table==='conventus_managed_events');
ok('etkinlik guncellendi', upd.length===1);
const defs = upd.length ? upd[0].patch.registration_field_defs : [];
const anahtarlar = defs.map(d=>d.key);
ok('mevcut alan korundu (ekleme modu)', anahtarlar[0]==='first_name');
ok('duzeltilen anahtar alindi', anahtarlar.includes('last_name'));
ok('bozuk anahtar sizmadi', anahtarlar.indexOf('__')<0 && anahtarlar.indexOf('')<0);
ok('ozel alanlar eklendi', anahtarlar.includes('dietary') && anahtarlar.includes('shuttle'));
const dietary = defs.filter(d=>d.key==='dietary')[0];
ok('secenekler tasindi', dietary && Array.isArray(dietary.options) && dietary.options.length===3);
ok('ozel alan core=false', dietary && dietary.core===false);

const consIns = ops.filter(o=>o.op==='insert' && o.table==='conventus_event_consents');
ok('onay metni eklendi', consIns.length===1);

const audit = ops.filter(o=>o.op==='update' && o.table==='conventus_form_imports');
ok('denetim kaydi isaretlendi', audit.length===1 && !!audit[0].patch.applied_at);

await p.screenshot({path:'/var/tmp/ai-form-import.png', fullPage:true});
console.log('\nsayfa hatalari    :', errs.length?errs:'yok');
console.log(fail===0 && errs.length===0 ? '\n== TEST-AI-FORM-IMPORT: HEPSI YESIL' : '\n== BASARISIZ: '+fail);
await b.close();
process.exit((fail || errs.length) ? 1 : 0);
