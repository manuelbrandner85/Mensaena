// reactivate-dormant — sanfte Reaktivierung schlafender Nutzer (per pg_cron 1x/Tag).
// NUR an eingewilligte Bestandsnutzer (reactivation_opt_in), streng gedrosselt
// ueber notify_guard. Ein notifications-Insert loest via DB-Trigger automatisch
// den Push aus. Loggt nur Metadaten (kein Klartext).
import { callAiChain } from '../_shared/ai.ts'
import { CORS, json, adminClient, logAi } from '../_shared/util.ts'
import { marketingGuard } from '../_shared/notify_guard.ts'

const BATCH = 40 // pro Lauf, Volumen/Kosten begrenzen

function firstName(p: { name?: string; nickname?: string }): string {
  const src = (p.name || p.nickname || '').toString().trim()
  return src ? src.split(/\s+/)[0] : ''
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()
  const cutoff = new Date(Date.now() - 7 * 86_400_000).toISOString()

  // Kandidaten: opt-in + seit 7+ Tagen inaktiv (user_status.updated_at-Proxy).
  const { data: cands, error } = await admin
    .from('profiles')
    .select('id, name, nickname, latitude, longitude, region_id, '
      + 'user_status!left(updated_at)')
    .eq('reactivation_opt_in', true)
    .limit(300)
  if (error) return json({ error: error.message }, 500)

  const dormant = (cands ?? []).filter((p: Record<string, unknown>) => {
    const us = p.user_status as { updated_at?: string } | { updated_at?: string }[] | null
    const ts = Array.isArray(us) ? us[0]?.updated_at : us?.updated_at
    return !ts || ts < cutoff
  }).slice(0, BATCH)

  let sent = 0
  let skipped = 0
  for (const p of dormant) {
    const guard = await marketingGuard(admin, {
      userId: p.id as string,
      optInColumn: 'reactivation_opt_in',
    })
    // Stille Zeit (scheduledFor gesetzt) -> diesen Lauf ueberspringen
    // (Cron laeuft 17:00 UTC = ausserhalb der Ruhezeit; selten relevant).
    if (!guard.allowed || guard.scheduledFor) { skipped++; continue }

    // Personalisierter Anlass: a) Hilfe in der Naehe, b) neue Nachbarn, c) generisch.
    let reasonKind = 'generic'
    let detail = ''
    try {
      if (p.latitude != null && p.longitude != null) {
        const { data: near } = await admin.rpc('get_nearby_posts', {
          lat: p.latitude, lng: p.longitude, radius: 15, limit: 5,
        })
        const arr = Array.isArray(near) ? near : (near?.posts ?? [])
        const help = arr.find((x: { type?: string }) =>
          x.type === 'help_needed' || x.type === 'crisis')
        if (help) { reasonKind = 'nearby_help'; detail = (help.title ?? '').toString().slice(0, 80) }
      }
      if (reasonKind === 'generic' && p.region_id) {
        const { count } = await admin
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .eq('region_id', p.region_id)
          .gte('created_at', cutoff)
        if ((count ?? 0) > 0) { reasonKind = 'new_neighbors'; detail = String(count) }
      }
    } catch (_) {/* generisch */}

    const fn = firstName(p as { name?: string; nickname?: string })
    const greet = fn ? `${fn}, ` : ''
    let title = 'Schön, dich wiederzusehen 🌱'
    let body: string
    if (reasonKind === 'nearby_help') {
      title = 'Jemand in deiner Nähe braucht Hilfe'
      body = `${greet}in deiner Nachbarschaft gibt es eine offene Bitte. Vielleicht magst du vorbeischauen?`
    } else if (reasonKind === 'new_neighbors') {
      title = 'Neue Nachbarn in deiner Region'
      body = `${greet}diese Woche sind neue Nachbar:innen dazugekommen. Schau doch mal, was los ist 🌱`
    } else {
      // Sanfte, warme generische Ermutigung — kurz, ueber die KI-Kette.
      const { text } = await callAiChain(
        'Schreibe EINEN warmen, kurzen Satz (max 20 Woerter), der eine:n Nachbarn '
        + 'sanft einlaedt, in die Nachbarschaftshilfe-App zurueckzukommen. Keine '
        + 'Werbefloskeln, kein Druck, auf Deutsch.',
        fn ? `Sprich die Person mit "${fn}" an.` : 'Ohne Namen.',
        { timeoutMs: 8000 },
      )
      body = text || `${greet}deine Nachbarschaft freut sich auf dich 🌱`
    }

    try {
      await admin.from('notifications').insert({
        user_id: p.id,
        type: 'reactivation',
        category: 'system',
        title,
        body,
        link: '/dashboard/settings', // Abmelde-/Einstellungs-Link (Pflicht)
        metadata: { marketing: true, kind: 'reactivate', reason: reasonKind },
      })
      await logAi(admin, { userId: p.id as string, feature: 'reactivate' })
      sent++
    } catch (_) { skipped++ }
  }

  return json({ ok: true, candidates: dormant.length, sent, skipped })
})
