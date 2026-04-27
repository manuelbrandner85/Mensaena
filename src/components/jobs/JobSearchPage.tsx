'use client'

import { useState, useEffect, useCallback } from 'react'
import { Briefcase, MapPin, Clock, ExternalLink, Search, Loader2, ChevronLeft, ChevronRight, Filter, SlidersHorizontal } from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { searchJobs, WORKTIME_OPTIONS, type JobOffer, type WorktimeKey } from '@/lib/api/jobsearch'

const RADIUS_OPTIONS = [10, 25, 50, 100, 200]
const PAGE_SIZE = 10

function formatDate(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ''
  return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

function JobCard({ job }: { job: JobOffer }) {
  const href = job.url ?? `https://www.arbeitsagentur.de/jobsuche/suche?id=${job.refnr}`
  const wt = WORKTIME_OPTIONS.find(o => o.key === job.worktime)?.label

  return (
    <div className="bg-white rounded-2xl border border-warm-100 shadow-soft hover:shadow-card hover:border-stone-300 transition-all p-4 group">
      <div className="flex items-start gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary-50 border border-primary-100 flex items-center justify-center flex-shrink-0">
          <Briefcase className="w-5 h-5 text-primary-600" />
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-ink-900 text-sm leading-snug group-hover:text-primary-700 transition-colors">
            {job.title}
          </h3>
          <p className="text-xs text-ink-600 mt-0.5 font-medium">{job.employer}</p>
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 mt-1.5">
            {job.city && (
              <span className="flex items-center gap-1 text-xs text-ink-500">
                <MapPin className="w-3 h-3" />{job.city}{job.plz ? ` (${job.plz})` : ''}
              </span>
            )}
            {job.startDate && (
              <span className="flex items-center gap-1 text-xs text-ink-500">
                <Clock className="w-3 h-3" />ab {formatDate(job.startDate)}
              </span>
            )}
            {wt && (
              <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-primary-50 text-primary-700 border border-primary-100">
                {wt}
              </span>
            )}
          </div>
        </div>
        <a
          href={href}
          target="_blank"
          rel="noopener noreferrer"
          aria-label={`${job.title} bei ${job.employer} öffnen`}
          className="flex-shrink-0 flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium bg-primary-600 text-white hover:bg-primary-700 transition-colors whitespace-nowrap"
        >
          <ExternalLink className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">Zur Stelle</span>
        </a>
      </div>
      {job.publishedDate && (
        <p className="text-xs text-ink-400 mt-2 text-right">
          veröffentlicht {formatDate(job.publishedDate)}
        </p>
      )}
    </div>
  )
}

function Skeleton() {
  return (
    <div className="space-y-3">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="animate-pulse bg-white rounded-2xl border border-warm-100 p-4 flex gap-3">
          <div className="w-10 h-10 rounded-xl bg-stone-200 flex-shrink-0" />
          <div className="flex-1 space-y-2">
            <div className="h-4 bg-stone-200 rounded w-2/3" />
            <div className="h-3 bg-stone-200 rounded w-1/3" />
            <div className="h-3 bg-stone-200 rounded w-1/2" />
          </div>
        </div>
      ))}
    </div>
  )
}

export default function JobSearchPage() {
  const [plz, setPlz]           = useState('')
  const [query, setQuery]       = useState('')
  const [radius, setRadius]     = useState(25)
  const [worktime, setWorktime] = useState<WorktimeKey[]>([])
  const [page, setPage]         = useState(0)
  const [jobs, setJobs]         = useState<JobOffer[]>([])
  const [total, setTotal]       = useState(0)
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState<string | null>(null)
  const [searched, setSearched] = useState(false)
  const [showFilters, setShowFilters] = useState(false)

  // Pre-fill PLZ from profile
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      supabase.from('profiles').select('zip, location_text').eq('id', user.id).maybeSingle()
        .then(({ data }) => {
          const z = data?.zip ?? data?.location_text?.match(/\b\d{5}\b/)?.[0] ?? ''
          if (z) setPlz(z)
        })
    })
  }, [])

  const doSearch = useCallback(async (p = 0) => {
    if (!plz.trim()) return
    setLoading(true)
    setError(null)
    setPage(p)
    setSearched(true)
    try {
      const r = await searchJobs({
        plz: plz.trim(),
        radius,
        query: query.trim() || undefined,
        worktime: worktime.length ? worktime : undefined,
        page: p,
        limit: PAGE_SIZE,
      })
      setJobs(r.jobs)
      setTotal(r.total)
    } catch {
      setError('Stellen konnten nicht geladen werden. Bitte prüfe deine Internetverbindung.')
    } finally {
      setLoading(false)
    }
  }, [plz, radius, query, worktime])

  // Auto-search when PLZ pre-filled
  useEffect(() => {
    if (plz && !searched) doSearch(0)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [plz])

  const toggleWorktime = (key: WorktimeKey) => {
    setWorktime(prev =>
      prev.includes(key) ? prev.filter(k => k !== key) : [...prev, key]
    )
  }

  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="max-w-3xl mx-auto space-y-4">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-ink-900 flex items-center gap-2">
          <Briefcase className="w-6 h-6 text-primary-600" />
          Jobs in der Nachbarschaft
        </h1>
        <p className="text-sm text-ink-500 mt-0.5">
          Stellenangebote der Bundesagentur für Arbeit in deiner Nähe
        </p>
      </div>

      {/* Search card */}
      <div className="bg-white rounded-2xl border border-warm-100 shadow-soft p-4 space-y-3">
        {/* PLZ + Suchwort row */}
        <div className="flex gap-2">
          <div className="relative">
            <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 pointer-events-none" />
            <input
              type="text"
              inputMode="numeric"
              pattern="\d{5}"
              maxLength={5}
              value={plz}
              onChange={e => setPlz(e.target.value)}
              placeholder="PLZ"
              aria-label="Postleitzahl"
              className="input pl-9 w-28 text-sm"
            />
          </div>
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 pointer-events-none" />
            <input
              type="search"
              value={query}
              onChange={e => setQuery(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && doSearch(0)}
              placeholder="Beruf oder Stichwort (optional)"
              aria-label="Berufsbezeichnung oder Stichwort"
              className="input pl-9 w-full text-sm"
            />
          </div>
        </div>

        {/* Radius + Filter toggle row */}
        <div className="flex items-center gap-2 flex-wrap">
          <select
            value={radius}
            onChange={e => setRadius(Number(e.target.value))}
            aria-label="Umkreis in Kilometern"
            className="input text-sm py-1.5 pr-8 w-auto"
          >
            {RADIUS_OPTIONS.map(r => (
              <option key={r} value={r}>{r} km Umkreis</option>
            ))}
          </select>

          <button
            onClick={() => setShowFilters(s => !s)}
            className={cn(
              'flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium border transition-all',
              showFilters || worktime.length
                ? 'bg-primary-50 text-primary-700 border-primary-200'
                : 'bg-white text-ink-600 border-stone-200 hover:bg-warm-50',
            )}
          >
            <SlidersHorizontal className="w-3.5 h-3.5" />
            Arbeitszeit
            {worktime.length > 0 && (
              <span className="w-4 h-4 rounded-full bg-primary-600 text-white text-[9px] font-bold flex items-center justify-center">
                {worktime.length}
              </span>
            )}
          </button>

          <button
            onClick={() => doSearch(0)}
            disabled={!plz.trim() || loading}
            className="ml-auto flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 disabled:opacity-50 transition-colors"
          >
            {loading
              ? <Loader2 className="w-4 h-4 animate-spin" />
              : <Search className="w-4 h-4" />
            }
            Suchen
          </button>
        </div>

        {/* Worktime filter checkboxes */}
        {showFilters && (
          <div className="flex flex-wrap gap-2 pt-1 border-t border-warm-100">
            {WORKTIME_OPTIONS.map(o => (
              <label
                key={o.key}
                className={cn(
                  'flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-medium border cursor-pointer transition-all select-none',
                  worktime.includes(o.key)
                    ? 'bg-primary-50 text-primary-700 border-primary-300'
                    : 'bg-white text-ink-600 border-stone-200 hover:border-primary-200',
                )}
              >
                <input
                  type="checkbox"
                  className="w-3.5 h-3.5 accent-primary-600"
                  checked={worktime.includes(o.key)}
                  onChange={() => toggleWorktime(o.key)}
                />
                {o.label}
              </label>
            ))}
          </div>
        )}
      </div>

      {/* Results */}
      {loading ? (
        <Skeleton />
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-2xl p-4 text-sm text-red-600">
          {error}
        </div>
      ) : searched && jobs.length === 0 ? (
        <div className="bg-white rounded-2xl border border-warm-100 shadow-soft p-8 text-center">
          <Briefcase className="w-10 h-10 text-stone-400 mx-auto mb-3" />
          <p className="text-ink-600 font-medium">Keine Stellen gefunden</p>
          <p className="text-sm text-ink-400 mt-1">Versuche einen größeren Umkreis oder andere Suchbegriffe.</p>
        </div>
      ) : jobs.length > 0 ? (
        <>
          <div className="flex items-center justify-between text-xs text-ink-500">
            <span><strong className="text-ink-900">{total.toLocaleString('de-DE')}</strong> Stellen gefunden</span>
            <span>Seite {page + 1} von {totalPages}</span>
          </div>

          <div className="space-y-3">
            {jobs.map(job => <JobCard key={job.refnr} job={job} />)}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2 pt-2">
              <button
                onClick={() => doSearch(page - 1)}
                disabled={page === 0 || loading}
                className="flex items-center gap-1 px-3 py-2 rounded-xl text-sm font-medium border border-warm-200 bg-white text-ink-700 hover:bg-warm-50 disabled:opacity-40 transition-colors"
              >
                <ChevronLeft className="w-4 h-4" /> Zurück
              </button>
              <span className="text-sm text-ink-500 tabular-nums">
                {page + 1} / {totalPages}
              </span>
              <button
                onClick={() => doSearch(page + 1)}
                disabled={page >= totalPages - 1 || loading}
                className="flex items-center gap-1 px-3 py-2 rounded-xl text-sm font-medium border border-warm-200 bg-white text-ink-700 hover:bg-warm-50 disabled:opacity-40 transition-colors"
              >
                Weiter <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          )}
        </>
      ) : null}
    </div>
  )
}
