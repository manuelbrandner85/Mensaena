const BASE = 'https://abfallnavi.api.bund.dev'

// ─── Interfaces ──────────────────────────────────────────────────────────────

export interface AbfallRegion {
  id: string
  name: string
}

export interface AbfallOrt {
  id: string
  name: string
}

export interface AbfallStrasse {
  id: string
  name: string
}

export interface AbfallHausnummer {
  id: string
  name: string
}

export interface AbfallTermin {
  date: string     // ISO date string "YYYY-MM-DD"
  fraktion: string // e.g. "restmuell", "papier", …
}

export interface NextTermine {
  today: AbfallTermin[]
  tomorrow: AbfallTermin[]
  thisWeek: AbfallTermin[]  // next 7 days excluding today & tomorrow
  upcoming: AbfallTermin[]  // all future dates
}

// ─── Fraktionen ──────────────────────────────────────────────────────────────

export interface FraktionInfo {
  label: string
  icon: string       // lucide-react icon name
  emoji: string
  color: string      // tailwind color base name
  bgColor: string
  textColor: string
  borderColor: string
  dotColor: string
}

export const FRAKTIONEN_INFO: Record<string, FraktionInfo> = {
  restmuell: {
    label: 'Restmüll',
    icon: 'Trash2',
    emoji: '🗑️',
    color: 'gray',
    bgColor: 'bg-gray-100',
    textColor: 'text-gray-700',
    borderColor: 'border-gray-300',
    dotColor: 'bg-gray-500',
  },
  papier: {
    label: 'Papier / Karton',
    icon: 'Newspaper',
    emoji: '📰',
    color: 'blue',
    bgColor: 'bg-blue-100',
    textColor: 'text-blue-700',
    borderColor: 'border-blue-300',
    dotColor: 'bg-blue-500',
  },
  gelb: {
    label: 'Gelber Sack',
    icon: 'Package',
    emoji: '🟡',
    color: 'yellow',
    bgColor: 'bg-yellow-100',
    textColor: 'text-yellow-700',
    borderColor: 'border-yellow-300',
    dotColor: 'bg-yellow-500',
  },
  bio: {
    label: 'Biotonne',
    icon: 'Leaf',
    emoji: '🌿',
    color: 'green',
    bgColor: 'bg-green-100',
    textColor: 'text-green-700',
    borderColor: 'border-green-300',
    dotColor: 'bg-green-500',
  },
  sperr: {
    label: 'Sperrmüll',
    icon: 'Truck',
    emoji: '🛋️',
    color: 'amber',
    bgColor: 'bg-amber-100',
    textColor: 'text-amber-800',
    borderColor: 'border-amber-300',
    dotColor: 'bg-amber-600',
  },
}

export const FRAKTIONEN_LIST = ['restmuell', 'papier', 'gelb', 'bio', 'sperr'] as const
export type Fraktion = (typeof FRAKTIONEN_LIST)[number]

// ─── Known regions (no discovery endpoint exists) ────────────────────────────

export const KNOWN_REGIONS: AbfallRegion[] = [
  { id: 'aachen',            name: 'Aachen (Stadt)' },
  { id: 'zew2',              name: 'Aachen (Kreis) – ZEW²' },
  { id: 'awa',               name: 'AWA – Landsberg am Lech' },
  { id: 'awido',             name: 'AWIDO – Donau-Iller' },
  { id: 'awm',               name: 'AWM – München' },
  { id: 'baw',               name: 'BAW – Westallgäu' },
  { id: 'brsg',              name: 'Breisgau-Hochschwarzwald' },
  { id: 'eaw',               name: 'EAW – Rheingau-Taunus' },
  { id: 'egg',               name: 'Egg / Vorarlberg (AT)' },
  { id: 'hlg',               name: 'HLG – Hochtaunus' },
  { id: 'kreis-es',          name: 'Esslingen (Kreis)' },
  { id: 'kreis-reutlingen',  name: 'Reutlingen (Kreis)' },
  { id: 'lwb',               name: 'LWB – Böblingen' },
  { id: 'nawu',              name: 'NAWU – Neckar-Alb' },
  { id: 'nit',               name: 'NIT – Tuttlingen' },
  { id: 'reg-mue',           name: 'Mühldorf am Inn' },
  { id: 'rno',               name: 'RNO – Ortenaukreis' },
  { id: 'wos',               name: 'WOS – Westerwald-Abfallwirtschaft' },
  { id: 'zvo',               name: 'ZVO – Ostholstein' },
]

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function apiFetch<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { cache: 'no-store' })
  if (!res.ok) throw new Error(`Abfallnavi ${res.status}: ${path}`)
  return res.json() as Promise<T>
}

// ─── Public API functions ─────────────────────────────────────────────────────

export function fetchRegions(): Promise<AbfallRegion[]> {
  return Promise.resolve(KNOWN_REGIONS)
}

export async function fetchOrte(region: string): Promise<AbfallOrt[]> {
  return apiFetch<AbfallOrt[]>(`/${region}/orte.json`)
}

export async function fetchStrassen(region: string, ortId: string): Promise<AbfallStrasse[]> {
  return apiFetch<AbfallStrasse[]>(`/${region}/strassen/${ortId}.json`)
}

export async function fetchHausnummern(region: string, strasseId: string): Promise<AbfallHausnummer[]> {
  return apiFetch<AbfallHausnummer[]>(`/${region}/hausnummern/${strasseId}.json`)
}

export async function fetchTermine(
  region: string,
  hausnummerId: string,
): Promise<AbfallTermin[]> {
  // Fetch all fraktionen in parallel; skip any that return 404
  const results = await Promise.allSettled(
    FRAKTIONEN_LIST.map(async (fraktion) => {
      const raw = await apiFetch<string[] | Array<{ Datum: string }>>(
        `/${region}/termine/${hausnummerId}/${fraktion}.json`,
      )
      // API may return plain strings or objects with "Datum" field
      const dates: string[] = Array.isArray(raw)
        ? raw.map((r) => (typeof r === 'string' ? r : (r as { Datum: string }).Datum))
        : []
      return dates.map((date) => ({ date, fraktion }))
    }),
  )

  const termine: AbfallTermin[] = []
  for (const r of results) {
    if (r.status === 'fulfilled') termine.push(...r.value)
  }

  return termine.sort((a, b) => a.date.localeCompare(b.date))
}

// ─── getNextTermine ───────────────────────────────────────────────────────────

function toISODate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

export function getNextTermine(termine: AbfallTermin[]): NextTermine {
  const now = new Date()
  const todayBase = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const tomorrowBase = new Date(todayBase)
  tomorrowBase.setDate(tomorrowBase.getDate() + 1)
  const weekEnd = new Date(todayBase)
  weekEnd.setDate(weekEnd.getDate() + 7)

  const todayStr = toISODate(todayBase)
  const tomorrowStr = toISODate(tomorrowBase)

  const today = termine.filter((t) => t.date === todayStr)
  const tomorrow = termine.filter((t) => t.date === tomorrowStr)
  const thisWeek = termine.filter((t) => {
    const d = new Date(t.date)
    return d > tomorrowBase && d <= weekEnd
  })
  const upcoming = termine.filter((t) => t.date >= todayStr)

  return { today, tomorrow, thisWeek, upcoming }
}

// ─── Date display helpers ─────────────────────────────────────────────────────

export function formatAbfallDate(dateStr: string): string {
  const d = new Date(dateStr + 'T00:00:00')
  return d.toLocaleDateString('de-DE', { weekday: 'short', day: 'numeric', month: 'short' })
}

export function groupByDate(termine: AbfallTermin[]): Map<string, AbfallTermin[]> {
  const map = new Map<string, AbfallTermin[]>()
  for (const t of termine) {
    const existing = map.get(t.date) ?? []
    existing.push(t)
    map.set(t.date, existing)
  }
  return map
}
