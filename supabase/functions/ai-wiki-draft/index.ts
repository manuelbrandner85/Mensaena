// ai-wiki-draft — NUR Admin. Erzeugt einen Wiki-Entwurf und legt ihn als
// knowledge_articles mit status='draft' an. Admin gibt später frei.
import { callAiChain, parseAiJson } from '../_shared/ai.ts'
import {
  CORS, json, getUser, adminClient, checkRate, logAi, RATE_LIMIT_MSG,
} from '../_shared/util.ts'

const CATS = [
  'food', 'everyday', 'moving', 'animals', 'housing', 'knowledge', 'skills',
  'mental', 'mobility', 'sharing', 'emergency', 'general',
]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()

  // Admin-Check (Defense-in-depth zusätzlich zu RLS).
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  if (!(await checkRate(admin, user.id, 'ai_wiki', 5, 20))) {
    return json({ draft: null, limited: true, message: RATE_LIMIT_MSG })
  }
  const body = await req.json().catch(() => ({}))
  const topic = (body.topic ?? '').toString().slice(0, 300)
  const lang = (body.lang ?? 'de').toString().slice(0, 5)
  if (!topic.trim()) return json({ error: 'empty' }, 400)

  const system =
    'Du schreibst einen sachlichen, hilfreichen Wissensartikel für eine ' +
    'Nachbarschaftshilfe-App. Keine erfundenen Fakten, keine Verschwörungen, ' +
    'kein medizinischer/rechtlicher Rat als Ersatz für Fachpersonen. Antworte ' +
    'AUSSCHLIESSLICH als JSON {"title":"...","content":"Markdown, min 200 Zeichen",' +
    '"category":"<einer der erlaubten>","tags":["..."]}. ' +
    `Erlaubte category-Werte: ${CATS.join(', ')}. Sprache: ${lang}.`

  const { text, provider } =
    await callAiChain(system, topic, { timeoutMs: 12_000, jsonMode: true })
  await logAi(admin, { userId: user.id, feature: 'ai_wiki', provider, lang })

  const d = parseAiJson<{
    title?: string; content?: string; category?: string; tags?: string[]
  }>(text)
  if (!d || !d.title || !d.content) {
    return json({ draft: null, error: 'unavailable' })
  }
  const title = d.title.toString().slice(0, 200)
  const content = d.content.toString()
  const category = CATS.includes(d.category ?? '') ? d.category : 'general'
  const tags = Array.isArray(d.tags)
    ? d.tags.map((t) => t.toString().slice(0, 40)).slice(0, 8)
    : []
  if (title.length < 5 || content.length < 50) {
    return json({ draft: null, error: 'too_short' })
  }

  let articleId: string | null = null
  try {
    const { data: ins } = await admin
      .from('knowledge_articles')
      .insert({
        author_id: user.id,
        title,
        content,
        category,
        tags,
        status: 'draft',
      })
      .select('id')
      .maybeSingle()
    articleId = ins?.id ?? null
  } catch (_) {
    // Entwurf zurückgeben auch wenn Insert scheitert.
  }

  return json({
    draft: { id: articleId, title, content, category, tags },
    provider,
  })
})
