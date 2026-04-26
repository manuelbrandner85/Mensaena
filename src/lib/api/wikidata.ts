// ─────────────────────────────────────────────────────────────────────────────
// Wikidata SPARQL API – Ortsinfo & "Wusstest du?"-Fakten
// https://query.wikidata.org/sparql
//
// Wikimedia TOS: User-Agent Header ist Pflicht.
// Stadtdaten ändern sich selten → 7-Tage localStorage-Cache.
// ─────────────────────────────────────────────────────────────────────────────

const SPARQL_ENDPOINT = 'https://query.wikidata.org/sparql'
const NOMINATIM_ENDPOINT = 'https://nominatim.openstreetmap.org'
const USER_AGENT = 'MensaEna/1.0 (https://www.mensaena.de)'
const TIMEOUT_MS = 10_000
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000 // 7 Tage

// ── Public Types ──────────────────────────────────────────────────────────────

export interface CityInfo {
  name:          string
  population:    number | null
  areaSqKm:      number | null
  mayorName:     string | null
  imageUrl:      string | null
  coatOfArmsUrl: string | null
  foundedYear:   number | null
  elevation:     number | null
  website:       string | null
  wikidataUrl:   string | null
}

// ── localStorage Cache ────────────────────────────────────────────────────────

interface CacheEntry<T> { data: T; ts: number }

function lsRead<T>(key: string): T | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry<T>
    if (Date.now() - ts < CACHE_TTL_MS) return data
    localStorage.removeItem(key)
  } catch { /* quota or parse */ }
  return null
}

function lsWrite<T>(key: string, data: T) {
  if (typeof window === 'undefined') return
  try {
    localStorage.setItem(key, JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry<T>))
  } catch { /* quota exceeded */ }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Mediawiki image CDN thumbnail URL from a raw Wikimedia Commons filename. */
function thumbUrl(rawUrl: string, width = 400): string {
  try {
    // e.g. http://commons.wikimedia.org/wiki/Special:FilePath/Foo.jpg
    const filename = decodeURIComponent(rawUrl.split('/').pop() ?? '')
    if (!filename) return rawUrl
    // MD5 hash prefix for cache path
    const encoder = new TextEncoder()
    const bytes    = encoder.encode(filename.replace(/ /g, '_'))
    // Simple djb2 to produce a stable hex-like prefix (browser-compatible, no crypto needed)
    let h = 5381
    for (const b of bytes) h = ((h << 5) + h + b) & 0xFFFFFFFF
    const hex  = Math.abs(h).toString(16).padStart(8, '0')
    const a    = hex[0]
    const ab   = hex.slice(0, 2)
    const safe = filename.replace(/ /g, '_')
    return `https://upload.wikimedia.org/wikipedia/commons/thumb/${a}/${ab}/${encodeURIComponent(safe)}/${width}px-${encodeURIComponent(safe)}`
  } catch {
    return rawUrl
  }
}

function sparqlValue(binding: Record<string, { value: string } | undefined>, key: string): string | null {
  return binding[key]?.value ?? null
}

function sparqlNumber(binding: Record<string, { value: string } | undefined>, key: string): number | null {
  const v = sparqlValue(binding, key)
  if (!v) return null
  const n = parseFloat(v)
  return isNaN(n) ? null : n
}

// ── SPARQL Queries ────────────────────────────────────────────────────────────

function buildCityQuery(cityName: string): string {
  // Sanitize: remove SPARQL injection chars
  const safe = cityName.replace(/['"\\]/g, '')
  return `
SELECT DISTINCT
  ?city ?cityLabel
  ?population ?area
  ?mayor ?mayorLabel
  ?image ?coat_of_arms
  ?founded ?elevation ?website
WHERE {
  {
    ?city wdt:P31/wdt:P279* wd:Q515 .
  } UNION {
    ?city wdt:P31 wd:Q22865 .
  } UNION {
    ?city wdt:P31 wd:Q42744322 .
  }
  ?city wdt:P17 wd:Q183 .
  ?city rdfs:label "${safe}"@de .

  OPTIONAL { ?city wdt:P1082 ?population }
  OPTIONAL { ?city wdt:P2046 ?area }
  OPTIONAL { ?city wdt:P6   ?mayor }
  OPTIONAL { ?city wdt:P18  ?image }
  OPTIONAL { ?city wdt:P94  ?coat_of_arms }
  OPTIONAL { ?city wdt:P571 ?founded }
  OPTIONAL { ?city wdt:P2044 ?elevation }
  OPTIONAL { ?city wdt:P856 ?website }

  SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en" }
}
ORDER BY DESC(?population)
LIMIT 1
`.trim()
}

// Austria + Switzerland fallback
function buildCityQueryDACH(cityName: string): string {
  const safe = cityName.replace(/['"\\]/g, '')
  return `
SELECT DISTINCT
  ?city ?cityLabel
  ?population ?area
  ?mayor ?mayorLabel
  ?image ?coat_of_arms
  ?founded ?elevation ?website
WHERE {
  {
    ?city wdt:P31/wdt:P279* wd:Q515 .
  } UNION {
    ?city wdt:P31 wd:Q22865 .
  }
  ?city wdt:P17 ?country .
  FILTER(?country IN (wd:Q183, wd:Q40, wd:Q39))
  ?city rdfs:label "${safe}"@de .

  OPTIONAL { ?city wdt:P1082 ?population }
  OPTIONAL { ?city wdt:P2046 ?area }
  OPTIONAL { ?city wdt:P6   ?mayor }
  OPTIONAL { ?city wdt:P18  ?image }
  OPTIONAL { ?city wdt:P94  ?coat_of_arms }
  OPTIONAL { ?city wdt:P571 ?founded }
  OPTIONAL { ?city wdt:P2044 ?elevation }
  OPTIONAL { ?city wdt:P856 ?website }

  SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en" }
}
ORDER BY DESC(?population)
LIMIT 1
`.trim()
}

// ── Fetch helpers ─────────────────────────────────────────────────────────────

async function runSparql(query: string): Promise<Record<string, { value: string } | undefined>[] | null> {
  try {
    const url = `${SPARQL_ENDPOINT}?query=${encodeURIComponent(query)}&format=json`
    const res = await fetch(url, {
      signal:  AbortSignal.timeout(TIMEOUT_MS),
      headers: {
        'User-Agent': USER_AGENT,
        'Accept':     'application/sparql-results+json',
      },
    })
    if (!res.ok) return null
    const json = (await res.json()) as {
      results: { bindings: Record<string, { value: string }>[] }
    }
    return json.results.bindings
  } catch {
    return null
  }
}

function parseBinding(
  row:  Record<string, { value: string } | undefined>,
  name: string,
): CityInfo {
  const cityUri = sparqlValue(row, 'city')
  const founded = sparqlNumber(row, 'founded')
  const rawImage = sparqlValue(row, 'image')
  const rawCoat  = sparqlValue(row, 'coat_of_arms')

  return {
    name:          sparqlValue(row, 'cityLabel') ?? name,
    population:    sparqlNumber(row, 'population'),
    areaSqKm:      sparqlNumber(row, 'area'),
    mayorName:     sparqlValue(row, 'mayorLabel'),
    imageUrl:      rawImage ? thumbUrl(rawImage, 600) : null,
    coatOfArmsUrl: rawCoat  ? thumbUrl(rawCoat, 200)  : null,
    foundedYear:   founded != null ? new Date(founded).getFullYear() : null,
    elevation:     sparqlNumber(row, 'elevation'),
    website:       sparqlValue(row, 'website'),
    wikidataUrl:   cityUri ? cityUri.replace('http://www.wikidata.org/entity/', 'https://www.wikidata.org/wiki/') : null,
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Lädt Ortsinformationen von Wikidata anhand eines Stadtnamens.
 * Probiert zuerst Deutschland, dann DACH-Fallback.
 * Ergebnis wird 7 Tage gecacht.
 */
export async function fetchCityInfo(cityName: string): Promise<CityInfo | null> {
  const name  = cityName.trim()
  if (!name)  return null
  const key   = `wikidata_city_${name.toLowerCase().replace(/\s+/g, '_')}`

  const cached = lsRead<CityInfo>(key)
  if (cached)  return cached

  // 1st try: Germany only
  let rows = await runSparql(buildCityQuery(name))

  // 2nd try: DACH (AT + CH fallback)
  if (!rows || rows.length === 0) {
    rows = await runSparql(buildCityQueryDACH(name))
  }

  if (!rows || rows.length === 0) {
    lsWrite(key, null)
    return null
  }

  const info = parseBinding(rows[0], name)
  lsWrite(key, info)
  return info
}

/**
 * Gibt einen tagesbasierten "Wusstest du?"-Fakt für eine Stadt zurück.
 * Rotiert täglich durch verfügbare Fakten.
 */
export async function fetchRandomFact(cityName: string): Promise<string | null> {
  const info = await fetchCityInfo(cityName)
  if (!info) return null

  const facts: string[] = []

  if (info.population != null) {
    facts.push(`In ${info.name} leben ${info.population.toLocaleString('de-DE')} Menschen.`)
  }
  if (info.foundedYear != null) {
    facts.push(`${info.name} wurde im Jahr ${info.foundedYear} gegründet – vor ${new Date().getFullYear() - info.foundedYear} Jahren.`)
  }
  if (info.areaSqKm != null) {
    facts.push(`${info.name} hat eine Fläche von ${Math.round(info.areaSqKm).toLocaleString('de-DE')} km².`)
  }
  if (info.mayorName != null) {
    facts.push(`Bürgermeister:in von ${info.name} ist ${info.mayorName}.`)
  }
  if (info.elevation != null) {
    facts.push(`${info.name} liegt auf einer Höhe von ${Math.round(info.elevation).toLocaleString('de-DE')} Metern über dem Meeresspiegel.`)
  }
  if (info.population != null && info.areaSqKm != null && info.areaSqKm > 0) {
    const density = Math.round(info.population / info.areaSqKm)
    facts.push(`In ${info.name} leben ${density.toLocaleString('de-DE')} Einwohner pro km².`)
  }

  if (facts.length === 0) return null

  // Tagesbasierter Seed (UTC day-of-year)
  const now = new Date()
  const dayOfYear = Math.floor(
    (now.getTime() - new Date(now.getUTCFullYear(), 0, 0).getTime()) / 86_400_000,
  )
  return facts[dayOfYear % facts.length]
}

/**
 * Ermittelt den Stadtnamen aus Koordinaten via Nominatim Reverse Geocoding.
 * Gibt null zurück wenn kein Ort gefunden.
 */
export async function getCityFromCoords(lat: number, lon: number): Promise<string | null> {
  const key = `nominatim_city_${Math.round(lat * 10) / 10}_${Math.round(lon * 10) / 10}`
  const cached = lsRead<string>(key)
  if (cached) return cached

  try {
    const url = `${NOMINATIM_ENDPOINT}/reverse?lat=${lat}&lon=${lon}&format=json&zoom=10&accept-language=de`
    const res = await fetch(url, {
      signal:  AbortSignal.timeout(5_000),
      headers: { 'User-Agent': USER_AGENT },
    })
    if (!res.ok) return null
    const json = (await res.json()) as {
      address?: {
        city?: string; town?: string; village?: string; county?: string; state?: string
      }
    }
    const city = json.address?.city ?? json.address?.town ?? json.address?.village ?? null
    if (city) lsWrite(key, city)
    return city
  } catch {
    return null
  }
}
