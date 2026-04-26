// ── Ländererkennung und GeoContext ────────────────────────────────────────────
// Zwei-Stufen-Strategie:
//  1) detectCountryFromBounds — instant, offline, via COUNTRY_BOUNDS
//  2) detectCountryFromNominatim — Fallback bei nicht erkannten Punkten,
//     Reverse-Geocoding via OpenStreetMap Nominatim (1 req/s, 24 h Cache)
//
// getGeoContext() liefert das vollständige Profil (countryCode, countryName,
// supportLevel, bundesland, isEU) und ist der zentrale Einstiegspunkt für
// regionsabhängige Features.

import { COUNTRY_BOUNDS, getContainingCountries, isInBoundingBox } from './bounds'
import { coordsToBundesland, plzToBundesland } from './plz-mapping'
import type { BundeslandCode } from './plz-mapping'

// ── Typen ─────────────────────────────────────────────────────────────────────

/**
 * Support-Stufe einer Region. Steuert welche Features aktiviert werden.
 *  - DE     → Vollausstattung (NINA, DWD/Bright Sky, Pegelonline, Tagesschau …)
 *  - AT/CH  → DACH-Set (MeteoAlarm, Open-Meteo, Feiertage, Luftqualität …)
 *  - EU     → EU-Set (MeteoAlarm, RASFF, Open-Meteo, Feiertage)
 *  - WORLD  → Basis (Open-Meteo, Nager.Date)
 */
export type SupportedCountry = 'DE' | 'AT' | 'CH' | 'EU' | 'WORLD'

export interface GeoContext {
  /** ISO-3166-1 Alpha-2, z. B. 'DE' */
  countryCode: string
  /** Lokalisierter Ländername, z. B. 'Deutschland' */
  countryName: string
  /** Support-Tier für Feature-Routing */
  supportLevel: SupportedCountry
  /** Deutsches Bundesland (nur bei countryCode === 'DE') */
  bundesland?: BundeslandCode
  /** Ist das Land in der EU? */
  isEU: boolean
  /** Original-Koordinaten */
  lat: number
  lng: number
}

// ── EU-Mitgliedstaaten (ISO Alpha-2) ──────────────────────────────────────────

const EU_COUNTRIES: ReadonlySet<string> = new Set([
  'DE', 'AT', 'FR', 'IT', 'ES', 'PT', 'NL', 'BE', 'LU', 'IE', 'FI', 'SE',
  'DK', 'PL', 'CZ', 'SK', 'HU', 'RO', 'BG', 'HR', 'SI', 'EE', 'LV', 'LT',
  'MT', 'CY', 'GR',
])

// ── Lokalisierte Ländernamen (deutsch) ────────────────────────────────────────

const COUNTRY_NAMES_DE: Record<string, string> = {
  DE: 'Deutschland', AT: 'Österreich', CH: 'Schweiz', LI: 'Liechtenstein',
  FR: 'Frankreich', IT: 'Italien', ES: 'Spanien', PT: 'Portugal',
  NL: 'Niederlande', BE: 'Belgien', LU: 'Luxemburg', IE: 'Irland',
  FI: 'Finnland', SE: 'Schweden', DK: 'Dänemark', PL: 'Polen',
  CZ: 'Tschechien', SK: 'Slowakei', HU: 'Ungarn', RO: 'Rumänien',
  BG: 'Bulgarien', HR: 'Kroatien', SI: 'Slowenien', EE: 'Estland',
  LV: 'Lettland', LT: 'Litauen', MT: 'Malta', CY: 'Zypern', GR: 'Griechenland',
  GB: 'Vereinigtes Königreich', NO: 'Norwegen', IS: 'Island',
  US: 'Vereinigte Staaten', CA: 'Kanada',
}

// ── Priorität bei überlappenden Bounding Boxes ────────────────────────────────
// Kleinere/eingeschlossene Länder zuerst, damit z. B. LU vor DE/BE/FR gewinnt.
const BOUNDS_PRIORITY = [
  'LU', 'BE', 'CH', 'AT', 'NL', 'CZ', 'DK', 'PL', 'IT', 'FR', 'DE',
] as const

// ── Caching für Nominatim ─────────────────────────────────────────────────────

const NOMINATIM_CACHE_KEY_PREFIX = 'mensaena_nominatim_country_'
const NOMINATIM_CACHE_TTL_MS = 24 * 60 * 60 * 1000 // 24 h
const NOMINATIM_TIMEOUT_MS = 8_000
const NOMINATIM_MIN_INTERVAL_MS = 1_100 // Nominatim Usage Policy: 1 req/s

let lastNominatimAt = 0

interface NominatimCacheEntry {
  countryCode: string
  cachedAt: number
}

function readNominatimCache(lat: number, lng: number): string | null {
  if (typeof window === 'undefined') return null
  try {
    const key = `${NOMINATIM_CACHE_KEY_PREFIX}${lat.toFixed(2)}_${lng.toFixed(2)}`
    const raw = window.localStorage.getItem(key)
    if (!raw) return null
    const parsed = JSON.parse(raw) as NominatimCacheEntry
    if (Date.now() - parsed.cachedAt > NOMINATIM_CACHE_TTL_MS) return null
    return parsed.countryCode
  } catch {
    return null
  }
}

function writeNominatimCache(lat: number, lng: number, countryCode: string): void {
  if (typeof window === 'undefined') return
  try {
    const key = `${NOMINATIM_CACHE_KEY_PREFIX}${lat.toFixed(2)}_${lng.toFixed(2)}`
    const entry: NominatimCacheEntry = { countryCode, cachedAt: Date.now() }
    window.localStorage.setItem(key, JSON.stringify(entry))
  } catch {
    /* QuotaExceeded oder Privatmodus – ignorieren */
  }
}

// ── Hilfsfunktionen ───────────────────────────────────────────────────────────

function deriveSupportLevel(countryCode: string): SupportedCountry {
  if (countryCode === 'DE') return 'DE'
  if (countryCode === 'AT') return 'AT'
  if (countryCode === 'CH') return 'CH'
  if (EU_COUNTRIES.has(countryCode)) return 'EU'
  return 'WORLD'
}

function getCountryName(countryCode: string): string {
  return COUNTRY_NAMES_DE[countryCode] ?? countryCode
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Erkennt das Land instant und offline aus den Bounding Boxes.
 * Liefert null wenn der Punkt außerhalb aller bekannten Boxen liegt.
 */
export function detectCountryFromBounds(
  lat: number,
  lng: number,
): string | null {
  for (const code of BOUNDS_PRIORITY) {
    const bounds = COUNTRY_BOUNDS[code]
    if (bounds && isInBoundingBox(lat, lng, bounds)) return code
  }
  // Fallback: irgendein Treffer, der nicht in der Priorität-Liste steht
  const others = getContainingCountries(lat, lng)
  return others[0] ?? null
}

/**
 * Reverse-Geocoding via OpenStreetMap Nominatim.
 * Drosselt auf 1 req/s (Usage Policy) und cached die Antwort 24 h
 * in localStorage (Schlüssel auf 2 Nachkommastellen gerundet).
 *
 * @returns ISO-Alpha-2 Ländercode (Großbuchstaben). Bei Fehler 'XX'.
 */
export async function detectCountryFromNominatim(
  lat: number,
  lng: number,
): Promise<string> {
  const cached = readNominatimCache(lat, lng)
  if (cached) return cached

  const wait = NOMINATIM_MIN_INTERVAL_MS - (Date.now() - lastNominatimAt)
  if (wait > 0) await new Promise(r => setTimeout(r, wait))
  lastNominatimAt = Date.now()

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), NOMINATIM_TIMEOUT_MS)

  try {
    const url =
      `https://nominatim.openstreetmap.org/reverse` +
      `?lat=${lat}&lon=${lng}&format=json&accept-language=de&zoom=3`
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)',
        Accept: 'application/json',
      },
    })
    if (!res.ok) return 'XX'
    const data = (await res.json()) as { address?: { country_code?: string } }
    const code = (data.address?.country_code ?? 'XX').toUpperCase()
    writeNominatimCache(lat, lng, code)
    return code
  } catch {
    return 'XX'
  } finally {
    clearTimeout(timeoutId)
  }
}

/**
 * Liefert den vollständigen GeoContext für einen Koordinatenpunkt.
 * Strategie: Bounding-Box zuerst (instant, offline), Nominatim als Fallback.
 */
export async function getGeoContext(
  lat: number,
  lng: number,
): Promise<GeoContext> {
  let countryCode = detectCountryFromBounds(lat, lng)
  if (!countryCode) {
    countryCode = await detectCountryFromNominatim(lat, lng)
  }
  const cc = countryCode === 'XX' ? 'XX' : countryCode
  const supportLevel = deriveSupportLevel(cc)
  const bundesland: BundeslandCode | undefined =
    cc === 'DE' ? coordsToBundesland(lat, lng) : undefined

  return {
    countryCode: cc,
    countryName: getCountryName(cc),
    supportLevel,
    ...(bundesland ? { bundesland } : {}),
    isEU: EU_COUNTRIES.has(cc),
    lat,
    lng,
  }
}

/**
 * GeoContext aus einer deutschen PLZ ableiten.
 * Praktisch für Onboarding/Profilformulare ohne Browser-Geolocation.
 */
export function getGeoContextFromPlz(
  plz: string,
): Pick<GeoContext, 'countryCode' | 'countryName' | 'supportLevel' | 'bundesland' | 'isEU'> {
  const bundesland = plzToBundesland(plz)
  const isGermany = bundesland !== 'NATIONAL'
  return {
    countryCode: isGermany ? 'DE' : 'XX',
    countryName: isGermany ? 'Deutschland' : 'Unbekannt',
    supportLevel: isGermany ? 'DE' : 'WORLD',
    ...(isGermany ? { bundesland } : {}),
    isEU: isGermany,
  }
}
