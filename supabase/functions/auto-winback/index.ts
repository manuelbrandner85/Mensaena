// auto-winback — Cron wöchentlich. Wenn jemand EINEN Kanal abbestellt hat
// (z. B. Reaktivierungs-Pushes aus), aber einen anderen erlaubten Kanal noch
// offen lässt (marketing_opt_in), nutzen wir diesen SEHR sparsam für einen
// letzten warmen Win-Back — streng im Rahmen der Opt-ins + notify_guard.
import { CORS, json, adminClient, logAi } from '../_shared/util.ts'
import { marketingGuard } from '../_shared/notify_guard.ts'

const BATCH = 25
const DORMANT_DAYS = 30

function firstName(p: { name?: string; nickname?: string }): string {
  const src = (p.name || p.nickname || '').toString().trim()
  return src ? src.split(/\s+/)[0] : ''
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()
  const cutoff = new Date(Date.now() - DORMANT_DAYS * 86_400_000).toISOString()

  // Reaktivierung abbestellt, aber Marketing-Kanal noch erlaubt + lange inaktiv.
  const { data: cands, error } = await admin
    .from('profiles')
    .select('id, name, nickname, last_active')
    .eq('reactivation_opt_in', false)
    .eq('marketing_opt_in', true)
    .or(`last_active.is.null,last_active.lt.${cutoff}`)
    .limit(200)
  if (error) return json({ error: error.message }, 500)

  let sent = 0
  let skipped = 0
  for (const p of (cands ?? [])) {
    if (sent >= BATCH) break
    // Win-Back läuft über den verbleibenden Kanal: marketing_opt_in.
    const guard = await marketingGuard(admin, {
      userId: p.id as string, optInColumn: 'marketing_opt_in',
    })
    if (!guard.allowed || guard.scheduledFor) { skipped++; continue }

    const fn = firstName(p as { name?: string; nickname?: string })
    const greet = fn ? `${fn}, ` : ''
    try {
      await admin.from('notifications').insert({
        user_id: p.id, type: 'winback', category: 'system',
        title: 'Wir denken an dich 🌱',
        body: `${greet}deine Nachbarschaft ist weiter aktiv. Falls du mal `
          + `reinschauen magst — wir freuen uns. (Du kannst dich jederzeit in `
          + `den Einstellungen abmelden.)`,
        link: '/dashboard/settings',
        metadata: { marketing: true, kind: 'winback', channel: 'marketing' },
      })
      await logAi(admin, { userId: p.id as string, feature: 'winback' })
      sent++
    } catch (_) { skipped++ }
  }

  return json({ ok: true, sent, skipped })
})
