// ── PLZ / Bundesland / AGS / Tagesschau-Region Mapping (Deutschland) ──────────
// Quelle der Wahrheit für die Bundesland-Heuristik. Alle anderen Module
// importieren von hier, damit es genau eine Implementierung gibt.

// ── Bundesland-Codes ─────────────────────────────────────────────────────────

export type BundeslandCode =
  | 'BW' | 'BY' | 'BE' | 'BB' | 'HB' | 'HH'
  | 'HE' | 'MV' | 'NI' | 'NW' | 'RP' | 'SL'
  | 'SN' | 'ST' | 'SH' | 'TH' | 'NATIONAL'

// ── Bundesland-Metadaten ─────────────────────────────────────────────────────

export const BUNDESLAND_NAMES: Record<BundeslandCode, string> = {
  BW:        'Baden-Württemberg',
  BY:        'Bayern',
  BE:        'Berlin',
  BB:        'Brandenburg',
  HB:        'Bremen',
  HH:        'Hamburg',
  HE:        'Hessen',
  MV:        'Mecklenburg-Vorpommern',
  NI:        'Niedersachsen',
  NW:        'Nordrhein-Westfalen',
  RP:        'Rheinland-Pfalz',
  SL:        'Saarland',
  SN:        'Sachsen',
  ST:        'Sachsen-Anhalt',
  SH:        'Schleswig-Holstein',
  TH:        'Thüringen',
  NATIONAL:  'Deutschland (bundesweit)',
}

// ── PLZ → Bundesland Mapping ─────────────────────────────────────────────────

/**
 * Heuristische Zuordnung der ersten 1-2 PLZ-Ziffern zu Bundesländern.
 * Quelle: Deutsche Post Leitzonen.
 *
 * Einzelne Grenzfälle (PLZ-Bereiche an Bundeslandgrenzen) können falsch sein,
 * decken aber den überwiegenden Teil korrekt ab.
 */
function plzPrefixToBundesland(plz: string): BundeslandCode | null {
  const trimmed = plz.replace(/\s/g, '')
  if (trimmed.length < 2) return null

  const firstTwo = parseInt(trimmed.slice(0, 2), 10)
  if (isNaN(firstTwo)) return null

  if (firstTwo >= 1 && firstTwo <= 9)  return 'SN'
  if (firstTwo === 10 || firstTwo === 12 || firstTwo === 13) return 'BE'
  if (firstTwo === 14)                                       return 'BB'
  if (firstTwo >= 15 && firstTwo <= 16) return 'BB'
  if (firstTwo >= 17 && firstTwo <= 19) return 'MV'
  if (firstTwo >= 20 && firstTwo <= 21) return 'HH'
  if (firstTwo === 22)                  return 'HH'
  if (firstTwo >= 23 && firstTwo <= 25) return 'SH'
  if (firstTwo === 26 || firstTwo === 27) return 'NI'
  if (firstTwo === 28)                  return 'HB'
  if (firstTwo >= 29 && firstTwo <= 31) return 'NI'
  if (firstTwo >= 32 && firstTwo <= 33) return 'NW'
  if (firstTwo === 34)                  return 'HE'
  if (firstTwo === 35)                  return 'HE'
  if (firstTwo === 36)                  return 'HE'
  if (firstTwo >= 37 && firstTwo <= 38) return 'NI'
  if (firstTwo === 39)                  return 'ST'
  if (firstTwo >= 40 && firstTwo <= 48) return 'NW'
  if (firstTwo === 49)                  return 'NI'
  if (firstTwo >= 50 && firstTwo <= 51) return 'NW'
  if (firstTwo === 52)                  return 'NW'
  if (firstTwo === 53)                  return 'NW'
  if (firstTwo >= 54 && firstTwo <= 56) return 'RP'
  if (firstTwo === 57)                  return 'NW'
  if (firstTwo >= 58 && firstTwo <= 59) return 'NW'
  if (firstTwo >= 60 && firstTwo <= 65) return 'HE'
  if (firstTwo === 66)                  return 'SL'
  if (firstTwo >= 67 && firstTwo <= 68) return 'RP'
  if (firstTwo === 68)                  return 'BW'
  if (firstTwo >= 69 && firstTwo <= 79) return 'BW'
  if (firstTwo >= 80 && firstTwo <= 87) return 'BY'
  if (firstTwo === 88)                  return 'BW'
  if (firstTwo >= 89 && firstTwo <= 96) return 'BY'
  if (firstTwo >= 97 && firstTwo <= 97) return 'BY'
  if (firstTwo >= 98 && firstTwo <= 99) return 'TH'

  return null
}

/**
 * PLZ → Bundesland-Code.
 * Gibt 'NATIONAL' zurück wenn keine eindeutige Zuordnung möglich ist.
 */
export function plzToBundesland(plz: string | null | undefined): BundeslandCode {
  if (!plz) return 'NATIONAL'
  return plzPrefixToBundesland(plz) ?? 'NATIONAL'
}

/**
 * Bundesland aus Koordinaten – grobe Bounding-Box-Heuristik.
 * Fallback wenn keine PLZ verfügbar ist (z. B. nur lat/lng aus Geolocation).
 */
export function coordsToBundesland(lat: number, lon: number): BundeslandCode {
  // Stadtstaaten zuerst (klein, exakt prüfen)
  if (lat >= 53.39 && lat <= 53.74 && lon >= 8.10 && lon <= 9.30) return 'HB'
  if (lat >= 53.39 && lat <= 53.74 && lon >= 9.71 && lon <= 10.33) return 'HH'
  if (lat >= 52.34 && lat <= 52.68 && lon >= 13.08 && lon <= 13.77) return 'BE'

  // Flächenstaaten – grobe Boxen
  if (lat >= 47.27 && lat <= 50.56 && lon >= 9.00 && lon <= 13.84) return 'BY'
  if (lat >= 47.53 && lat <= 49.79 && lon >= 7.51 && lon <= 10.50) return 'BW'
  if (lat >= 49.11 && lat <= 50.94 && lon >= 8.00 && lon <= 10.24) return 'HE'
  if (lat >= 50.32 && lat <= 51.65 && lon >= 5.86 && lon <= 9.46)  return 'NW'
  if (lat >= 49.11 && lat <= 50.94 && lon >= 6.11 && lon <= 8.51)  return 'RP'
  if (lat >= 49.11 && lat <= 49.64 && lon >= 6.36 && lon <= 7.40)  return 'SL'
  if (lat >= 51.32 && lat <= 53.89 && lon >= 6.65 && lon <= 11.59) return 'NI'
  if (lat >= 53.36 && lat <= 55.07 && lon >= 7.86 && lon <= 11.32) return 'SH'
  if (lat >= 53.10 && lat <= 54.71 && lon >= 10.59 && lon <= 14.41) return 'MV'
  if (lat >= 51.36 && lat <= 53.56 && lon >= 11.27 && lon <= 14.77) return 'BB'
  if (lat >= 50.17 && lat <= 51.69 && lon >= 11.87 && lon <= 15.04) return 'SN'
  if (lat >= 50.17 && lat <= 53.04 && lon >= 10.55 && lon <= 13.18) return 'ST'
  if (lat >= 50.20 && lat <= 51.65 && lon >= 9.87 && lon <= 12.66)  return 'TH'

  return 'NATIONAL'
}

// ── AGS Bundesland-Präfix (2-stelliger Amtlicher Gemeindeschlüssel) ──────────

const BUNDESLAND_TO_AGS: Record<BundeslandCode, string> = {
  SH: '01', HH: '02', NI: '03', HB: '04', NW: '05', HE: '06', RP: '07',
  BW: '08', BY: '09', SL: '10', BE: '11', BB: '12', MV: '13', SN: '14',
  ST: '15', TH: '16', NATIONAL: '00',
}

/**
 * Liefert das 2-stellige AGS-Präfix für eine PLZ.
 * Fällt auf '00' zurück wenn die PLZ nicht zugeordnet werden kann.
 */
export function plzToAgs(plz: string | null | undefined): string {
  const code = plzToBundesland(plz)
  return BUNDESLAND_TO_AGS[code] ?? '00'
}

// ── Tagesschau Regional-IDs ──────────────────────────────────────────────────

const BUNDESLAND_TO_REGION_ID: Record<BundeslandCode, number> = {
  BW: 1,  BY: 2,  BE: 3,  BB: 4,  HB: 5,  HH: 6,  HE: 7,  MV: 8,
  NI: 9,  NW: 10, RP: 11, SL: 12, SN: 13, ST: 14, SH: 15, TH: 16,
  NATIONAL: 0,
}

/**
 * Mappt einen BundeslandCode auf die Tagesschau-Regional-ID (1–16).
 * Liefert 0 für NATIONAL / unbekannte Bundesländer.
 */
export function bundeslandToRegionId(state: BundeslandCode): number {
  return BUNDESLAND_TO_REGION_ID[state] ?? 0
}
