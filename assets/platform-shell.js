// ── CONVENTITY · Platform Shell ──────────────────────────────────────────────
// Shared runtime for all platform standalone pages (conventus, convergens, etc.)
// Handles: theme, live clock, AI prompts, platform overlay boot

(function(){

  // ── THEME ──
  const html = document.documentElement;
  const mql  = window.matchMedia('(prefers-color-scheme: dark)');
  function effectiveTheme(pref){ return pref==='system'?(mql.matches?'dark':'light'):pref; }
  function applyTheme(){
    const pref = localStorage.getItem('conventity-theme-pref')||'system';
    html.setAttribute('data-theme', effectiveTheme(pref));
    document.querySelectorAll('[data-theme-control] [data-theme-pref]').forEach(b=>{
      b.classList.toggle('on', b.dataset.themePref===pref);
    });
  }
  document.querySelectorAll('[data-theme-control] [data-theme-pref]').forEach(b=>{
    b.addEventListener('click',()=>{ localStorage.setItem('conventity-theme-pref',b.dataset.themePref); applyTheme(); });
  });
  if(mql&&mql.addEventListener) mql.addEventListener('change',()=>{ if((localStorage.getItem('conventity-theme-pref')||'system')==='system') applyTheme(); });
  applyTheme();

  // ── LIVE UTC CLOCK ──
  function tickLive(){
    const now = new Date();
    const t = String(now.getUTCHours()).padStart(2,'0')+':'+String(now.getUTCMinutes()).padStart(2,'0')+' UTC';
    document.querySelectorAll('[data-cvg-live]').forEach(el=>{
      const txt = el.textContent||''; const sep = txt.indexOf('·');
      el.textContent = (sep>0 ? t+' '+txt.slice(sep) : t);
    });
  }
  tickLive(); setInterval(tickLive,30000);

  // ── AI PROMPT CONSOLE ──
  document.querySelectorAll('.cvg-prompt[data-plt-persona]').forEach(p=>{
    const persona   = p.dataset.pltPersona;
    const textarea  = p.querySelector('.plt-prompt-text');
    const sendBtn   = p.querySelector('.plt-prompt-send');
    const out       = p.querySelector('.plt-prompt-out');
    if(!textarea||!sendBtn||!out) return;

    async function ask(prompt){
      if(!prompt||!prompt.trim()) return;
      out.classList.add('loading'); out.textContent='Thinking…'; sendBtn.disabled=true;
      try {
        const res = await fetch('https://api.anthropic.com/v1/messages',{
          method:'POST',
          headers:{'Content-Type':'application/json'},
          body:JSON.stringify({
            model:'claude-sonnet-4-6',
            max_tokens:800,
            system: persona,
            messages:[{role:'user',content:prompt}]
          })
        });
        const data = await res.json();
        const text = (data.content||[]).filter(c=>c.type==='text').map(c=>c.text).join('\n');
        out.classList.remove('loading');
        out.textContent = text || 'No response.';
      } catch(e){
        out.classList.remove('loading');
        out.textContent = 'AI temporarily unavailable.';
      } finally { sendBtn.disabled=false; }
    }

    sendBtn.addEventListener('click',()=>ask(textarea.value));
    textarea.addEventListener('keydown',(e)=>{ if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();ask(textarea.value);} });
    textarea.addEventListener('input',()=>{ textarea.style.height='auto'; textarea.style.height=Math.min(textarea.scrollHeight,120)+'px'; });
    p.querySelectorAll('[data-plt-suggest]').forEach(b=>{
      b.addEventListener('click',()=>{ const q=b.dataset.pltSuggest; textarea.value=q; textarea.dispatchEvent(new Event('input')); ask(q); });
    });
  });

  // ── CLOSE BUTTON (standalone pages go back to homepage) ──
  document.querySelectorAll('[data-plt-close]').forEach(b=>{
    b.addEventListener('click',()=>{ window.location.href='/'; });
  });

  // ── PLATFORM OVERLAY OPEN (standalone = already showing, just scroll) ──
  document.querySelectorAll('[data-open-platform]').forEach(el=>{
    el.addEventListener('click',(e)=>{
      e.preventDefault();
      const id = el.dataset.openPlatform;
      window.location.href = '/platforms/'+id+'.html';
    });
  });

  // ── STANDALONE BOOT ──
  // On standalone pages the overlay is auto-opened
  const overlay = document.querySelector('.cvg-overlay');
  if(overlay){
    overlay.classList.add('open');
    overlay.removeAttribute('aria-hidden');
    document.body.style.overflow = '';
  }

})();
