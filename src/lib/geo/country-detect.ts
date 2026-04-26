// ── Ländererkennung aus Koordinaten ──────────────────────────────────────────
// Rein lokal, kein API-Call. Nutzt COUNTRY_BOUNDS für O(1)-Lookup.
// Bei Überlappungen (z. B. AT/CH/DE Grenzregionen) wird nach Priorität entschieden.

import { COUNTRY_BOUNDS, isInBoundingBox } from './bounds'
import { plzToBundesland, coordsToBundesland } from './plz-mapping'
import type { BundeslandCode } from './plz-mapping'

// ── Typen ─────────────────────────────────────────────────────────────────────

export type SupportedCountry = 'DE' | 'AT' | 'CH' | 'NL' | 'BE' | 'LU' | 'PL' | 'CZ' | 'DK' | 'FR' | 'IT'

export interface GeoContext {
  /** ISO-3166-1 Alpha-2 Ländercode oder null wenn außerhalb aller Bounds */
  country:    SupportedCountry | null
  /** Bundesland-Code (nur für DE) */
  bundesland: BundeslandCode | null
  /** Koordinaten des Nutzers */
  lat:        number
  lng:        number
  /** Gibt an ob der Nutzer in Deutschland ist */
  isGermany:  boolean
  /** Gibt an ob der Nutzer im DACH-Raum ist */
  isDACH:     boolean
}

// ── Prioritätsliste bei überlappenden Bounding Boxes ─────────────────────────
// Kleinere Länder zuerst (LU < BE < CH < AT < NL < CZ < DK < PL < IT < FR < DE)
const PRIORITY: SupportedCountry[] = [
  'LU', 'BE', 'CH', 'AT', 'NL', 'CZ', 'DK', 'PL', 'IT', 'FR', 'DE',
]

/**
 * Erkennt das Land für einen Koordinatenpunkt anhand der Bounding Boxes.
 * Gibt `null` zurück wenn der Punkt außerhalb aller bekannten Grenzen liegt.
 */
export function detectCountryFromBounds(
  lat: number,
  lng: number,
): SupportedCountry | null {
  const matches = PRIORITY.filter(code => {
    const bounds = COUNTRY_BOUNDS[code]
    return bounds ? isInBoundingBox(lat, lng, bounds) : false
  })
  return matches[0] ?? null
}

/**
 * Gibt den vollständigen Geo-Kontext für einen Koordinatenpunkt zurück.
 * Inkl. Ländererkennung und Bundesland (für DE).
 */
export function getGeoContext(lat: number, lng: number): GeoContext {
  const country = detectCountryFromBounds(lat, lng)
  const isGermany = country === 'DE'
  const bundesland: BundeslandCode | null = isGermany
    ? coordsToBundesland(lat, lng)
    : null

  return {
    country,
    bundesland,
    lat,
    lng,
    isGermany,
    isDACH: country === 'DE' || country === 'AT' || country === 'CH',
  }
}

/**
 * Gibt den Geo-Kontext für eine PLZ zurück (nur DE).
 * Nützlich wenn keine Koordinaten, aber eine PLZ bekannt ist.
 */
export function getGeoContextFromPlz(plz: string): Pick<GeoContext, 'country' | 'bundesland' | 'isGermany' | 'isDACH'> {
  const bundesland = plzToBundesland(plz)
  const isGermany = bundesland !== 'NATIONAL'
  return {
    country:    isGermany ? 'DE' : null,
    bundesland: isGermany ? bundesland : null,
    isGermany,
    isDACH:     isGermany,
  }
}
