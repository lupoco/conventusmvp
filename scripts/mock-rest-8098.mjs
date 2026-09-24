/* Sahte PostgREST ucu — under-construction.html'deki erişim talebi formunun
   farklı sunucu yanıtlarına nasıl davrandığını test etmek için.
   Bu dosya daha önce elle ayağa kaldırılıyordu ve depoda yoktu; test tek
   başına çalışmıyordu. Artık test onu kendisi başlatıyor.

   GET  /__mode/<201|409|500>   -> bundan sonraki POST'un döneceği durum
   GET  /__count                -> o ana dek alınan POST sayısı (bot tuzağı testi)
   POST /rest/v1/<tablo>        -> seçilen durumu döner
*/
import { createServer } from 'node:http';
const PORT = Number(process.env.MOCK_PORT || 8098);
let mode = 201;
let posts = 0;
const CORS = {
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'*',
  'access-control-allow-methods':'GET,POST,OPTIONS',
};
const srv = createServer((req,res)=>{
  if(req.method==='OPTIONS'){ res.writeHead(204,CORS); return res.end(); }
  if((req.url||'')==='/__count'){
    res.writeHead(200,{...CORS,'content-type':'text/plain'}); return res.end(String(posts)); }
  const m=/^\/__mode\/(\d{3})$/.exec(req.url||'');
  if(m){ mode=Number(m[1]); res.writeHead(200,{...CORS,'content-type':'text/plain'}); return res.end(String(mode)); }
  let body='';
  req.on('data',c=>{ body+=c; });
  req.on('end',()=>{
    if(req.method==='POST') posts++;
    if(mode===201){ res.writeHead(201,{...CORS,'content-type':'application/json'}); return res.end(''); }
    if(mode===409){ res.writeHead(409,{...CORS,'content-type':'application/json'});
      return res.end(JSON.stringify({code:'23505',message:'duplicate key value violates unique constraint "uq_car_open_email"'})); }
    res.writeHead(500,{...CORS,'content-type':'application/json'});
    res.end(JSON.stringify({message:'internal error'}));
  });
});
srv.listen(PORT, ()=>{ if(process.env.MOCK_QUIET!=='1') console.log('mock rest :'+PORT); });
export default srv;
