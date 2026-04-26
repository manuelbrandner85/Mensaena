'use client'

import { useEffect, useState, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { Sparkles, ArrowRight, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  classifyIntent,
  INTENT_LABELS,
  INTENT_EMOJI,
  INTENT_ROUTES,
  type IntentType,
  type IntentMatch,
} from '@/lib/intent-classifier'

interface IntentSuggestionBannerProps {
  /** What the user typed so far */
  title: string
  description?: string
  /** What the user CURRENTLY selected */
  currentType: string
  /** Called when user accepts the suggestion. Receives the new IntentType. */
  onAccept: (intent: IntentType) => void
  /** If true, navigate to the dedicated module instead of just changing type. */
  navigateOnAccept?: boolean
  /** Used to override redirect URL (defaults to INTENT_ROUTES). */
  redirectOverride?: Partial<Record<IntentType, string>>
  className?: string
}

const DEBOUNCE_MS = 600

export default function IntentSuggestionBanner({
  title,
  description = '',
  currentType,
  onAccept,
  navigateOnAccept = false,
  redirectOverride,
  className,
}: IntentSuggestionBannerProps) {
  const router = useRouter()
  const [match, setMatch] = useState<IntentMatch | null>(null)
  const [dismissed, setDismissed] = useState<Set<IntentType>>(new Set())

  // Debounced classifier
  useEffect(() => {
    const timer = setTimeout(() => {
      const m = classifyIntent(title, description)
      setMatch(m)
    }, DEBOUNCE_MS)
    return () => clearTimeout(timer)
  }, [title, description])

  const visible = useMemo(() => {
    if (!match) return false
    if (dismissed.has(match.type)) return false
    // Don't suggest the same type the user already selected
    if (match.type === currentType) return false
    // Map legacy current types to intent equivalents
    if (match.type === 'help_request' && currentType === 'help_request') return false
    if (match.type === 'help_offered' && currentType === 'help_offered') return false
    return true
  }, [match, currentType, dismissed])

  if (!visible || !match) return null

  const handleAccept = () => {
    if (navigateOnAccept) {
      const url = redirectOverride?.[match.type] ?? INTENT_ROUTES[match.type]
      // Pass title/description through query params so the new page can pre-fill
      const params = new URLSearchParams()
      if (title) params.set('title', title)
      if (description) params.set('description', description)
      router.push(`${url}?${params}`)
      return
    }
    onAccept(match.type)
  }

  const handleDismiss = () => {
    setDismissed(prev => new Set(prev).add(match.type))
  }

  return (
    <div
      role="status"
      className={cn(
        'flex items-start gap-2.5 p-3 rounded-xl border bg-gradient-to-r from-primary-50 to-blue-50',
        'border-primary-200 shadow-sm animate-fade-in',
        className,
      )}
    >
      <div className="w-7 h-7 rounded-lg bg-white border border-primary-200 flex items-center justify-center flex-shrink-0 mt-0.5">
        <Sparkles className="w-4 h-4 text-primary-600" />
      </div>

      <div className="flex-1 min-w-0">
        <p className="text-xs text-stone-700 leading-snug">
          Klingt nach{' '}
          <strong className="text-primary-700 whitespace-nowrap">
            {INTENT_EMOJI[match.type]} {INTENT_LABELS[match.type]}
          </strong>
          {match.matchedKeywords.length > 0 && (
            <span className="text-stone-400 hidden sm:inline">
              {' '}— erkannt: <em className="not-italic">{match.matchedKeywords.slice(0, 3).join(', ')}</em>
            </span>
          )}
        </p>
        <div className="flex items-center gap-2 mt-1.5">
          <button
            type="button"
            onClick={handleAccept}
            className="flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-semibold bg-primary-600 text-white hover:bg-primary-700 transition-colors"
          >
            {navigateOnAccept ? 'Zur passenden Seite' : 'Wechseln'}
            <ArrowRight className="w-3 h-3" />
          </button>
          <button
            type="button"
            onClick={handleDismiss}
            className="text-[11px] font-medium text-stone-500 hover:text-stone-700 transition-colors"
          >
            Nein, weiter
          </button>
        </div>
      </div>

      <button
        type="button"
        onClick={handleDismiss}
        aria-label="Vorschlag schließen"
        className="text-stone-400 hover:text-stone-600 flex-shrink-0 -mr-1 -mt-1 p-1"
      >
        <X className="w-3.5 h-3.5" />
      </button>
    </div>
  )
}
