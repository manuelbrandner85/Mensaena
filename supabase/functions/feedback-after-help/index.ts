// feedback-after-help — Cron täglich. Nach abgeschlossener Interaktion eine
// freundliche Bitte um eine kurze Bewertung / einen Erfahrungsbericht an die
// helfende Person. Transaktional (Folge der eigenen Hilfe), daher kein
// notify_guard — aber genau EINMAL pro Interaktion (Dedupe via metadata).
// Schönste Berichte landen mit Einwilligung (consent_public) in testimonials.
import { CORS, json, adminClient } from '../_shared/util.ts'

const BATCH = 100

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()
  const since = new Date(Date.now() - 2 * 86_400_000).toISOString()

  // Kürzlich abgeschlossene Interaktionen.
  const { data: rows, error } = await admin
    .from('interactions')
    .select('id, helper_id, updated_at')
    .eq('status', 'completed')
    .gte('updated_at', since)
    .not('helper_id', 'is', null)
    .limit(400)
  if (error) return json({ error: error.message }, 500)

  // Bereits gefragte Interaktionen (Dedupe).
  const { data: asked } = await admin
    .from('notifications')
    .select('metadata')
    .eq('type', 'feedback_request')
    .gte('created_at', new Date(Date.now() - 14 * 86_400_000).toISOString())
    .limit(2000)
  const askedIds = new Set<string>()
  for (const n of (asked ?? []) as Array<{ metadata?: Record<string, unknown> }>) {
    const iid = n.metadata?.interaction_id
    if (iid) askedIds.add(String(iid))
  }

  let sent = 0
  for (const r of (rows ?? []).slice(0, BATCH * 2)) {
    if (sent >= BATCH) break
    const id = String(r.id)
    if (askedIds.has(id)) continue
    try {
      await admin.from('notifications').insert({
        user_id: r.helper_id,
        type: 'feedback_request',
        category: 'system',
        title: 'Wie war deine Hilfe? 🌱',
        body: 'Magst du in einem Satz erzählen, wie es gelaufen ist? Deine '
          + 'Erfahrung hilft anderen Nachbar:innen, Vertrauen zu fassen.',
        link: '/dashboard/ratings',
        metadata: { kind: 'feedback', interaction_id: id },
      })
      askedIds.add(id)
      sent++
    } catch (_) { /* skip */ }
  }

  return json({ ok: true, sent })
})
