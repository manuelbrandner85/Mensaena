export const WORKTIME_OPTIONS = [
  { key: 'vz',  label: 'Vollzeit' },
  { key: 'tz',  label: 'Teilzeit' },
  { key: 'mj',  label: 'Minijob' },
  { key: 'snw', label: 'Schicht/Nacht/WE' },
  { key: 'ho',  label: 'Homeoffice' },
] as const

export type WorktimeKey = typeof WORKTIME_OPTIONS[number]['key']

export interface JobOffer {
  refnr: string
  title: string
  employer: string
  city: string
  plz: string
  startDate: string | null
  publishedDate: string
  url: string | null
  worktime: string | null
}

export interface JobSearchResult {
  jobs: JobOffer[]
  total: number
}

export interface JobSearchOptions {
  plz: string
  radius?: number
  query?: string
  worktime?: WorktimeKey[]
  page?: number
  limit?: number
}

export async function searchJobs(options: JobSearchOptions): Promise<JobSearchResult> {
  const params = new URLSearchParams()
  params.set('plz', options.plz)
  if (options.radius)  params.set('radius', String(options.radius))
  if (options.query)   params.set('query',  options.query)
  if (options.worktime?.length) params.set('worktime', options.worktime.join(';'))
  if (options.page)    params.set('page',   String(options.page))
  if (options.limit)   params.set('limit',  String(options.limit))

  const res = await fetch(`/api/jobs?${params}`, { cache: 'no-store' })
  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err.error ?? `Jobs API error ${res.status}`)
  }
  return res.json()
}
