// ============================================================
// Conventity — notify-drain Edge Function
//
// conventity_outbox kuyrugunu bosaltir: bekleyen satirlari alir, e-postayi
// URETIR ve gonderir, sonucu satira yazar.
//
// NEDEN AYRI SUREC: bildirim, durum degisikligiyle ayni transaction'da
// kuyruga yazildi (kaybolamaz). Gonderim ise dis bir servise baglidir ve
// basarisiz olabilir; onu transaction'in icine sokmak kaydi bloke ederdi.
//
// NEDEN METIN BURADA: merkezi bakim. Musteriye ozel sablon kopyasi yok;
// dil/metin tek yerden degisir. Kiraciya ozel olan yalnizca VERI.
//
// CAGIRAN: zamanlanmis is (Supabase Scheduled Function ya da pg_cron +
// net.http_post). Yalnizca service_role anahtari ile cagrilabilir.
//
// DEPLOY:
//   supabase secrets set RESEND_API_KEY=re_...
//   supabase secrets set MAIL_FROM='Conventity <bildirim@conventity.com>'
//   supabase secrets set PUBLIC_BASE_URL=https://conventity.com
//   supabase functions deploy notify-drain
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { govde } from './render.js'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_KEY   = Deno.env.get('RESEND_API_KEY') || ''
const MAIL_FROM    = Deno.env.get('MAIL_FROM') || 'Conventity <bildirim@conventity.com>'
const BASE_URL     = (Deno.env.get('PUBLIC_BASE_URL') || 'https://conventity.com').replace(/\/+$/, '')
const BATCH        = Number(Deno.env.get('NOTIFY_BATCH') || 25)

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
function json(status: number, obj: unknown): Response {
  return new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'Content-Type': 'application/json' } })
}

// --- metin: ayri, saf modulde (test edilebilir) ---

// --- gonderim ---------------------------------------------------------
async function gonder(satir: Satir, icerik: { konu: string; html: string; metin: string }) {
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${RESEND_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: MAIL_FROM,
      to: [satir.to_name ? `${satir.to_name} <${satir.to_email}>` : satir.to_email],
      subject: icerik.konu, html: icerik.html, text: icerik.metin,
    }),
  })
  if (!r.ok) throw new Error(`resend ${r.status}: ${(await r.text()).slice(0, 200)}`)
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' })

  // Yalnizca service_role. Kuyrugu disaridan kimse tetikleyemez.
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '')
  if (!token || token !== SERVICE_KEY) return json(401, { error: 'service_role_required' })

  // Anahtar yoksa HICBIR SEY alma: satirlar 'pending' kalsin, kaybolmasin.
  if (!RESEND_KEY) {
    return json(503, { error: 'mail_key_missing',
      detail: 'RESEND_API_KEY tanimli degil. Kuyruk bekliyor, hicbir bildirim kaybolmadi.' })
  }

  type Satir = {
    id: number; kind: string; to_email: string; to_name: string | null; lang: string
    payload: Record<string, unknown>; attempts: number
  }

  const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })
  const { data: satirlar, error } = await db.rpc('conventity_outbox_claim', { p_limit: BATCH })
  if (error) return json(500, { error: 'claim_failed', detail: error.message })

  let gonderilen = 0, basarisiz = 0, atlanan = 0
  for (const s of (satirlar || []) as Satir[]) {
    const icerik = govde(s, BASE_URL)
    if (!icerik) {
      // Sablonu olmayan tur sessizce yutulmaz: sebebiyle birlikte GORUNUR kalir.
      await db.rpc('conventity_outbox_finish',
        { p_id: s.id, p_ok: false, p_error: `bilinmeyen tur: ${s.kind}` })
      atlanan++; continue
    }
    try {
      await gonder(s, icerik)
      await db.rpc('conventity_outbox_finish', { p_id: s.id, p_ok: true, p_error: null })
      gonderilen++
    } catch (e) {
      await db.rpc('conventity_outbox_finish',
        { p_id: s.id, p_ok: false, p_error: String((e as Error).message || e) })
      basarisiz++
    }
  }

  return json(200, { alinan: (satirlar || []).length, gonderilen, basarisiz, atlanan })
})
