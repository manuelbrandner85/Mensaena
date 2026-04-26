'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { Briefcase, MapPin, ExternalLink, Loader2, ChevronRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { searchJobs, WORKTIME_OPTIONS, type JobOffer, type WorktimeKey } from '@/lib/api/jobsearch'

type Filter = 'all' | WorktimeKey

const FILTER_CHIPS: { key: Filter; label: string }[] = [
  { key: 'all', label: 'Alle' },
  { key: 'mj',  label: 'Minijob' },
  { key: 'tz',  label: 'Teilzeit' },
  { key: 'vz',  label: 'Vollzeit' },
  { key: 'ho',  label: 'Homeoffice' },
]

function formatDate(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ''
  return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

function Skeleton() {
  return (
    <div className="space-y-3">
      {[1, 2, 3].map(i => (
        <div key={i} className="animate-pulse flex gap-3 p-3 rounded-xl bg-warm-50">
          <div className="w-9 h-9 rounded-lg bg-stone-200 flex-shrink-0" />
          <div className="flex-1 space-y-2">
            <div className="h-3.5 bg-stone-200 rounded w-3/4" />
            <div className="h-3 bg-stone-200 rounded w-1/2" />
          </div>
        </div>
      ))}
    </div>
  )
}

export default function JobsNearbyWidget() {
  const [plz, setPlz]       = useState<string | null>(null)
  const [jobs, setJobs]     = useState<JobOffer[]>([])
  const [total, setTotal]   = useState(0)
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<Filter>('all')
  const [error, setError]   = useState<string | null>(null)

  // Load user PLZ from profile
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) { setLoading(false); return }
      supabase.from('profiles').select('zip, location_text').eq('id', user.id).maybeSingle()
        .then(({ data }) => {
          const zip = data?.zip ?? data?.location_text?.match(/\b\d{5}\b/)?.[0] ?? null
          setPlz(zip)
          if (!zip) setLoading(false)
        })
    })
  }, [])

  useEffect(() => {
    if (plz === null) return
    if (!plz) { setLoading(false); return }
    setLoading(true)
    setError(null)
    searchJobs({
      plz,
      radius: 25,
      worktime: filter === 'all' ? ['vz', 'tz', 'mj', 'ho', 'snw'] : [filter],
      limit: 5,
    })
      .then(r => { setJobs(r.jobs); setTotal(r.total) })
      .catch(() => setError('Stellen konnten nicht geladen werden.'))
      .finally(() => setLoading(false))
  }, [plz, filter])

  const worktimeLabel = (wt: string | null) => {
    if (!wt) return null
    return WORKTIME_OPTIONS.find(o => o.key === wt)?.label ?? wt
  }

  return (
    <div className="bg-white rounded-2xl border border-warm-100 shadow-soft overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-warm-100">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-primary-100 flex items-center justify-center flex-shrink-0">
            <Briefcase className="w-4 h-4 text-primary-600" />
          </div>
          <h2 className="text-sm font-semibold text-ink-900">Jobs in deiner Nähe</h2>
        </div>
        <Link
          href="/dashboard/jobs"
          className="flex items-center gap-0.5 text-xs font-medium text-primary-600 hover:text-primary-700 transition-colors"
        >
          Alle <ChevronRight className="w-3.5 h-3.5" />
        </Link>
      </div>

      {/* Filter chips */}
      {plz && (
        <div className="flex gap-1.5 px-4 pt-3 pb-1 overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
          {FILTER_CHIPS.map(c => (
            <button
              key={c.key}
              onClick={() => setFilter(c.key)}
              className={cn(
                'flex-shrink-0 px-2.5 py-1 rounded-full text-[11px] font-medium border transition-all',
                filter === c.key
                  ? 'bg-primary-600 text-white border-primary-600'
                  : 'bg-white text-ink-600 border-stone-200 hover:border-primary-300',
              )}
            >
              {c.label}
            </button>
          ))}
        </div>
      )}

      {/* Body */}
      <div className="px-4 py-3 space-y-1">
        {loading ? (
          <Skeleton />
        ) : error ? (
          <p className="text-xs text-red-500 py-2">{error}</p>
        ) : !plz ? (
          <p className="text-xs text-ink-500 py-2">
            Trage deine PLZ in deinem Profil ein, um Jobs in der Nähe zu sehen.
          </p>
        ) : jobs.length === 0 ? (
          <p className="text-xs text-ink-500 py-2">
            Aktuell keine Stellen im Umkreis – schaue später nochmal!
          </p>
        ) : (
          jobs.map(job => (
            <a
              key={job.refnr}
              href={job.url ?? `https://www.arbeitsagentur.de/jobsuche/suche?id=${job.refnr}`}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-start gap-2.5 p-2.5 rounded-xl hover:bg-warm-50 transition-colors group"
            >
              <div className="w-8 h-8 rounded-lg bg-primary-50 border border-primary-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <Briefcase className="w-4 h-4 text-primary-500" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-semibold text-ink-900 truncate group-hover:text-primary-700 transition-colors">
                  {job.title}
                </p>
                <p className="text-[11px] text-ink-600 truncate">{job.employer}</p>
                <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                  {job.city && (
                    <span className="flex items-center gap-0.5 text-[10px] text-ink-400">
                      <MapPin className="w-2.5 h-2.5" />{job.city}
                    </span>
                  )}
                  {worktimeLabel(job.worktime) && (
                    <span className="text-[10px] text-primary-600 font-medium">
                      {worktimeLabel(job.worktime)}
                    </span>
                  )}
                </div>
              </div>
              <ExternalLink className="w-3.5 h-3.5 text-stone-400 group-hover:text-primary-400 flex-shrink-0 mt-1 transition-colors" />
            </a>
          ))
        )}
      </div>

      {/* Footer */}
      {total > 5 && plz && !loading && !error && (
        <div className="px-4 pb-3">
          <Link
            href="/dashboard/jobs"
            className="block text-center text-xs font-medium text-primary-600 hover:text-primary-700 py-2 rounded-xl hover:bg-primary-50 transition-colors border border-primary-100"
          >
            Alle {total.toLocaleString('de-DE')} Stellen anzeigen →
          </Link>
        </div>
      )}
    </div>
  )
}
