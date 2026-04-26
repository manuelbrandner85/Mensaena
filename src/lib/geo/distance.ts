// ── Distanz-Hilfsfunktionen ───────────────────────────────────────────────────

/**
 * Haversine-Großkreisentfernung zwischen zwei WGS-84-Punkten.
 * Rückgabe in Metern.
 */
export function haversineDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6_371_000 // Erdradius in Metern
  const toRad = (deg: number) => (deg * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

/**
 * Formatiert eine Entfernung in Metern als lesbaren deutschen String.
 * < 1 000 m → "350 m"
 * ≥ 1 000 m → "1,2 km"
 */
export function formatDistance(meters: number): string {
  if (meters < 1_000) {
    return `${Math.round(meters)} m`
  }
  const km = meters / 1_000
  return `${km.toLocaleString('de-DE', { maximumFractionDigits: 1 })} km`
}

export interface HasCoords {
  lat: number
  lng: number
}

/**
 * Sortiert ein Array von Objekten aufsteigend nach Entfernung zum Referenzpunkt.
 *
 * @param items    Zu sortierende Elemente
 * @param lat      Referenz-Breitengrad
 * @param lng      Referenz-Längengrad
 * @param getCoords  Funktion die lat/lng aus einem Element extrahiert;
 *                   gibt null/undefined zurück wenn keine Koordinaten vorhanden →
 *                   solche Elemente werden ans Ende sortiert.
 */
export function sortByDistance<T>(
  items: T[],
  lat: number,
  lng: number,
  getCoords: (item: T) => HasCoords | null | undefined,
): T[] {
  return [...items].sort((a, b) => {
    const ca = getCoords(a)
    const cb = getCoords(b)
    if (!ca && !cb) return 0
    if (!ca) return 1
    if (!cb) return -1
    return (
      haversineDistance(lat, lng, ca.lat, ca.lng) -
      haversineDistance(lat, lng, cb.lat, cb.lng)
    )
  })
}
