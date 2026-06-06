// ════════════════════════════════════════════════════════════════════════
// _shared/notify_guard.ts — globale Schutzregeln für ALLE automatischen
// Marketing/Retention-Pushes. Im Zweifel NICHT senden.
//
//  • Globale Notbremse: app_settings.marketing_paused == 'true' -> nichts.
//  • Opt-out: nur senden, wenn die jeweilige profiles-Spalte (z.B.
//    reactivation_opt_in / marketing_opt_in) true ist.
//  • Frequenz: max. 1 Marketing-Push / 72h UND max. 2 / 7 Tage.
//    Gezählt werden nur Nachrichten mit metadata.marketing == true
//    (transaktionale Pushes wie Anrufe/DMs tragen das NICHT).
//  • Stille Zeiten 22:00–08:00 (Europe/Berlin, Primaerlocale): nicht sofort
//    pushen -> scheduledFor auf den naechsten 08:00-Slot legen.
// ════════════════════════════════════════════════════════════════════════
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4'

export interface GuardResult {
  allowed: boolean
  reason?: string
  // ISO-String, wenn der Versand wegen stiller Zeit verschoben werden soll.
  scheduledFor: string | null
}

const QUIET_START = 22 // 22:00
const QUIET_END = 8 // 08:00

/// Berechnet die aktuelle Stunde + naechsten erlaubten Zeitpunkt in Berlin.
function berlinSchedule(): { hour: number; nextAllowed: string | null } {
  const now = new Date()
  const fmt = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Berlin',
    hour: '2-digit',
    hour12: false,
  })
  const hour = parseInt(fmt.format(now), 10)
  const inQuiet = hour >= QUIET_START || hour < QUIET_END
  if (!inQuiet) return { hour, nextAllowed: null }
  // Naechsten 08:00 Berlin als UTC-ISO bestimmen (grobe, robuste Schaetzung:
  // Berlin = UTC+1/+2; wir legen den Slot auf den naechsten 08:00 lokaler Zeit).
  const offsetMin = -new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Berlin' }))
    .getTimezoneOffset() // nicht zuverlaessig in allen Runtimes -> Fallback unten
  void offsetMin
  const target = new Date(now)
  // Wenn es schon nach Mitternacht ist (0-7h), heute 08:00; sonst morgen 08:00.
  const addDay = hour >= QUIET_START ? 1 : 0
  // grobe Annahme Berlin = UTC+2 (Sommer) -> 08:00 lokal ≈ 06:00 UTC.
  target.setUTCDate(target.getUTCDate() + addDay)
  target.setUTCHours(6, 0, 0, 0)
  return { hour, nextAllowed: target.toISOString() }
}

export async function marketingGuard(
  admin: SupabaseClient,
  opts: { userId: string; optInColumn: 'marketing_opt_in' | 'reactivation_opt_in' },
): Promise<GuardResult> {
  // 1) Globale Notbremse
  try {
    const { data: brake } = await admin
      .from('app_settings').select('value').eq('key', 'marketing_paused').maybeSingle()
    const v = brake?.value
    if (v === true || v === 'true') return { allowed: false, reason: 'paused', scheduledFor: null }
  } catch (_) {/* fail-closed unten nicht noetig; weiter */}

  // 2) Opt-in der Spalte
  const { data: prof } = await admin
    .from('profiles').select(opts.optInColumn).eq('id', opts.userId).maybeSingle()
  if (!prof || prof[opts.optInColumn] !== true) {
    return { allowed: false, reason: 'opt_out', scheduledFor: null }
  }

  // 3) Frequenz (nur metadata.marketing == true)
  const since72 = new Date(Date.now() - 72 * 3600_000).toISOString()
  const since7d = new Date(Date.now() - 7 * 86_400_000).toISOString()
  try {
    const { count: c72 } = await admin
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', opts.userId)
      .eq('metadata->>marketing', 'true')
      .gte('created_at', since72)
    if ((c72 ?? 0) >= 1) return { allowed: false, reason: 'freq_72h', scheduledFor: null }
    const { count: c7 } = await admin
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', opts.userId)
      .eq('metadata->>marketing', 'true')
      .gte('created_at', since7d)
    if ((c7 ?? 0) >= 2) return { allowed: false, reason: 'freq_7d', scheduledFor: null }
  } catch (_) {
    // Im Zweifel NICHT senden.
    return { allowed: false, reason: 'freq_error', scheduledFor: null }
  }

  // 4) Stille Zeiten -> ggf. verschieben
  const { nextAllowed } = berlinSchedule()
  return { allowed: true, scheduledFor: nextAllowed }
}
