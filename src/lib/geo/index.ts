// ── Geo-Utility Library – zentraler Re-Export ─────────────────────────────────

export {
  haversineDistance,
  formatDistance,
  sortByDistance,
  type HasCoords,
} from './distance'

export {
  detectCountryFromBounds,
  getGeoContext,
  getGeoContextFromPlz,
  type GeoContext,
  type SupportedCountry,
} from './country-detect'

export {
  plzToBundesland,
  coordsToBundesland,
  plzToAgs,
  bundeslandToRegionId,
  type BundeslandCode,
} from './plz-mapping'

export {
  isInBoundingBox,
  COUNTRY_BOUNDS,
  type CountryBounds,
} from './bounds'

export {
  formatCoordinates,
  formatLatLng,
} from './format'

export {
  getCurrentPosition,
  watchPosition,
  type GeoPosition,
  type GeoError,
} from './browser-location'

// Legacy-Exports (haversine.ts – gibt Distanz in km zurück)
export { haversineDistance as haversineDistanceKm, formatDistance as formatDistanceKm } from './haversine'
export { createRateLimiter, type RateLimiter } from './rate-limiter'
