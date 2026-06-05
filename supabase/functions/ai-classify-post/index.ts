// ai-classify-post — schlägt {type, category} vor (nur Enum-Werte).
// Aufruf nur wenn die lokale Heuristik im Flutter unsicher ist (Kostenschutz).
import { callAiChain, parseAiJson } from '../_shared/ai.ts'
import {
  CORS, json, getUser, adminClient, checkRate, logAi, RATE_LIMIT_MSG,
} from '../_shared/util.ts'

const TYPES = [
  'help_needed', 'help_offered', 'rescue', 'animal', 'housing', 'supply',
  'mobility', 'sharing', 'crisis', 'community',
]
const CATS = [
  'food', 'everyday', 'moving', 'animals', 'housing', 'knowledge', 'skills',
  'mental', 'mobility', 'sharing', 'emergency', 'general',
]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()
  if (!(await checkRate(admin, user.id, 'ai_classify', 10, 30))) {
    return json({ type: null, category: null, limited: true })
  }
  const body = await req.json().catch(() => ({}))
  const title = (body.title ?? '').toString().slice(0, 300)
  const description = (body.description ?? '').toString().slice(0, 1500)
  if (!title.trim() && !description.trim()) return json({ error: 'empty' }, 400)

  const system =
    'Du klassifizierst einen Nachbarschafts-Beitrag. Antworte AUSSCHLIESSLICH als ' +
    'JSON {"type":"<wert>","category":"<wert>"}. ' +
    `Erlaubte type-Werte: ${TYPES.join(', ')}. ` +
    `Erlaubte category-Werte: ${CATS.join(', ')}. ` +
    'Wähle die jeweils beste Passung. KEINE anderen Werte, kein Freitext.'

  const { text, provider } = await callAiChain(
    system,
    `Titel: ${title}\nText: ${description}`,
    { timeoutMs: 12_000, jsonMode: true },
  )
  await logAi(admin, { userId: user.id, feature: 'ai_classify', provider })

  const parsed = parseAiJson<{ type?: string; category?: string }>(text)
  const type = parsed && TYPES.includes(parsed.type ?? '') ? parsed.type : null
  const category =
    parsed && CATS.includes(parsed.category ?? '') ? parsed.category : null
  return json({ type, category, provider })
})
