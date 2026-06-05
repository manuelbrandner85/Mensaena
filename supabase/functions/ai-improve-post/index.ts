// ai-improve-post — Stichworte -> klarer, freundlicher Nachbarschafts-Beitrag.
import { callAiChain } from '../_shared/ai.ts'
import {
  CORS, json, getUser, adminClient, checkRate, logAi, RATE_LIMIT_MSG,
} from '../_shared/util.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()
  if (!(await checkRate(admin, user.id, 'ai_improve', 5, 10))) {
    return json({ improved: null, limited: true, message: RATE_LIMIT_MSG })
  }
  const body = await req.json().catch(() => ({}))
  const rawText = (body.rawText ?? '').toString().slice(0, 1500)
  const lang = (body.lang ?? 'de').toString().slice(0, 5)
  if (!rawText.trim()) return json({ error: 'empty' }, 400)

  const system =
    'Formuliere aus diesem Stichwort-Text einen klaren, freundlichen, kurzen ' +
    'Nachbarschafts-Beitrag. Keine Übertreibung, keine erfundenen Fakten, keine ' +
    'Notruf-/Krisensprache wenn nicht im Text. Antworte NUR mit dem fertigen ' +
    `Beitragstext (kein Markdown, keine Anführungszeichen), in der Sprache: ${lang}.`

  const { text, provider } = await callAiChain(system, rawText, { timeoutMs: 12_000 })
  await logAi(admin, { userId: user.id, feature: 'ai_improve', provider, lang })
  if (!text) return json({ improved: null, error: 'unavailable' })
  return json({ improved: text, provider })
})
