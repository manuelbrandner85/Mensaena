// Lebensmittel- und Produktwarnungen aus dem öffentlichen Bayern-Verbraucherschutz-
// Feed (BVL-Aggregat). Kein API-Key nötig. Antwortformat ist nicht offiziell
// dokumentiert – wir mappen defensiv auf ein stabiles internes Interface und
// fallen leise auf [] zurück, wenn der Upstream wackelt.

export interface FoodWarning {
  id: string
  title: string
  publishedDate: string
  productName: string
  manufacturer: string
  description: string
  affectedStates: string[]
  imageUrl?: string
  link?: string
  /** Best-Guess Schweregrad: "high" = Gesundheitsgefahr / Rückruf, "medium" = Hinweis. */
  severity: 'high' | 'medium'
}

export interface FetchFoodWarningsOptions {
  /** Maximale Anzahl der zurückgegebenen Warnungen (nach 30-Tage-Filter). Default 20. */
  limit?: number
}

const PRIMARY_ENDPOINT =
  'https://megov.bayern.de/verbraucherschutz/baystmuv-verbraucherschutz/rest/api/warnings/merged'

const FALLBACK_ENDPOINT = 'https://lebensmittelwarnung.api.bund.dev/'

const DEFAULT_LIMIT = 20
const RECENT_WINDOW_DAYS = 30
const CACHE_TTL_MS = 2 * 60 * 60 * 1000 // 2 Stunden

// Modul-globaler In-Memory-Cache (Server- und Client-seitig). Auf dem Client
// zusätzlich in localStorage gespiegelt, damit Page-Wechsel nicht refetchen.
let memoryCache: { data: FoodWarning[]; timestamp: number } | null = null
let inflight: Promise<FoodWarning[]> | null = null

const STORAGE_KEY = 'mensaena_foodwarnings_cache'

// 16 deutsche Bundesländer + gängige Aliasse, damit ein freitextliches
// Profil-Feld wie "München, Bayern" oder "Hamburg" trotzdem matcht.
const STATE_ALIASES: Record<string, string[]> = {
  'Baden-Württemberg': ['baden-württemberg', 'baden württemberg', 'bw'],
  'Bayern': ['bayern', 'bavaria', 'by'],
  'Berlin': ['berlin', 'be'],
  'Brandenburg': ['brandenburg', 'bb'],
  'Bremen': ['bremen', 'hb'],
  'Hamburg': ['hamburg', 'hh'],
  'Hessen': ['hessen', 'hesse', 'he'],
  'Mecklenburg-Vorpommern': ['mecklenburg-vorpommern', 'mecklenburg vorpommern', 'mv'],
  'Niedersachsen': ['niedersachsen', 'lower saxony', 'ni'],
  'Nordrhein-Westfalen': ['nordrhein-westfalen', 'nrw', 'north rhine-westphalia'],
  'Rheinland-Pfalz': ['rheinland-pfalz', 'rheinland pfalz', 'rlp'],
  'Saarland': ['saarland', 'sl'],
  'Sachsen': ['sachsen', 'saxony', 'sn'],
  'Sachsen-Anhalt': ['sachsen-anhalt', 'sachsen anhalt', 'st'],
  'Schleswig-Holstein': ['schleswig-holstein', 'schleswig holstein', 'sh'],
  'Thüringen': ['thüringen', 'thueringen', 'thuringia', 'th'],
}

const NATIONWIDE_TOKENS = ['bundesweit', 'deutschland', 'alle', 'germany', 'nationwide']

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function asString(value: any, fallback = ''): string {
  if (value == null) return fallback
  if (typeof value === 'string') return value
  if (typeof value === 'number') return String(value)
  return fallback
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function asArray(value: any): unknown[] {
  if (Array.isArray(value)) return value
  if (value == null) return []
  return [value]
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function pickString(obj: any, keys: string[], fallback = ''): string {
  if (!obj || typeof obj !== 'object') return fallback
  for (const key of keys) {
    const v = obj[key]
    if (typeof v === 'string' && v.trim()) return v.trim()
  }
  return fallback
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function pickFirst<T = any>(obj: any, keys: string[]): T | undefined {
  if (!obj || typeof obj !== 'object') return undefined
  for (const key of keys) {
    if (obj[key] !== undefined && obj[key] !== null) return obj[key] as T
  }
  return undefined
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function detectSeverity(raw: any, title: string, description: string): 'high' | 'medium' {
  const haystack = `${title} ${description}`.toLowerCase()
  // Klassische Trigger-Begriffe für Rückrufe / Gesundheitsgefahr
  if (
    haystack.includes('rückruf') ||
    haystack.includes('rueckruf') ||
    haystack.includes('gesundheitsgefahr') ||
    haystack.includes('salmonell') ||
    haystack.includes('listerien') ||
    haystack.includes('e. coli') ||
    haystack.includes('botulin') ||
    haystack.includes('fremdkörper') ||
    haystack.includes('metallteile') ||
    haystack.includes('glassplitter') ||
    haystack.includes('plastiksplitter')
  ) return 'high'
  // Optionales Severity-Feld vom Upstream
  const explicit = pickString(raw, ['severity', 'risk', 'risk_level', 'level']).toLowerCase()
  if (
    explicit.includes('hoch') ||
    explicit === 'high' ||
    explicit === 'severe' ||
    explicit === 'extreme'
  ) return 'high'
  return 'medium'
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function extractStates(raw: any): string[] {
  const candidates: unknown[] = []
  // Mögliche Feldnamen aus den verschiedenen Endpunkten
  for (const key of ['affectedStates', 'states', 'bundeslaender', 'bundeslander', 'regions', 'area']) {
    const v = raw?.[key]
    if (v == null) continue
    if (Array.isArray(v)) candidates.push(...v)
    else candidates.push(v)
  }
  const out = new Set<string>()
  for (const item of candidates) {
    if (typeof item === 'string') {
      out.add(item.trim())
      continue
    }
    if (item && typeof item === 'object') {
      const name = pickString(item, ['name', 'label', 'state', 'designation', 'value'])
      if (name) out.add(name)
    }
  }
  return Array.from(out).filter(Boolean)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapToFoodWarning(raw: any): FoodWarning | null {
  if (!raw || typeof raw !== 'object') return null

  const product = pickFirst<Record<string, unknown>>(raw, ['product', 'productInfo', 'item']) ?? {}

  const id = asString(
    pickFirst(raw, ['id', 'uuid', 'warningId', 'warning_id', 'identifier']) ?? '',
  )
  const title = pickString(raw, ['title', 'subject', 'designation', 'headline', 'name'])
  const publishedDate = pickString(raw, [
    'publishedDate', 'published_at', 'publishDate', 'datePublished', 'date', 'sent',
  ])
  const productName = pickString(product, ['designation', 'name', 'productName', 'title']) ||
    pickString(raw, ['productName', 'product_name'])
  const manufacturer = pickString(product, ['manufacturer', 'producer', 'brand', 'company']) ||
    pickString(raw, ['manufacturer', 'producer', 'brand', 'company'])
  const description = pickString(raw, [
    'warning', 'description', 'reason', 'summary', 'text', 'content', 'detail',
  ])
  const link = pickString(raw, ['link', 'url', 'href', 'detailUrl'])
  const imageUrl = pickString(raw, ['image', 'imageUrl', 'image_url', 'thumbnail']) ||
    pickString(product, ['image', 'imageUrl'])
  const affectedStates = extractStates(raw)
  const severity = detectSeverity(raw, title, description)

  // Mindest-Datenqualität: ohne Titel oder ohne Datum überspringen
  if (!title || !publishedDate) return null

  return {
    id: id || `${title}-${publishedDate}`,
    title,
    publishedDate,
    productName: productName || title,
    manufacturer: manufacturer || 'Unbekannt',
    description,
    affectedStates,
    imageUrl: imageUrl || undefined,
    link: link || undefined,
    severity,
  }
}

function isWithinRecentWindow(iso: string, days: number): boolean {
  const ts = Date.parse(iso)
  if (Number.isNaN(ts)) return false
  return Date.now() - ts <= days * 24 * 60 * 60 * 1000
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function extractWarningArray(payload: any): unknown[] {
  if (Array.isArray(payload)) return payload
  if (payload && typeof payload === 'object') {
    for (const key of ['warnings', 'data', 'results', 'items', 'content', 'entries']) {
      const v = payload[key]
      if (Array.isArray(v)) return v
    }
  }
  return []
}

async function fetchEndpoint(url: string): Promise<unknown[]> {
  // `next: { revalidate }` greift im Server-Kontext (App Router fetch-Cache),
  // wird im Browser von Next stillschweigend ignoriert.
  const res = await fetch(url, {
    headers: { Accept: 'application/json' },
    next: { revalidate: 7200 },
  })
  if (!res.ok) throw new Error(`${res.status} ${url}`)
  const data = await res.json()
  return extractWarningArray(data)
}

function readClientCache(): FoodWarning[] | null {
  if (memoryCache && Date.now() - memoryCache.timestamp < CACHE_TTL_MS) {
    return memoryCache.data
  }
  if (typeof window === 'undefined') return null
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { data: FoodWarning[]; timestamp: number }
    if (Date.now() - parsed.timestamp < CACHE_TTL_MS) {
      memoryCache = parsed
      return parsed.data
    }
  } catch {
    // ignore parse / storage errors
  }
  return null
}

function writeClientCache(data: FoodWarning[]) {
  const entry = { data, timestamp: Date.now() }
  memoryCache = entry
  if (typeof window === 'undefined') return
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(entry))
  } catch {
    // localStorage kann voll oder gesperrt sein – egal, In-Memory reicht.
  }
}

/**
 * Lädt aktuelle Lebensmittel- und Produktwarnungen.
 *
 * - Greift zuerst auf den Bayern-Aggregat-Feed zu, fällt bei Fehler auf
 *   den `bund.dev`-Mirror zurück.
 * - Filtert auf die letzten 30 Tage.
 * - Cached das Ergebnis 2 Stunden in Memory + (clientseitig) localStorage.
 * - Wirft NIE – im Fehlerfall wird `[]` zurückgegeben.
 */
export async function fetchFoodWarnings(
  options: FetchFoodWarningsOptions = {},
): Promise<FoodWarning[]> {
  const limit = Math.max(1, options.limit ?? DEFAULT_LIMIT)

  const cached = readClientCache()
  if (cached) return cached.slice(0, limit)

  if (inflight) {
    const data = await inflight
    return data.slice(0, limit)
  }

  inflight = (async () => {
    const queryString = '?food=true&product=true&sort=publishedDate&order=desc&rows=50&start=0'
    const endpoints = [`${PRIMARY_ENDPOINT}${queryString}`, FALLBACK_ENDPOINT]

    let raw: unknown[] = []
    for (const url of endpoints) {
      try {
        raw = await fetchEndpoint(url)
        if (raw.length) break
      } catch {
        // Nächsten Endpunkt versuchen
      }
    }

    const mapped: FoodWarning[] = []
    const seen = new Set<string>()
    for (const item of raw) {
      const w = mapToFoodWarning(item)
      if (!w) continue
      if (!isWithinRecentWindow(w.publishedDate, RECENT_WINDOW_DAYS)) continue
      if (seen.has(w.id)) continue
      seen.add(w.id)
      mapped.push(w)
    }
    mapped.sort((a, b) => Date.parse(b.publishedDate) - Date.parse(a.publishedDate))

    writeClientCache(mapped)
    return mapped
  })()

  try {
    const data = await inflight
    return data.slice(0, limit)
  } catch {
    return []
  } finally {
    inflight = null
  }
}

/**
 * Prüft ob eine Warnung für das Bundesland des Users relevant ist.
 *
 * Match-Strategie:
 *  1. Warnung hat keine `affectedStates` → bundesweit relevant.
 *  2. Warnung enthält "bundesweit" / "Deutschland" → bundesweit relevant.
 *  3. User-State (mit Aliassen) kommt in einem `affectedStates`-Eintrag vor.
 */
export function isRelevantForState(warning: FoodWarning, userState: string): boolean {
  const stateInput = (userState ?? '').trim().toLowerCase()
  if (!stateInput) return true

  const states = warning.affectedStates ?? []
  if (states.length === 0) return true

  const haystack = states.map(s => s.toLowerCase()).join(' | ')

  // 2. Bundesweit?
  if (NATIONWIDE_TOKENS.some(t => haystack.includes(t))) return true

  // 3. Direkt-Match oder Alias-Match
  const aliases = new Set<string>([stateInput])
  for (const [canonical, list] of Object.entries(STATE_ALIASES)) {
    if (list.includes(stateInput) || canonical.toLowerCase() === stateInput) {
      list.forEach(a => aliases.add(a))
      aliases.add(canonical.toLowerCase())
    }
  }
  // Auch grobe Substring-Matches: User schreibt "München, Bayern" → matcht "Bayern"
  for (const alias of aliases) {
    if (haystack.includes(alias)) return true
  }
  return false
}

/** Setzt den modulinternen Cache zurück (Tests / manueller Refresh). */
export function clearFoodWarningsCache() {
  memoryCache = null
  if (typeof window !== 'undefined') {
    try { window.localStorage.removeItem(STORAGE_KEY) } catch { /* noop */ }
  }
}
