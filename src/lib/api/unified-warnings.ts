// ─────────────────────────────────────────────────────────────────────────────
// Unified Warnings – kombiniert NINA, MeteoAlarm und (optional) DWD zu einer
// einheitlichen Liste. Konsumenten arbeiten nur mit `UnifiedWarning`, ohne
// die Quelle kennen zu müssen.
//
// Strategie:
//   - DE: Promise.allSettled([NINA, MeteoAlarm]) — NINA hat Vorrang (offiziell),
//         Duplikate werden über Headline/Bereich grob erkannt und entfernt.
//   - EU: nur MeteoAlarm.
//   - Sonst: leeres Array.
// ─────────────────────────────────────────────────────────────────────────────

import { fetchNinaWarnings, type NinaWarning } from '@/lib/nina-api'
import { fetchMeteoAlarmWarnings, type MeteoAlarmWarning } from './meteoalarm'
import { plzToAgs } from '@/lib/geo/plz-mapping'

// ── Typen ────────────────────────────────────────────────────────────────────

export type UnifiedSeverity = 'minor' | 'moderate' | 'severe' | 'extreme'
export type UnifiedType =
  | 'weather' | 'flood' | 'fire' | 'health' | 'civil' | 'other'
export type UnifiedSource = 'nina' | 'meteoalarm' | 'dwd'

export interface UnifiedWarning {
  id: string
  title: string
  description: string
  severity: UnifiedSeverity
  type: UnifiedType
  source: UnifiedSource
  onset: string
  expires: string
  area: string
  instruction?: string
  url?: string
}

// ── Mapping-Helfer ───────────────────────────────────────────────────────────

const SEVERITY_RANK: Record<UnifiedSeverity, number> = {
  extreme: 4, severe: 3, moderate: 2, minor: 1,
}

function severityFromCap(s: string): UnifiedSeverity {
  switch (s) {
    case 'Extreme': return 'extreme'
    case 'Severe':  return 'severe'
    case 'Moderate': return 'moderate'
    default:        return 'minor'
  }
}

function detectType(title: string, event?: string): UnifiedType {
  const haystack = `${title} ${event ?? ''}`.toLowerCase()
  if (/hochwasser|flut|flood/.test(haystack)) return 'flood'
  if (/feuer|brand|wildfire|fire/.test(haystack)) return 'fire'
  if (/gesundheit|hitze|smog|pollen|health/.test(haystack)) return 'health'
  if (/gewitter|sturm|orkan|hagel|schnee|wind|frost|wetter|weather/.test(haystack)) return 'weather'
  if (/zivilschutz|katastrophen|civil|defense/.test(haystack)) return 'civil'
  return 'other'
}

function ninaToUnified(w: NinaWarning): UnifiedWarning {
  return {
    id: `nina-${w.id}`,
    title: w.title,
    description: w.description,
    severity: severityFromCap(w.severity),
    type: detectType(w.title, w.type),
    source: 'nina',
    onset: w.startDate,
    expires: '',
    area: w.area,
    instruction: w.instruction || undefined,
  }
}

function meteoToUnified(w: MeteoAlarmWarning): UnifiedWarning {
  return {
    id: `meteoalarm-${w.id}`,
    title: w.headline || w.event,
    description: w.description,
    severity: severityFromCap(w.severity),
    type: detectType(w.headline, w.event),
    source: 'meteoalarm',
    onset: w.onset,
    expires: w.expires,
    area: w.areaDesc,
  }
}

// Naive Duplikat-Erkennung: gleiche Severity + ähnlicher Titel + gleiche Region
function dedupKey(w: UnifiedWarning): string {
  const titlePart = w.title.toLowerCase().replace(/\s+/g, ' ').slice(0, 30)
  return `${w.severity}|${titlePart}|${w.area.slice(0, 20)}`
}

function dedupe(warnings: UnifiedWarning[]): UnifiedWarning[] {
  const seen = new Set<string>()
  const result: UnifiedWarning[] = []
  // NINA zuerst (offiziell), MeteoAlarm danach – dadurch gewinnt NINA bei Konflikten.
  const ordered = [...warnings].sort((a, b) => {
    if (a.source === 'nina' && b.source !== 'nina') return -1
    if (b.source === 'nina' && a.source !== 'nina') return 1
    return 0
  })
  for (const w of ordered) {
    const key = dedupKey(w)
    if (seen.has(key)) continue
    seen.add(key)
    result.push(w)
  }
  return result
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Lädt alle aktiven Warnungen für die Region.
 *
 * @param lat          Breitengrad
 * @param lng          Längengrad
 * @param countryCode  ISO-3166-1 Alpha-2 (DE, AT, CH, …)
 * @param plz          Optionale PLZ für AGS-basierte NINA-Anfrage (DE only)
 */
export async function fetchAllWarnings(
  lat: number,
  lng: number,
  countryCode: string,
  plz?: string,
): Promise<UnifiedWarning[]> {
  // void to silence "unused" warnings — lat/lng werden zukünftig für
  // MeteoAlarm-Filterung nach Bounding-Box verwendet.
  void lat
  void lng

  const cc = countryCode.toUpperCase()

  if (cc === 'DE') {
    const ags = plz ? plzToAgs(plz) : '000000000000'
    const [ninaRes, meteoRes] = await Promise.allSettled([
      fetchNinaWarnings(ags),
      fetchMeteoAlarmWarnings('DE'),
    ])
    const merged: UnifiedWarning[] = []
    if (ninaRes.status === 'fulfilled') merged.push(...ninaRes.value.map(ninaToUnified))
    if (meteoRes.status === 'fulfilled') merged.push(...meteoRes.value.map(meteoToUnified))
    return dedupe(merged).sort(
      (a, b) => SEVERITY_RANK[b.severity] - SEVERITY_RANK[a.severity],
    )
  }

  // EU-Länder, AT, CH → MeteoAlarm
  const meteo = await fetchMeteoAlarmWarnings(cc).catch(() => [])
  return meteo.map(meteoToUnified).sort(
    (a, b) => SEVERITY_RANK[b.severity] - SEVERITY_RANK[a.severity],
  )
}
