import { NextRequest, NextResponse } from 'next/server'
import type { WaterMeasurement } from '@/lib/api/waterlevel'

const BASE = 'https://www.pegelonline.wsv.de/webservices/rest-api/v2'

export async function GET(req: NextRequest) {
  try {
    const uuid = req.nextUrl.searchParams.get('uuid')
    if (!uuid) return NextResponse.json({ error: 'uuid required' }, { status: 400 })

    const res = await fetch(`${BASE}/stations/${uuid}/W/measurements.json?start=P1D`, {
      headers: {
        'User-Agent': 'Mensaena/1.0 (+https://www.mensaena.de)',
        Accept: 'application/json',
      },
      next: { revalidate: 900 },
    })
    if (!res.ok) {
      console.error('measurements API error', res.status)
      return NextResponse.json({ error: `Pegel API ${res.status}` }, { status: 502 })
    }
    const raw = await res.json()
    const measurements: WaterMeasurement[] = (raw as { timestamp: string; value: number }[])
      .map(m => ({ timestamp: m.timestamp, value: m.value }))

    return NextResponse.json(measurements, {
      headers: { 'Cache-Control': 'public, s-maxage=900, stale-while-revalidate=300' },
    })
  } catch (err) {
    console.error('measurements route error', err)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
