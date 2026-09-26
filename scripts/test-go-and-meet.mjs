/* go-and-meet.html — etkinlik sayfası (sahte Supabase).
   Kapsam: liste modu · etkinlik modu · dört bölüm · kültür/eş ayrımı ·
   gm_services filtresi · rezervasyon → gm_plan · anon'da giriş daveti ·
   üç ekran genişliğinde responsive.
   Kullanım: npx http-server -p 8099 -s .  &&  node scripts/test-go-and-meet.mjs */
import { chromium } from 'playwright';
const b = await chromium.launch({ executablePath:'/opt/pw-browsers/chromium' });

const MOCK = (signedIn) => `
window.__OPS=[];
const EVENTS=[
 {id:7,code:'LANDCOM-CONF-2026',title:'LANDCOM Konferansı 2026',start_date:'2026-11-17',end_date:'2026-11-19',
  city:'İzmir',country:'Türkiye',host_org:'LANDCOM',description:'Kara kuvvetleri konferansı.',published:true,
  gm_services:['accommodation','transfer_car','culture_spouse']},
 {id:8,code:'SMOKE-MVP-26',title:'Smoke MVP 2026',start_date:'2026-05-04',end_date:'2026-05-05',
  city:'Ankara',country:'Türkiye',host_org:'Conventity',description:'Test.',published:true,
  gm_services:[]}
];
const INV=[
 {id:'i1',provider_id:'p1',category:'accommodation',title:'Hotel Kordon',description:'Konferans salonuna 5 dk.',
  details:{single:'€120',double:'€155',discount:'%22',promo:'LANDCOM26'},price_amount:120,currency:'EUR',
  date_from:'2026-11-16',date_to:'2026-11-20',capacity:40,provider_name:null},
 {id:'i2',provider_id:'p2',category:'transfer_car',title:'Havalimanı transferi',description:'ADB → otel.',
  details:{kind:'transfer'},price_amount:35,currency:'EUR',date_from:null,date_to:null,capacity:null},
 {id:'i3',provider_id:'p2',category:'transfer_car',title:'Araç kiralama — kompakt',description:'Günlük.',
  details:{kind:'car_rental'},price_amount:45,currency:'EUR',date_from:null,date_to:null,capacity:null},
 {id:'i4',provider_id:'p3',category:'culture_spouse',title:'Efes turu',description:'Tam gün.',
  details:{kind:'tour'},price_amount:60,currency:'EUR',date_from:'2026-11-18',date_to:'2026-11-18',capacity:25},
 {id:'i5',provider_id:'p3',category:'culture_spouse',title:'Eş programı — Alaçatı',description:'Refakatçiler için.',
  details:{kind:'spouse'},price_amount:55,currency:'EUR',date_from:'2026-11-18',date_to:'2026-11-18',capacity:15}
];
const PROVS=[{id:'p1',name:'Kordon Otelcilik',city:'İzmir'},{id:'p2',name:'Ege Transfer',city:'İzmir'},
             {id:'p3',name:'Anadolu Turizm',city:'İzmir'}];
/* p.reload() sahte modulu bastan calistirdigi icin PLAN sifirlaniyordu ve
   iki iddia da YANLIS SEBEPLE sonuc veriyordu. Tohumu localStorage'da tutuyoruz. */
let PLAN=[]; try{ PLAN=JSON.parse(localStorage.getItem('__seedPlan')||'[]'); }catch(_){}
window.__setPlan=(v)=>{ PLAN=v; try{ localStorage.setItem('__seedPlan',JSON.stringify(v)); }catch(_){} };
function qb(table){
  const self={_f:{},_del:false,
    select(){return self;}, eq(c,v){self._f[c]=v;return self;}, order(){return self;},
    maybeSingle(){ if(table==='conventus_managed_events'){
        const e=EVENTS.filter(x=>x.code===self._f.code)[0]||null;
        return Promise.resolve({data:e,error:null}); }
      return Promise.resolve({data:null,error:null}); },
    single(){ const row=Object.assign({id:'pl'+(PLAN.length+1)}, self._ins);
      PLAN.push(row); return Promise.resolve({data:row,error:null}); },
    insert(row){ window.__OPS.push({op:'insert',table,row}); self._ins=row; return self; },
    delete(){ self._del=true; return self; },
    then(res){
      if(self._del){ window.__OPS.push({op:'delete',table,id:self._f.id});
        PLAN=PLAN.filter(x=>x.id!==self._f.id);
        return Promise.resolve({data:null,error:null}).then(res); }
      let data=[];
      if(table==='conventus_managed_events') data=EVENTS.filter(x=>x.published);
      if(table==='gm_inventory')        data=INV;
      if(table==='gm_providers_public') data=PROVS;
      if(table==='gm_plan')             data=PLAN;
      return Promise.resolve({data,error:null}).then(res);
    }};
  return self;
}
window.supabase={createClient(){return{from:qb,rpc(){return Promise.resolve({data:null,error:null});},
  auth:{getSession(){return Promise.resolve({data:{session:${signedIn?"{user:{id:'u1',email:'a@b.c'}}":"null"}}});},
        onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};},signOut(){return Promise.resolve({});}}};}};
`;

async function page(signedIn){
  const ctx = await b.newContext({viewport:{width:1280,height:1100}});
  const p = await ctx.newPage();
  p.__errs=[];
  p.on('pageerror', e=>p.__errs.push('pageerror: '+e.message));
  p.on('console', m=>{ if(m.type()==='error' && !/ERR_CERT|fonts\.g|jsdelivr|unpkg|favicon/.test(m.text())) p.__errs.push('console: '+m.text()); });
  await p.route('**/assets/js/cv-config.js', r=>r.fulfill({contentType:'application/javascript',
    body:"window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='k';window.__CV_CONFIG_READY=true;"}));
  await p.route('**/supabase-js@2**', r=>r.fulfill({contentType:'application/javascript', body:MOCK(signedIn)}));
  await p.addInitScript(()=>{ try{localStorage.setItem('cv-lang','tr');}catch(e){} });
  return p;
}

let fail=0;
const bad=(m)=>{ console.log('  ✗ '+m); fail=1; };
const ok =(m)=>console.log('  ✓ '+m);
const BASE='http://localhost:8099/platforms/conventus/go-and-meet.html';

// ============ 1) LISTE MODU ============
console.log('\n== liste modu ==');
let p = await page(false);
await p.goto(BASE,{waitUntil:'load'}); await p.waitForTimeout(900);
const evCards = p.locator('.door');
(await evCards.count())===2 ? ok('iki etkinlik kartı') : bad('kart sayısı: '+await evCards.count());
const c0=(await evCards.nth(0).innerText()).replace(/\s+/g,' ');
c0.includes('LANDCOM') ? ok('etkinlik adı var') : bad('ad yok: '+c0);
c0.includes('17.11.2026') ? ok('tarih DD.MM.YYYY') : bad('tarih biçimi: '+c0);
c0.includes('İzmir') ? ok('yer var') : bad('yer yok');
if(p.__errs.length) bad('liste hataları: '+p.__errs.join(' / ')); else ok('sayfa hatası yok');

// ============ 2) ETKINLIK MODU — anon ============
console.log('\n== etkinlik modu · giriş yapılmamış ==');
await p.goto(BASE+'?e=LANDCOM-CONF-2026',{waitUntil:'load'}); await p.waitForTimeout(900);
const secs = p.locator('section.sec');
(await secs.count())===4 ? ok('dört bölüm (konaklama · ulaşım · tur · eş)') : bad('bölüm sayısı: '+await secs.count());
// kalemi olmayan bolum katilimciya CIZILMEMELI
const bosBolum = await p.locator('section.sec .cards').evaluateAll(els=>els.filter(e=>e.children.length===0).length);
bosBolum===0 ? ok('boş bölüm çizilmiyor') : bad(bosBolum+' boş bölüm çiziliyor');
const titles=(await p.locator('.sec-h h2').allInnerTexts()).map(s=>s.trim());
console.log('   bölümler:', titles.join(' | '));
// kultur / es ayrimi — ayni kategoriden geliyorlar, details.kind ile ayrilmali
const tur=(await p.locator('#tur').innerText()).replace(/\s+/g,' ');
const es =(await p.locator('#es').innerText()).replace(/\s+/g,' ');
(tur.includes('Efes turu') && !tur.includes('Alaçatı')) ? ok('kültür turu yalnız turu içeriyor') : bad('tur bölümü: '+tur);
(es.includes('Alaçatı')  && !es.includes('Efes'))       ? ok('eş programı yalnız eş kalemini içeriyor') : bad('eş bölümü: '+es);
const ulasim=(await p.locator('#ulasim').innerText()).replace(/\s+/g,' ');
(ulasim.includes('transferi')&&ulasim.includes('Araç kiralama')) ? ok('ulaşımda iki kalem birlikte') : bad('ulaşım: '+ulasim);
// fiyat + saglayici
const k=(await p.locator('#konaklama .door').first().innerText()).replace(/\s+/g,' ');
/€|EUR/.test(k) ? ok('fiyat biçimlenmiş') : bad('fiyat yok: '+k);
// .org'daki zengin icerik: tek/cift fiyat, indirim rozeti, promosyon kodu
k.includes('€120') && k.includes('€155') ? ok('tek/çift fiyat ayrı gösteriliyor') : bad('oda fiyatları yok: '+k);
/%22\s*indirim/i.test(k) ? ok('indirim rozeti var') : bad('indirim rozeti yok: '+k);
k.includes('LANDCOM26') ? ok('promosyon kodu gösteriliyor') : bad('promosyon kodu yok: '+k);
// ust cubuk etkinlik moduna gecince adi gostermeli
const crumb=(await p.locator('#crumb').innerText()).trim();
crumb.includes('LANDCOM') ? ok('üst çubukta etkinlik adı: '+crumb) : bad('üst çubuk güncellenmedi: '+crumb);
// eyebrow tek satirda kalmali (tireli kod bolunuyordu)
const ebLines = await p.locator('.eyebrow span').evaluate(el=>{
  const lh=parseFloat(getComputedStyle(el).lineHeight)||16;
  return Math.round(el.getBoundingClientRect().height/lh); });
ebLines<=1 ? ok('eyebrow tek satır') : bad('eyebrow '+ebLines+' satıra bölünüyor');
// .who text-transform:uppercase uyguluyor; innerText dönüşmüş metni verir
/kordon otelcilik/i.test(k) ? ok('sağlayıcı adı var') : bad('sağlayıcı yok: '+k);
// anon -> giris daveti, rezervasyon dugmesi YOK
(await p.locator('[data-book]').count())===0 ? ok('anon rezervasyon düğmesi görmüyor') : bad('anon rezervasyon düğmesi var');
(await p.locator('a[href*="/login.html"]').count())>0 ? ok('giriş daveti var') : bad('giriş daveti yok');
if(p.__errs.length) bad('hatalar: '+p.__errs.join(' / '));

// ============ 3) gm_services FILTRESI ============
console.log('\n== hizmeti kapalı etkinlik ==');
await p.goto(BASE+'?e=SMOKE-MVP-26',{waitUntil:'load'}); await p.waitForTimeout(800);
(await p.locator('section.sec').count())===0 ? ok('hiç bölüm çizilmedi') : bad('bölüm var');
(await p.locator('.empty').first().innerText()).includes('kapalı') ? ok('kapalı açıklaması gösteriliyor') : bad('açıklama yok');
await p.context().close();

// ============ 4) REZERVASYON — giris yapilmis ============
console.log('\n== rezervasyon ==');
p = await page(true);
await p.evaluate(()=>{ try{localStorage.removeItem('__seedPlan');}catch(_){}} ).catch(()=>{});
await p.goto(BASE+'?e=LANDCOM-CONF-2026',{waitUntil:'load'}); await p.waitForTimeout(900);
(await p.locator('[data-book]').count())===5 ? ok('beş kalemde rezervasyon düğmesi') : bad('düğme sayısı: '+await p.locator('[data-book]').count());
await p.locator('#konaklama [data-book]').first().click(); await p.waitForTimeout(700);
const ops=await p.evaluate(()=>window.__OPS);
const ins=ops.filter(o=>o.op==='insert'&&o.table==='gm_plan').pop();
ins ? ok('gm_plan satırı yazıldı') : bad('gm_plan yazılmadı');
if(ins){
  console.log('   yazılan:', JSON.stringify(ins.row));
  ins.row.status==='requested'   ? ok("status 'requested' (talep, onay değil)") : bad('status: '+ins.row.status);
  ins.row.category==='accommodation' ? ok('kategori doğru') : bad('kategori: '+ins.row.category);
  ins.row.inventory_id==='i1'    ? ok('envanter bağlandı') : bad('inventory_id: '+ins.row.inventory_id);
  ins.row.event_id===7           ? ok('etkinlik bağlandı') : bad('event_id: '+ins.row.event_id);
}
const body=(await p.locator('#konaklama').innerText()).replace(/\s+/g,' ');
/talep edildi/i.test(body) ? ok('kart "talep edildi" durumuna geçti') : bad('durum güncellenmedi: '+body);
(await p.locator('[data-cancel]').count())>0 ? ok('geri alma düğmesi çıktı') : bad('geri alma yok');
// geri al
await p.locator('[data-cancel]').first().click(); await p.waitForTimeout(700);
const ops2=await p.evaluate(()=>window.__OPS);
ops2.some(o=>o.op==='delete'&&o.table==='gm_plan') ? ok('geri alma gm_plan satırını sildi') : bad('silme olmadı');
(await p.locator('#konaklama [data-book]').count())>0 ? ok('rezervasyon düğmesi geri geldi') : bad('düğme dönmedi');

// ---- ONAYLANMIS TALEP: katilimci geri alamamali (silme politikasi da izin vermiyor)
await p.evaluate(()=>{ window.__setPlan([{id:'plx',event_id:7,user_id:'u1',category:'accommodation',
  inventory_id:'i1',status:'confirmed'}]); });
await p.reload({waitUntil:'load'}); await p.waitForTimeout(900);
const kk=(await p.locator('#konaklama .door').first().innerText()).replace(/\s+/g,' ');
/onaylandı/i.test(kk) ? ok('onaylandı durumu gösteriliyor') : bad('durum yok: '+kk);
(await p.locator('#konaklama [data-cancel]').count())===0 ? ok('onaylanmışta geri alma düğmesi yok') : bad('geri alma düğmesi var');
(await p.locator('#konaklama [data-book]').count())===0 ? ok('yeniden talep düğmesi de yok') : bad('yeniden talep düğmesi var');

// ---- IPTAL EDILMIS TALEP: yok sayilmali, yeniden talep edilebilmeli
await p.evaluate(()=>{ window.__setPlan([{id:'ply',event_id:7,user_id:'u1',category:'accommodation',
  inventory_id:'i1',status:'cancelled'}]); });
await p.reload({waitUntil:'load'}); await p.waitForTimeout(900);
(await p.locator('#konaklama [data-book]').count())>0 ? ok('iptal sonrası yeniden talep edilebiliyor') : bad('iptal edilmiş talep hâlâ engelliyor');
if(p.__errs.length) bad('hatalar: '+p.__errs.join(' / '));

// ============ 5) RESPONSIVE ============
console.log('\n== responsive ==');
for(const [w,h,ad,bekEn] of [[360,800,'telefon',1],[768,1000,'tablet',2],[1440,1000,'masaüstü',3]]){
  await p.setViewportSize({width:w,height:h}); await p.waitForTimeout(400);
  const grid = p.locator('#konaklama .cards');
  const cols = await grid.evaluate(el=>getComputedStyle(el).gridTemplateColumns.split(' ').length);
  const sw = await p.evaluate(()=>document.documentElement.scrollWidth);
  const cw = await p.evaluate(()=>document.documentElement.clientWidth);
  const tasma = sw > cw+1;
  console.log(`   ${ad} ${w}px → ${cols} sütun, yatay taşma: ${tasma?'VAR':'yok'}`);
  cols===bekEn ? ok(ad+': '+bekEn+' sütun') : bad(ad+': '+cols+' sütun (beklenen '+bekEn+')');
  !tasma ? ok(ad+': yatay kaydırma yok') : bad(ad+': YATAY TAŞMA — '+sw+' > '+cw);
}
// Ekran goruntusu dongunun SONRASINDA alinirsa son genislikte cikar — mobili
// gormek icin viewport'u acikca geri kucultuyoruz.
await p.setViewportSize({width:360,height:800}); await p.waitForTimeout(400);
await p.screenshot({path:'/var/tmp/gm-mobil.png', fullPage:true});
await p.setViewportSize({width:1280,height:1100}); await p.waitForTimeout(400);
await p.screenshot({path:'/var/tmp/gm-masaustu.png', fullPage:true});

await b.close();
console.log(fail ? '\nSONUÇ: BAŞARISIZ' : '\nSONUÇ: GEÇTİ');
process.exit(fail);
