// auto-health-report — Cron wöchentlich. Die KI fasst Wachstum, aktivste/
// schwächste Regionen und Auffälligkeiten zusammen und gibt konkrete
// Empfehlungen. Ergebnis als Admin-Notification + optional E-Mail an den Owner.
// Transaktional (Admin-intern) — kein notify_guard nötig.
import { CORS, json, adminClient, logAi } from '../_shared/util.ts'
import { callAiChain } from '../_shared/ai.ts'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()
  const since7 = new Date(Date.now() - 7 * 86_400_000).toISOString()
  const since14 = new Date(Date.now() - 14 * 86_400_000).toISOString()

  const [newUsers7, newUsers14, helps7, active7, posts7, regionsRes] =
    await Promise.all([
      admin.from('profiles').select('id', { count: 'exact', head: true })
        .gte('created_at', since7),
      admin.from('profiles').select('id', { count: 'exact', head: true })
        .gte('created_at', since14),
      admin.from('interactions').select('id', { count: 'exact', head: true })
        .eq('status', 'completed').gte('updated_at', since7),
      admin.from('profiles').select('id', { count: 'exact', head: true })
        .gte('last_active', since7),
      admin.from('posts').select('id', { count: 'exact', head: true })
        .gte('created_at', since7),
      // deno-lint-ignore no-explicit-any
      admin.rpc('marketing_regions_overview') as { data: Array<Record<string, any>> | null },
    ])

  const nu7 = newUsers7.count ?? 0
  const nuPrev = Math.max(0, (newUsers14.count ?? 0) - nu7)
  const regions = (regionsRes.data ?? []) as Array<Record<string, unknown>>
  const sorted = [...regions].sort((a, b) =>
    Number(b.active_7d ?? 0) - Number(a.active_7d ?? 0))
  const top = sorted.slice(0, 3).map((r) =>
    `${r.name} (${r.active_7d ?? 0})`).join(', ')
  const weak = sorted.filter((r) => Number(r.active_7d ?? 0) > 0).slice(-3)
    .map((r) => `${r.name} (${r.active_7d ?? 0})`).join(', ')

  const facts = [
    `Neue Nutzer:innen (7 Tage): ${nu7} (Vorwoche: ${nuPrev})`,
    `Aktive Nutzer:innen (7 Tage): ${active7.count ?? 0}`,
    `Abgeschlossene Hilfen (7 Tage): ${helps7.count ?? 0}`,
    `Neue Beiträge (7 Tage): ${posts7.count ?? 0}`,
    `Aktivste Regionen: ${top || '—'}`,
    `Schwächste aktive Regionen: ${weak || '—'}`,
  ].join('\n')

  const { text } = await callAiChain(
    'Du bist Wachstums-Analyst:in einer gemeinnützigen Nachbarschaftshilfe-App. '
    + 'Fasse den Wochen-Zustand in 4–6 kurzen Sätzen zusammen (Wachstum, '
    + 'aktivste/schwächste Regionen, Auffälligkeiten) und gib 2–3 konkrete, '
    + 'umsetzbare Empfehlungen. Nüchtern, ehrlich, Deutsch. Keine Floskeln.',
    facts,
    { timeoutMs: 12000 },
  )
  const summary = (text || facts).trim()

  // Admin-Notifications
  const { data: admins } = await admin
    .from('profiles').select('id').eq('role', 'admin').limit(20)
  for (const a of (admins ?? []) as { id: string }[]) {
    await admin.from('notifications').insert({
      user_id: a.id, type: 'health_report', category: 'system',
      title: '📊 Wöchentlicher Health-Report',
      body: summary.slice(0, 900),
      link: '/dashboard/admin/marketing',
      metadata: { kind: 'health_report' },
    })
  }

  // Optional: E-Mail an Owner (app_settings.owner_email ODER env MAIL_OWNER).
  let mailed = false
  try {
    const { data: ownerSetting } = await admin
      .from('app_settings').select('value').eq('key', 'owner_email').maybeSingle()
    const owner = (ownerSetting?.value as string | null)
      ?? Deno.env.get('MAIL_OWNER') ?? ''
    if (owner) {
      const html = `<h2>Mensaena — Wöchentlicher Health-Report</h2>`
        + `<pre style="white-space:pre-wrap;font-family:inherit">${facts}</pre>`
        + `<hr><p>${summary.replace(/\n/g, '<br>')}</p>`
      await admin.functions.invoke('send-email', {
        body: {
          to: owner,
          subject: 'Mensaena — Wöchentlicher Health-Report',
          html,
          category: 'health_report',
        },
      })
      mailed = true
    }
  } catch (_) { /* E-Mail optional */ }

  await logAi(admin, { userId: null, feature: 'health_report' })
  return json({ ok: true, admins: (admins ?? []).length, mailed })
})
