import { NextRequest, NextResponse } from 'next/server'
import type { JobOffer, JobSearchResult } from '@/lib/api/jobsearch'

const JOBS_URL = 'https://rest.arbeitsagentur.de/jobboerse/jobsuche-service/pc/v4/jobs'
const API_KEY  = 'jobboerse-jobsuche'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapJob(s: Record<string, any>): JobOffer {
  const loc = s.arbeitsort ?? {}
  return {
    refnr:         s.refnr ?? '',
    title:         s.titel ?? s.beruf ?? 'Stelle',
    employer:      s.arbeitgeber ?? '',
    city:          loc.ort ?? '',
    plz:           loc.plz ?? '',
    startDate:     s.eintrittsdatum ?? null,
    publishedDate: s.aktuelleVeroeffentlichungsdatum ?? s.modifikationsTimestamp ?? '',
    url:           s.externeUrl ?? null,
    worktime:      s.arbeitszeit ?? null,
  }
}

export async function GET(req: NextRequest) {
  try {
    const sp     = req.nextUrl.searchParams
    const plz    = sp.get('plz')
    if (!plz) return NextResponse.json({ error: 'plz required' }, { status: 400 })

    const radius   = sp.get('radius')   ?? '25'
    const query    = sp.get('query')    ?? ''
    const worktime = sp.get('worktime') ?? 'vz;tz;mj;ho'
    const page     = sp.get('page')     ?? '0'
    const limit    = sp.get('limit')    ?? '10'

    const params = new URLSearchParams({
      wo:          plz,
      umkreis:     radius,
      arbeitszeit: worktime,
      page,
      size:        limit,
    })
    if (query) params.set('was', query)

    const res = await fetch(`${JOBS_URL}?${params}`, {
      headers: {
        'X-API-Key':  API_KEY,
        'User-Agent': 'Mensaena/1.0 (+https://www.mensaena.de)',
        Accept:        'application/json',
      },
      next: { revalidate: 300 },
    })

    if (!res.ok) {
      const text = await res.text()
      console.error('BA API error', res.status, text.slice(0, 200))
      return NextResponse.json({ error: `BA API ${res.status}` }, { status: 502 })
    }

    const data = await res.json()
    const result: JobSearchResult = {
      jobs:  (data.stellenangebote ?? []).map(mapJob),
      total: data.maxErgebnisse ?? 0,
    }
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' },
    })
  } catch (err) {
    console.error('jobs route error', err)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
