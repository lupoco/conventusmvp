import { chromium } from 'playwright';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const ctx = await b.newContext({ viewport: { width: 1400, height: 950 } });
const p = await ctx.newPage();
const errs = [];
p.on('pageerror', e => errs.push('pageerror: ' + e.message));
p.on('console', m => { if (m.type()==='error' && !/ERR_CERT|fonts\.g|jsdelivr|unpkg/.test(m.text())) errs.push('console: '+m.text()); });

// supabase-js CDN'i ve config'i sahte istemciyle degistir
await p.route('**/assets/js/cv-config.js', r => r.fulfill({ contentType:'application/javascript',
  body: "window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='k';window.__CV_CONFIG_READY=true;" }));
await p.route('**/supabase-js@2**', r => r.fulfill({ contentType:'application/javascript', body: `
window.__ACCESS_ROWS = [
 {id:'a1',created_at:'2026-09-22T10:15:00+00:00',full_name:'Ayşe Yılmaz',email:'ayse@example.org',org_name:'Örnek Kurum',purpose:'Conventus MVP ile ilgileniyorum.',lang:'tr',source:'coming_soon',status:'new',note:null,handled_at:null},
 {id:'a2',created_at:'2026-09-21T16:40:00+00:00',full_name:'John Carter',email:'john@example.com',org_name:null,purpose:null,lang:'en',source:'coming_soon',status:'contacted',note:'aradim',handled_at:'2026-09-21T18:00:00+00:00'},
 {id:'a3',created_at:'2026-09-20T09:00:00+00:00',full_name:'Spam Bot',email:'x@spam.test',org_name:null,purpose:null,lang:'en',source:'coming_soon',status:'spam',note:null,handled_at:null}
];
window.__UPDATES = [];
function qb(table){
  let filters={}; 
  const self={
    select(){return self;}, order(){return self;}, limit(){return self;},
    eq(c,v){filters[c]=v; return self;},
    update(patch){ self._patch=patch; return self; },
    insert(){return Promise.resolve({data:null,error:null});},
    delete(){return self;},
    then(res){
      if(self._patch){ window.__UPDATES.push({table,id:filters.id,patch:self._patch});
        return Promise.resolve({data:null,error:null}).then(res); }
      let rows = table==='conventity_access_requests' ? window.__ACCESS_ROWS.slice() : [];
      if(filters.status) rows = rows.filter(r=>r.status===filters.status);
      return Promise.resolve({data:rows,error:null}).then(res);
    }
  };
  return self;
}
window.supabase = { createClient(){ return {
  from:qb,
  rpc(n){ return Promise.resolve({data:true,error:null}); },
  auth:{ getSession(){return Promise.resolve({data:{session:{access_token:'t',user:{id:'u1',email:'admin@e.com'}}}});},
         signOut(){return Promise.resolve({});},
         onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};} }
};}};
`}));
await p.addInitScript(() => { try{localStorage.setItem('cv-lang','tr');}catch(e){} });
await p.goto('http://localhost:8099/core.html', { waitUntil:'load' });
await p.waitForTimeout(1500);

const tab = p.locator('.tab[data-k="access"]');
console.log('sekme var mi           :', await tab.count() === 1);
console.log('sekme etiketi          :', (await tab.innerText()).trim());
await tab.click(); await p.waitForTimeout(600);
console.log('baslik                 :', await p.locator('.ptitle').innerText());
console.log('sayac                  :', await p.locator('#arCount').innerText());
console.log('satir sayisi           :', await p.locator('#arList tbody tr').count());
console.log('ilk satir              :', (await p.locator('#arList tbody tr').first().innerText()).replace(/\s+/g,' ').trim());
await p.screenshot({ path:'/var/tmp/core-access.png' });

// filtre
await p.selectOption('#arFilter','new'); await p.waitForTimeout(400);
console.log('filtre=new -> satir    :', await p.locator('#arList tbody tr').count());
await p.selectOption('#arFilter',''); await p.waitForTimeout(400);

// detay cekmecesi + durum degistirme
await p.locator('#arList tbody tr').first().click(); await p.waitForTimeout(400);
console.log('cekmece acildi         :', await p.locator('#drawer.on').count() === 1);
console.log('cekmece basligi        :', await p.locator('#drawerTitle').innerText());
await p.selectOption('#f_arst','invited');
await p.fill('#f_arnote','davet gonderildi');
await p.screenshot({ path:'/var/tmp/core-access-drawer.png' });
await p.click('#dSave'); await p.waitForTimeout(500);
const ups = await p.evaluate(() => window.__UPDATES);
console.log('kaydedilen guncelleme  :', JSON.stringify(ups));
console.log('cekmece kapandi        :', await p.locator('#drawer.on').count() === 0);

// EN'e gec
await p.evaluate(()=>{document.querySelectorAll('#langPill button').forEach(b=>{if(b.getAttribute('data-lang')==='en')b.click();});});
await p.waitForTimeout(500);
console.log('EN sekme etiketi       :', (await p.locator('.tab[data-k="access"]').innerText()).trim());

await b.close();
console.log(errs.length ? 'HATA:\n'+errs.join('\n') : 'JS hatasi yok');
