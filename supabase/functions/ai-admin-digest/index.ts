// ai-admin-digest — KI-Tages-Zusammenfassung fürs Admin-Dashboard.
// Sammelt echte Plattform-Zahlen (letzte 24h) und lässt die KI-Kette daraus
// eine kurze, ruhige deutsche Lagebeschreibung formulieren. Ergebnis wird in
// ai_admin_digests gecacht (ein Digest je Tag) und in ai_admin_audit geloggt.
//
// Admin-only. Respektiert das Feature-Flag 'daily_digest'. Schreibt NICHTS
// an Nutzer — reine Lese-/Zusammenfassungs-Funktion.
import { callAiChain } from '../_shared/ai.ts'
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()

  // Nur Admins.
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  // Feature-Flag muss aktiv sein.
  const { data: enabled } = await admin
    .rpc('ai_feature_enabled', { p_key: 'daily_digest' })
  if (enabled === false) return json({ error: 'feature_disabled', disabled: true }, 200)

  const sinceIso = new Date(Date.now() - 24 * 3600 * 1000).toISOString()
  const today = new Date().toISOString().slice(0, 10)

  // Falls heute schon ein Digest existiert und kein force → cached zurück.
  const body = await req.json().catch(() => ({}))
  const force = body?.force === true
  if (!force) {
    const { data: existing } = await admin
      .from('ai_admin_digests')
      .select('summary, stats, provider, created_at')
      .eq('period', today).eq('scope', 'daily').maybeSingle()
    if (existing?.summary) return json({ ...existing, cached: true })
  }

  // ── Echte Zahlen einsammeln (best-effort, parallel) ──────────────────────
  const headCount = async (
    table: string, build: (q: any) => any = (q) => q,
  ): Promise<number> => {
    try {
      const { count } = await build(
        admin.from(table).select('id', { count: 'exact', head: true }),
      )
      return count ?? 0
    } catch (_) {
      return 0
    }
  }

  const [
    newUsers, newPosts, openReports, newMessages, newEvents, activeCrises,
  ] = await Promise.all([
    headCount('profiles', (q) => q.gte('created_at', sinceIso)),
    headCount('posts', (q) => q.gte('created_at', sinceIso)),
    headCount('reports', (q) => q.eq('status', 'pending')),
    headCount('messages', (q) => q.gte('created_at', sinceIso)),
    headCount('events', (q) => q.gte('created_at', sinceIso)),
    headCount('crises', (q) => q.eq('status', 'active')),
  ])

  const stats = {
    new_users_24h: newUsers,
    new_posts_24h: newPosts,
    open_reports: openReports,
    new_messages_24h: newMessages,
    new_events_24h: newEvents,
    active_crises: activeCrises,
  }

  const system =
    'Du bist die ruhige, kompetente Assistenz für die Admins einer ' +
    'Nachbarschaftshilfe-App (Mensaena). Fasse die Tageszahlen in 3–5 ' +
    'kurzen deutschen Sätzen zusammen: was ist auffällig, worauf sollte ' +
    'das Team heute zuerst schauen. Sachlich, freundlich, keine Floskeln, ' +
    'keine Aufzählungszeichen, kein Markdown. Wenn offene Meldungen > 0 ' +
    'sind, weise dezent darauf hin.'

  const userContent =
    'Zahlen der letzten 24 Stunden:\n' +
    `- Neue Nutzer: ${newUsers}\n` +
    `- Neue Beiträge: ${newPosts}\n` +
    `- Neue Nachrichten: ${newMessages}\n` +
    `- Neue Events: ${newEvents}\n` +
    `- Offene Meldungen (gesamt): ${openReports}\n` +
    `- Aktive Krisen: ${activeCrises}`

  const { text: summary, provider } =
    await callAiChain(system, userContent, { timeoutMs: 15_000 })

  const finalSummary = summary && summary.trim()
    ? summary.trim()
    : `Heute: ${newUsers} neue Nutzer, ${newPosts} neue Beiträge, ` +
      `${openReports} offene Meldungen, ${activeCrises} aktive Krisen.`

  // Cachen (upsert auf period+scope).
  try {
    await admin.from('ai_admin_digests').upsert({
      period: today,
      scope: 'daily',
      summary: finalSummary,
      stats,
      provider,
    }, { onConflict: 'period,scope' })
  } catch (_) { /* best-effort */ }

  // Audit.
  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'daily_digest',
      actor_id: user.id,
      action: 'generate_digest',
      summary: finalSummary.slice(0, 280),
      provider,
      meta: stats,
    })
  } catch (_) { /* best-effort */ }

  return json({ summary: finalSummary, stats, provider, cached: false })
})
