// ai-trend-detect — erkennt Themen-Trends in der Community (letzte 24h).
// Analysiert Beiträge nach Häufung, Kategorie, Stimmung. Cached in
// ai_admin_digests (scope='trends'). Admin-only. Flag: 'trend_detection'.
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

  const { data: enabled } = await admin
    .rpc('ai_feature_enabled', { p_key: 'trend_detection' })
  if (enabled === false) return json({ error: 'feature_disabled', disabled: true }, 200)

  const body = await req.json().catch(() => ({}))
  const force = body?.force === true

  const today = new Date().toISOString().slice(0, 10)

  // Cache-Check (max 2h alt)
  if (!force) {
    const stale = new Date(Date.now() - 2 * 3600_000).toISOString()
    const { data: cached } = await admin
      .from('ai_admin_digests')
      .select('summary, stats, created_at')
      .eq('period', today).eq('scope', 'trends')
      .maybeSingle()
    if (cached && cached.created_at > stale) {
      return json({ ...cached, cached: true })
    }
  }

  const since24h = new Date(Date.now() - 24 * 3600_000).toISOString()
  const since6h  = new Date(Date.now() - 6  * 3600_000).toISOString()

  // Beiträge der letzten 24h (mit Kategorie + Kurzinhalt)
  const { data: posts24h } = await admin
    .from('posts')
    .select('content, category, created_at')
    .gte('created_at', since24h)
    .limit(80)

  const { data: posts6h } = await admin
    .from('posts')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', since6h)

  const total24h = posts24h?.length ?? 0
  const total6h  = (posts6h as unknown as { count: number })?.count ?? 0

  // Kategorie-Häufung zählen
  const catCounts: Record<string, number> = {}
  for (const p of (posts24h ?? [])) {
    const cat = p.category || 'sonstige'
    catCounts[cat] = (catCounts[cat] || 0) + 1
  }

  // Inhaltsstichprobe (erste 150 Zeichen pro Beitrag)
  const samples = (posts24h ?? [])
    .slice(0, 30)
    .map((p) => (p.content as string | null)?.slice(0, 150) ?? '')
    .filter(Boolean)
    .join('\n---\n')

  const SYSTEM =
    'Du bist Community-Analytiker einer Nachbarschaftshilfe-App (Mensaena). ' +
    'Analysiere Beitrags-Trends der letzten 24h und gib einen Lagebericht. ' +
    'Antworte NUR mit validem JSON (kein Markdown):\n' +
    '{"summary":"2-3 Sätze Gesamtlage","trends":[' +
    '{"topic":"Thema","volume":N,"direction":"up|stable|down","sentiment":"positiv|neutral|negativ","note":"1 Satz"}' +
    ']}\n\n' +
    'Maximal 5 Trends. Richtung: up=deutlich mehr als normal, stable=normal, down=weniger.'

  const userMsg =
    `Beiträge (24h): ${total24h} gesamt, davon letzte 6h: ${total6h}\n\n` +
    `Kategorie-Verteilung:\n${Object.entries(catCounts)
      .sort(([, a], [, b]) => b - a)
      .map(([k, v]) => `  ${k}: ${v}`)
      .join('\n')}\n\n` +
    `Inhaltsstichprobe (30 zufällige Beiträge):\n${samples || '(keine Beiträge)'}`

  let summary = `Heute: ${total24h} Beiträge in den letzten 24 Stunden.`
  let trends: unknown[] = []
  let provider: string | null = null

  try {
    const result = await callAiChain(SYSTEM, userMsg, { timeoutMs: 15_000 })
    provider = result.provider
    const parsed = JSON.parse(result.text.replace(/```json\n?|```/g, '').trim())
    summary = String(parsed.summary || summary)
    trends = Array.isArray(parsed.trends) ? parsed.trends.slice(0, 5) : []
  } catch { /* use defaults */ }

  const stats = { total24h, total6h, categories: catCounts }

  // In ai_admin_digests cachen (scope='trends')
  try {
    await admin.from('ai_admin_digests').upsert({
      period: today,
      scope: 'trends',
      summary,
      stats: { ...stats, trends },
      provider,
    }, { onConflict: 'period,scope' })
  } catch { /* best-effort */ }

  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'trend_detection',
      actor_id: user.id,
      action: 'detect_trends',
      summary: summary.slice(0, 280),
      provider,
      meta: stats,
    })
  } catch { /* best-effort */ }

  return json({ summary, trends, stats, provider, cached: false })
})
