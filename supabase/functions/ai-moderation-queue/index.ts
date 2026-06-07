// ai-moderation-queue — analysiert bis zu 20 pending Reports und gibt
// pro Meldung eine KI-Empfehlung (remove/keep/escalate/needs_review) zurück.
// Speichert die Ergebnisse in reports.ai_* und loggt in ai_admin_audit.
// Admin-only. Respektiert Feature-Flag 'auto_moderate'.
import { callAiChain } from '../_shared/ai.ts'
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

const TABLE_MAP: Record<string, { table: string; cols: string }> = {
  post:         { table: 'posts',         cols: 'content' },
  comment:      { table: 'comments',      cols: 'content' },
  message:      { table: 'messages',      cols: 'content' },
  board_post:   { table: 'board_posts',   cols: 'content' },
  event:        { table: 'events',        cols: 'title, description' },
  organization: { table: 'organizations', cols: 'name, description' },
  user:         { table: 'profiles',      cols: 'display_name, bio' },
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()

  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const { data: enabled } = await admin
    .rpc('ai_feature_enabled', { p_key: 'auto_moderate' })
  if (enabled === false) return json({ error: 'feature_disabled', disabled: true }, 200)

  const body = await req.json().catch(() => ({}))
  const limit = Math.min(Number(body?.limit) || 20, 20)

  const { data: reports } = await admin
    .from('reports')
    .select('id, content_type, content_id, reason, comment, created_at')
    .eq('status', 'pending')
    .order('created_at', { ascending: true })
    .limit(limit)

  if (!reports?.length) return json({ analyzed: 0, reports: [] })

  async function fetchContent(contentType: string, contentId: string): Promise<string> {
    const m = TABLE_MAP[contentType]
    if (!m) return ''
    try {
      const { data } = await admin
        .from(m.table).select(m.cols).eq('id', contentId).maybeSingle()
      if (!data) return ''
      return Object.values(data as Record<string, unknown>)
        .filter(Boolean).join('\n\n').toString().slice(0, 1000)
    } catch { return '' }
  }

  const SYSTEM =
    'Du bist Community-Manager einer Nachbarschaftshilfe-App (Mensaena). ' +
    'Analysiere gemeldete Inhalte sachlich. ' +
    'Antworte NUR mit validem JSON ohne Markdown: ' +
    '{"recommendation":"remove|keep|escalate|needs_review",' +
    '"confidence":0.0-1.0,"reason":"max 150 Zeichen Deutsch"}\n\n' +
    'remove=klarer Verstoß (Hass, Drohung, Spam, illegaler Inhalt)\n' +
    'keep=kein Verstoß, harmloser Inhalt oder Fehlmeldung\n' +
    'escalate=schwerwiegend, braucht sofortige menschliche Prüfung\n' +
    'needs_review=grenzwertig, Kontext fehlt'

  const results: Record<string, unknown>[] = []
  const VALID_RECS = ['remove', 'keep', 'escalate', 'needs_review']

  for (let i = 0; i < reports.length; i += 5) {
    const batch = reports.slice(i, i + 5)
    const analyzed = await Promise.all(batch.map(async (report) => {
      const content = await fetchContent(report.content_type, report.content_id)
      const userMsg =
        `Gemeldeter Inhalt (${report.content_type}):\n` +
        (content ? `"${content}"\n\n` : '(Inhalt nicht abrufbar)\n\n') +
        `Meldungsgrund: ${report.reason}` +
        (report.comment ? `\nDetails: ${report.comment}` : '')

      try {
        const { text, provider } = await callAiChain(SYSTEM, userMsg, { timeoutMs: 12_000 })
        const raw = text.replace(/```json\n?|```/g, '').trim()
        const parsed = JSON.parse(raw)

        const recommendation = VALID_RECS.includes(parsed.recommendation)
          ? parsed.recommendation as string : 'needs_review'
        const confidence = Math.max(0, Math.min(1, Number(parsed.confidence) || 0.5))
        const reason = String(parsed.reason || '').slice(0, 150)

        await admin.from('reports').update({
          ai_recommendation: recommendation,
          ai_confidence: confidence,
          ai_reason: reason,
          ai_analyzed_at: new Date().toISOString(),
        }).eq('id', report.id)

        return { ...report, ai_recommendation: recommendation, ai_confidence: confidence, ai_reason: reason, provider }
      } catch {
        return { ...report, ai_recommendation: 'needs_review', ai_confidence: 0.5, ai_reason: 'Analyse fehlgeschlagen' }
      }
    }))
    results.push(...analyzed)
  }

  const removeCount = results.filter((r) => r['ai_recommendation'] === 'remove').length
  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'auto_moderate',
      actor_id: user.id,
      action: 'analyze_queue',
      summary: `${results.length} Meldungen analysiert, ${removeCount} Entfernung empfohlen`,
      provider: (results[0] as Record<string, unknown>)?.['provider'] ?? 'unknown',
      meta: { analyzed: results.length, remove: removeCount },
    })
  } catch { /* best-effort */ }

  return json({ analyzed: results.length, reports: results })
})
