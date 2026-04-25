import { NextRequest, NextResponse } from 'next/server'
import type { JobOffer, JobSearchResult } from '@/lib/api/jobsearch'

const ARBEITNOW_URL = 'https://www.arbeitnow.com/api/job-board-api'

// Rough PLZ → German state mapping (first digit) for location hints
const PLZ_REGION: Record<string, string[]> = {
  '0': ['Sachsen', 'Thüringen', 'Halle', 'Leipzig', 'Dresden', 'Chemnitz'],
  '1': ['Berlin', 'Brandenburg', 'Mecklenburg', 'Vorpommern', 'Potsdam', 'Rostock'],
  '2': ['Hamburg', 'Bremen', 'Schleswig', 'Holstein', 'Lübeck', 'Kiel'],
  '3': ['Niedersachsen', 'Hannover', 'Braunschweig', 'Göttingen', 'Osnabrück', 'Kassel'],
  '4': ['Nordrhein', 'Westfalen', 'Münster', 'Düsseldorf', 'Essen', 'Dortmund', 'Bielefeld', 'Bochum', 'Duisburg', 'Wuppertal'],
  '5': ['Köln', 'Bonn', 'Aachen', 'Koblenz', 'Trier', 'Mainz', 'Rheinland'],
  '6': ['Frankfurt', 'Hessen', 'Darmstadt', 'Wiesbaden', 'Mannheim', 'Heidelberg', 'Saarbrücken'],
  '7': ['Stuttgart', 'Karlsruhe', 'Tübingen', 'Freiburg', 'Ulm', 'Württemberg', 'Baden'],
  '8': ['München', 'Augsburg', 'Ingolstadt', 'Bayern'],
  '9': ['Nürnberg', 'Würzburg', 'Regensburg', 'Bayreuth', 'Bayern', 'Franken'],
}

function plzToHints(plz: string | null): string[] {
  if (!plz || plz.length < 1) return []
  return PLZ_REGION[plz[0]] ?? []
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function detectWorktime(job: any): string | null {
  const types: string[] = (job.job_types ?? []).map((s: string) => s.toLowerCase())
  const tags:  string[] = (job.tags      ?? []).map((s: string) => s.toLowerCase())
  if (job.remote === true || tags.some(t => t.includes('remote') || t.includes('homeoffice'))) return 'ho'
  if (types.includes('part-time') || tags.some(t => t.includes('teilzeit') || t.includes('part time'))) return 'tz'
  if (types.includes('mini-job')  || tags.some(t => t.includes('minijob')  || t.includes('mini-job'))) return 'mj'
  if (types.includes('full-time') || tags.some(t => t.includes('vollzeit') || t.includes('full time'))) return 'vz'
  return null
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapJob(s: Record<string, any>): JobOffer {
  return {
    refnr:         s.slug ?? '',
    title:         s.title ?? 'Stelle',
    employer:      s.company_name ?? '',
    city:          s.location ?? (s.remote ? 'Remote' : ''),
    plz:           '',
    startDate:     null,
    publishedDate: s.created_at ? new Date(s.created_at * 1000).toISOString() : '',
    url:           s.url ?? `https://www.arbeitnow.com/jobs/${s.slug}`,
    worktime:      detectWorktime(s),
  }
}

export async function GET(req: NextRequest) {
  try {
    const sp        = req.nextUrl.searchParams
    const plz       = sp.get('plz')
    const query     = (sp.get('query') ?? '').trim().toLowerCase()
    const worktime  = (sp.get('worktime') ?? '').split(';').filter(Boolean)
    const page      = Math.max(0, Number(sp.get('page') ?? '0'))
    const limit     = Math.max(1, Math.min(50, Number(sp.get('limit') ?? '10')))

    const hints = plzToHints(plz).map(h => h.toLowerCase())

    // Arbeitnow paginates ~50 per page (1-indexed). Fetch up to 4 pages = 200 jobs.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const allJobs: any[] = []
    let total = 0
    for (let p = 1; p <= 4; p++) {
      const url = `${ARBEITNOW_URL}?page=${p}`
      const res = await fetch(url, {
        headers: { 'User-Agent': 'Mensaena/1.0 (+https://www.mensaena.de)', Accept: 'application/json' },
        next: { revalidate: 600 },
      })
      if (!res.ok) {
        console.error('Arbeitnow API error', res.status)
        break
      }
      const data = await res.json()
      total = data.meta?.total ?? total
      const arr = data.data ?? []
      allJobs.push(...arr)
      if (arr.length < 50) break
    }

    // Filter
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let filtered: any[] = allJobs
    if (query) {
      filtered = filtered.filter(j =>
        (j.title || '').toLowerCase().includes(query) ||
        (j.company_name || '').toLowerCase().includes(query) ||
        (j.tags || []).some((t: string) => t.toLowerCase().includes(query)),
      )
    }
    if (worktime.length) {
      filtered = filtered.filter(j => {
        const wt = detectWorktime(j)
        return wt && worktime.includes(wt)
      })
    }
    // Location-hint filtering: keep jobs that match the PLZ region OR are remote
    if (hints.length && plz) {
      const matched = filtered.filter(j => {
        const loc = (j.location || '').toLowerCase()
        return j.remote === true || hints.some(h => loc.includes(h))
      })
      // If the region match yields nothing, fall back to remote-only
      // so the user sees something instead of an empty list
      filtered = matched.length > 0
        ? matched
        : filtered.filter(j => j.remote === true)
    }

    const start = page * limit
    const pageJobs = filtered.slice(start, start + limit).map(mapJob)

    const result: JobSearchResult = {
      jobs:  pageJobs,
      total: filtered.length,
    }
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'public, s-maxage=600, stale-while-revalidate=120' },
    })
  } catch (err) {
    console.error('jobs route error', err)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
