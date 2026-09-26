/* event-manage.html → "Protokol" sekmesi — davranış testi (sahte Supabase).
   Kapsam: ayar formu referanstan doluyor mu · kıyafet önizlemesi mevsime göre
   değişiyor mu · kayıt DOĞRUDAN UPDATE değil RPC ile gidiyor mu · sıralama
   view'den geliyor ve skora göre mi diziliyor.
   Kullanım: npx http-server -p 8099 -s .  &&  node scripts/test-event-protocol-tab.mjs */
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
  community_id:'c-1',published:true,registration_open:true,logistics:{},protocol_enabled:true};
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
function data(t){ return t==='conventus_event_reg_types'?TYPES:t==='conventus_event_tracks'?TRACKS:t==='conventus_event_consents'?CONS:
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

const tab = p.locator('.tab', {hasText:'Protokol'});
(await tab.count())===1 ? ok('Protokol sekmesi var') : bad('sekme yok');
await tab.click(); await p.waitForTimeout(700);

// --- 0) ana anahtar: kapatinca ayarlar ve sira gizlenmeli
await p.isChecked('#pr_on') ? ok('anahtar açık (etkinlikte protokol var)') : bad('anahtar kapalı geldi');
await p.uncheck('#pr_on'); await p.waitForTimeout(250);
await p.locator('#pr_body').isHidden() ? ok('kapatınca ayarlar gizleniyor') : bad('kapalıyken ayarlar görünüyor');
await p.check('#pr_on'); await p.waitForTimeout(250);
await p.locator('#pr_body').isVisible() ? ok('açınca ayarlar geri geliyor') : bad('açılmadı');

// --- 1) ayar formu referanstan doluyor mu
const listOpts = await p.locator('#pr_list option').allInnerTexts();
listOpts.length===2 ? ok('iki öncelik listesi geldi: '+listOpts.join(' / ')) : bad('öncelik listesi: '+JSON.stringify(listOpts));
const hostOpts = await p.locator('#pr_host option').count();
hostOpts===4 ? ok('ev sahibi ulus listesi (3 ulus + boş)') : bad('ulus seçenek sayısı: '+hostOpts);

// --- 2) kiyafet onizlemesi mevsime gore degisiyor mu (kaynak §3.1)
await p.selectOption('#pr_dress','mess_dress'); await p.waitForTimeout(200);
let prev=(await p.locator('#pr_dressPrev').innerText()).replace(/\s+/g,' ');
prev.includes('Black Tie — Dinner Jacket') ? ok('sivil karşılık gösteriliyor') : bad('sivil karşılık yok: '+prev);
!prev.includes('Mess Dress —') ? ok('mevsim seçilmeden askerî satır çıkmıyor') : bad('mevsimsiz askerî satır çıktı');
await p.selectOption('#pr_season','summer'); await p.waitForTimeout(200);
prev=(await p.locator('#pr_dressPrev').innerText()).replace(/\s+/g,' ');
prev.includes('yazlık') ? ok('yazlık üniforma gösteriliyor') : bad('yazlık gelmedi: '+prev);
await p.selectOption('#pr_season','winter'); await p.waitForTimeout(200);
prev=(await p.locator('#pr_dressPrev').innerText()).replace(/\s+/g,' ');
prev.includes('Mess Dress — Black Tie') ? ok('kışlık üniforma gösteriliyor') : bad('kışlık gelmedi: '+prev);
// ayrica: kademe degisince onizleme de degismeli
await p.selectOption('#pr_dress','service_a'); await p.waitForTimeout(200);
prev=(await p.locator('#pr_dressPrev').innerText()).replace(/\s+/g,' ');
prev.includes('ceket ve kravat') ? ok('kademe değişince önizleme güncelleniyor') : bad('kademe değişimi yansımadı: '+prev);
await p.selectOption('#pr_dress','mess_dress'); await p.waitForTimeout(200);

// --- 3) KAYIT: dogrudan update DEGIL, RPC
await p.selectOption('#pr_list','vip_civil');
await p.selectOption('#pr_host','TUR');
await p.click('#prSave'); await p.waitForTimeout(500);
const ops=await p.evaluate(()=>window.__OPS);
const rpc=ops.filter(o=>o.op==='rpc' && o.name==='conventus_set_event_protocol').pop();
const directUpd=ops.filter(o=>o.op==='update' && o.table==='conventus_managed_events');
rpc ? ok('RPC çağrıldı') : bad('RPC çağrılmadı');
directUpd.length===0 ? ok('doğrudan UPDATE yok (sessiz 0-satır tuzağı kapalı)') : bad('doğrudan UPDATE yapılmış');
if(rpc){
  console.log('  gönderilen:', JSON.stringify(rpc.args));
  rpc.args.p_precedence_list==='vip_civil' ? ok('öncelik listesi gönderildi') : bad('liste: '+rpc.args.p_precedence_list);
  rpc.args.p_host_nation==='TUR'           ? ok('ev sahibi ulus gönderildi')   : bad('ulus: '+rpc.args.p_host_nation);
  rpc.args.p_dress_season==='winter'       ? ok('mevsim gönderildi')           : bad('mevsim: '+rpc.args.p_dress_season);
  rpc.args.p_activity_id==='a-1'           ? ok('activity_id gönderildi')      : bad('activity_id: '+rpc.args.p_activity_id);
  rpc.args.p_protocol_enabled===true       ? ok('ana anahtar gönderildi')      : bad('protocol_enabled: '+rpc.args.p_protocol_enabled);
}

// --- 4) SIRALAMA
const rows = p.locator('#prOrder table.grid tbody tr');
const n = await rows.count();
n===3 ? ok('3 satır listelendi') : bad('satır sayısı: '+n);
const names = await rows.locator('td:nth-child(2)').allInnerTexts();
const scores = (await rows.locator('td:nth-child(4)').allInnerTexts()).map(s=>parseInt(s,10));
console.log('  sıra      :', names.map(s=>s.replace(/\s+/g,' ').trim()).join('  →  '));
console.log('  skorlar   :', scores.join(' > '));
(scores[0]>=scores[1] && scores[1]>=scores[2]) ? ok('skora göre azalan sıralı') : bad('sıra bozuk: '+scores);
scores[0]===1100 ? ok('en üstte temsilci (1100) — temsil önceliği kazandı') : bad('en üst skor: '+scores[0]);

// rozetler
const t0=(await rows.nth(0).innerText()).replace(/\s+/g,' ');
// .st stili text-transform:uppercase uyguluyor; innerText donusmus metni verir
/onur konuğu/i.test(t0) ? ok('onur konuğu rozeti var') : bad('onur konuğu rozeti yok: '+t0);
const hostRow=(await rows.nth(1).innerText()).replace(/\s+/g,' ');
/ev sahib/i.test(hostRow) ? ok('ev sahibi rozeti var') : bad('ev sahibi rozeti yok: '+hostRow);

// temsil sutunu: temsil edilen (kendi sifati) bicimi
hostRow.includes('Genelkurmay Başkanı') ? ok('sıfat TR etiketiyle gösteriliyor') : bad('sıfat sütunu ham anahtar mı? '+hostRow);
!/national_rep|chief_of_defence/.test(await rows.allInnerTexts().then(a=>a.join(' ')))
  ? ok('hiçbir yerde ham sıfat anahtarı sızmıyor') : bad('ham anahtar sızıyor');
const repRow=(await rows.nth(0).innerText());
repRow.includes('Bakan (Ulusal Temsilci)') ? ok('temsil "temsil edilen (kendi)" olarak gösteriliyor') : bad('temsil gösterimi: '+repRow);

// kimlik dizesi
t0.includes('GEN "Doe" USA A') ? ok('kimlik dizesi (§2.1 biçimi) gösteriliyor') : bad('kimlik dizesi yok');

// --- 5) ORDER zinciri: sayfa V25 adim 5-7'yi kurdu mu
/* Zincir IKI kez kurulur: acilista bir, kaydetmeden sonra bir. Ikincisi kasitli
   — ev sahibi ulus degisince sira da degisir. Her gecisi ayri dogruluyoruz. */
const BEKLENEN=['precedence_score','date_of_rank','partner_bucket','nation_sort','last_name'];
const orders=(await p.evaluate(()=>window.__ORDERS)).filter(o=>o.table==='conventus_precedence_v').map(o=>o.col);
console.log('  order zinciri:', orders.join(' → '));
const gecis=[]; for(let i=0;i<orders.length;i+=BEKLENEN.length) gecis.push(orders.slice(i,i+BEKLENEN.length));
gecis.length===2 ? ok('sıra iki kez yüklendi (açılış + kayıt sonrası)') : bad('yükleme sayısı: '+gecis.length);
gecis.every(g=>JSON.stringify(g)===JSON.stringify(BEKLENEN))
  ? ok('V25 adım 5–7 sıralaması her geçişte eksiksiz') : bad('order zinciri beklenenden farklı');

await p.screenshot({path:'/var/tmp/proto-tab.png', fullPage:true});
console.log('sayfa hataları    :', errs.length?errs.join(' / '):'yok');
if(errs.length) fail=1;
await b.close();
console.log(fail ? '\nSONUÇ: BAŞARISIZ' : '\nSONUÇ: GEÇTİ');
process.exit(fail);
