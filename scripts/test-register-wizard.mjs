/* register-conventus.html — kayıt sihirbazı uçtan uca davranış testi.
   Gerçek Supabase'e bağlanmaz: cv-config.js ve supabase-js CDN'i sahteyle
   değiştirilir, yazma çağrıları yakalanır.
   Kullanım: npx http-server -p 8099 -s .  &&  node scripts/test-register-wizard.mjs */
import { chromium } from 'playwright';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const ctx = await b.newContext({ viewport:{ width:760, height:1000 } });
const p = await ctx.newPage();
const errs=[];
p.on('pageerror', e=>errs.push('pageerror: '+e.message));
p.on('console', m=>{ if(m.type()==='error' && !/ERR_CERT|fonts\.g|jsdelivr|unpkg/.test(m.text())) errs.push('console: '+m.text()); });

await p.route('**/assets/js/cv-config.js', r=>r.fulfill({contentType:'application/javascript',
  body:"window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='k';window.__CV_CONFIG_READY=true;"}));
await p.route('**/supabase-js@2**', r=>r.fulfill({contentType:'application/javascript', body:`
window.__WRITES=[];
const EV_FIXTURE={id:7,code:'LANDCOM-CONF-2026',title:'LANDCOM Konferansı 2026',start_date:'2026-11-17',
  end_date:'2026-11-19',location:'Belirlenecek',host_org:'LANDCOM',description:'Test',
  published:true,registration_open:true,registration_field_defs:[]};
const TYPES=[{id:1,key:'delegate',label:'Katılımcı',note:'Konferansa katılacaksanız seçin.',allow_other:false,sort:1},
             {id:2,key:'other',label:'Diğer',note:'Uymuyorsa açıklayın.',allow_other:true,sort:9}];
const TRACKS=[{id:11,key:'main',title:'Ana program',starts_on:'2026-11-17',ends_on:'2026-11-19',time_from:'09:00',time_to:'17:00',sort:1},
              {id:12,key:'site',title:'Saha ziyareti',starts_on:'2026-11-18',ends_on:'2026-11-18',capacity:20,external_note:'Ayrı kayıt gerekir.',sort:2}];
const CONSENTS=[{id:21,key:'participant_list',version:1,body:'Katılımcı listesinde paylaşılmasına onay veriyorum.',is_required:true,sort:1},
                {id:22,key:'media',version:2,body:'Görüntü yayımına onay veriyorum.',is_required:false,sort:2}];
function qb(table){
  const self={ _t:table,
    select(){return self;}, eq(){return self;}, order(){return self;},
    maybeSingle(){ if(table==='conventus_managed_events') return Promise.resolve({data:EV_FIXTURE,error:null});
                   return Promise.resolve({data:null,error:null}); },
    single(){ return Promise.resolve({data:{id:99,confirmation_code:'ABCD234XYZ',status:'submitted'},error:null}); },
    insert(rows){ window.__WRITES.push({table,rows}); return self; },
    then(res){
      let data=[];
      if(table==='conventus_event_reg_types') data=TYPES;
      if(table==='conventus_event_tracks')    data=TRACKS;
      if(table==='conventus_event_consents')  data=CONSENTS;
      return Promise.resolve({data,error:null}).then(res);
    }
  };
  return self;
}
window.supabase={createClient(){return{ from:qb, rpc(){return Promise.resolve({data:true,error:null});},
  auth:{ getSession(){return Promise.resolve({data:{session:{user:{id:'u1',email:'aday@example.org',user_metadata:{}}}}});},
         updateUser(){return Promise.resolve({});}, signOut(){return Promise.resolve({});},
         onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};} } };}};
`}));
await p.addInitScript(()=>{ try{localStorage.setItem('cv-lang','tr');localStorage.setItem('cv-theme','dark');}catch(e){} });

await p.goto('http://localhost:8099/platforms/conventus/register-conventus.html?e=LANDCOM-CONF-2026',{waitUntil:'load'});
await p.waitForTimeout(1200);

const stepLabel = async()=> (await p.locator('.wz-step b').innerText()).trim();
const stepNo    = async()=> (await p.locator('.wz-step span').innerText()).trim();

console.log('1 adim          :', await stepLabel(), '|', await stepNo());
console.log('  dil TR mi     :', (await p.title()).startsWith('Kayıt'));

// --- adim 1: tip secmeden ilerlemeyi dene
await p.click('#wzNext'); await p.waitForTimeout(250);
console.log('  tipsiz ilerle :', (await p.locator('#wzMsg').innerText()).trim());

await p.click('[data-key="delegate"]'); await p.waitForTimeout(250);
await p.click('#wzNext'); await p.waitForTimeout(300);
console.log('2 adim          :', await stepLabel(), '|', await stepNo());

// --- adim 2: parkur
console.log('  dis kayit notu:', await p.locator('.pick .ext').innerText());
await p.click('[data-key="main"]'); await p.waitForTimeout(200);
await p.click('[data-key="site"]'); await p.waitForTimeout(200);
await p.click('#wzNext'); await p.waitForTimeout(300);
console.log('3 adim          :', await stepLabel(), '|', await stepNo());

// --- adim 3: kisisel bilgiler
await p.fill('#fnm','Ayşe'); await p.fill('#lnm','Yılmaz'); await p.fill('#phn','+90 555 111 22 33');
await p.fill('#pss','A1234567'); await p.fill('#dob','16021981');
await p.selectOption('#cty','Türkiye'); await p.fill('#inst','Örnek Kurum');
await p.selectOption('#rk','__other__'); await p.fill('#rkOther','Uzman');
await p.fill('#duty','Şube Müdürü'); await p.selectOption('#role','Delegate');
await p.click('#wzNext'); await p.waitForTimeout(300);
console.log('4 adim          :', await stepLabel(), '|', await stepNo());

// --- adim 4: zorunlu onaya HAYIR -> engellenmeli
await p.check('input[name="c_participant_list"][value="no"]');
await p.check('input[name="c_media"][value="yes"]');
await p.click('#wzNext'); await p.waitForTimeout(250);
console.log('  zorunlu onaya hayir:', (await p.locator('#wzMsg').innerText()).trim().slice(0,60)+'…');
await p.check('input[name="c_participant_list"][value="yes"]');
await p.click('#wzNext'); await p.waitForTimeout(300);
console.log('5 adim          :', await stepLabel(), '|', await stepNo());

// --- adim 5: ozet
const rev = (await p.locator('.rev').allInnerTexts()).join(' | ').replace(/\s+/g,' ');
console.log('  ozet          :', rev.slice(0,220)+'…');
console.log('  pasaport maskeli mi:', rev.includes('********'));
await p.screenshot({path:'/var/tmp/wiz-review.png', fullPage:true});

// --- bolum bazli duzenle
await p.locator('.rev .h a').first().click(); await p.waitForTimeout(300);
console.log('  duzenle -> adim:', await stepLabel());
await p.click('#wzNext'); await p.waitForTimeout(250);
await p.click('#wzNext'); await p.waitForTimeout(250);
await p.click('#wzNext'); await p.waitForTimeout(250);
await p.click('#wzNext'); await p.waitForTimeout(250);
console.log('  geri donus    :', await stepLabel());

// --- gonder
await p.click('#wzNext'); await p.waitForTimeout(900);
const done=(await p.locator('.state').innerText()).replace(/\s+/g,' ');
console.log('sonuc ekrani    :', done.slice(0,150)+'…');
console.log('  onay kodu     :', await p.locator('.code').innerText());
await p.screenshot({path:'/var/tmp/wiz-done.png', fullPage:true});

const w=await p.evaluate(()=>window.__WRITES);
const reg=w.find(x=>x.table==='conventus_registrations');
const trk=w.find(x=>x.table==='conventus_registration_tracks');
const con=w.find(x=>x.table==='conventus_registration_consents');
console.log('yazilan kayit   :', JSON.stringify({reg_type:reg.rows.reg_type, reg_type_other:reg.rows.reg_type_other,
  status:reg.rows.status, rank:reg.rows.rank_title, dob:reg.rows.dob}));
console.log('yazilan parkur  :', JSON.stringify(trk.rows));
console.log('yazilan onay    :', JSON.stringify(con.rows));
console.log('sayfa hatalari  :', errs.length?errs:'yok');
await b.close();
process.exit(errs.length?1:0);
