// ── Koordinaten-Formatierung ──────────────────────────────────────────────────

/**
 * Formatiert Koordinaten als kompakten deutschen String.
 * Beispiel: "48,1374° N, 11,5755° O"
 */
export function formatCoordinates(lat: number, lng: number): string {
  const latDir = lat >= 0 ? 'N' : 'S'
  const lngDir = lng >= 0 ? 'O' : 'W'
  const fmtLat = Math.abs(lat).toLocaleString('de-DE', {
    minimumFractionDigits: 4,
    maximumFractionDigits: 4,
  })
  const fmtLng = Math.abs(lng).toLocaleString('de-DE', {
    minimumFractionDigits: 4,
    maximumFractionDigits: 4,
  })
  return `${fmtLat}° ${latDir}, ${fmtLng}° ${lngDir}`
}

/**
 * Gibt Lat/Lng als separate formatierte Strings zurück.
 * Nützlich für aria-labels und Tooltips.
 */
export function formatLatLng(
  lat: number,
  lng: number,
): { lat: string; lng: string } {
  const latDir = lat >= 0 ? 'N' : 'S'
  const lngDir = lng >= 0 ? 'O' : 'W'
  return {
    lat: `${Math.abs(lat).toLocaleString('de-DE', { maximumFractionDigits: 4 })}° ${latDir}`,
    lng: `${Math.abs(lng).toLocaleString('de-DE', { maximumFractionDigits: 4 })}° ${lngDir}`,
  }
}
