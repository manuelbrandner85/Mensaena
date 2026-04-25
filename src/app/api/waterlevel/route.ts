import { NextRequest, NextResponse } from 'next/server'
import type { WaterStation } from '@/lib/api/waterlevel'

const PEGEL_URL = 'https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations.json?includeTimeseries=true&includeCurrentMeasurement=true'

// Server-side cache (lives per worker instance)
let _cache: { data: WaterStation[]; expires: number } | null = null
const CACHE_TTL = 15 * 60 * 1000

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function pickWTimeseries(timeseries: any[] | undefined) {
  if (!timeseries) return null
  // Prefer "W" (Wasserstand). Fall back to first with currentMeasurement.
  return timeseries.find(t => t.shortname === 'W' && t.currentMeasurement)
       ?? timeseries.find(t => t.currentMeasurement)
       ?? null
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapStation(s: any): WaterStation | null {
  const ts = pickWTimeseries(s.timeseries)
  if (!ts || !s.latitude || !s.longitude) return null
  const cm = ts.currentMeasurement
  if (!cm || cm.value === undefined || cm.value === null) return null

  // Trend from currentMeasurement.trend if available, else "stable"
  let trend: WaterStation['trend'] = 'stable'
  if (typeof cm.trend === 'number') {
    if (cm.trend > 0) trend = 'rising'
    else if (cm.trend < 0) trend = 'falling'
  }

  return {
    uuid:         s.uuid,
    name:         s.longname || s.shortname || s.uuid,
    waterName:    s.water?.longname || s.water?.shortname || '',
    lat:          s.latitude,
    lon:          s.longitude,
    currentLevel: cm.value,
    unit:         ts.unit ?? 'cm',
    timestamp:    cm.timestamp ?? '',
    trend,
  }
}

async function loadAllStations(): Promise<WaterStation[]> {
  if (_cache && Date.now() < _cache.expires) return _cache.data

  const res = await fetch(PEGEL_URL, {
    headers: {
      'User-Agent': 'Mensaena/1.0 (+https://www.mensaena.de)',
      Accept: 'application/json',
    },
    next: { revalidate: 900 },
  })
  if (!res.ok) throw new Error(`Pegel API ${res.status}`)
  const raw = await res.json()
  const mapped = (raw as unknown[])
    .map(mapStation)
    .filter((s): s is WaterStation => s !== null)
  _cache = { data: mapped, expires: Date.now() + CACHE_TTL }
  return mapped
}

export async function GET(req: NextRequest) {
  try {
    const sp = req.nextUrl.searchParams
    const lat    = Number(sp.get('lat'))
    const lon    = Number(sp.get('lon'))
    const radius = Number(sp.get('radius') ?? '50')
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return NextResponse.json({ error: 'lat & lon required' }, { status: 400 })
    }

    const all = await loadAllStations()
    const nearby = all
      .map(s => ({ s, d: haversineKm(lat, lon, s.lat, s.lon) }))
      .filter(({ d }) => d <= radius)
      .sort((a, b) => a.d - b.d)
      .slice(0, 50)
      .map(({ s }) => s)

    return NextResponse.json(nearby, {
      headers: { 'Cache-Control': 'public, s-maxage=900, stale-while-revalidate=300' },
    })
  } catch (err) {
    console.error('waterlevel route error', err)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
