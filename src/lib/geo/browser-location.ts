'use client'

// ── Browser Geolocation Wrapper ───────────────────────────────────────────────
// Kapselt die native Geolocation API mit TypeScript-freundlichem Interface,
// vernünftigen Defaults und deutschen Fehlermeldungen.

export interface GeoPosition {
  lat:      number
  lng:      number
  accuracy: number   // Meter
  altitude: number | null
  timestamp: number
}

export interface GeoError {
  code:    1 | 2 | 3  // PERMISSION_DENIED | POSITION_UNAVAILABLE | TIMEOUT
  message: string
}

const DEFAULT_OPTIONS: PositionOptions = {
  enableHighAccuracy: true,
  timeout:            10_000,
  maximumAge:         60_000, // 1 Minute Cache
}

function toGeoPosition(pos: GeolocationPosition): GeoPosition {
  return {
    lat:       pos.coords.latitude,
    lng:       pos.coords.longitude,
    accuracy:  pos.coords.accuracy,
    altitude:  pos.coords.altitude,
    timestamp: pos.timestamp,
  }
}

function toGeoError(err: GeolocationPositionError): GeoError {
  const messages: Record<number, string> = {
    1: 'Standortzugriff verweigert. Bitte erlaube den Zugriff in deinen Browser-Einstellungen.',
    2: 'Standort konnte nicht ermittelt werden. Bitte prüfe deine Verbindung.',
    3: 'Standortabfrage hat zu lange gedauert. Versuche es erneut.',
  }
  return {
    code:    err.code as 1 | 2 | 3,
    message: messages[err.code] ?? 'Unbekannter Standortfehler.',
  }
}

/**
 * Einmalige Standortabfrage.
 * Gibt `GeoPosition` bei Erfolg, `GeoError` bei Fehler zurück.
 */
export function getCurrentPosition(
  options?: PositionOptions,
): Promise<GeoPosition> {
  return new Promise((resolve, reject) => {
    if (typeof window === 'undefined' || !('geolocation' in navigator)) {
      reject({
        code: 2,
        message: 'Geolocation wird von diesem Browser nicht unterstützt.',
      } satisfies GeoError)
      return
    }
    navigator.geolocation.getCurrentPosition(
      pos  => resolve(toGeoPosition(pos)),
      err  => reject(toGeoError(err)),
      { ...DEFAULT_OPTIONS, ...options },
    )
  })
}

/**
 * Kontinuierliche Standortüberwachung.
 * Gibt eine Cleanup-Funktion zurück (stoppt das Watching).
 *
 * @param onPosition  Callback bei neuer Position
 * @param onError     Callback bei Fehler (optional)
 * @param options     PositionOptions Overrides
 */
export function watchPosition(
  onPosition: (pos: GeoPosition) => void,
  onError?:   (err: GeoError) => void,
  options?:   PositionOptions,
): () => void {
  if (typeof window === 'undefined' || !('geolocation' in navigator)) {
    onError?.({
      code: 2,
      message: 'Geolocation wird von diesem Browser nicht unterstützt.',
    })
    return () => { /* noop */ }
  }

  const watchId = navigator.geolocation.watchPosition(
    pos => onPosition(toGeoPosition(pos)),
    err => onError?.(toGeoError(err)),
    { ...DEFAULT_OPTIONS, maximumAge: 5_000, ...options },
  )

  return () => navigator.geolocation.clearWatch(watchId)
}
