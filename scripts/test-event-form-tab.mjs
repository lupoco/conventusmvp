/* event-manage.html → "Kayıt formu" sekmesi — davranış testi (sahte Supabase).
   Kullanım: npx http-server -p 8099 -s .  &&  node scripts/test-event-form-tab.mjs */
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
  community_id:'c-1',published:true,registration_open:true,logistics:{}};
let TYPES=[{id:1,event_id:7,key:'delegate',label:'Katılımcı',note:'Konferansa katılacaksanız.',allow_other:false,sort:1,is_active:true}];
let TRACKS=[];
let CONS=[{id:21,event_id:7,key:'participant_list',version:1,body:'Listede paylaşılmasına onay veriyorum.',is_required:true,sort:1,is_active:true}];
function data(t){ return t==='conventus_event_reg_types'?TYPES:t==='conventus_event_tracks'?TRACKS:t==='conventus_event_consents'?CONS:[]; }
function qb(table){
  const self={ _f:{},
    select(){return self;}, eq(c,v){ self._f[c]=v; return self;}, order(){return self;},
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
  rpc(n){ return Promise.resolve({data:true,error:null}); },
  auth:{ getSession(){return Promise.resolve({data:{session:{user:{id:'u1',email:'org@example.org'}}}});},
         signOut(){return Promise.resolve({});}, onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};} } };}};
`}));
await p.addInitScript(()=>{ try{localStorage.setItem('cv-lang','tr');}catch(e){} });
await p.goto('http://localhost:8099/platforms/conventus/event-manage.html?e=LANDCOM-CONF-2026',{waitUntil:'load'});
await p.waitForTimeout(1000);

const tab = p.locator('.tab', {hasText:'Kayıt formu'});
console.log('sekme var mi      :', await tab.count()===1);
await tab.click(); await p.waitForTimeout(600);
console.log('kart sayisi (3)   :', await p.locator('#tb .card').count());
console.log('bos parkur uyarisi:', (await p.locator('#tb .card').nth(1).locator('.empty').last().innerText()).trim());

// --- parkur ekle
await p.locator('[data-fmadd="tracks"]').click(); await p.waitForTimeout(300);
await p.fill('#fm_key','site'); await p.fill('#fm_title','Saha ziyareti');
await p.fill('#fm_from','18112026'); await p.fill('#fm_to','18112026');
await p.fill('#fm_tfrom','09:00'); await p.fill('#fm_tto','16:00'); await p.fill('#fm_cap','20');
await p.fill('#fm_ext','Ayrı kayıt gerekir.');
await p.click('#fmSave'); await p.waitForTimeout(600);
console.log('parkur eklendi    :', (await p.locator('#tb .card').nth(1).innerText()).replace(/\s+/g,' ').includes('Saha ziyareti'));
console.log('  tarih maskesi   :', (await p.locator('#tb .card').nth(1).innerText()).includes('18.11.2026'));

// --- gecersiz tarih reddedilmeli
await p.locator('[data-fmadd="tracks"]').click(); await p.waitForTimeout(300);
await p.fill('#fm_key','bad'); await p.fill('#fm_title','Hatali'); await p.fill('#fm_from','31022026');
await p.click('#fmSave'); await p.waitForTimeout(300);
console.log('gecersiz tarih    :', (await p.locator('#fmErr').innerText()).trim());
await p.click('#fmCancel'); await p.waitForTimeout(200);

// --- gecersiz anahtar
await p.locator('[data-fmadd="types"]').click(); await p.waitForTimeout(300);
await p.fill('#fm_key','Büyük Harf!'); await p.fill('#fm_label','X');
await p.click('#fmSave'); await p.waitForTimeout(300);
console.log('gecersiz anahtar  :', (await p.locator('#fmErr').innerText()).trim());
await p.click('#fmCancel'); await p.waitForTimeout(200);

// --- onay metnini degistir -> yeni surum acilmali
await p.locator('#tb .card').nth(2).locator('[data-fme]').first().click(); await p.waitForTimeout(300);
await p.fill('#fm_body','Listede paylasilmasina onay veriyorum. (guncellendi)');
await p.click('#fmSave'); await p.waitForTimeout(700);
const ops = await p.evaluate(()=>window.__OPS);
const consIns = ops.filter(o=>o.op==='insert'&&o.table==='conventus_event_consents');
const consUpd = ops.filter(o=>o.op==='update'&&o.table==='conventus_event_consents');
console.log('yeni surum acildi :', consIns.length===1 && consIns[0].row.version===2);
console.log('eski surum pasif  :', consUpd.length===1 && consUpd[0].patch.is_active===false);
console.log('  eski metin duruyor:', (await p.locator('#tb .card').nth(2).innerText()).includes('v1'));

await p.screenshot({path:'/var/tmp/form-tab.png', fullPage:true});
console.log('sayfa hatalari    :', errs.length?errs:'yok');
await b.close();
process.exit(errs.length?1:0);
