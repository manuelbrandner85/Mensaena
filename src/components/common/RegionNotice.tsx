'use client'

// ── RegionNotice – Hinweis bei nicht unterstützter Region ─────────────────────
// Dezenter Info-Banner (blau), zeigt warum ein Feature gerade nicht verfügbar
// ist. Optional dismissbar – die Auswahl wird in localStorage gespeichert,
// damit der gleiche Hinweis nicht wiederholt erscheint.

import { useState } from 'react'
import { Info, X } from 'lucide-react'
import type { GeoContext, SupportedCountry } from '@/lib/geo/country-detect'

export interface RegionNoticeProps {
  /** Mindest-Stufe die für das Feature nötig ist (DE | AT | CH | EU | WORLD) */
  requiredCountry: SupportedCountry
  /** Aktueller GeoContext oder null */
  currentContext: GeoContext | null
  /** Optional: Feature-spezifischer Text vor der Standard-Botschaft */
  featureName?: string
  /** Stable Schlüssel für localStorage-Dismiss (Default: feature_${requiredCountry}) */
  dismissKey?: string
  /** Optional: Zusätzliche Klassen für den Wrapper */
  className?: string
}

const REGION_LABELS: Record<SupportedCountry, string> = {
  DE: 'Deutschland',
  AT: 'Österreich',
  CH: 'der Schweiz',
  EU: 'der Europäischen Union',
  WORLD: 'allen Regionen',
}

function buildMessage(
  required: SupportedCountry,
  current: GeoContext | null,
  featureName?: string,
): string {
  const where = REGION_LABELS[required]
  const featurePart = featureName
    ? `Das Feature „${featureName}" ist`
    : 'Dieses Feature ist'
  if (!current || current.countryCode === 'XX') {
    return `${featurePart} nur in ${where} verfügbar. Dein Standort ist noch nicht bekannt.`
  }
  return `${featurePart} nur in ${where} verfügbar. Du befindest dich in ${current.countryName}.`
}

export function RegionNotice({
  requiredCountry,
  currentContext,
  featureName,
  dismissKey,
  className = '',
}: RegionNoticeProps) {
  const storageKey = `mensaena_region_notice_${dismissKey ?? `${featureName ?? 'feature'}_${requiredCountry}`}`

  const [dismissed, setDismissed] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false
    try {
      return window.localStorage.getItem(storageKey) === '1'
    } catch {
      return false
    }
  })

  if (dismissed) return null

  function handleDismiss() {
    setDismissed(true)
    try {
      window.localStorage.setItem(storageKey, '1')
    } catch {
      /* ignore */
    }
  }

  const message = buildMessage(requiredCountry, currentContext, featureName)

  return (
    <div
      role="status"
      aria-live="polite"
      className={`relative flex items-start gap-3 rounded-xl border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-900 dark:border-blue-800 dark:bg-blue-950/40 dark:text-blue-100 ${className}`}
    >
      <Info aria-hidden className="mt-0.5 h-4 w-4 flex-shrink-0 text-blue-600 dark:text-blue-300" />
      <p className="flex-1 leading-snug">{message}</p>
      <button
        type="button"
        onClick={handleDismiss}
        aria-label="Hinweis ausblenden"
        className="flex-shrink-0 rounded-md p-1 text-blue-700 transition-colors hover:bg-blue-100 dark:text-blue-300 dark:hover:bg-blue-900/40"
      >
        <X aria-hidden className="h-4 w-4" />
      </button>
    </div>
  )
}

export default RegionNotice
