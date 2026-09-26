/* register-conventus.html — protokol referansi OKUNAMADIGINDA ne oluyor?
   Beklenen (Secenek C): gomulu yedek listeye SESSIZCE dusmek YOK.
   Serbest metin + gorunur uyari + answers.ref_degraded isareti.
   Kullanim: npx http-server -p 8099 -s .  &&  node scripts/test-register-ref-degraded.mjs */
import { chromium } from 'playwright';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const ctx = await b.newContext({ viewport:{ width:760, height:1000 } });
const p = await ctx.newPage();
const errs=[]; let sawRefWarn=false;
p.on('pageerror', e=>errs.push('pageerror: '+e.message));
p.on('console', m=>{ if(/protokol referansi okunamadi/.test(m.text())) sawRefWarn=true; });
// '[register] protokol referansi okunamadi' BEKLENEN uyaridir — testin
// dogrulamak istedigi sey zaten bu (sessiz dusme yok). Gurultu sayilmaz.
p.on('console', m=>{ if(m.type()==='error'
  && !/ERR_CERT|fonts\.g|jsdelivr|unpkg/.test(m.text())
  && !/protokol referansi okunamadi/.test(m.text())) errs.push('console: '+m.text()); });

await p.route('**/assets/js/cv-config.js', r=>r.fulfill({contentType:'application/javascript',
  body:"window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='k';window.__CV_CONFIG_READY=true;"}));
await p.route('**/supabase-js@2**', r=>r.fulfill({contentType:'application/javascript', body:`
window.__WRITES=[];
const EV_FIXTURE={id:7,code:'LANDCOM-CONF-2026',title:'LANDCOM Konferansı 2026',start_date:'2026-11-17',
  end_date:'2026-11-19',location:'Belirlenecek',host_org:'LANDCOM',description:'Test',
  published:true,registration_open:true,registration_field_defs:[],protocol_enabled:true};
const TYPES=[{id:1,key:'delegate',label:'Katılımcı',note:'Konferansa katılacaksanız seçin.',allow_other:false,sort:1},
             {id:2,key:'other',label:'Diğer',note:'Uymuyorsa açıklayın.',allow_other:true,sort:9}];
const TRACKS=[{id:11,key:'main',title:'Ana program',starts_on:'2026-11-17',ends_on:'2026-11-19',time_from:'09:00',time_to:'17:00',sort:1},
              {id:12,key:'site',title:'Saha ziyareti',starts_on:'2026-11-18',ends_on:'2026-11-18',capacity:20,external_note:'Ayrı kayıt gerekir.',sort:2}];
const CONSENTS=[{id:21,key:'participant_list',version:1,body:'Katılımcı listesinde paylaşılmasına onay veriyorum.',is_required:true,sort:1},
                {id:22,key:'media',version:2,body:'Görüntü yayımına onay veriyorum.',is_required:false,sort:2}];
const NATIONS=[{code_mil:'TUR',name_en:'Turkey',name_tr:'Türkiye',bloc:'nato'},
               {code_mil:'USA',name_en:'United States',name_tr:'Amerika Birleşik Devletleri',bloc:'nato'},
               {code_mil:'FIN',name_en:'Finland',name_tr:'Finlandiya',bloc:'nato'}];
const RANKS=[{id:101,grade_code:'OF-5',service:'A',name_en:'Colonel',acronym:'COL',sort:50},
             {id:102,grade_code:'OF-9',service:'A',name_en:'General',acronym:'GEN',sort:10},
             {id:201,grade_code:'OF-5',service:'N',name_en:'Captain',acronym:'CAPT',sort:50}];
const GRADES=[{code:'OF-9',ordinal:700,civ_equiv:null},{code:'OF-5',ordinal:400,civ_equiv:'A5'},
              {code:'OR-6',ordinal:110,civ_equiv:'B2'},{code:'OR-5',ordinal:100,civ_equiv:'B2'}];
// REF_FAIL=true ise referans okumalari hata doner -> serbest metne dusmeli
window.__REF_FAIL = /reffail/.test(location.search);
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
      if(/^conventity_ref_/.test(table)){
        if(window.__REF_FAIL) return Promise.resolve({data:null,error:{message:'permission denied'}}).then(res);
        if(table==='conventity_ref_nation')     data=NATIONS;
        if(table==='conventity_ref_rank')       data=RANKS;
        if(table==='conventity_ref_nato_grade') data=GRADES;
      }
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

await p.goto('http://localhost:8099/platforms/conventus/register-conventus.html?e=LANDCOM-CONF-2026&reffail=1',{waitUntil:'load'});
await p.waitForTimeout(1200);

let fail=0;
const bad=(m)=>{ console.log('  ✗ '+m); fail=1; };
const ok =(m)=>console.log('  ✓ '+m);

// kayit tipi + parkur adimlarini gec
await p.click('[data-key="delegate"]'); await p.waitForTimeout(200);
await p.click('#wzNext'); await p.waitForTimeout(250);
await p.click('[data-key="main"]');    await p.waitForTimeout(200);
await p.click('#wzNext'); await p.waitForTimeout(300);
console.log('kisisel bilgiler adimi:', (await p.locator('.wz-step b').innerText()).trim());

// 1) gorunur uyari VAR mi
const warn=(await p.locator('.msg.err').first().innerText().catch(()=>'')).trim();
warn.includes('yüklenemedi') ? ok('gorunur uyari cikiyor') : bad('uyari yok — sessiz dusme!');

// 2) alanlar serbest metne dusmus mu, gomulu listeye DEGIL
const ctyTag = await p.locator('#cty').evaluate(e=>e.tagName);
const rkTag  = await p.locator('#rk').evaluate(e=>e.tagName);
ctyTag==='INPUT' ? ok('ulus serbest metin') : bad('ulus hala SELECT ('+ctyTag+') — gomulu listeye dusmus olabilir');
rkTag ==='INPUT' ? ok('rutbe serbest metin') : bad('rutbe hala SELECT ('+rkTag+') — gomulu listeye dusmus olabilir');
(await p.locator('#svc').count())===0 ? ok('kuvvet secimi gizli') : bad('kuvvet secimi hala var');

// 3) form YINE DE gonderilebiliyor mu (erisilebilirlik korunuyor)
await p.fill('#fnm','Ayşe'); await p.fill('#lnm','Yılmaz'); await p.fill('#phn','+90 555 111 22 33');
await p.fill('#pss','A1234567'); await p.fill('#dob','16021981');
await p.fill('#cty','Türkiye'); await p.fill('#inst','Örnek Kurum');
await p.fill('#rk','Albay'); await p.fill('#duty','Şube Müdürü');
await p.selectOption('#role','Delegate');
await p.click('#wzNext'); await p.waitForTimeout(300);
await p.check('input[name="c_participant_list"][value="yes"]');
await p.check('input[name="c_media"][value="yes"]');
await p.click('#wzNext'); await p.waitForTimeout(300);
console.log('ozet adimi            :', (await p.locator('.wz-step b').innerText()).trim());
await p.click('#wzNext'); await p.waitForTimeout(900);

const w=await p.evaluate(()=>window.__WRITES);
const reg=(w.find(x=>x.table==='conventus_registrations')||{}).rows;
if(!reg){ bad('kayit hic yazilmadi — form olmus'); }
else{
  ok('kayit yazildi (form olmedi)');
  console.log('  yazilan:', JSON.stringify({country:reg.country, nation_code:reg.nation_code,
    rank_title:reg.rank_title, rank_id:reg.rank_id, grade_code:reg.grade_code,
    ref_degraded:(reg.answers||{}).ref_degraded}));
  // 4) EN ONEMLISI: satir isaretli mi — organizator bulabilsin
  (reg.answers||{}).ref_degraded===true ? ok('satir ref_degraded ile isaretli')
                                        : bad('isaret yok — sessiz sapma!');
  reg.rank_title==='Albay' ? ok('serbest metin rank_title\'a yazildi') : bad('rank_title: '+reg.rank_title);
  reg.rank_id==null   ? ok('rank_id bos (uydurulmadi)')    : bad('rank_id uydurulmus: '+reg.rank_id);
  reg.nation_code==null ? ok('nation_code bos (uydurulmadi)') : bad('nation_code uydurulmus: '+reg.nation_code);
}

sawRefWarn ? ok('konsola teshis yazildi') : bad('konsola teshis yazilmadi');
console.log('sayfa hatalari        :', errs.length?errs.join(' / '):'yok');
if(errs.length) fail=1;
await b.close();
console.log(fail ? '\nSONUC: BASARISIZ' : '\nSONUC: GECTI');
process.exit(fail);
