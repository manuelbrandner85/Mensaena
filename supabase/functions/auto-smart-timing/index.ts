// auto-smart-timing — Cron wöchentlich. Lernt aus campaign_events (Öffnungen)
// die Stunde mit der höchsten Öffnungsrate — global und pro Region — und legt
// sie in send_time_pref ab. Geplante Sendungen können diese Stunde nutzen
// (immer innerhalb der erlaubten Zeiten 08–22, das erzwingt notify_guard).
import { CORS, json, adminClient } from '../_shared/util.ts'

const LOOKBACK_DAYS = 90
const MIN_SAMPLES = 5
const ALLOWED_MIN = 8   // 08:00
const ALLOWED_MAX = 21  // 21:00 (letzter Slot vor stiller Zeit)

function argmaxHour(hist: Record<number, number>): { hour: number; total: number } {
  let best = -1
  let bestCount = -1
  let total = 0
  for (let h = ALLOWED_MIN; h <= ALLOWED_MAX; h++) {
    const c = hist[h] ?? 0
    total += c
    if (c > bestCount) { bestCount = c; best = h }
  }
  return { hour: best < 0 ? 9 : best, total }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const admin = adminClient()
  const since = new Date(Date.now() - LOOKBACK_DAYS * 86_400_000).toISOString()

  // Öffnungen mit Stunde + Region des Nutzers (embedded select über FK user_id).
  const { data, error } = await admin
    .from('campaign_events')
    .select('hour_berlin, profiles:user_id(region)')
    .eq('kind', 'open')
    .not('hour_berlin', 'is', null)
    .gte('created_at', since)
    .limit(20000)
  if (error) return json({ error: error.message }, 500)

  const global: Record<number, number> = {}
  const perRegion: Record<string, Record<number, number>> = {}
  for (const row of (data ?? []) as Array<Record<string, unknown>>) {
    const h = Number(row.hour_berlin)
    if (!Number.isFinite(h)) continue
    global[h] = (global[h] ?? 0) + 1
    const prof = row.profiles as { region?: string | null } | null
    const region = (prof?.region ?? '').toString().trim()
    if (region) {
      perRegion[region] ??= {}
      perRegion[region][h] = (perRegion[region][h] ?? 0) + 1
    }
  }

  const upserts: Array<Record<string, unknown>> = []
  const g = argmaxHour(global)
  if (g.total >= MIN_SAMPLES) {
    upserts.push({ scope: 'global', scope_id: 'all', best_hour: g.hour,
      sample_size: g.total, updated_at: new Date().toISOString() })
  }
  for (const [region, hist] of Object.entries(perRegion)) {
    const r = argmaxHour(hist)
    if (r.total >= MIN_SAMPLES) {
      upserts.push({ scope: 'region', scope_id: region, best_hour: r.hour,
        sample_size: r.total, updated_at: new Date().toISOString() })
    }
  }

  let saved = 0
  for (const u of upserts) {
    const { error: upErr } = await admin
      .from('send_time_pref')
      .upsert(u, { onConflict: 'scope,scope_id' })
    if (!upErr) saved++
  }
  return json({ ok: true, saved, regions: Object.keys(perRegion).length })
})
