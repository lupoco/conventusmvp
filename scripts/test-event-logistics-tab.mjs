/* event-manage.html → "Lojistik envanteri" sekmesi (sahte Supabase).
   Kapsam: dört kategori · kültür/eş ayrımı · saglayici ZORUNLU DEGIL ·
   tek/cift fiyat ve promosyon yalniz konaklamada · kapali hizmet uyarisi ·
   gm_inventory'ye yazma.
   Kullanım: npx http-server -p 8099 -s .  &&  node scripts/test-event-logistics-tab.mjs */
import { chromium } from 'playwright';
const b = await chromium.launch({ executablePath:'/opt/pw-browsers/chromium' });
const p = await (await b.newContext({viewport:{width:1280,height:1000}})).newPage();
const errs=[];
p.on('pageerror', e=>errs.push('pageerror: '+e.message));
p.on('console', m=>{ if(m.type()==='error' && !/ERR_CERT|fonts\.g|jsdelivr|unpkg/.test(m.text())) errs.push('console: '+m.text()); });
p.on('dialog', d=>d.accept());

await p.route('**/assets/js/cv-config.js', r=>r.fulfill({contentType:'application/javascript',
  body:"window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='k';"}));
await p.route('**/supabase-js@2**', r=>r.fulfill({contentType:'application/javascript', body:`
window.__OPS=[];
const EV={id:7,code:'LANDCOM-CONF-2026',title:'LANDCOM Konferansı 2026',activity_id:'a-1',
  community_id:'c-1',published:true,registration_open:true,logistics:{},protocol_enabled:true,gm_services:['accommodation','culture_spouse']};
let TYPES=[{id:1,event_id:7,key:'delegate',label:'Katılımcı',note:'Konferansa katılacaksanız.',allow_other:false,sort:1,is_active:true}];
let TRACKS=[];
let CONS=[{id:21,event_id:7,key:'participant_list',version:1,body:'Listede paylaşılmasına onay veriyorum.',is_required:true,sort:1,is_active:true}];
const NATIONS=[{code_mil:'TUR',name_en:'Turkey',name_tr:'Türkiye'},
               {code_mil:'USA',name_en:'United States',name_tr:'Amerika Birleşik Devletleri'},
               {code_mil:'DEU',name_en:'Germany',name_tr:'Almanya'}];
const PLISTS=[{key:'nato_internal',label_en:'NATO internal order of precedence',label_tr:'NATO iç öncelik sırası'},
              {key:'vip_civil',label_en:'Precedence list for events with military VIPs',label_tr:'Askerî VIP listesi'}];
const DRESS=[{key:'mess_dress',ordinal:1,label_en:'Mess Dress',label_tr:'Mess Dress',
              winter_uniform:'Mess Dress — Black Tie',summer_uniform:'Mess Dress (yazlık) — Black Tie',
              civilian:'Black Tie — Dinner Jacket',note:'En resmi üniforma'},
             {key:'service_a',ordinal:3,label_en:'Service Dress (A)',label_tr:'Service Dress (A)',
              winter_uniform:'Service Dress — ceket ve kravat',summer_uniform:'Service Dress — hafif',
              civilian:'Informal — Lounge Suit',note:null}];
// conventus_precedence_v BILEREK karisik sirada: sayfa order() cagirsa bile
// mock siralamiyor, bu yuzden ekranda skora gore dizilmis gorunmeliler ancak
// sayfa dogru order zincirini kurmussa. Mock order'i kaydediyor.
const PREC=[
  {registration_id:3,event_id:7,first_name:'Cem',last_name:'Arslan',nation_code:'DEU',grade_code:'OF-5',
   capacity_key:'national_rep',represents_capacity_key:null,date_of_rank:'2019-03-01',is_guest_of_honour:false,
   precedence_score:400,identity_string:'COL "Arslan" DEU A',nation_sort:'Germany',is_host_nation:false,partner_bucket:0},
  {registration_id:1,event_id:7,first_name:'Ayşe',last_name:'Yılmaz',nation_code:'TUR',grade_code:'OF-5',
   capacity_key:'chief_of_defence',represents_capacity_key:null,date_of_rank:'2021-06-15',is_guest_of_honour:false,
   precedence_score:1050,identity_string:'COL "Yılmaz" TUR A',nation_sort:'Turkey',is_host_nation:true,partner_bucket:0},
  {registration_id:2,event_id:7,first_name:'John',last_name:'Doe',nation_code:'USA',grade_code:'OF-9',
   capacity_key:'national_rep',represents_capacity_key:'minister',date_of_rank:'2020-01-10',is_guest_of_honour:true,
   precedence_score:1100,identity_string:'GEN "Doe" USA A',nation_sort:'United States',is_host_nation:false,partner_bucket:0}
];
const CAPS=[{key:'national_rep',label_en:'National Representative',label_tr:'Ulusal Temsilci'},
            {key:'chief_of_defence',label_en:'Chief of Defence',label_tr:'Genelkurmay Başkanı'},
            {key:'minister',label_en:'Minister',label_tr:'Bakan'}];
window.__ORDERS=[];
let INV=[{id:'v1',event_id:7,category:'accommodation',title:'Hotel Kordon',provider_name:'Kordon Otelcilik',
  description:'5 dk.',price_amount:120,currency:'EUR',date_from:'2026-11-16',date_to:'2026-11-20',capacity:40,
  details:{single:'€120',double:'€155',discount:'%22',promo:'LANDCOM26'},is_active:true},
 {id:'v2',event_id:7,category:'culture_spouse',title:'Efes turu',provider_name:'Anadolu',
  details:{kind:'tour'},price_amount:60,currency:'EUR',is_active:true},
 {id:'v3',event_id:7,category:'culture_spouse',title:'Alaçatı',provider_name:'Anadolu',
  details:{kind:'spouse'},price_amount:55,currency:'EUR',is_active:true}];
function data(t){ return t==='gm_inventory'?INV:t==='conventus_event_reg_types'?TYPES:t==='conventus_event_tracks'?TRACKS:t==='conventus_event_consents'?CONS:
  t==='conventity_ref_nation'?NATIONS:t==='conventity_ref_precedence_list'?PLISTS:t==='conventity_ref_dress_code'?DRESS:t==='conventity_ref_capacity'?CAPS:
  t==='conventus_precedence_v'?PREC.slice().sort((a,b)=>b.precedence_score-a.precedence_score):[]; }
function qb(table){
  const self={ _f:{},
    select(){return self;}, eq(c,v){ self._f[c]=v; return self;},
    order(c,o){ window.__ORDERS.push({table,col:c,opt:o||null}); return self;},
    maybeSingle(){ if(table==='conventus_managed_events') return Promise.resolve({data:EV,error:null});
                   if(table==='conventus_communities') return Promise.resolve({data:{name:'LANDCOM',short_name:'LANDCOM'},error:null});
                   return Promise.resolve({data:null,error:null}); },
    insert(row){ window.__OPS.push({op:'insert',table,row});
      const arr=data(table); const r=Object.assign({id:Math.floor(Math.random()*1e6)},row); arr.push(r);
      return Promise.resolve({data:[r],error:null}); },
    update(patch){ self._patch=patch; return self; },
    delete(){ self._del=true; return self; },
    then(res){
      if(self._patch){ window.__OPS.push({op:'update',table,id:self._f.id,patch:self._patch});
        const arr=data(table); const r=arr.filter(x=>String(x.id)===String(self._f.id))[0];
        if(r) Object.assign(r,self._patch);
        return Promise.resolve({data:null,error:null}).then(res); }
      if(self._del){ window.__OPS.push({op:'delete',table,id:self._f.id});
        const arr=data(table); const i=arr.findIndex(x=>String(x.id)===String(self._f.id));
        if(i>=0) arr.splice(i,1);
        return Promise.resolve({data:null,error:null}).then(res); }
      return Promise.resolve({data:data(table).slice(),error:null}).then(res);
    }
  };
  return self;
}
window.supabase={createClient(){return{ from:qb,
  rpc(n,a){ window.__OPS.push({op:'rpc',name:n,args:a}); return Promise.resolve({data:true,error:null}); },
  auth:{ getSession(){return Promise.resolve({data:{session:{user:{id:'u1',email:'org@example.org'}}}});},
         signOut(){return Promise.resolve({});}, onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};} } };}};
`}));
await p.addInitScript(()=>{ try{localStorage.setItem('cv-lang','tr');}catch(e){} });
await p.goto('http://localhost:8099/platforms/conventus/event-manage.html?e=LANDCOM-CONF-2026',{waitUntil:'load'});
await p.waitForTimeout(1000);

let fail=0;
const bad=(m)=>{ console.log('  ✗ '+m); fail=1; };
const ok =(m)=>console.log('  ✓ '+m);

const tab = p.locator('.tab[data-tab="logi"]');
(await tab.count())===1 ? ok('Go & Meet envanteri sekmesi var') : bad('sekme yok');
// "Lojistik" gecen iki sekme olmamali — kullanici karistirmasin
const lojik=(await p.locator('.tab').allInnerTexts()).filter(t=>/lojistik/i.test(t));
lojik.length<=1 ? ok('sekme adları çakışmıyor') : bad('iki sekme birden "Lojistik": '+lojik.join(' / '));
await tab.click(); await p.waitForTimeout(700);

// --- dort kategori cipi, sayilariyla
const chips=(await p.locator('[data-lc]').allInnerTexts()).map(s=>s.replace(/\s+/g,' ').trim());
console.log('   kategoriler:', chips.join(' | '));
chips.length===4 ? ok('dört kategori') : bad('kategori sayısı: '+chips.length);
chips[0].includes('· 1') ? ok('konaklama sayacı 1') : bad('konaklama sayacı: '+chips[0]);
// kultur/es ayrimi: ayni kategoriden geliyorlar, details.kind ile ayrilmali
chips[2].includes('· 1') && chips[3].includes('· 1') ? ok('kültür ve eş ayrı sayılıyor') : bad('ayrım yok: '+chips[2]+' / '+chips[3]);

// --- kapali hizmet uyarisi (transfer_car gm_services'te YOK)
await p.locator('[data-lc="car"]').click(); await p.waitForTimeout(300);
(await p.locator('#tb .msg.err').count())>0 ? ok('kapalı kategori uyarısı çıkıyor') : bad('kapalı uyarısı yok');
await p.locator('[data-lc="acc"]').click(); await p.waitForTimeout(300);
(await p.locator('#tb .msg.err').count())===0 ? ok('açık kategoride uyarı yok') : bad('açık kategoride uyarı var');

// --- form: konaklamada oda fiyati var, turda YOK
await p.locator('#lgAdd').click(); await p.waitForTimeout(300);
(await p.locator('#lg_single').count())===1 ? ok('konaklamada tek/çift fiyat alanı var') : bad('oda fiyatı alanı yok');
(await p.locator('#lg_prov').count())===1 ? ok('sağlayıcı adı serbest metin') : bad('sağlayıcı alanı yok');
await p.locator('#lgCancelBtn').click(); await p.waitForTimeout(250);
await p.locator('[data-lc="tour"]').click(); await p.waitForTimeout(300);
await p.locator('#lgAdd').click(); await p.waitForTimeout(300);
(await p.locator('#lg_single').count())===0 ? ok('turda oda fiyatı alanı çıkmıyor') : bad('turda oda fiyatı var');

// --- yazma: saglayici kaydi OLMADAN kalem eklenebilmeli
await p.fill('#lg_title2','Bergama turu');
await p.fill('#lg_prov','Anadolu Turizm');
await p.fill('#lg_price','75');
await p.fill('#lg_from','19112026');
await p.fill('#lg_cap','20');
await p.locator('#lgSaveBtn').click(); await p.waitForTimeout(700);
const ops=await p.evaluate(()=>window.__OPS);
const ins=ops.filter(o=>o.op==='insert'&&o.table==='gm_inventory').pop();
ins ? ok('gm_inventory satırı yazıldı') : bad('yazılmadı');
if(ins){
  console.log('   yazılan:', JSON.stringify(ins.row));
  ins.row.provider_id===undefined ? ok('provider_id GÖNDERİLMİYOR (sağlayıcı kaydı gerekmiyor)') : bad('provider_id gönderilmiş');
  ins.row.provider_name==='Anadolu Turizm' ? ok('sağlayıcı adı metin olarak gitti') : bad('provider_name: '+ins.row.provider_name);
  ins.row.category==='culture_spouse' ? ok('kategori doğru') : bad('kategori: '+ins.row.category);
  ins.row.details && ins.row.details.kind==='tour' ? ok("details.kind='tour' (eş programından ayrılıyor)") : bad('details: '+JSON.stringify(ins.row.details));
  ins.row.date_from==='2026-11-19' ? ok('tarih ISO’ya çevrildi') : bad('date_from: '+ins.row.date_from);
  ins.row.event_id===7 ? ok('etkinlik bağlandı') : bad('event_id: '+ins.row.event_id);
  // bos alanlar details'e yazilmamali
  !('single' in (ins.row.details||{})) ? ok('boş oda fiyatı details’e yazılmadı') : bad('boş alan details’e yazılmış');
}
await p.screenshot({path:'/var/tmp/logi-tab.png', fullPage:true});
console.log('sayfa hataları:', errs.length?errs.join(' / '):'yok');
if(errs.length) fail=1;
await b.close();
console.log(fail ? '\nSONUÇ: BAŞARISIZ' : '\nSONUÇ: GEÇTİ');
process.exit(fail);
