import { NextResponse } from 'next/server'

// Cached route responses — TTL 10 min
const ROUTE_CACHE = new Map<string, { data: unknown; expires: number }>()
const CACHE_TTL_MS = 10 * 60 * 1000

const ORS_BASE = 'https://api.openrouteservice.org'
const PROFILE_MAP: Record<string, string> = {
  car:  'driving-car',
  bike: 'cycling-regular',
  foot: 'foot-walking',
}

function getKey(): string {
  return (
    process.env.NEXT_PUBLIC_ORS_API_KEY ||
    process.env.ORS_API_KEY ||
    ''
  )
}

function cacheGet(key: string) {
  const entry = ROUTE_CACHE.get(key)
  if (!entry) return null
  if (Date.now() > entry.expires) { ROUTE_CACHE.delete(key); return null }
  return entry.data
}

function cacheSet(key: string, data: unknown) {
  ROUTE_CACHE.set(key, { data, expires: Date.now() + CACHE_TTL_MS })
}

// ── GET – directions ─────────────────────────────────────────────────────────
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const profile = PROFILE_MAP[searchParams.get('profile') ?? 'foot'] ?? 'foot-walking'
  const fromLat = searchParams.get('fromLat')
  const fromLon = searchParams.get('fromLon')
  const toLat   = searchParams.get('toLat')
  const toLon   = searchParams.get('toLon')

  if (!fromLat || !fromLon || !toLat || !toLon) {
    return NextResponse.json({ error: 'Missing coordinates' }, { status: 400 })
  }

  const apiKey = getKey()
  if (!apiKey) {
    return NextResponse.json(
      { error: 'NEXT_PUBLIC_ORS_API_KEY not configured' },
      { status: 503 },
    )
  }

  const cacheKey = `route:${profile}:${fromLat},${fromLon}:${toLat},${toLon}`
  const cached = cacheGet(cacheKey)
  if (cached) return NextResponse.json(cached)

  try {
    const url = `${ORS_BASE}/v2/directions/${profile}?api_key=${apiKey}&start=${fromLon},${fromLat}&end=${toLon},${toLat}`
    const res = await fetch(url, { next: { revalidate: 600 } })

    if (!res.ok) {
      const text = await res.text()
      return NextResponse.json(
        { error: `ORS error ${res.status}`, detail: text },
        { status: res.status },
      )
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const raw: any = await res.json()
    const feature = raw?.features?.[0]
    if (!feature) {
      return NextResponse.json({ error: 'No route found' }, { status: 404 })
    }

    const summary = feature.properties?.summary ?? {}
    const steps =
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (feature.properties?.segments?.[0]?.steps ?? []).map((s: any) => ({
        instruction: s.instruction ?? '',
        distance: s.distance ?? 0,
        duration: s.duration ?? 0,
      }))

    const result = {
      distanceKm: (summary.distance ?? 0) / 1000,
      durationMin: (summary.duration ?? 0) / 60,
      geometry: feature.geometry,
      steps,
    }

    cacheSet(cacheKey, result)
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'private, max-age=600' },
    })
  } catch (err) {
    console.error('Routing GET error:', err)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}

// ── POST – isochrones ────────────────────────────────────────────────────────
export async function POST(request: Request) {
  let body: { center?: [number, number]; minutes?: number[]; profile?: string }
  try {
    body = await request.json()
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
  }

  const { center, minutes, profile: profileKey } = body
  if (!center || !minutes?.length) {
    return NextResponse.json({ error: 'Missing center or minutes' }, { status: 400 })
  }

  const profile = PROFILE_MAP[profileKey ?? 'foot'] ?? 'foot-walking'
  const apiKey = getKey()
  if (!apiKey) {
    return NextResponse.json(
      { error: 'NEXT_PUBLIC_ORS_API_KEY not configured' },
      { status: 503 },
    )
  }

  const cacheKey = `iso:${profile}:${center.join(',')}:${minutes.join(',')}`
  const cached = cacheGet(cacheKey)
  if (cached) return NextResponse.json(cached)

  try {
    const res = await fetch(`${ORS_BASE}/v2/isochrones/${profile}`, {
      method: 'POST',
      headers: {
        Authorization: apiKey,
        'Content-Type': 'application/json; charset=utf-8',
        Accept: 'application/json, application/geo+json',
      },
      body: JSON.stringify({
        locations: [[center[1], center[0]]], // ORS expects [lon, lat]
        range: minutes.map((m) => m * 60),   // seconds
        range_type: 'time',
      }),
    })

    if (!res.ok) {
      const text = await res.text()
      return NextResponse.json(
        { error: `ORS error ${res.status}`, detail: text },
        { status: res.status },
      )
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const raw: any = await res.json()
    const polygons = (raw?.features ?? []).map((f: unknown) => f)

    const result = { polygons }
    cacheSet(cacheKey, result)
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'private, max-age=600' },
    })
  } catch (err) {
    console.error('Routing POST error:', err)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
