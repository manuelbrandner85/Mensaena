// ── NINA Warn-API ─────────────────────────────────────────────────────────────
// Primary:  https://nina.api.proxy.bund.dev/api31/
// Fallback: https://warnung.bund.de/api31/
//
// Endpunkte:
//   dashboard/{ags}.json  → Liste aktiver Warnungen für einen Gemeindeschlüssel
//   warnings/{id}.json    → Details einer einzelnen Warnung per ID
//
// Ohne AGS-Parameter wird '000000000000' (bundesweite Warnungen) verwendet.
// Cache: sessionStorage, TTL 15 Minuten.
// Timeout: 8 Sekunden per AbortController.

const PRIMARY_BASE  = 'https://nina.api.proxy.bund.dev/api31'
const FALLBACK_BASE = 'https://warnung.bund.de/api31'
const TIMEOUT_MS    = 8_000
const CACHE_TTL_MS  = 15 * 60 * 1000  // 15 Minuten

// ── Public Types ──────────────────────────────────────────────────────────────

export interface NinaWarning {
  id:          string
  version:     number
  startDate:   string
  severity:    'Minor' | 'Moderate' | 'Severe' | 'Extreme'
  type:        string
  title:       string
  description: string
  instruction: string
  area:        string
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const SEVERITY_ORDER: Record<NinaWarning['severity'], number> = {
  Extreme:  4,
  Severe:   3,
  Moderate: 2,
  Minor:    1,
}

const VALID_SEVERITIES = new Set<string>(['Minor', 'Moderate', 'Severe', 'Extreme'])

function normaliseSeverity(raw: unknown): NinaWarning['severity'] {
  if (typeof raw !== 'string') return 'Minor'
  const s = raw.charAt(0).toUpperCase() + raw.slice(1).toLowerCase()
  return VALID_SEVERITIES.has(s) ? (s as NinaWarning['severity']) : 'Minor'
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapToWarning(raw: any): NinaWarning | null {
  if (!raw || typeof raw !== 'object') return null

  // Dashboard-Einträge können Kurzform (nur ID + Metadaten) oder Vollform haben.
  // Wir greifen auf alle bekannten Feldnamen zurück.
  const id = String(raw.id ?? raw.identifier ?? raw.warningId ?? '')
  if (!id) return null

  return {
    id,
    version:     Number(raw.version)                          ?? 0,
    startDate:   String(raw.startDate ?? raw.sent ?? raw.effective ?? ''),
    severity:    normaliseSeverity(raw.severity),
    type:        String(raw.type ?? raw.msgType ?? raw.event ?? ''),
    title:       String(
      raw.title ?? raw.headline ??
      raw.info?.[0]?.headline ?? raw.i18nTitle?.de ?? '',
    ),
    description: String(
      raw.description ??
      raw.info?.[0]?.description ?? raw.i18nDescription?.de ?? '',
    ),
    instruction: String(
      raw.instruction ??
      raw.info?.[0]?.instruction ?? raw.i18nInstruction?.de ?? '',
    ),
    area:        String(
      raw.area ??
      raw.info?.[0]?.area?.[0]?.areaDesc ?? raw.areaDesc ?? '',
    ),
  }
}

// ── sessionStorage Cache ──────────────────────────────────────────────────────

interface CacheEntry { data: NinaWarning[]; ts: number }

function readCache(key: string): NinaWarning[] | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry
    if (Date.now() - ts < CACHE_TTL_MS) return data
  } catch { /* sessionStorage disabled */ }
  return null
}

function writeCache(key: string, data: NinaWarning[]) {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(key, JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry))
  } catch { /* quota */ }
}

// ── Fetch mit Primary + Fallback + Timeout ────────────────────────────────────

async function fetchDashboard(ags: string): Promise<NinaWarning[]> {
  const paths = [
    `${PRIMARY_BASE}/dashboard/${ags}.json`,
    `${FALLBACK_BASE}/dashboard/${ags}.json`,
  ]

  for (const url of paths) {
    try {
      const res = await fetch(url, {
        signal: AbortSignal.timeout(TIMEOUT_MS),
        headers: { 'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)' },
        next: { revalidate: 900 },
      })
      if (!res.ok) continue

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const data: any = await res.json()
      const items: unknown[] = Array.isArray(data) ? data : []
      const warnings = items
        .map(mapToWarning)
        .filter((w): w is NinaWarning => w !== null)
      if (warnings.length > 0 || url.startsWith(PRIMARY_BASE)) return warnings
    } catch {
      // Nächste URL versuchen
    }
  }
  return []
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Holt aktive NINA-Warnungen für einen Gemeindeschlüssel (AGS).
 *
 * @param ags 12-stelliger Amtlicher Gemeindeschlüssel.
 *            Default: '000000000000' = bundesweite Warnungen.
 */
export async function fetchNinaWarnings(ags = '000000000000'): Promise<NinaWarning[]> {
  const cacheKey = `mensaena_nina_${ags}`
  const cached = readCache(cacheKey)
  if (cached) return cached

  try {
    const warnings = await fetchDashboard(ags)

    // Deduplizieren nach ID
    const seen = new Set<string>()
    const unique = warnings.filter(w => {
      if (seen.has(w.id)) return false
      seen.add(w.id)
      return true
    })

    // Nach Severity absteigend sortieren
    const sorted = unique.sort(
      (a, b) => SEVERITY_ORDER[b.severity] - SEVERITY_ORDER[a.severity],
    )

    writeCache(cacheKey, sorted)
    return sorted
  } catch {
    return []
  }
}

/**
 * Lädt die Volldetails einer einzelnen Warnung per ID.
 * Nutzt den Primary-Endpunkt: warnings/{id}.json
 */
export async function fetchWarningDetails(id: string): Promise<NinaWarning | null> {
  try {
    const res = await fetch(
      `${PRIMARY_BASE}/warnings/${id}.json`,
      {
        signal: AbortSignal.timeout(TIMEOUT_MS),
        headers: { 'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)' },
        next: { revalidate: 900 },
      },
    )
    if (!res.ok) return null
    const data = await res.json()
    return mapToWarning(data)
  } catch {
    return null
  }
}
