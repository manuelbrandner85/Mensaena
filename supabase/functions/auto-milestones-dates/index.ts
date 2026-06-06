// auto-milestones-dates — Jubilaeums-Nachrichten (1 Jahr dabei, runde Hilfe-
// Zahlen). Cron taeglich. Transaktional (KEIN metadata.marketing), also kein
// Frequenz-Limit ueber notify_guard noetig. Trotzdem nur an opt-in-Nutzer.
import { CORS, json, adminClient } from '../_shared/util.ts'

interface Profile {
  id: string; name?: string | null; nickname?: string | null;
  created_at: string; karma_points?: number | null;
}
const BATCH = 200
const HELP_THRESHOLDS = [1, 5, 10, 25, 50, 100, 250]

function firstName(p: Profile): string {
  const src = (p.name || p.nickname || '').toString().trim()
  return src ? src.split(/\s+/)[0] : ''
}

function isAnniversaryToday(createdAt: string): boolean {
  const c = new Date(createdAt)
  const now = new Date()
  if (c.getUTCMonth() !== now.getUTCMonth() || c.getUTCDate() !== now.getUTCDate()) return false
  const years = now.getUTCFullYear() - c.getUTCFullYear()
  return years >= 1
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()

  // Globale Notbremse respektieren (auch bei transaktionalen Nachrichten).
  const { data: brake } = await admin
    .from('app_settings').select('value').eq('key', 'marketing_paused').maybeSingle()
  if (brake?.value === true || brake?.value === 'true') {
    return json({ ok: true, skipped: 'paused' })
  }

  // 1) Jahres-Jubilaeen: alle Profile, deren created_at heute Tag/Monat trifft.
  const { data: profs } = await admin
    .from('profiles')
    .select('id, name, nickname, created_at, karma_points, marketing_opt_in')
    .eq('marketing_opt_in', true)
    .limit(2000)

  let anniv = 0
  let helpMilestone = 0
  for (const p of ((profs ?? []) as (Profile & { marketing_opt_in?: boolean })[]).slice(0, BATCH)) {
    if (!isAnniversaryToday(p.created_at)) continue
    const years = new Date().getUTCFullYear() - new Date(p.created_at).getUTCFullYear()
    const dedupKey = `anniv-${years}-${new Date().getUTCFullYear()}`
    // Idempotenz: existiert schon eine Notification mit kind=anniv und year heute?
    const { data: exists } = await admin
      .from('notifications').select('id')
      .eq('user_id', p.id).eq('type', 'anniversary')
      .gte('created_at', new Date(Date.now() - 86_400_000).toISOString())
      .maybeSingle()
    if (exists) continue
    const fn = firstName(p)
    await admin.from('notifications').insert({
      user_id: p.id, type: 'anniversary', category: 'system',
      title: `🌱 ${years} Jahr${years === 1 ? '' : 'e'} dabei`,
      body: `${fn ? fn + ', ' : ''}danke, dass du seit ${years} Jahr${years === 1 ? '' : 'en'} Teil von Mensaena bist.`,
      link: '/dashboard/profile',
      metadata: { kind: 'anniversary', year: years, dedup: dedupKey },
    })
    anniv++
  }

  // 2) Runde Hilfe-Zahlen aus interactions.status='completed' pro Nutzer.
  // (kann teuer sein — daher Limit 300 Profile pro Lauf)
  for (const p of ((profs ?? []) as Profile[]).slice(0, 300)) {
    const { count } = await admin
      .from('interactions').select('id', { count: 'exact', head: true })
      .eq('helper_id', p.id).eq('status', 'completed')
    const c = count ?? 0
    if (!HELP_THRESHOLDS.includes(c)) continue
    // Idempotenz: Notification mit metadata.help_count = c bereits da?
    const { data: exists } = await admin
      .from('notifications').select('id')
      .eq('user_id', p.id).eq('type', 'help_milestone')
      .eq('metadata->>help_count', String(c))
      .maybeSingle()
    if (exists) continue
    const fn = firstName(p)
    await admin.from('notifications').insert({
      user_id: p.id, type: 'help_milestone', category: 'system',
      title: `🌟 ${c} Mal geholfen`,
      body: `${fn ? fn + ', ' : ''}du hast Nachbar:innen schon ${c} Mal geholfen. Mensaena lebt durch dich.`,
      link: '/dashboard/karma-history',
      metadata: { kind: 'help_milestone', help_count: c },
    })
    helpMilestone++
  }

  return json({ ok: true, anniv, helpMilestone })
})
