// WARAQ — Edge Function `chat` (محفوظة للرجوع إليها فقط)
// لم تعد مستخدمة: الواجهة الآن تتصل بـ Gemini مباشرة بمفتاح يدخله كل مستخدم.
// لا تحتاج نشرها ولا أسرار GEMINI_API_KEY لتشغيل المساعد الحالي.
//
// الأسرار المطلوبة في Supabase → Project Settings → Edge Functions → Secrets:
//   GEMINI_API_KEY      = مفتاح Google AI Studio
//   (SUPABASE_URL و SUPABASE_ANON_KEY يُحقنان تلقائياً)
// ويجب تطبيق supabase/schema.sql أولاً لتفعيل chat_rate_limit.

import { createClient } from 'jsr:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const GEMINI_KEY = Deno.env.get('GEMINI_API_KEY')!
const MODEL = Deno.env.get('GEMINI_MODEL') || 'gemini-2.5-flash'

const ALLOWED_ORIGINS = [
  'https://abitcode2007.github.io',
  'http://localhost:5173',
  'http://127.0.0.1:5500',
]

const SYSTEM = `أنت «مساعد ورق»، مساعد شخصي ودراسي عربي موجز وودود، تتعرف على الطالب تدريجياً من خلال المحادثة.
في السياق حقل profile.facts يحتوي معلومات سبق أن تذكرتها عنه؛ استخدمها دائماً لتخصيص ردودك واقتراحاتك دون أن تعيد السؤال عنها.
عندما يخبرك المستخدم بمعلومة دائمة عنه (اسمه، تخصصه، مستواه، أهدافه، طريقة مذاكرته، أوقات فراغه، أسلوب الرد الذي يفضله، مادة يصعب عليه فهمها...) استخدم أداة remember لحفظها فوراً. وإذا طلب النسيان استخدم forget.
لا تخترع معرّفات، ولا تنفّذ تعديلاً إلا بطلب صريح من المستخدم.
التواريخ بصيغة YYYY-MM-DD والأوقات بصيغة HH:MM.
أجب بالعربية وباختصار، وأكد ما نفّذته بوضوح، واسأل أحياناً سؤالاً قصيراً لتتعرّف عليه أكثر.`

const TOOLS = [{
  functionDeclarations: [
    { name: 'add_subject', description: 'إضافة مادة دراسية', parameters: { type: 'OBJECT', properties: { name: { type: 'STRING' }, doctor: { type: 'STRING' } }, required: ['name'] } },
    { name: 'add_lecture', description: 'إضافة محاضرة إلى الجدول', parameters: { type: 'OBJECT', properties: { subject: { type: 'STRING' }, day: { type: 'STRING', description: 'السبت، الأحد، الاثنين، الثلاثاء، الأربعاء، الخميس، الجمعة' }, start: { type: 'STRING' }, end: { type: 'STRING' }, room: { type: 'STRING' } }, required: ['subject', 'day', 'start', 'end'] } },
    { name: 'add_exam', description: 'إضافة امتحان', parameters: { type: 'OBJECT', properties: { subject: { type: 'STRING' }, date: { type: 'STRING' }, time: { type: 'STRING' }, exam_type: { type: 'STRING' } }, required: ['subject', 'date'] } },
    { name: 'add_task', description: 'إضافة مهمة أو واجب', parameters: { type: 'OBJECT', properties: { subject: { type: 'STRING' }, title: { type: 'STRING' }, due: { type: 'STRING' } }, required: ['title'] } },
    { name: 'delete_item', description: 'حذف عنصر', parameters: { type: 'OBJECT', properties: { item: { type: 'STRING', enum: ['subject', 'lecture', 'exam', 'task'] }, id: { type: 'STRING' } }, required: ['item', 'id'] } },
    { name: 'update_item', description: 'تعديل عنصر موجود', parameters: { type: 'OBJECT', properties: { item: { type: 'STRING', enum: ['subject', 'lecture', 'exam', 'task'] }, id: { type: 'STRING' }, subject: { type: 'STRING' }, name: { type: 'STRING' }, doctor: { type: 'STRING' }, day: { type: 'STRING' }, start: { type: 'STRING' }, end: { type: 'STRING' }, time: { type: 'STRING' }, date: { type: 'STRING' }, due: { type: 'STRING' }, room: { type: 'STRING' }, title: { type: 'STRING' }, exam_type: { type: 'STRING' }, done: { type: 'BOOLEAN' } }, required: ['item', 'id'] } },
    { name: 'remember', description: 'حفظ معلومة دائمة عن المستخدم لاستخدامها في المحادثات المستقبلية', parameters: { type: 'OBJECT', properties: { fact: { type: 'STRING' } }, required: ['fact'] } },
    { name: 'forget', description: 'حذف معلومة محفوظة عن المستخدم', parameters: { type: 'OBJECT', properties: { fact: { type: 'STRING' } }, required: ['fact'] } },
  ],
}]

const json = (body: unknown, status = 200, origin = ALLOWED_ORIGINS[0]) =>
  new Response(status === 204 ? null : JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'no-store',
    },
  })

Deno.serve(async (req) => {
  const origin = req.headers.get('origin') || ''
  const safeOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]
  if (req.method === 'OPTIONS') return json({}, 204, safeOrigin)
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405, safeOrigin)
  if (origin && !ALLOWED_ORIGINS.includes(origin)) return json({ error: 'forbidden' }, 403, safeOrigin)

  const auth = req.headers.get('Authorization') || ''
  const jwt = auth.replace(/^Bearer\s+/i, '')
  if (!jwt) return json({ error: 'unauthorized' }, 401, safeOrigin)

  const supabase = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt)
  if (authErr || !user) return json({ error: 'unauthorized' }, 401, safeOrigin)

  // تحديد معدل دقيق عبر الدالة SQL (15/دقيقة و200/يوم)
  const { data: allowed, error: rlErr } = await supabase.rpc('chat_rate_limit', { p_user: user.id })
  if (rlErr || allowed === false) {
    console.warn('rate limit:', rlErr?.message || 'exceeded', user.id)
    return json({ error: 'limit' }, 200, safeOrigin)
  }

  let payload: { contents?: unknown; context?: unknown }
  try { payload = await req.json() } catch { return json({ error: 'invalid json' }, 400, safeOrigin) }

  const contents = payload.contents
  const size = JSON.stringify(contents || {}).length + JSON.stringify(payload.context || {}).length
  if (!Array.isArray(contents) || contents.length === 0 || contents.length > 40 || size > 100000) {
    return json({ error: 'invalid request' }, 400, safeOrigin)
  }

  try {
    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM + '\n\nسياق المستخدم الحالي (بياناته وما يتذكره المساعد عنه):\n' + JSON.stringify(payload.context || {}) }] },
          contents: contents.slice(-20),
          tools: [TOOLS],
          generationConfig: { temperature: 0.4, maxOutputTokens: 1024 },
        }),
      },
    )

    if (r.status === 429 || r.status === 403) return json({ error: 'limit' }, 200, safeOrigin)
    if (!r.ok) {
      console.error('gemini status', r.status, (await r.text()).slice(0, 300))
      return json({ error: 'provider error' }, 502, safeOrigin)
    }

    const data = await r.json()
    const content = data?.candidates?.[0]?.content
    if (!content) return json({ error: 'empty response' }, 502, safeOrigin)
    return json({ content }, 200, safeOrigin)
  } catch (e) {
    console.error('chat error', e)
    return json({ error: 'provider error' }, 502, safeOrigin)
  }
})
