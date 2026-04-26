/**
 * Photon Geocoder – https://photon.komoot.io
 * No API key required. Free, OpenStreetMap-based.
 */

import { haversineDistance } from '@/lib/geo/haversine'

export interface PhotonResult {
  displayName: string
  street?: string
  housenumber?: string
  postcode?: string
  city?: string
  state?: string
  country?: string
  latitude: number
  longitude: number
}

interface PhotonFeature {
  type: 'Feature'
  geometry: { type: 'Point'; coordinates: [number, number] }
  properties: {
    name?: string
    street?: string
    housenumber?: string
    postcode?: string
    city?: string
    district?: string
    county?: string
    state?: string
    country?: string
    type?: string
    osm_type?: string
  }
}

interface PhotonResponse {
  type: 'FeatureCollection'
  features: PhotonFeature[]
}

let abortController: AbortController | null = null

function buildDisplayName(p: PhotonFeature['properties']): string {
  const parts: string[] = []

  // Name (only if distinct from street, e.g. POI name or city name)
  if (p.name && p.name !== p.street) {
    parts.push(p.name)
  }

  // Street + house number
  if (p.street) {
    parts.push([p.street, p.housenumber].filter(Boolean).join(' '))
  }

  // Postcode + city
  const cityPart = [p.postcode, p.city ?? p.county].filter(Boolean).join(' ')
  if (cityPart) parts.push(cityPart)

  // State (only if different from city, avoids "München, München")
  if (p.state && p.state !== p.city && p.state !== p.county) {
    parts.push(p.state)
  }

  return parts.length > 0 ? parts.join(', ') : (p.name ?? 'Unbekannter Ort')
}

export async function searchAddress(
  query: string,
  options?: { lat?: number; lon?: number; limit?: number; maxRadiusKm?: number },
): Promise<PhotonResult[]> {
  if (query.trim().length < 3) return []

  // Cancel any in-flight request
  abortController?.abort()
  abortController = new AbortController()

  const params = new URLSearchParams({
    q: query.trim(),
    lang: 'de',
    limit: String(options?.limit ?? 5),
  })
  if (options?.lat !== undefined) params.set('lat', String(options.lat))
  if (options?.lon !== undefined) params.set('lon', String(options.lon))

  const res = await fetch(`https://photon.komoot.io/api/?${params}`, {
    signal: abortController.signal,
    headers: { Accept: 'application/json' },
  })

  if (!res.ok) return []

  const json = (await res.json()) as PhotonResponse

  const results = (json.features ?? []).map((feature) => {
    const [lon, lat] = feature.geometry.coordinates
    const p = feature.properties
    return {
      displayName: buildDisplayName(p),
      street: p.street,
      housenumber: p.housenumber,
      postcode: p.postcode,
      city: p.city ?? p.county,
      state: p.state,
      country: p.country,
      latitude: lat,
      longitude: lon,
    }
  })

  if (options?.maxRadiusKm !== undefined && options.lat !== undefined && options.lon !== undefined) {
    const { maxRadiusKm, lat, lon } = options
    return results.filter(r => haversineDistance(lat, lon, r.latitude, r.longitude) <= maxRadiusKm)
  }

  return results
}
