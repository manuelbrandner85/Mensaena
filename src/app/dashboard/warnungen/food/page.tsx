'use client'

// ── /dashboard/warnungen/food ─────────────────────────────────────────────────
// Vollständige Liste der Lebensmittelwarnungen (BVL + RASFF), Filter nach
// Severity / Land / Zeitraum, Suchfeld. RegionNotice wenn nicht DE/EU.

import { useEffect, useMemo, useState } from 'react'
import {
  AlertTriangle, Search, ExternalLink, Filter, Calendar, Globe, X,
} from 'lucide-react'
import {
  fetchAllFoodWarnings,
  isRasffAvailable,
  getRasffPortalUrl,
  type FoodWarning,
} from '@/lib/api/foodwarnings'
import { useGeoStore } from '@/stores/geoStore'
import { RegionNotice } from '@/components/common/RegionNotice'

type SeverityFilter = 'all' | 'high' | 'medium'
type PeriodFilter = 'all' | '7d' | '30d' | '90d'

function isWithin(period: PeriodFilter, isoDate: string): boolean {
  if (period === 'all') return true
  const days = period === '7d' ? 7 : period === '30d' ? 30 : 90
  const t = Date.parse(isoDate)
  if (!isFinite(t)) return true
  return Date.now() - t < days * 24 * 60 * 60 * 1000
}

export default function FoodWarningsPage() {
  const context = useGeoStore(s => s.context)
  const [warnings, setWarnings] = useState<FoodWarning[]>([])
  const [loaded, setLoaded] = useState(false)
  const [search, setSearch] = useState('')
  const [severity, setSeverity] = useState<SeverityFilter>('all')
  const [country, setCountry] = useState<string>('all')
  const [period, setPeriod] = useState<PeriodFilter>('30d')

  const supportLevel = context?.supportLevel ?? 'WORLD'
  const showFeature = supportLevel === 'DE' || supportLevel === 'EU' ||
                      supportLevel === 'AT' || supportLevel === 'CH'

  useEffect(() => {
    if (!showFeature || !context) {
      setLoaded(true)
      return
    }
    let cancelled = false
    fetchAllFoodWarnings({
      countryCode: context.countryCode,
      supportLevel: context.supportLevel,
    })
      .then(list => { if (!cancelled) setWarnings(list) })
      .catch(() => { if (!cancelled) setWarnings([]) })
      .finally(() => { if (!cancelled) setLoaded(true) })
    return () => { cancelled = true }
  }, [context, showFeature])

  const countries = useMemo(() => {
    const set = new Set<string>()
    for (const w of warnings) {
      if (w.notificationCountry) set.add(w.notificationCountry)
    }
    return Array.from(set).sort()
  }, [warnings])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return warnings.filter(w => {
      if (severity !== 'all' && w.severity !== severity) return false
      if (country !== 'all' && (w.notificationCountry ?? '').toUpperCase() !== country) return false
      if (!isWithin(period, w.publishedDate)) return false
      if (q) {
        const hay = `${w.title} ${w.productName} ${w.manufacturer} ${w.description}`.toLowerCase()
        if (!hay.includes(q)) return false
      }
      return true
    })
  }, [warnings, search, severity, country, period])

  return (
    <div className="mx-auto max-w-5xl space-y-4 p-4">
      <header className="flex items-center gap-3">
        <AlertTriangle aria-hidden className="h-6 w-6 text-orange-500" />
        <div>
          <h1 className="text-xl font-bold text-ink-900 dark:text-stone-100">
            Lebensmittelwarnungen
          </h1>
          <p className="text-sm text-ink-500 dark:text-ink-400">
            Aktuelle Rückrufe und Hinweise von BVL und RASFF EU
          </p>
        </div>
      </header>

      {!showFeature && (
        <RegionNotice
          requiredCountry="EU"
          currentContext={context}
          featureName="Lebensmittelwarnungen"
        />
      )}

      {showFeature && (
        <>
          {/* Filterleiste */}
          <div
            className="grid grid-cols-1 gap-2 rounded-xl border border-stone-200 bg-white p-3 sm:grid-cols-2 lg:grid-cols-4 dark:border-ink-700 dark:bg-ink-800"
            role="search"
            aria-label="Lebensmittelwarnungen filtern"
          >
            <label className="relative flex items-center">
              <Search aria-hidden className="absolute left-3 h-4 w-4 text-ink-400" />
              <input
                type="search"
                placeholder="Produkt, Marke, Hersteller…"
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="w-full rounded-lg border border-stone-200 bg-white py-2 pl-9 pr-3 text-sm focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 dark:border-stone-500 dark:bg-ink-900 dark:text-stone-100"
                aria-label="Suchen"
              />
              {search && (
                <button
                  type="button"
                  onClick={() => setSearch('')}
                  aria-label="Suche löschen"
                  className="absolute right-2 rounded p-1 text-ink-400 hover:bg-stone-100 dark:hover:bg-ink-700"
                >
                  <X aria-hidden className="h-3 w-3" />
                </button>
              )}
            </label>

            <label className="flex items-center gap-2">
              <Filter aria-hidden className="h-4 w-4 text-ink-400" />
              <select
                value={severity}
                onChange={e => setSeverity(e.target.value as SeverityFilter)}
                aria-label="Schweregrad"
                className="w-full rounded-lg border border-stone-200 bg-white px-3 py-2 text-sm dark:border-stone-500 dark:bg-ink-900 dark:text-stone-100"
              >
                <option value="all">Alle Schweregrade</option>
                <option value="high">Nur Rückrufe (high)</option>
                <option value="medium">Nur Hinweise (medium)</option>
              </select>
            </label>

            <label className="flex items-center gap-2">
              <Globe aria-hidden className="h-4 w-4 text-ink-400" />
              <select
                value={country}
                onChange={e => setCountry(e.target.value)}
                aria-label="Land"
                className="w-full rounded-lg border border-stone-200 bg-white px-3 py-2 text-sm dark:border-stone-500 dark:bg-ink-900 dark:text-stone-100"
              >
                <option value="all">Alle Länder</option>
                {countries.map(c => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </label>

            <label className="flex items-center gap-2">
              <Calendar aria-hidden className="h-4 w-4 text-ink-400" />
              <select
                value={period}
                onChange={e => setPeriod(e.target.value as PeriodFilter)}
                aria-label="Zeitraum"
                className="w-full rounded-lg border border-stone-200 bg-white px-3 py-2 text-sm dark:border-stone-500 dark:bg-ink-900 dark:text-stone-100"
              >
                <option value="7d">Letzte 7 Tage</option>
                <option value="30d">Letzte 30 Tage</option>
                <option value="90d">Letzte 90 Tage</option>
                <option value="all">Alle</option>
              </select>
            </label>
          </div>

          {/* RASFF-Verfügbarkeit */}
          {loaded && !isRasffAvailable() && (
            <div className="flex items-center justify-between rounded-xl border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-900 dark:border-blue-800 dark:bg-blue-950/40 dark:text-blue-100">
              <span>RASFF EU ist gerade nicht direkt erreichbar.</span>
              <a
                href={getRasffPortalUrl()}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 font-medium underline hover:no-underline"
              >
                EU-Warnungen auf RASFF-Portal
                <ExternalLink aria-hidden className="h-3 w-3" />
              </a>
            </div>
          )}

          {/* Liste */}
          {!loaded ? (
            <div role="status" className="space-y-2">
              {[1, 2, 3].map(i => (
                <div key={i} className="h-20 animate-pulse rounded-xl bg-stone-100 dark:bg-ink-800" />
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <p className="rounded-xl border border-stone-200 bg-white px-4 py-8 text-center text-sm text-ink-500 dark:border-ink-700 dark:bg-ink-800 dark:text-ink-400">
              Keine Warnungen für diese Filter.
            </p>
          ) : (
            <ul className="space-y-2">
              {filtered.map(w => (
                <li
                  key={w.id}
                  className={`rounded-xl border bg-white p-4 dark:bg-ink-800 ${
                    w.severity === 'high'
                      ? 'border-red-200 dark:border-red-800'
                      : 'border-orange-200 dark:border-orange-800'
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1 min-w-0">
                      <div className="mb-1 flex flex-wrap items-center gap-2 text-[11px] font-semibold uppercase tracking-wide">
                        <span className={
                          w.severity === 'high'
                            ? 'rounded-full bg-red-100 px-2 py-0.5 text-red-800 dark:bg-red-900/40 dark:text-red-200'
                            : 'rounded-full bg-orange-100 px-2 py-0.5 text-orange-800 dark:bg-orange-900/40 dark:text-orange-200'
                        }>
                          {w.severity === 'high' ? 'Rückruf' : 'Hinweis'}
                        </span>
                        <span className="rounded-full bg-stone-100 px-2 py-0.5 text-ink-700 dark:bg-ink-700 dark:text-stone-400">
                          {w.source === 'rasff' ? 'RASFF EU' : w.source === 'manual' ? 'Manuell' : 'BVL'}
                        </span>
                        {w.notificationCountry && (
                          <span className="rounded-full bg-stone-100 px-2 py-0.5 text-ink-700 dark:bg-ink-700 dark:text-stone-400">
                            {w.notificationCountry}
                          </span>
                        )}
                        <span className="text-ink-400">
                          {new Date(w.publishedDate).toLocaleDateString('de-DE')}
                        </span>
                      </div>
                      <h2 className="text-sm font-semibold text-ink-900 dark:text-stone-100">
                        {w.title}
                      </h2>
                      {w.productName && (
                        <p className="mt-0.5 text-xs text-ink-600 dark:text-stone-400">
                          {w.productName}
                          {w.manufacturer && ` · ${w.manufacturer}`}
                        </p>
                      )}
                      {w.description && (
                        <p className="mt-1 line-clamp-2 text-xs text-ink-500 dark:text-ink-400">
                          {w.description}
                        </p>
                      )}
                    </div>
                    {w.link && (
                      <a
                        href={w.link}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex-shrink-0 inline-flex items-center gap-1 rounded-lg border border-stone-200 px-3 py-1.5 text-xs font-medium text-ink-700 hover:bg-stone-50 dark:border-stone-500 dark:text-stone-300 dark:hover:bg-ink-700"
                      >
                        Details
                        <ExternalLink aria-hidden className="h-3 w-3" />
                      </a>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}

          {/* Externe Quellen */}
          <div className="flex flex-wrap gap-2 pt-2 text-xs">
            <a
              href="https://www.lebensmittelwarnung.de"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 rounded-full border border-stone-200 px-3 py-1.5 text-ink-700 hover:bg-stone-50 dark:border-stone-500 dark:text-stone-300 dark:hover:bg-ink-700"
            >
              BVL Lebensmittelwarnung.de
              <ExternalLink aria-hidden className="h-3 w-3" />
            </a>
            <a
              href={getRasffPortalUrl()}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 rounded-full border border-stone-200 px-3 py-1.5 text-ink-700 hover:bg-stone-50 dark:border-stone-500 dark:text-stone-300 dark:hover:bg-ink-700"
            >
              EU RASFF Portal
              <ExternalLink aria-hidden className="h-3 w-3" />
            </a>
          </div>
        </>
      )}
    </div>
  )
}
