const NINA_BASE = 'https://nina.api.proxy.bund.dev/api31'

export interface NinaWarning {
  id: string
  version: number
  startDate: string
  severity: 'Minor' | 'Moderate' | 'Severe' | 'Extreme'
  type: string
  title: string
  description: string
  instruction: string
  area: string
}

const SEVERITY_ORDER: Record<NinaWarning['severity'], number> = {
  Extreme:  4,
  Severe:   3,
  Moderate: 2,
  Minor:    1,
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapToWarning(raw: any): NinaWarning {
  return {
    id:          raw.id          ?? '',
    version:     raw.version     ?? 0,
    startDate:   raw.startDate   ?? raw.sent ?? '',
    severity:    raw.severity    ?? 'Minor',
    type:        raw.type        ?? raw.msgType ?? '',
    title:       raw.title       ?? raw.info?.[0]?.headline ?? '',
    description: raw.description ?? raw.info?.[0]?.description ?? '',
    instruction: raw.instruction ?? raw.info?.[0]?.instruction ?? '',
    area:        raw.area        ?? raw.info?.[0]?.area?.[0]?.areaDesc ?? '',
  }
}

async function fetchFeed(url: string): Promise<NinaWarning[]> {
  const res = await fetch(url, { next: { revalidate: 900 } })
  if (!res.ok) throw new Error(`${res.status} ${url}`)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const data: any[] = await res.json()
  return Array.isArray(data) ? data.map(mapToWarning) : []
}

export async function fetchNinaWarnings(): Promise<NinaWarning[]> {
  try {
    const feeds = [
      `${NINA_BASE}/dashboard/katwarn.json`,
      `${NINA_BASE}/dashboard/mowas.json`,
      `${NINA_BASE}/dashboard/biwapp.json`,
    ]

    const results = await Promise.allSettled(feeds.map(fetchFeed))

    const warnings: NinaWarning[] = []
    for (const result of results) {
      if (result.status === 'fulfilled') {
        warnings.push(...result.value)
      }
    }

    // Deduplicate by id
    const seen = new Set<string>()
    const unique = warnings.filter(w => {
      if (seen.has(w.id)) return false
      seen.add(w.id)
      return true
    })

    // Sort by severity descending
    return unique.sort((a, b) => SEVERITY_ORDER[b.severity] - SEVERITY_ORDER[a.severity])
  } catch {
    return []
  }
}

export async function fetchWarningDetails(id: string): Promise<NinaWarning | null> {
  try {
    const res = await fetch(`${NINA_BASE}/warnings/${id}.json`, { next: { revalidate: 900 } })
    if (!res.ok) return null
    const data = await res.json()
    return mapToWarning(data)
  } catch {
    return null
  }
}
