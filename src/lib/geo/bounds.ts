// ── Bounding Boxes für europäische Länder ─────────────────────────────────────
// Koordinaten in WGS-84. Dienen zur schnellen (O(1)) Ländererkennung ohne
// externen API-Aufruf. Überlappungen (z. B. AT/CH/DE) werden in country-detect
// durch Priorisierung aufgelöst.

export interface CountryBounds {
  latMin: number
  latMax: number
  lngMin: number
  lngMax: number
}

export const COUNTRY_BOUNDS: Record<string, CountryBounds> = {
  DE: { latMin: 47.27, latMax: 55.06, lngMin:  5.87, lngMax: 15.04 },
  AT: { latMin: 46.37, latMax: 49.02, lngMin:  9.53, lngMax: 17.16 },
  CH: { latMin: 45.82, latMax: 47.81, lngMin:  5.96, lngMax: 10.49 },
  NL: { latMin: 50.75, latMax: 53.47, lngMin:  3.36, lngMax:  7.21 },
  BE: { latMin: 49.50, latMax: 51.50, lngMin:  2.55, lngMax:  6.40 },
  LU: { latMin: 49.45, latMax: 50.18, lngMin:  5.73, lngMax:  6.53 },
  PL: { latMin: 49.00, latMax: 54.83, lngMin: 14.12, lngMax: 24.15 },
  CZ: { latMin: 48.55, latMax: 51.06, lngMin: 12.09, lngMax: 18.86 },
  DK: { latMin: 54.56, latMax: 57.75, lngMin:  8.07, lngMax: 15.20 },
  FR: { latMin: 41.33, latMax: 51.12, lngMin: -5.14, lngMax:  9.56 },
  IT: { latMin: 36.65, latMax: 47.09, lngMin:  6.63, lngMax: 18.52 },
}

/**
 * Prüft ob ein Koordinatenpaar innerhalb einer Bounding Box liegt.
 */
export function isInBoundingBox(
  lat: number,
  lng: number,
  bounds: CountryBounds,
): boolean {
  return (
    lat >= bounds.latMin &&
    lat <= bounds.latMax &&
    lng >= bounds.lngMin &&
    lng <= bounds.lngMax
  )
}
