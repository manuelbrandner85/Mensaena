// region-ignite-alert — Cron taeglich. Wenn eine Region erstmals >=20 aktive
// Nutzer (letzte 7 Tage aktiv) erreicht hat, Admin-Notification + KI-
// Handlungsvorschlag. Idempotent ueber app_settings-Marker.
import { CORS, json, adminClient } from '../_shared/util.ts'
import { callAiChain } from '../_shared/ai.ts'

const THRESHOLD = 20

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()

  // Aktive Nutzer pro Region (letzte 7 Tage) — RPC liefert jsonb-Array.
  // deno-lint-ignore no-explicit-any
  const { data: regions } = await admin.rpc('marketing_regions_overview') as
    { data: Array<Record<string, any>> | null }

  const ignited: string[] = []
  for (const r of (regions ?? [])) {
    const name = (r.name ?? '').toString()
    const active = Number(r.active_7d ?? 0)
    if (!name || active < THRESHOLD) continue
    const key = `region_ignited:${name}`
    const { data: marker } = await admin
      .from('app_settings').select('value').eq('key', key).maybeSingle()
    if (marker?.value) continue // schon gefeiert

    // KI-Handlungsvorschlag
    const { text } = await callAiChain(
      'Du bist Berater fuer eine Nachbarschaftshilfe-App. Schreibe 2 konkrete '
      + 'Handlungsvorschlaege (je max 1 Satz) fuer den Admin, wenn eine Region '
      + 'erstmals >=20 aktive Nutzer hat. Pragmatisch, keine Marketing-Floskeln. '
      + 'Deutsch.',
      `Region: "${name}", aktive Nutzer letzte 7 Tage: ${active}.`,
      { timeoutMs: 10000 },
    )

    // Admin-Notification an alle Admins (transaktional, kein marketing-flag).
    const { data: admins } = await admin
      .from('profiles').select('id').eq('role', 'admin').limit(20)
    for (const a of (admins ?? []) as { id: string }[]) {
      await admin.from('notifications').insert({
        user_id: a.id, type: 'region_ignite', category: 'system',
        title: `🔥 Region "${name}" ist startklar`,
        body: `${active} aktive Nutzer (7 Tage). ${text || ''}`.trim(),
        link: '/dashboard/admin/marketing',
        metadata: { kind: 'region_ignite', region: name, active },
      })
    }
    // Marker setzen
    await admin.from('app_settings').upsert({
      key, value: { ignited_at: new Date().toISOString(), active },
      description: `Region "${name}" hat ${THRESHOLD}+ aktive Nutzer erreicht`,
    })
    ignited.push(name)
  }
  return json({ ok: true, ignited })
})
