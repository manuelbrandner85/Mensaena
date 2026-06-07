// ai-crisis-triage — bewertet aktive Krisen nach Dringlichkeit und gibt
// konkrete Handlungsempfehlungen. Speichert in crises.ai_triage* und
// loggt in ai_admin_audit. Admin-only. Feature-Flag: 'crisis_summary'.
import { callAiChain } from '../_shared/ai.ts'
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

const VALID_URGENCY = ['critical', 'high', 'medium', 'low']

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()

  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const { data: enabled } = await admin
    .rpc('ai_feature_enabled', { p_key: 'crisis_summary' })
  if (enabled === false) return json({ error: 'feature_disabled', disabled: true }, 200)

  const staleThreshold = new Date(Date.now() - 2 * 3600 * 1000).toISOString()

  const { data: crises } = await admin
    .from('crises')
    .select(
      'id, title, description, category, urgency, affected_count, ' +
      'location_text, created_at, helper_count, needed_helpers, ' +
      'ai_triage, ai_triage_urgency, ai_triage_at',
    )
    .eq('status', 'active')
    .or(`ai_triage_at.is.null,ai_triage_at.lt.${staleThreshold}`)
    .order('created_at', { ascending: false })
    .limit(15)

  if (!crises?.length) return json({ analyzed: 0, crises: [] })

  const SYSTEM =
    'Du bist Krisenkoordinator einer Nachbarschaftshilfe-App (Mensaena). ' +
    'Bewerte Krisenberichte nüchtern und empfehle konkrete Maßnahmen. ' +
    'Antworte NUR mit validem JSON ohne Markdown:\n' +
    '{"urgency":"critical|high|medium|low",' +
    '"assessment":"2-3 Sätze Deutsch",' +
    '"actions":["Maßnahme 1","Maßnahme 2","Maßnahme 3"]}\n\n' +
    'critical=unmittelbare Lebensgefahr, Behörden jetzt | ' +
    'high=ernste Lage, schnell handeln | ' +
    'medium=Hilfe nötig, kein Notfall | ' +
    'low=überschaubar, freiwillige Helfer reichen'

  const results: Record<string, unknown>[] = []

  for (let i = 0; i < crises.length; i += 5) {
    const batch = crises.slice(i, i + 5)
    const analyzed = await Promise.all(batch.map(async (crisis) => {
      const userMsg =
        `Krise: ${crisis.title}\n` +
        `Kategorie: ${crisis.category} | Dringlichkeit (gemeldet): ${crisis.urgency}\n` +
        `Betroffene: ${crisis.affected_count} | Helfer: ${crisis.helper_count}/${crisis.needed_helpers}\n` +
        `Ort: ${crisis.location_text || 'nicht angegeben'}\n\n` +
        `Beschreibung: ${crisis.description}`

      try {
        const { text, provider } = await callAiChain(SYSTEM, userMsg, { timeoutMs: 12_000 })
        const raw = text.replace(/```json\n?|```/g, '').trim()
        const parsed = JSON.parse(raw)

        const urgency = VALID_URGENCY.includes(parsed.urgency) ? parsed.urgency as string : crisis.urgency
        const assessment = String(parsed.assessment || '').slice(0, 500)
        const actions = Array.isArray(parsed.actions)
          ? (parsed.actions as unknown[]).slice(0, 3).map(String)
          : []

        await admin.from('crises').update({
          ai_triage: assessment,
          ai_triage_urgency: urgency,
          ai_triage_actions: actions,
          ai_triage_at: new Date().toISOString(),
        }).eq('id', crisis.id)

        return { ...crisis, ai_triage: assessment, ai_triage_urgency: urgency, ai_triage_actions: actions, provider }
      } catch {
        return { ...crisis }
      }
    }))
    results.push(...analyzed)
  }

  const criticalCount = results.filter((r) => r['ai_triage_urgency'] === 'critical').length
  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'crisis_summary',
      actor_id: user.id,
      action: 'triage_crises',
      summary: `${results.length} Krisen triagiert, ${criticalCount} kritisch`,
      provider: (results[0] as Record<string, unknown>)?.['provider'] ?? 'unknown',
      meta: { analyzed: results.length, critical: criticalCount },
    })
  } catch { /* best-effort */ }

  return json({ analyzed: results.length, crises: results })
})
