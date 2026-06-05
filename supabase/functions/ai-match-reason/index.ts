// ai-match-reason — erklärt in 1-2 Sätzen, warum ein Match passt.
import { callAiChain } from '../_shared/ai.ts'
import {
  CORS, json, getUser, adminClient, checkRate, logAi, RATE_LIMIT_MSG,
} from '../_shared/util.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const admin = adminClient()
  if (!(await checkRate(admin, user.id, 'ai_match', 10, 20))) {
    return json({ reason: null, limited: true, message: RATE_LIMIT_MSG })
  }
  const body = await req.json().catch(() => ({}))
  const matchId = (body.match_id ?? '').toString()
  const lang = (body.lang ?? 'de').toString().slice(0, 5)
  if (!matchId) return json({ error: 'empty' }, 400)

  const { data: m } = await admin
    .from('matches')
    .select('id, offer_post_id, request_post_id, offer_user_id, request_user_id, match_score, score_breakdown')
    .eq('id', matchId)
    .maybeSingle()
  if (!m) return json({ error: 'not_found' }, 404)
  // Datenschutz: nur Beteiligte dürfen die Begründung sehen.
  if (m.offer_user_id !== user.id && m.request_user_id !== user.id) {
    return json({ error: 'forbidden' }, 403)
  }

  const ids = [m.offer_post_id, m.request_post_id].filter(Boolean)
  const { data: posts } = await admin
    .from('posts')
    .select('id, type, category, title, description')
    .in('id', ids)
  const offer = posts?.find((p: { id: string }) => p.id === m.offer_post_id)
  const request = posts?.find((p: { id: string }) => p.id === m.request_post_id)

  const system =
    'Erkläre in 1-2 warmherzigen, konkreten Sätzen, warum dieses Hilfe-Angebot ' +
    'und diese Hilfe-Anfrage zueinander passen. Keine erfundenen Fakten, kein ' +
    `Marketing-Ton. Antworte NUR mit der Begründung in der Sprache: ${lang}.`
  const content =
    `Angebot: ${offer?.title ?? '–'} (${offer?.type}/${offer?.category}) — ` +
    `${(offer?.description ?? '').toString().slice(0, 300)}\n` +
    `Anfrage: ${request?.title ?? '–'} (${request?.type}/${request?.category}) — ` +
    `${(request?.description ?? '').toString().slice(0, 300)}\n` +
    `Score: ${m.match_score} | Details: ${JSON.stringify(m.score_breakdown ?? {})}`

  const { text, provider } = await callAiChain(system, content, { timeoutMs: 12_000 })
  await logAi(admin, { userId: user.id, feature: 'ai_match', provider, lang })
  if (!text) return json({ reason: null, error: 'unavailable' })
  return json({ reason: text, provider })
})
