// ============================================================
// Conventity — org-invite Edge Function
//
// conventity.org üyeliği için ADRES TANIMLAMA. Yönetim uygulaması
// (/yonetim/ → Üyeler) çağırır.
//
// Neden sunucu işlevi: conventity.org üyelik sayfası, tanımlı olmayan
// adrese kod göndermemeli ve hesap açmamalıdır. Bu yüzden sayfa yeni hesap
// AÇMAZ (shouldCreateUser:false); hesabı, adres tanımlanırken bu işlev açar.
// Hesap açmak service_role ister; o anahtar yalnız burada durur.
//
// HER çağrı, çağıranın ekosistem yöneticisi olduğunu
// conventity_is_admin('ecosystem') ile doğrular; değilse 403.
//
// POST body: { email, kind?, note? }
//   kind: 'stakeholder' (varsayılan) | 'firm' | 'subscriber'
// Yapılanlar:
//   1) Bu e-postayla hesap yoksa açar (parolasız, e-posta doğrulanmış sayılır;
//      kişi yine de yalnız kendi posta kutusuna gelen kodla girebilir).
//      Hesap varsa dokunmaz.
//   2) conventity_org_members içinde satır yoksa 'invited' olarak ekler.
// Kişiye E-POSTA GÖNDERMEZ: kişiye haber vermek tanımlayanın işidir (yalnız kişinin bu iş için
// verdiği adres tanımlanır). Yanıtta kişisel veri dönmez. Kabul edilmeyen tanım ve hesabı 30 günde
// sunucuda silinir (sql/22 → conventity_org_purge).
//
// DEPLOY: supabase functions deploy org-invite   (verify_jwt açık kalır)
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const ANON_KEY     = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// Yalnız yönetim uygulamasının yayımlandığı adresler çağırabilir.
const ORIGINS = ['https://conventity.com', 'https://www.conventity.com']
const KINDS = ['stakeholder', 'firm', 'subscriber']

function cors(req: Request): Record<string, string> {
  const o = req.headers.get('Origin') || ''
  return {
    'Access-Control-Allow-Origin': ORIGINS.includes(o) ? o : ORIGINS[0],
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const H = cors(req)
  const json = (status: number, obj: unknown) =>
    new Response(JSON.stringify(obj), { status, headers: { ...H, 'Content-Type': 'application/json' } })

  if (req.method === 'OPTIONS') return new Response('ok', { headers: H })
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' })

  try {
    const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '')
    if (!token) return json(401, { error: 'no_token' })

    // 1) Çağıran: kendi oturumuyla; yönetici mi?
    const asUser = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false },
    })
    const { data: uData, error: uErr } = await asUser.auth.getUser()
    if (uErr || !uData?.user) return json(401, { error: 'invalid_token' })
    const { data: isAdmin, error: aErr } = await asUser.rpc('conventity_is_admin', { p_scope: 'ecosystem' })
    if (aErr) return json(500, { error: 'admin_check_failed' })
    if (isAdmin !== true) return json(403, { error: 'not_admin' })

    // 2) Girdi
    const body = await req.json().catch(() => ({} as Record<string, unknown>))
    const email = String(body.email || '').trim().toLowerCase()
    const kind = KINDS.includes(String(body.kind)) ? String(body.kind) : 'stakeholder'
    const note = String(body.note || '').trim().slice(0, 200) || null
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) || email.length > 254) return json(400, { error: 'bad_email' })

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    // 3) Satır zaten var mı?
    const { data: have, error: hErr } = await admin.from('conventity_org_members').select('id').eq('email', email).limit(1)
    if (hErr) return json(500, { error: 'members_unavailable' })
    if (have && have.length) return json(409, { error: 'already_listed' })

    // 4) Hesap: yoksa aç. "Zaten kayıtlı" hata değildir.
    let created = false
    let createdId: string | null = null
    const { data: cData, error: cErr } = await admin.auth.admin.createUser({ email, email_confirm: true })
    if (!cErr) { created = true; createdId = cData?.user?.id ?? null }
    else if (!/already|registered|exists/i.test(cErr.message || '')) return json(400, { error: 'account_failed' })

    // 5) Üyelik satırı
    const { error: iErr } = await admin.from('conventity_org_members')
      .insert({ email, kind, status: 'invited', note, invited_by: uData.user.id })
    if (iErr) {
      // Satır yazılamadıysa az önce açılan hesap öksüz kalmasın.
      if (created && createdId) { try { await admin.auth.admin.deleteUser(createdId) } catch (_) { /* yoksay */ } }
      return json(400, { error: 'insert_failed' })
    }

    return json(200, { ok: true, account_created: created })
  } catch (_) {
    return json(500, { error: 'server_error' })
  }
})
