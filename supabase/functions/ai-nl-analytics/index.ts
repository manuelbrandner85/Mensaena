// ai-nl-analytics — Admin stellt Fragen in natürlicher Sprache an die DB.
// KI wählt aus einem festen Satz sicherer Abfragen und formatiert die Antwort.
// Keine freie SQL-Ausführung — nur vordefinierte Abfragen, parametrisiert via KI.
// Admin-only. Feature-Flag: 'daily_digest' (allgemeine Analytics-Berechtigung).
import { callAiChain } from '../_shared/ai.ts'
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()

  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const body = await req.json().catch(() => ({}))
  const question = String(body?.question ?? '').trim().slice(0, 500)
  if (!question) return json({ error: 'question_required' }, 400)

  // ── Vordefinierte sichere Abfragen ─────────────────────────────────────
  const now = new Date()
  const since24h = new Date(now.getTime() - 24 * 3600_000).toISOString()
  const since7d  = new Date(now.getTime() - 7  * 86400_000).toISOString()
  const since30d = new Date(now.getTime() - 30 * 86400_000).toISOString()
  const todayStr = now.toISOString().slice(0, 10)

  const headCount = async (table: string, filter?: (q: ReturnType<typeof admin.from>) => ReturnType<typeof admin.from>): Promise<number> => {
    try {
      const q = admin.from(table).select('id', { count: 'exact', head: true })
      const { count } = await (filter ? filter(q as unknown as ReturnType<typeof admin.from>) : q)
      return (count as number) ?? 0
    } catch { return 0 }
  }

  const QUERY_CATALOG: Record<string, { label: string; fn: () => Promise<number> }> = {
    users_total:          { label: 'Nutzer gesamt',              fn: () => headCount('profiles') },
    users_new_24h:        { label: 'Neue Nutzer (24h)',          fn: () => headCount('profiles', (q) => q.gte('created_at', since24h)) },
    users_new_7d:         { label: 'Neue Nutzer (7 Tage)',       fn: () => headCount('profiles', (q) => q.gte('created_at', since7d)) },
    users_new_30d:        { label: 'Neue Nutzer (30 Tage)',      fn: () => headCount('profiles', (q) => q.gte('created_at', since30d)) },
    posts_total:          { label: 'Beiträge gesamt',            fn: () => headCount('posts') },
    posts_new_24h:        { label: 'Neue Beiträge (24h)',        fn: () => headCount('posts', (q) => q.gte('created_at', since24h)) },
    posts_new_7d:         { label: 'Neue Beiträge (7 Tage)',     fn: () => headCount('posts', (q) => q.gte('created_at', since7d)) },
    reports_pending:      { label: 'Offene Meldungen',           fn: () => headCount('reports', (q) => q.eq('status', 'pending')) },
    reports_total:        { label: 'Meldungen gesamt (30 Tage)', fn: () => headCount('reports', (q) => q.gte('created_at', since30d)) },
    crises_active:        { label: 'Aktive Krisen',              fn: () => headCount('crises', (q) => q.eq('status', 'active')) },
    crises_total_30d:     { label: 'Krisen gesamt (30 Tage)',    fn: () => headCount('crises', (q) => q.gte('created_at', since30d)) },
    messages_new_24h:     { label: 'Nachrichten (24h)',          fn: () => headCount('messages', (q) => q.gte('created_at', since24h)) },
    events_new_7d:        { label: 'Neue Events (7 Tage)',       fn: () => headCount('events', (q) => q.gte('created_at', since7d)) },
    high_risk_users:      { label: 'Hochrisiko-Nutzer',          fn: () => headCount('ai_user_risk', (q) => q.eq('level', 'high')) },
  }

  // ── KI wählt passende Abfragen aus ─────────────────────────────────────
  const catalogList = Object.entries(QUERY_CATALOG)
    .map(([k, v]) => `${k}: ${v.label}`)
    .join('\n')

  const SYSTEM =
    'Du hilfst dem Admin einer Nachbarschaftshilfe-App (Mensaena) Datenfragen zu beantworten. ' +
    'Wähle die relevanten Abfrage-IDs und formuliere danach eine präzise deutsche Antwort.\n\n' +
    'Antworte NUR mit validem JSON (kein Markdown):\n' +
    '{"query_ids":["id1","id2"],"answer_template":"Antwort mit {id1} und {id2} als Platzhalter"}\n\n' +
    `Verfügbare Abfragen:\n${catalogList}\n\n` +
    'Wähle 1–4 relevante IDs. Platzhalter im Template genau wie die ID-Namen.'

  let queryIds: string[] = []
  let answerTemplate = ''
  let provider: string | null = null

  try {
    const result = await callAiChain(SYSTEM, `Admin-Frage: ${question}`, { timeoutMs: 12_000 })
    provider = result.provider
    const parsed = JSON.parse(result.text.replace(/```json\n?|```/g, '').trim())
    queryIds = (parsed.query_ids as string[] ?? []).filter((id) => id in QUERY_CATALOG)
    answerTemplate = String(parsed.answer_template ?? '')
  } catch {
    return json({ error: 'ki_failed' }, 500)
  }

  if (!queryIds.length) {
    return json({
      question,
      answer: 'Diese Frage kann ich mit den verfügbaren Daten leider nicht beantworten.',
      data: {},
      provider,
    })
  }

  // ── Sichere Abfragen ausführen ─────────────────────────────────────────
  const data: Record<string, number> = {}
  await Promise.all(queryIds.map(async (id) => {
    data[id] = await QUERY_CATALOG[id].fn()
  }))

  // Platzhalter in Template ersetzen
  let answer = answerTemplate
  for (const [id, val] of Object.entries(data)) {
    answer = answer.replaceAll(`{${id}}`, String(val))
  }

  // Zweiter KI-Pass: Rohdaten in natürliche Sprache überführen (falls Template leer)
  if (!answer || answer.includes('{')) {
    const valStr = Object.entries(data)
      .map(([id, val]) => `${QUERY_CATALOG[id]?.label}: ${val}`)
      .join(', ')
    const { text: formatted } = await callAiChain(
      'Formuliere eine kurze, natürliche deutsche Antwort auf Basis der Daten.',
      `Frage: ${question}\nDaten: ${valStr}`,
      { timeoutMs: 10_000 },
    )
    answer = formatted || valStr
  }

  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'daily_digest',
      actor_id: user.id,
      action: 'nl_query',
      summary: question.slice(0, 280),
      provider,
      meta: { queries: queryIds, data },
    })
  } catch { /* best-effort */ }

  return json({ question, answer, data, provider })
})
