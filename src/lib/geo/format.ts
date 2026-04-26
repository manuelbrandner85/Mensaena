// ── Koordinaten-Formatierung ──────────────────────────────────────────────────

/**
 * Formatiert Koordinaten als kompakten String.
 * Beispiel: formatCoordinates(52.520, 13.405, 3) → "52.520°N, 13.405°E"
 *
 * @param lat       Breitengrad
 * @param lng       Längengrad
 * @param precision Nachkommastellen (Default: 4)
 */
export function formatCoordinates(
  lat: number,
  lng: number,
  precision: number = 4,
): string {
  const latDir = lat >= 0 ? 'N' : 'S'
  const lngDir = lng >= 0 ? 'E' : 'W'
  const fmtLat = Math.abs(lat).toFixed(precision)
  const fmtLng = Math.abs(lng).toFixed(precision)
  return `${fmtLat}°${latDir}, ${fmtLng}°${lngDir}`
}

/**
 * Gibt Lat/Lng als zusammengesetzten String zurück.
 * Beispiel: formatLatLng(52.52, 13.41) → "52.52, 13.41"
 */
export function formatLatLng(lat: number, lng: number): string {
  return `${lat.toFixed(2)}, ${lng.toFixed(2)}`
}
