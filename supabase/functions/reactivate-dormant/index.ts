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
  const now = Date.now()
  const cutoff7  = new Date(now -  7 * 86_400_000).toISOString()
  const cutoff21 = new Date(now - 21 * 86_400_000).toISOString()
  const cutoff45 = new Date(now - 45 * 86_400_000).toISOString()

  // Kandidaten: opt-in + seit 7+ Tagen inaktiv (user_status.updated_at-Proxy).
  const { data: cands, error } = await admin
    .from('profiles')
    .select('id, name, nickname, latitude, longitude, region, '
      + 'user_status!left(updated_at)')
    .eq('reactivation_opt_in', true)
    .limit(300)
  if (error) return json({ error: error.message }, 500)

  // C13: Eskalations-Stufe pro Kandidat bestimmen (7/21/45). Nach 45-er
  // Stufe -> Ruhe (kein weiterer Versuch).
  type Cand = { id: string; name?: string; nickname?: string;
    latitude?: number; longitude?: number; region?: string;
    user_status?: { updated_at?: string } | { updated_at?: string }[] | null }
  function lastSeenIso(p: Cand): string | null {
    const us = p.user_status as { updated_at?: string } | { updated_at?: string }[] | null
    return Array.isArray(us) ? (us[0]?.updated_at ?? null) : (us?.updated_at ?? null)
  }
  const dormant: Array<Cand & { stage: 7 | 21 | 45 }> = []
  for (const p of (cands ?? []) as Cand[]) {
    const ts = lastSeenIso(p)
    if (ts && ts >= cutoff7) continue
    const stage: 7 | 21 | 45 = (!ts || ts < cutoff45)
      ? 45 : (ts < cutoff21 ? 21 : 7)
    dormant.push({ ...p, stage })
  }
  dormant.splice(BATCH)

  // Vorhandene Stufen pro Nutzer laden (idempotenz; nach 45 Ruhe).
  const ids = dormant.map((d) => d.id)
  const { data: logs } = ids.length
    ? await admin.from('reactivation_log').select('user_id, stage').in('user_id', ids)
    : { data: [] }
  const sentMap = new Map<string, Set<number>>()
  for (const l of (logs ?? []) as Array<{ user_id: string; stage: number }>) {
    if (!sentMap.has(l.user_id)) sentMap.set(l.user_id, new Set())
    sentMap.get(l.user_id)!.add(l.stage)
  }

  let sent = 0
  let skipped = 0
  for (const p of dormant) {
    // Idempotenz: diese Stufe schon gesendet -> skip. 45 ist final.
    const done = sentMap.get(p.id) ?? new Set<number>()
    if (done.has(p.stage)) { skipped++; continue }
    if (done.has(45)) { skipped++; continue }

    const guard = await marketingGuard(admin, {
      userId: p.id, optInColumn: 'reactivation_opt_in',
    })
    if (!guard.allowed || guard.scheduledFor) { skipped++; continue }

    // Personalisierter Anlass: a) Hilfe in der Naehe, b) neue Nachbarn, c) generisch.
    let reasonKind = 'generic'
    try {
      if (p.latitude != null && p.longitude != null) {
        const { data: near } = await admin.rpc('get_nearby_posts', {
          lat: p.latitude, lng: p.longitude, radius: 15, limit: 5,
        })
        const arr = Array.isArray(near) ? near : (near?.posts ?? [])
        const help = arr.find((x: { type?: string }) =>
          x.type === 'help_needed' || x.type === 'crisis')
        if (help) { reasonKind = 'nearby_help' }
      }
      if (reasonKind === 'generic' && p.region) {
        const { count } = await admin
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .eq('region', p.region)
          .gte('created_at', cutoff7)
        if ((count ?? 0) > 0) { reasonKind = 'new_neighbors' }
      }
    } catch (_) {/* generisch */}

    const fn = firstName(p as { name?: string; nickname?: string })
    const greet = fn ? `${fn}, ` : ''

    // C13: Tonfall je Stufe — sanft (7) -> staerker (21) -> letzter Versuch (45).
    let title: string
    let body: string
    if (p.stage === 7) {
      // sanft
      title = 'Schön, dich wiederzusehen 🌱'
      if (reasonKind === 'nearby_help') {
        body = `${greet}in deiner Nachbarschaft gibt es eine offene Bitte. Vielleicht magst du vorbeischauen?`
      } else if (reasonKind === 'new_neighbors') {
        body = `${greet}diese Woche sind neue Nachbar:innen dazugekommen. Schau doch mal, was los ist 🌱`
      } else {
        body = `${greet}deine Nachbarschaft freut sich auf dich 🌱`
      }
    } else if (p.stage === 21) {
      // staerker — konkrete Erinnerung
      title = 'Wir vermissen dich in der Nachbarschaft'
      const { text } = await callAiChain(
        'Schreibe 2 warme Saetze (max 30 Worte zusammen), die eine:n Nachbarn nach '
        + '~3 Wochen Pause konkret und warm zur Nachbarschaftshilfe-App zurueckholen. '
        + 'Kein Druck, kein Marketing-Sprech, Deutsch.',
        fn ? `Sprich die Person mit "${fn}" an.` : 'Ohne Namen.',
        { timeoutMs: 8000 },
      )
      body = text || `${greet}seit ein paar Wochen war es ruhig — magst du nochmal vorbeischauen? Vielleicht braucht jemand in deiner Nähe Unterstützung.`
    } else {
      // 45 — letzter, herzlicher Versuch
      title = 'Ein letzter, herzlicher Anstups 🌿'
      body = `${greet}falls du Mensaena nicht mehr nutzen magst, ist das völlig okay. Das ist unser letzter Versuch — danach lassen wir dich in Ruhe. Bis vielleicht eines Tages.`
    }

    try {
      await admin.from('notifications').insert({
        user_id: p.id,
        type: 'reactivation',
        category: 'system',
        title,
        body,
        link: '/dashboard/settings', // Abmelde-/Einstellungs-Link (Pflicht)
        metadata: { marketing: true, kind: 'reactivate', reason: reasonKind, stage: p.stage },
      })
      await logAi(admin, { userId: p.id, feature: 'reactivate' })
      // Stufe im reactivation_log markieren (Idempotenz; nach 45 -> kein
      // weiterer Versuch).
      await admin.from('reactivation_log').insert({ user_id: p.id, stage: p.stage })
      sent++
    } catch (_) { skipped++ }
  }

  return json({ ok: true, candidates: dormant.length, sent, skipped })
})
