import { NextRequest, NextResponse } from 'next/server'
import type { JobOffer, JobSearchResult } from '@/lib/api/jobsearch'

const TOKEN_URL    = 'https://rest.arbeitsagentur.de/oauth/gettoken_cc'
const JOBS_URL     = 'https://rest.arbeitsagentur.de/jobboerse/jobsuche-service/pc/v4/jobs'
const CLIENT_ID     = 'c003a37f-024f-462a-b36d-b001be4cd24a'
const CLIENT_SECRET = '32a39620-32b3-4307-9aa1-511e3d7f48a8'
const API_KEY       = 'jobboerse-jobsuche'
const TOKEN_TTL_MS  = 9 * 60 * 1000 // 9 min (expires in 10)

let _token: string | null = null
let _tokenExpires = 0

async function getToken(): Promise<string> {
  if (_token && Date.now() < _tokenExpires) return _token

  const body = new URLSearchParams({
    grant_type:    'client_credentials',
    client_id:     CLIENT_ID,
    client_secret: CLIENT_SECRET,
  })
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'X-API-Key': API_KEY, 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  })
  if (!res.ok) throw new Error(`Token fetch failed: ${res.status}`)
  const data = await res.json()
  _token = data.access_token as string
  _tokenExpires = Date.now() + TOKEN_TTL_MS
  return _token
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapJob(s: Record<string, any>): JobOffer {
  const loc = s.arbeitsort ?? {}
  return {
    refnr:         s.refnr ?? '',
    title:         s.beruf ?? s.titel ?? 'Stelle',
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

    const radius   = sp.get('radius')  ?? '25'
    const query    = sp.get('query')   ?? ''
    const worktime = sp.get('worktime') ?? 'vz;tz;mj;ho'
    const page     = sp.get('page')    ?? '0'
    const limit    = sp.get('limit')   ?? '10'

    const token = await getToken()
    const params = new URLSearchParams({
      wo:          plz,
      umkreis:     radius,
      arbeitszeit: worktime,
      page,
      size:        limit,
    })
    if (query) params.set('was', query)

    const res = await fetch(`${JOBS_URL}?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
      next: { revalidate: 300 }, // 5-min edge cache
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
