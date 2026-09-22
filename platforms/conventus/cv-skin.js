/* ============================================================
   CONVENTITY ORTAK DERİ (cv-skin.js)
   Standart: Conventus ana sayfa paleti — krem zemin, beyaz kart,
   lacivert mürekkep, Conventus mavisi; altın = organizatör vurgusu.
   Tema anahtarı: cn-dark · Dil anahtarı: cv-lang (tüm sayfalarda ortak)
   ============================================================ */
(function(){
  var css=getComputedStyle(document.documentElement);
  function has(v){return (css.getPropertyValue(v)||'').trim()!=='';}

  /* ---- standart paleti ---- */
  var L={bg:'#F5F2EC',paper:'#fff',paper2:'#FAF7F1',paper3:'#F1EDE3',
         ink:'#0E2148',ink2:'#1F2D55',muted:'#5A6486',
         line:'#E5DFD2',line2:'#D6CFBE',
         pf:'#004990',pfGlow:'rgba(0,73,144,.10)',
         gold:'#B8892B',goldSoft:'rgba(184,137,43,.12)',
         ok:'#1E8E5A',warn:'#B7791F',bad:'#C0392B',field:'#FFFFFF'};
  /* Koyu tema = navy (S1) — near-black yerine lacivert; katmanlı derinlik */
  var D={bg:'#0B1428',paper:'#101C36',paper2:'#0E1A32',paper3:'#14213F',
         ink:'#EEF1F7',ink2:'#AAB4C8',muted:'#7F8AA2',
         line:'#243456',line2:'#2A3A5E',
         pf:'#4B92DB',pfGlow:'rgba(75,146,219,.14)',
         gold:'#E0A63C',goldSoft:'rgba(224,166,60,.14)',
         ok:'#34C97F',warn:'#E0A63C',bad:'#E4604E',field:'#0E1A32'};

  function block(map,P){
    return Object.keys(map).map(function(k){return '--'+k+':'+P[map[k]];}).join(';');
  }

  /* ---- aile haritaları (sayfanın kendi değişken adları → standart değerler) ---- */
  var fam=null,map=null;
  if(has('--navy')){                       /* lacivert motor ailesi: agenda/applications/announcements */
    fam='navy';
    map={navy:'bg',navy2:'paper2',panel:'paper',panel2:'paper2',panel3:'paper3',
         ink:'ink',muted:'muted',line:'line',line2:'line2',
         gold:'gold','gold-soft':'goldSoft',tc:'pf',ok:'ok',warn:'warn',bad:'bad'};
  }else if(has('--surface')){              /* altın pano ailesi: new-event/register/overview */
    fam='goldboard';
    map={bg:'bg',surface:'paper','surface-2':'paper2',panel:'paper2',field:'field',
         text:'ink',sub:'muted',muted:'muted',border:'line','border-accent':'line2',
         gold:'gold','gold-dim':'goldSoft',ok:'ok',err:'bad'};
  }else if(has('--paper')){                /* standart aile: index/programme/gm-* — değerleri sabitle */
    fam='standard';
    map={bg:'bg',paper:'paper',paper2:'paper2',ink:'ink',ink2:'ink2',muted:'muted',
         line:'line',line2:'line2',pf:'pf','pf-glow':'pfGlow'};
  }
  if(map){
    var st=document.createElement('style');
    st.id='cv-skin';
    st.textContent=':root{'+block(map,L)+'}\n'
      +'body[data-dark]{'+block(map,D)+'}\n'
      +'body{transition:background .18s,color .18s}';
    document.head.appendChild(st);
  }

  /* ---- tema: cn-dark ana anahtar ---- */
  function apply(){
    var d=localStorage.getItem('cn-dark')==='1';
    if(document.body){document.body.toggleAttribute('data-dark',d);}
    var b=document.getElementById('cvSkinToggle'); if(b)b.textContent=d?'\u2600\uFE0F':'\uD83C\uDF19';
  }
  window.cvSkinToggle=function(){
    localStorage.setItem('cn-dark',localStorage.getItem('cn-dark')==='1'?'0':'1');
    apply();
  };

  function ready(fn){document.readyState!=='loading'?fn():document.addEventListener('DOMContentLoaded',fn);}
  ready(function(){
    apply();
    /* sayfanın kendi tema düğmesi yoksa standart düğmeyi tak */
    if(!document.getElementById('themeBtn')&&!document.getElementById('cvSkinToggle')){
      var b=document.createElement('button');
      b.id='cvSkinToggle';
      b.title='Theme';
      b.style.cssText='position:fixed;right:16px;bottom:16px;z-index:99997;width:38px;height:38px;border-radius:100px;border:1px solid var(--line,#D6CFBE);background:var(--paper,#fff);color:var(--ink,#0E2148);font-size:16px;cursor:pointer;box-shadow:0 6px 18px rgba(0,0,0,.14)';
      b.onclick=window.cvSkinToggle;
      document.body.appendChild(b);
      apply();
    }
  });

  /* dil ana anahtarı güvence: yoksa en */
  if(!localStorage.getItem('cv-lang'))localStorage.setItem('cv-lang','en');
})();
