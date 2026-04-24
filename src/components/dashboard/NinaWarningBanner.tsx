'use client'

import { useState, useEffect, useCallback } from 'react'
import { AlertTriangle, X, ChevronDown, ChevronUp, Shield } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { NinaWarning } from '@/lib/nina-api'

const SEVERITY_STYLES: Record<NinaWarning['severity'], string> = {
  Extreme:  'bg-red-600 text-white',
  Severe:   'bg-orange-500 text-white',
  Moderate: 'bg-yellow-400 text-black',
  Minor:    'bg-blue-100 text-blue-800',
}

const BADGE_STYLES: Record<NinaWarning['severity'], string> = {
  Extreme:  'bg-white/20 text-white',
  Severe:   'bg-white/20 text-white',
  Moderate: 'bg-black/10 text-black',
  Minor:    'bg-blue-200 text-blue-900',
}

const SEVERITY_LABELS: Record<NinaWarning['severity'], string> = {
  Extreme:  'EXTREM',
  Severe:   'SCHWER',
  Moderate: 'MITTEL',
  Minor:    'GERING',
}

// Cache: 15 min TTL, shared across mounts to avoid refetch on every navigation
const CACHE_TTL = 15 * 60 * 1000
const CACHE_KEY = 'mensaena_nina_warnings'
let moduleCache: { data: NinaWarning[]; timestamp: number } | null = null
let inflight: Promise<NinaWarning[]> | null = null

function readCache(): NinaWarning[] | null {
  if (moduleCache && Date.now() - moduleCache.timestamp < CACHE_TTL) {
    return moduleCache.data
  }
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(CACHE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { data: NinaWarning[]; timestamp: number }
    if (Date.now() - parsed.timestamp < CACHE_TTL) {
      moduleCache = parsed
      return parsed.data
    }
  } catch {}
  return null
}

function writeCache(data: NinaWarning[]) {
  const entry = { data, timestamp: Date.now() }
  moduleCache = entry
  try { localStorage.setItem(CACHE_KEY, JSON.stringify(entry)) } catch {}
}

async function loadWarnings(): Promise<NinaWarning[]> {
  if (inflight) return inflight
  inflight = (async () => {
    try {
      const res = await fetch('/api/nina/warnings')
      if (!res.ok) return []
      const data = await res.json()
      const warnings = Array.isArray(data.warnings) ? data.warnings as NinaWarning[] : []
      writeCache(warnings)
      return warnings
    } catch {
      return []
    } finally {
      inflight = null
    }
  })()
  return inflight
}

export default function NinaWarningBanner() {
  const cached = typeof window !== 'undefined' ? readCache() : null
  const [warnings, setWarnings] = useState<NinaWarning[]>(cached ?? [])
  const [loading, setLoading] = useState(cached === null)
  const [dismissed, setDismissed] = useState<Set<string>>(new Set())
  const [expandedId, setExpandedId] = useState<string | null>(null)

  const fetchWarnings = useCallback(async () => {
    const data = await loadWarnings()
    setWarnings(data)
    setLoading(false)
  }, [])

  useEffect(() => {
    // Skip fetch entirely if module cache is still fresh
    if (moduleCache && Date.now() - moduleCache.timestamp < CACHE_TTL) {
      setLoading(false)
      return
    }
    fetchWarnings()
    const interval = setInterval(fetchWarnings, CACHE_TTL)
    return () => clearInterval(interval)
  }, [fetchWarnings])

  const dismiss = (id: string) => {
    setDismissed(prev => new Set(prev).add(id))
    if (expandedId === id) setExpandedId(null)
  }

  const toggleExpand = (id: string) => {
    setExpandedId(prev => (prev === id ? null : id))
  }

  const visible = warnings.filter(w => !dismissed.has(w.id))

  if (loading || visible.length === 0) return null

  return (
    <div className="space-y-1 mb-4">
      {visible.map(warning => {
        const isExpanded = expandedId === warning.id
        const isExtreme = warning.severity === 'Extreme'

        return (
          <div
            key={warning.id}
            className={cn(
              'rounded-xl overflow-hidden shadow-sm',
              SEVERITY_STYLES[warning.severity],
              isExtreme && 'ring-2 ring-red-400'
            )}
          >
            {/* Compact row */}
            <div className="flex items-center gap-2 px-4 py-2.5">
              <AlertTriangle
                className={cn('w-4 h-4 flex-shrink-0', isExtreme && 'animate-pulse')}
              />

              <span className={cn(
                'text-[10px] font-bold px-1.5 py-0.5 rounded uppercase tracking-wide flex-shrink-0',
                BADGE_STYLES[warning.severity]
              )}>
                {SEVERITY_LABELS[warning.severity]}
              </span>

              <button
                onClick={() => toggleExpand(warning.id)}
                className="flex-1 flex items-center gap-2 text-left min-w-0"
              >
                <span className="text-sm font-medium truncate">{warning.title}</span>
                {warning.area && (
                  <span className="hidden sm:inline text-xs opacity-75 truncate flex-shrink-0">
                    · {warning.area}
                  </span>
                )}
                <span className="flex-shrink-0 ml-auto opacity-75">
                  {isExpanded
                    ? <ChevronUp className="w-3.5 h-3.5" />
                    : <ChevronDown className="w-3.5 h-3.5" />
                  }
                </span>
              </button>

              <button
                onClick={() => dismiss(warning.id)}
                aria-label="Warnung schließen"
                className="p-1 rounded-lg opacity-70 hover:opacity-100 transition-opacity flex-shrink-0 min-w-[32px] min-h-[32px] flex items-center justify-center"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            {/* Expanded details */}
            {isExpanded && (
              <div className="px-4 pb-4 pt-1 border-t border-white/20 space-y-2">
                {warning.description && (
                  <p className="text-sm opacity-90 leading-relaxed">{warning.description}</p>
                )}
                {warning.instruction && (
                  <div className="flex items-start gap-2 mt-2">
                    <Shield className="w-4 h-4 flex-shrink-0 mt-0.5 opacity-75" />
                    <p className="text-sm font-medium">{warning.instruction}</p>
                  </div>
                )}
                {warning.area && (
                  <p className="text-xs opacity-60">Betroffenes Gebiet: {warning.area}</p>
                )}
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
