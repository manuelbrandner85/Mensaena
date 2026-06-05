// ai-translate — reine Übersetzung, Ton beibehalten, nichts hinzufügen.
import { callAiChain } from '../_shared/ai.ts'
import {
  CORS, json, getUser, adminClient, checkRate, logAi, RATE_LIMIT_MSG,
} from '../_shared/util.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()
  if (!(await checkRate(admin, user.id, 'ai_translate', 15, 40))) {
    return json({ translated: null, limited: true, message: RATE_LIMIT_MSG })
  }
  const body = await req.json().catch(() => ({}))
  const text = (body.text ?? '').toString().slice(0, 3000)
  const targetLang = (body.targetLang ?? 'de').toString().slice(0, 5)
  if (!text.trim()) return json({ error: 'empty' }, 400)

  const system =
    `Übersetze den folgenden Text exakt in die Sprache "${targetLang}". ` +
    'Behalte Ton und Bedeutung bei, füge NICHTS hinzu, erkläre nichts, ' +
    'antworte NUR mit der Übersetzung (kein Markdown, keine Anführungszeichen). ' +
    'Wenn der Text bereits in der Zielsprache ist, gib ihn unverändert zurück.'

  const { text: out, provider } =
    await callAiChain(system, text, { timeoutMs: 12_000 })
  await logAi(admin, { userId: user.id, feature: 'ai_translate', provider, lang: targetLang })
  if (!out) return json({ translated: null, error: 'unavailable' })
  return json({ translated: out, provider })
})
