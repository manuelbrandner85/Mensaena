// ── Region-basiertes API-Routing ──────────────────────────────────────────────
// Bestimmt anhand des GeoContext, welche externen Datenquellen für eine Region
// verfügbar sind. Komponenten lesen diese Konfiguration und blenden Features
// aus, die im aktuellen Land nicht unterstützt werden.

import type { GeoContext, SupportedCountry } from '@/lib/geo/country-detect'

// ── Typen ─────────────────────────────────────────────────────────────────────

export type WeatherSource = 'open-meteo' | 'brightsky'
export type WarningSource = 'nina' | 'meteoalarm' | 'dwd'
export type HolidayApi = 'nager-date' | 'feiertage-api'

export interface ApiAvailability {
  weather: { primary: WeatherSource; fallback?: WeatherSource }
  warnings: { sources: WarningSource[] }
  foodWarnings: boolean
  wasteCalendar: boolean
  holidays: { api: HolidayApi; countryCode: string }
  airQuality: boolean
  pollen: boolean
  waterLevels: boolean
  radiation: boolean
  autobahn: boolean
  news: { source: string }
}

// ── Default-Profil (WORLD) ────────────────────────────────────────────────────

function worldDefaults(countryCode: string): ApiAvailability {
  return {
    weather:      { primary: 'open-meteo' },
    warnings:     { sources: [] },
    foodWarnings: false,
    wasteCalendar: false,
    holidays:     { api: 'nager-date', countryCode },
    airQuality:   true,
    pollen:       false,
    waterLevels:  false,
    radiation:    false,
    autobahn:     false,
    news:         { source: 'none' },
  }
}

// ── Kern-Logik ────────────────────────────────────────────────────────────────

/**
 * Liefert die API-Verfügbarkeit für den gegebenen GeoContext.
 *
 * Verfügbarkeitsmatrix:
 *  - DE     → Vollausstattung (NINA, DWD/Bright Sky, Pegelonline, BfS, Autobahn,
 *             Tagesschau, Lebensmittelwarnung, Abfallnavi, Pollen, Luftqualität)
 *  - AT/CH  → MeteoAlarm, Open-Meteo, Feiertage, Luftqualität, Pollen (AT)
 *  - EU     → MeteoAlarm, RASFF, Open-Meteo, Feiertage, Luftqualität
 *  - WORLD  → Open-Meteo, Nager.Date Feiertage
 */
export function getApiAvailability(ctx: GeoContext): ApiAvailability {
  const level: SupportedCountry = ctx.supportLevel
  const cc = ctx.countryCode

  switch (level) {
    case 'DE':
      return {
        weather:      { primary: 'brightsky', fallback: 'open-meteo' },
        warnings:     { sources: ['nina', 'meteoalarm', 'dwd'] },
        foodWarnings: true,
        wasteCalendar: true,
        holidays:     { api: 'feiertage-api', countryCode: 'DE' },
        airQuality:   true,
        pollen:       true,
        waterLevels:  true,
        radiation:    true,
        autobahn:     true,
        news:         { source: 'tagesschau' },
      }

    case 'AT':
      return {
        weather:      { primary: 'open-meteo' },
        warnings:     { sources: ['meteoalarm'] },
        foodWarnings: false,
        wasteCalendar: false,
        holidays:     { api: 'nager-date', countryCode: 'AT' },
        airQuality:   true,
        pollen:       true,
        waterLevels:  false,
        radiation:    false,
        autobahn:     false,
        news:         { source: 'none' },
      }

    case 'CH':
      return {
        weather:      { primary: 'open-meteo' },
        warnings:     { sources: ['meteoalarm'] },
        foodWarnings: false,
        wasteCalendar: false,
        holidays:     { api: 'nager-date', countryCode: 'CH' },
        airQuality:   true,
        pollen:       false,
        waterLevels:  false,
        radiation:    false,
        autobahn:     false,
        news:         { source: 'none' },
      }

    case 'EU':
      return {
        weather:      { primary: 'open-meteo' },
        warnings:     { sources: ['meteoalarm'] },
        foodWarnings: true, // RASFF EU-weit, sofern erreichbar
        wasteCalendar: false,
        holidays:     { api: 'nager-date', countryCode: cc },
        airQuality:   true,
        pollen:       false,
        waterLevels:  false,
        radiation:    false,
        autobahn:     false,
        news:         { source: 'none' },
      }

    case 'WORLD':
    default:
      return worldDefaults(cc)
  }
}

/**
 * Prüft ob ein Feature im aktuellen Kontext aktiviert ist.
 * Sicherheitsnetz: ohne Context wird konservativ false zurückgegeben.
 */
export function isFeatureAvailable(
  ctx: GeoContext | null,
  feature:
    | 'foodWarnings'
    | 'wasteCalendar'
    | 'pollen'
    | 'waterLevels'
    | 'radiation'
    | 'autobahn'
    | 'airQuality',
): boolean {
  if (!ctx) return false
  const avail = getApiAvailability(ctx)
  return Boolean(avail[feature])
}
