/* core.html "Bekleyen kayıtlar" sekmesi — sahte RPC ile davranis testi.
   Gercek Supabase'e baglanmaz: supabase-js CDN'i ve cv-config.js sahteyle
   degistirilir, conventity_pending_members / conventity_approve_member
   cagrilari yakalanir.
   Kullanim:  npx http-server -p 8099 -s .   &&   node scripts/test-core-pending-panel.mjs
*/
import { chromium } from 'playwright';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const ctx = await b.newContext({ viewport: { width: 1400, height: 950 } });
const p = await ctx.newPage();
const errs = [];
p.on('pageerror', e => errs.push('pageerror: ' + e.message));
p.on('console', m => { if (m.type()==='error' && !/ERR_CERT|fonts\.g|jsdelivr|unpkg/.test(m.text())) errs.push('console: '+m.text()); });

await p.route('**/assets/js/cv-config.js', r => r.fulfill({ contentType:'application/javascript',
  body: "window.__CV_SUPABASE_URL='http://localhost:8098';window.__CV_ANON_KEY='k';window.__CV_CONFIG_READY=true;" }));
await p.route('**/supabase-js@2**', r => r.fulfill({ contentType:'application/javascript', body: `
window.__PENDING = [
 {auth_user_id:'b0000000-0000-0000-0000-000000000002',email:'ayse@example.org',created_at:'2026-09-23T08:15:00+00:00',
  email_confirmed:true,last_sign_in_at:null,full_name:'Ayşe Yılmaz',org_name:'Örnek Kurum',country:'TR',account_type:'corporate'},
 {auth_user_id:'c0000000-0000-0000-0000-000000000003',email:'mehmet@example.org',created_at:'2026-09-23T09:40:00+00:00',
  email_confirmed:false,last_sign_in_at:null,full_name:'mehmet',org_name:null,country:'NL',account_type:'personal'}
];
window.__RPC = [];
function qb(){ const self={ select(){return self;}, order(){return self;}, limit(){return self;}, eq(){return self;},
  then(res){ return Promise.resolve({data:[],error:null}).then(res); } }; return self; }
window.supabase = { createClient(){ return {
  from:qb,
  rpc(name,args){
    window.__RPC.push({name,args});
    if(name==='conventity_pending_members') return Promise.resolve({data:window.__PENDING.slice(),error:null});
    if(name==='conventity_approve_member'){
      window.__PENDING = window.__PENDING.filter(r=>r.auth_user_id!==args.p_uid);
      return Promise.resolve({data:'onaylandi',error:null});
    }
    return Promise.resolve({data:true,error:null});
  },
  auth:{ getSession(){return Promise.resolve({data:{session:{access_token:'t',user:{id:'u1',email:'admin@e.com'}}}});},
         signOut(){return Promise.resolve({});},
         onAuthStateChange(){return {data:{subscription:{unsubscribe(){}}}};} }
};}};
`}));
await p.addInitScript(() => { try{localStorage.setItem('cv-lang','tr');}catch(e){} });
await p.goto('http://localhost:8099/core.html', { waitUntil:'load' });
await p.waitForTimeout(1500);

const tab = p.locator('.tab[data-k="pending"]');
console.log('sekme var mi        :', await tab.count() === 1);
console.log('sekme etiketi       :', (await tab.innerText()).trim());
await tab.click(); await p.waitForTimeout(700);
console.log('baslik              :', await p.locator('.ptitle').innerText());
console.log('sayac               :', await p.locator('#pmCount').innerText());
console.log('satir sayisi        :', await p.locator('#pmList tbody tr').count());
console.log('1. satir            :', (await p.locator('#pmList tbody tr').first().innerText()).replace(/\s+/g,' ').trim());
console.log('2. satir            :', (await p.locator('#pmList tbody tr').nth(1).innerText()).replace(/\s+/g,' ').trim());
await p.screenshot({ path:'/var/tmp/core-pending.png' });

// detay cekmecesi
await p.locator('#pmList tbody tr').first().click(); await p.waitForTimeout(500);
console.log('cekmece basligi     :', await p.locator('#drawerTitle').innerText().catch(()=>'(yok)'));
console.log('rol secimi varsayilan:', await p.locator('#f_pmrole').inputValue());
console.log('kapsam varsayilan   :', await p.locator('#f_pmscope').inputValue());
await p.screenshot({ path:'/var/tmp/core-pending-drawer.png' });

// onayla
await p.selectOption('#f_pmrole','organizer');
await p.selectOption('#f_pmscope','conventus');
await p.locator('#dSave').click(); await p.waitForTimeout(800);
const rpc = await p.evaluate(()=>window.__RPC);
const call = rpc.filter(r=>r.name==='conventity_approve_member').pop();
console.log('onay RPC            :', JSON.stringify(call));
console.log('onay sonrasi satir  :', await p.locator('#pmList tbody tr').count(), '(1 olmali)');

console.log('sayfa hatalari      :', errs.length ? errs : 'yok');
await b.close();
process.exit(errs.length ? 1 : 0);
