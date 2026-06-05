// ai-crisis-summary — fasst eine Krise + letzte Updates in 2-3 Sätzen zusammen.
// Gecacht in crises.ai_summary / ai_summary_at; nur neu, wenn neue Updates.
import { callAiChain } from '../_shared/ai.ts'
import {
  CORS, json, getUser, adminClient, checkRate, logAi, RATE_LIMIT_MSG,
} from '../_shared/util.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()
  if (!(await checkRate(admin, user.id, 'ai_crisis', 10, 30))) {
    return json({ summary: null, limited: true, message: RATE_LIMIT_MSG })
  }
  const body = await req.json().catch(() => ({}))
  const crisisId = (body.crisis_id ?? '').toString()
  const lang = (body.lang ?? 'de').toString().slice(0, 5)
  if (!crisisId) return json({ error: 'empty' }, 400)

  const { data: crisis } = await admin
    .from('crises')
    .select('id, title, description, category, urgency, status, ai_summary, ai_summary_at, updated_at')
    .eq('id', crisisId)
    .maybeSingle()
  if (!crisis) return json({ error: 'not_found' }, 404)

  const { data: updates } = await admin
    .from('crisis_updates')
    .select('content, update_type, created_at')
    .eq('crisis_id', crisisId)
    .order('created_at', { ascending: false })
    .limit(8)
  const latestUpdateAt = updates && updates.length
    ? updates[0].created_at
    : crisis.updated_at

  // Cache-Hit: vorhandene Zusammenfassung, keine neueren Updates.
  if (
    crisis.ai_summary &&
    crisis.ai_summary_at &&
    latestUpdateAt &&
    new Date(crisis.ai_summary_at) >= new Date(latestUpdateAt)
  ) {
    return json({ summary: crisis.ai_summary, cached: true })
  }

  const updatesText = (updates ?? [])
    .slice()
    .reverse()
    .map((u: { update_type: string; content: string }) =>
      `- [${u.update_type}] ${(u.content ?? '').toString().slice(0, 300)}`)
    .join('\n')

  const system =
    'Fasse den aktuellen Stand dieser Krise in 2-3 ruhigen, sachlichen Sätzen ' +
    'zusammen — was ist passiert, was ist der Status, was wird gebraucht. Keine ' +
    'Panik, keine erfundenen Fakten, keine Ferndiagnosen. Antworte NUR mit der ' +
    `Zusammenfassung in der Sprache: ${lang}.`
  const content =
    `Titel: ${crisis.title}\nKategorie: ${crisis.category} | Dringlichkeit: ` +
    `${crisis.urgency} | Status: ${crisis.status}\nBeschreibung: ` +
    `${(crisis.description ?? '').toString().slice(0, 800)}\n\nUpdates:\n${updatesText}`

  const { text, provider } = await callAiChain(system, content, { timeoutMs: 12_000 })
  await logAi(admin, { userId: user.id, feature: 'ai_crisis', provider, lang })
  if (!text) {
    return json({ summary: crisis.ai_summary ?? null, error: 'unavailable' })
  }

  try {
    await admin
      .from('crises')
      .update({ ai_summary: text, ai_summary_at: new Date().toISOString() })
      .eq('id', crisisId)
  } catch (_) {
    // best-effort cache
  }
  return json({ summary: text, cached: false, provider })
})
