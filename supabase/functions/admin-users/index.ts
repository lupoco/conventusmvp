// ============================================================
// Conventity — admin-users Edge Function
//
// service_role ile hassas kullanıcı yönetimi işlemleri. HER çağrı,
// çağıranın ekosistem yöneticisi olduğunu conventity_is_admin('ecosystem')
// ile DOĞRULAR — aksi halde 403. service_role anahtarı yalnız burada,
// istemciye asla sızmaz.
//
// İşlemler (POST body: { action, email }):
//   • reset    → hedef e-postaya parola sıfırlama bağlantısı gönderir
//   • disable  → kullanıcıyı yasaklar (~100 yıl ban)
//   • enable   → yasağı kaldırır
//   • delete   → kullanıcıyı siler (geri alınamaz)
//
// Her başarılı işlem conventity_audit'e (table_name='auth.users') yazılır.
//
// DEPLOY:
//   supabase functions deploy admin-users
//   (SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY
//    ortam değişkenleri Supabase tarafından otomatik sağlanır.)
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL  = Deno.env.get('SUPABASE_URL')!
const ANON_KEY      = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESET_REDIRECT = 'https://conventity.org/reset-password.html'

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(status: number, obj: unknown): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' })

  try {
    const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '')
    if (!token) return json(401, { error: 'no_token' })

    // 1) Çağıran kimliği — kullanıcının kendi token'ıyla (RLS'e saygılı)
    const asUser = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false },
    })
    const { data: uData, error: uErr } = await asUser.auth.getUser()
    if (uErr || !uData?.user) return json(401, { error: 'invalid_token' })
    const caller = uData.user

    // 2) Admin kapısı — audit sekmesiyle aynı fonksiyon
    const { data: isAdmin, error: aErr } = await asUser.rpc('conventity_is_admin', { p_scope: 'ecosystem' })
    if (aErr) return json(500, { error: 'admin_check_failed', detail: aErr.message })
    if (isAdmin !== true) return json(403, { error: 'not_admin' })

    const body = await req.json().catch(() => ({} as Record<string, unknown>))
    const action = String(body.action || '')
    const email = String(body.email || '').trim().toLowerCase()
    if (!email) return json(400, { error: 'email_required' })

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    // Hedef auth kullanıcısını e-posta ile çöz (profiles şemasından bağımsız)
    async function findUser(mail: string) {
      for (let page = 1; page <= 50; page++) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 })
        if (error) throw error
        const hit = data.users.find((u) => (u.email || '').toLowerCase() === mail)
        if (hit) return hit
        if (data.users.length < 200) break
      }
      return null
    }

    let result: Record<string, unknown>

    if (action === 'reset') {
      const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } })
      const { error } = await anon.auth.resetPasswordForEmail(email, { redirectTo: RESET_REDIRECT })
      if (error) return json(400, { error: error.message })
      result = { ok: true, action, email }
    } else if (action === 'disable' || action === 'enable' || action === 'delete') {
      const target = await findUser(email)
      if (!target) return json(404, { error: 'user_not_found' })
      if (target.id === caller.id) return json(400, { error: 'cannot_target_self' })

      if (action === 'delete') {
        const { error } = await admin.auth.admin.deleteUser(target.id)
        if (error) return json(400, { error: error.message })
      } else {
        const ban_duration = action === 'disable' ? '876000h' : 'none'
        const { error } = await admin.auth.admin.updateUserById(target.id, { ban_duration })
        if (error) return json(400, { error: error.message })
      }
      result = { ok: true, action, email, user_id: target.id }
    } else {
      return json(400, { error: 'unknown_action' })
    }

    // 3) Hesap verebilirlik — audit satırı (service_role RLS'i baypas eder)
    try {
      await admin.from('conventity_audit').insert({
        actor_auth_uid: caller.id,
        table_name: 'auth.users',
        action: action === 'delete' ? 'delete' : 'update',
        diff: { admin_action: action, target_email: email },
      })
    } catch (_) { /* audit hatası işlemi bozmaz */ }

    return json(200, result)
  } catch (e) {
    return json(500, { error: String((e as Error)?.message || e) })
  }
})
