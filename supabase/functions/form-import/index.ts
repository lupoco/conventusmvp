// ============================================================
// Conventity — form-import Edge Function
//
// Etkinlik yoneticisinin elindeki PDF/Word kayit formunu DIJITAL FORM
// tanimina (conventus_managed_events.registration_field_defs) cevirir.
//
// AKIS
//   1) Tarayici dosyayi ACAR ve DUZ METNE cevirir (pdf.js / JSZip).
//      Buraya yalnizca metin gelir — ikili dosya yuklenmez, saklanmaz.
//   2) Bu fonksiyon cagiranin O ETKINLIGI YONETEBILDIGINI dogrular
//      (conventity_can_manage_event). Aksi halde 403.
//   3) Metni modele verir, KATI bir sema ile alan onerisi ister.
//   4) Donen oneriyi SUNUCUDA dogrular (anahtar bicimi, tip beyaz listesi,
//      cekirdek anahtar beyaz listesi, sayi siniri). Model ne derse desin
//      sema disina cikamaz.
//   5) Oneriyi conventus_form_imports'a yazar ve istemciye DONDURUR.
//
// KRITIK: Bu fonksiyon registration_field_defs'i YAZMAZ. Oneriyi doner;
// yonetici ekranda gorur, duzeltir, secer ve kendisi kaydeder.
// "AI onerir, insan karar verir" — CLAUDE.md cekirdek prensibi.
//
// DEPLOY:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy form-import
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const ANON_KEY     = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const AI_KEY       = Deno.env.get('ANTHROPIC_API_KEY') || ''
const AI_MODEL     = Deno.env.get('FORM_IMPORT_MODEL') || 'claude-sonnet-5'

const MAX_METIN  = 60_000   // karakter — uzun formlar icin yeterli, maliyeti sinirlar
const MAX_ALAN   = 60       // tek formdan kabul edilen en fazla alan

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
function json(status: number, obj: unknown): Response {
  return new Response(JSON.stringify(obj), {
    status, headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

// --- semanin TEK KAYNAGI -----------------------------------------------
// register-conventus.html'in anladigi tipler.
const TIPLER = ['text', 'textarea', 'select', 'multi-select', 'checkbox', 'date', 'email', 'phone']
// register-conventus.html'deki CORE haritasi. Bunlar gercek KOLONA yazilir;
// listede olmayan her sey answers jsonb'ye dusen ozel alandir.
const CEKIRDEK = ['first_name', 'last_name', 'organisation', 'rank', 'duty', 'nation',
                  'phone', 'passport', 'dob', 'ns_email', 'attending_as', 'note']

const ALAN_SEMA = {
  type: 'object',
  properties: {
    fields: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          key:      { type: 'string', description: 'a-z, 0-9 ve alt cizgi; 2-40 karakter' },
          label:    { type: 'string', description: 'Formda gorunen soru metni, kaynaktaki dilde' },
          type:     { type: 'string', enum: TIPLER },
          required: { type: 'boolean' },
          core:     { type: 'boolean', description: 'true ise key CEKIRDEK listesinden olmali' },
          options:  { type: 'array', items: { type: 'string' } },
          source_line: { type: 'string', description: 'Kaynak belgedeki ilgili satir (denetim icin)' },
        },
        required: ['key', 'label', 'type', 'required', 'core'],
        additionalProperties: false,
      },
    },
    consents: {
      type: 'array',
      description: 'Belgede gecen onay/taahhut metinleri (KVKK, fotograf izni, katilimci listesi vb.)',
      items: {
        type: 'object',
        properties: {
          key:  { type: 'string' },
          body: { type: 'string' },
          required: { type: 'boolean' },
        },
        required: ['key', 'body', 'required'],
        additionalProperties: false,
      },
    },
    notes: {
      type: 'array',
      description: 'Cevrilemeyen ya da yoneticinin elle karar vermesi gereken noktalar',
      items: { type: 'string' },
    },
  },
  required: ['fields', 'consents', 'notes'],
  additionalProperties: false,
}

const YONERGE = `Sana bir etkinlik kayit formunun duz metni veriliyor (PDF veya Word'den cikarildi).
Gorevin bu formu dijital form TANIMINA cevirmek.

Kurallar:
1. Yalnizca belgede GERCEKTEN GECEN sorulari cikar. Eksik gorunse bile alan UYDURMA.
2. Su anlamlara gelen sorular icin core=true kullan ve key'i tam olarak su listeden sec:
   ${CEKIRDEK.join(', ')}
   (ornek: "Ad" -> first_name, "Soyad" -> last_name, "Kurum/Birlik" -> organisation,
    "Rutbe" -> rank, "Gorev" -> duty, "Ulke/Millet" -> nation, "Telefon" -> phone,
    "Pasaport No" -> passport, "Dogum Tarihi" -> dob, "NATO Secret e-posta" -> ns_email,
    "Katilim sekli" -> attending_as, "Not/Aciklama" -> note)
3. Listede karsiligi OLMAYAN her soru core=false ve kendi ureteceğin key ile gelir.
   key: kucuk harf, a-z 0-9 ve alt cizgi, 2-40 karakter, anlamli ve benzersiz.
4. label alanini KAYNAKTAKI DILDE ve kaynaktaki ifadeyle birak — cevirme.
5. Isaretlenecek secenekler varsa type='select' (veya birden fazla secilebiliyorsa
   'multi-select') kullan ve options'a secenekleri yaz.
6. Yildiz, "(zorunlu)", "(required)", kalin veya "*" isaretli sorular required=true.
   Emin degilsen required=false birak — yoneticiye sorulur.
7. Onay/taahhut/izin metinlerini (KVKK, fotograf, katilimci listesi paylasimi vb.)
   fields'a DEGIL consents'e koy.
8. Cikaramadigin, belirsiz ya da yoneticinin karar vermesi gereken her sey icin
   notes'a TURKCE tek cumlelik bir not yaz. Sessizce atlama.
9. source_line alanina, o alani hangi satirdan cikardigini kisaca yaz.`

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' })

  try {
    if (!AI_KEY) return json(503, { error: 'ai_key_missing',
      detail: 'ANTHROPIC_API_KEY Supabase secret olarak tanimlanmamis.' })

    const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '')
    if (!token) return json(401, { error: 'no_token' })

    const asUser = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false },
    })
    const { data: uData, error: uErr } = await asUser.auth.getUser()
    if (uErr || !uData?.user) return json(401, { error: 'invalid_token' })
    const caller = uData.user

    const body = await req.json().catch(() => ({} as Record<string, unknown>))
    const activityId = String(body.activity_id || '').trim()
    const sourceName = String(body.source_name || '').slice(0, 200)
    let metin = String(body.text || '')

    if (!activityId) return json(400, { error: 'activity_id_required' })
    if (metin.trim().length < 40) return json(400, { error: 'text_too_short',
      detail: 'Belgeden metin cikarilamadi. Taranmis (goruntu) PDF olabilir.' })

    // --- YETKI KAPISI: yalnizca bu etkinligi yonetebilen ---------------
    const { data: canManage, error: mErr } =
      await asUser.rpc('conventity_can_manage_event', { p_activity_id: activityId })
    if (mErr) return json(500, { error: 'manage_check_failed', detail: mErr.message })
    if (canManage !== true) return json(403, { error: 'not_event_manager' })

    let kirpildi = false
    if (metin.length > MAX_METIN) { metin = metin.slice(0, MAX_METIN); kirpildi = true }

    // --- model cagrisi: tool use ile SEMA ZORLANIR ---------------------
    const ai = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': AI_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: AI_MODEL,
        max_tokens: 8000,
        system: YONERGE,
        tool_choice: { type: 'tool', name: 'form_tanimi' },
        tools: [{ name: 'form_tanimi',
                  description: 'Cikarilan form alanlarini dondurur.',
                  input_schema: ALAN_SEMA }],
        messages: [{ role: 'user', content: 'KAYIT FORMU METNI:\n\n' + metin }],
      }),
    })

    if (!ai.ok) {
      const detay = await ai.text()
      return json(502, { error: 'ai_call_failed', status: ai.status, detail: detay.slice(0, 500) })
    }
    const aiJson = await ai.json()
    const blok = (aiJson.content || []).find((c: Record<string, unknown>) => c.type === 'tool_use')
    if (!blok) return json(502, { error: 'ai_no_tool_use' })
    const ham = blok.input as Record<string, unknown>

    // --- SUNUCU TARAFI DOGRULAMA --------------------------------------
    // Model semadan sapabilir; kabul edilen tek bicim asagidaki.
    const uyarilar: string[] = []
    const gorulen = new Set<string>()
    const alanlar = (Array.isArray(ham.fields) ? ham.fields : [])
      .slice(0, MAX_ALAN)
      .map((f: Record<string, unknown>) => {
        let key = String(f.key || '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
        const label = String(f.label || '').trim().slice(0, 200)
        let tip = String(f.type || 'text').toLowerCase()
        let core = f.core === true

        if (!/^[a-z0-9_]{2,40}$/.test(key)) return null
        if (!label) return null
        if (TIPLER.indexOf(tip) < 0) { uyarilar.push(`"${label}" icin bilinmeyen tip, metne cevrildi.`); tip = 'text' }
        if (core && CEKIRDEK.indexOf(key) < 0) {
          uyarilar.push(`"${label}" cekirdek alan olarak isaretlenmisti ama "${key}" bilinen bir cekirdek anahtar degil; ozel alana cevrildi.`)
          core = false
        }
        if (gorulen.has(key)) {           // ayni anahtar iki kez gelirse
          let i = 2
          while (gorulen.has(key + '_' + i)) i++
          uyarilar.push(`"${key}" iki kez gecti; ikincisi "${key}_${i}" yapildi.`)
          key = key + '_' + i
        }
        gorulen.add(key)

        const secenekler = Array.isArray(f.options)
          ? f.options.map((o: unknown) => String(o).slice(0, 120)).filter(Boolean).slice(0, 40)
          : []

        return {
          key, label, type: tip,
          required: f.required === true,
          visible: true,
          core,
          options: secenekler,
          source_line: String(f.source_line || '').slice(0, 240),
        }
      })
      .filter(Boolean)

    const onaylar = (Array.isArray(ham.consents) ? ham.consents : [])
      .slice(0, 20)
      .map((c: Record<string, unknown>) => {
        const key = String(c.key || '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
        const body2 = String(c.body || '').trim().slice(0, 2000)
        if (!/^[a-z0-9_]{2,40}$/.test(key) || !body2) return null
        return { key, body: body2, required: c.required === true }
      })
      .filter(Boolean)

    const notlar = (Array.isArray(ham.notes) ? ham.notes : [])
      .map((n: unknown) => String(n).slice(0, 300)).filter(Boolean).slice(0, 20)
      .concat(uyarilar)
    if (kirpildi) notlar.unshift(`Belge ${MAX_METIN} karakterde kesildi; sonrasi okunmadi.`)
    if (!alanlar.length) notlar.unshift('Belgeden hicbir gecerli alan cikarilamadi.')

    // --- denetim kaydi (service_role; RLS yalnizca okumada) ------------
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })
    const { data: kayit } = await admin.from('conventus_form_imports').insert({
      activity_id: activityId,
      imported_by: caller.id,
      source_name: sourceName || null,
      source_chars: metin.length,
      model: AI_MODEL,
      proposal: { fields: alanlar, consents: onaylar, notes: notlar },
    }).select('id').single()

    return json(200, {
      import_id: kayit?.id || null,
      fields: alanlar,
      consents: onaylar,
      notes: notlar,
      model: AI_MODEL,
    })
  } catch (e) {
    return json(500, { error: 'unexpected', detail: String((e as Error).message || e) })
  }
})
