'use client'

import { useEffect, useState, useCallback } from 'react'
import {
  Sparkles, Map, PlusCircle, MessageCircle, Users, Compass,
  ArrowRight, ArrowLeft, X, Check,
  type LucideIcon,
} from 'lucide-react'
import { cn } from '@/lib/utils'

const STORAGE_KEY = 'mensaena:onboarding-completed-v1'

interface Step {
  icon: LucideIcon
  eyebrow: string
  title: string
  body: string
  /** Background gradient variant for cinematic color change between steps. */
  tint: 'teal' | 'mint' | 'sky' | 'sunrise' | 'forest' | 'violet'
}

const STEPS: Step[] = [
  {
    icon: Sparkles,
    eyebrow: 'Willkommen',
    title: 'Schön, dass du da bist.',
    body: 'Mensaena ist deine Plattform für echte Nachbarschaftshilfe. In wenigen Schritten zeigen wir dir die wichtigsten Bereiche.',
    tint: 'teal',
  },
  {
    icon: Compass,
    eyebrow: 'Dashboard',
    title: 'Dein Überblick.',
    body: 'Hier siehst du alles Wichtige auf einen Blick: neue Anfragen, Nachrichten, passende Matches und aktuelle Aktivitäten in deiner Nähe.',
    tint: 'mint',
  },
  {
    icon: Map,
    eyebrow: 'Karte',
    title: 'Hilfe in deiner Nähe.',
    body: 'Entdecke Angebote, Gesuche und Ereignisse direkt in deiner Nachbarschaft. Filter nach Kategorie, Entfernung und Dringlichkeit.',
    tint: 'sky',
  },
  {
    icon: PlusCircle,
    eyebrow: 'Beitrag erstellen',
    title: 'Teile, was du kannst.',
    body: 'Biete Hilfe an oder bitte selbst um Unterstützung. Ob Einkauf, Werkzeug oder ein offenes Ohr — mit einem Klick erstellt.',
    tint: 'sunrise',
  },
  {
    icon: MessageCircle,
    eyebrow: 'Nachrichten',
    title: 'Direkt im Gespräch.',
    body: 'Chatte sicher und in Echtzeit mit deinen Nachbarn. Gruppen, Einzelchats und Benachrichtigungen — alles an einem Ort.',
    tint: 'forest',
  },
  {
    icon: Users,
    eyebrow: 'Gemeinschaft',
    title: 'Werde Teil des Netzwerks.',
    body: 'Trittt Gruppen bei, sammle Badges und baue Vertrauen auf. Gemeinsam sind wir Mensaena.',
    tint: 'violet',
  },
]

const TINT_CLASSES: Record<Step['tint'], string> = {
  teal:    'from-primary-500/25 via-primary-400/15 to-transparent',
  mint:    'from-emerald-400/25 via-primary-300/15 to-transparent',
  sky:     'from-sky-400/25 via-primary-300/15 to-transparent',
  sunrise: 'from-amber-400/25 via-primary-300/15 to-transparent',
  forest:  'from-teal-600/25 via-primary-500/15 to-transparent',
  violet:  'from-violet-400/25 via-primary-300/15 to-transparent',
}

const ICON_TINT: Record<Step['tint'], string> = {
  teal:    'bg-primary-100 text-primary-700',
  mint:    'bg-emerald-100 text-emerald-700',
  sky:     'bg-sky-100 text-sky-700',
  sunrise: 'bg-amber-100 text-amber-700',
  forest:  'bg-teal-100 text-teal-700',
  violet:  'bg-violet-100 text-violet-700',
}

interface OnboardingTourProps {
  /** If true, never show automatically (used during SSR / not-logged-in / public routes). */
  disabled?: boolean
}

export default function OnboardingTour({ disabled = false }: OnboardingTourProps) {
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const [step, setStep] = useState(0)
  const [closing, setClosing] = useState(false)

  // Decide whether to open on first render after the component mounts
  useEffect(() => {
    if (disabled) return
    if (typeof window === 'undefined') return
    try {
      const done = window.localStorage.getItem(STORAGE_KEY)
      if (!done) {
        // Small delay so the dashboard fades in first — feels more cinematic
        const t = setTimeout(() => setOpen(true), 600)
        return () => clearTimeout(t)
      }
    } catch {
      /* localStorage blocked — silently skip */
    }
  }, [disabled])

  // Listen for manual replay events
  useEffect(() => {
    const handler = () => {
      setStep(0)
      setClosing(false)
      setOpen(true)
    }
    window.addEventListener('mensaena:replay-onboarding', handler)
    return () => window.removeEventListener('mensaena:replay-onboarding', handler)
  }, [])

  // Escape to skip
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') close(false)
      if (e.key === 'ArrowRight') next()
      if (e.key === 'ArrowLeft') prev()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, step])

  // Lock body scroll while open
  useEffect(() => {
    if (!open) return
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [open])

  const close = useCallback((completed: boolean) => {
    setClosing(true)
    try {
      window.localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ completed, at: new Date().toISOString() }),
      )
    } catch { /* noop */ }
    setTimeout(() => {
      setOpen(false)
      setClosing(false)
      setStep(0)
    }, 280)
  }, [])

  const next = useCallback(() => {
    setStep((s) => {
      if (s >= STEPS.length - 1) {
        close(true)
        return s
      }
      return s + 1
    })
  }, [close])

  const prev = useCallback(() => {
    setStep((s) => Math.max(0, s - 1))
  }, [])

  const goTo = useCallback((i: number) => {
    setStep(Math.max(0, Math.min(STEPS.length - 1, i)))
  }, [])

  if (!open) return null

  const current = STEPS[step]
  const Icon = current.icon
  const isLast = step === STEPS.length - 1
  const isFirst = step === 0

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="onboarding-title"
      className={cn(
        'fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6',
        'transition-opacity duration-300',
        closing ? 'opacity-0 pointer-events-none' : 'opacity-100',
      )}
    >
      {/* Cinematic backdrop — ink wash + tinted aurora */}
      <div className="absolute inset-0 bg-ink-900/70 backdrop-blur-md" />
      <div
        className={cn(
          'absolute inset-0 bg-gradient-to-br transition-colors duration-700 ease-out',
          TINT_CLASSES[current.tint],
        )}
      />
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-[10%] left-[8%] w-64 h-64 rounded-full bg-primary-400/20 blur-3xl animate-float-slow" />
        <div className="absolute bottom-[12%] right-[10%] w-72 h-72 rounded-full bg-primary-300/15 blur-3xl animate-float-delayed" />
      </div>

      {/* Card */}
      <div
        key={step}
        className={cn(
          'relative w-full max-w-xl bg-paper rounded-3xl shadow-card border border-stone-200',
          'overflow-hidden animate-card-enter',
        )}
      >
        {/* Skip button */}
        <button
          type="button"
          onClick={() => close(false)}
          className="absolute top-4 right-4 z-10 w-9 h-9 rounded-full bg-stone-100 hover:bg-stone-200 text-ink-600 flex items-center justify-center transition-colors"
          aria-label="Onboarding überspringen"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Content */}
        <div className="px-6 sm:px-10 pt-10 pb-6 text-center">
          <div
            className={cn(
              'mx-auto w-20 h-20 rounded-3xl flex items-center justify-center mb-6 animate-bounce-in shadow-soft',
              ICON_TINT[current.tint],
            )}
          >
            <Icon className="w-10 h-10" strokeWidth={1.8} />
          </div>

          <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-primary-600 mb-2 animate-fade-in">
            {current.eyebrow}
          </p>

          <h2
            id="onboarding-title"
            className="font-display text-2xl sm:text-3xl text-ink-900 mb-4 leading-tight animate-slide-up"
          >
            {current.title}
          </h2>

          <p className="text-[15px] leading-relaxed text-ink-600 max-w-md mx-auto animate-fade-in-slow">
            {current.body}
          </p>
        </div>

        {/* Progress dots */}
        <div className="flex items-center justify-center gap-2 py-3">
          {STEPS.map((_, i) => (
            <button
              key={i}
              type="button"
              onClick={() => goTo(i)}
              className={cn(
                'rounded-full transition-all duration-300',
                i === step
                  ? 'w-6 h-2 bg-primary-500'
                  : i < step
                    ? 'w-2 h-2 bg-primary-300'
                    : 'w-2 h-2 bg-stone-300 hover:bg-stone-400',
              )}
              aria-label={`Schritt ${i + 1} von ${STEPS.length}`}
              aria-current={i === step ? 'step' : undefined}
            />
          ))}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between gap-3 px-6 sm:px-8 py-5 bg-stone-50 border-t border-stone-200">
          <button
            type="button"
            onClick={() => close(false)}
            className="text-[13px] text-ink-500 hover:text-ink-700 font-medium transition-colors"
          >
            Überspringen
          </button>

          <div className="flex items-center gap-2">
            {!isFirst && (
              <button
                type="button"
                onClick={prev}
                className="h-10 px-4 rounded-xl bg-stone-100 hover:bg-stone-200 text-ink-700 text-[13px] font-semibold inline-flex items-center gap-1.5 transition-colors"
              >
                <ArrowLeft className="w-4 h-4" />
                Zurück
              </button>
            )}
            <button
              type="button"
              onClick={next}
              className="h-10 px-5 rounded-xl bg-primary-500 hover:bg-primary-600 text-white text-[13px] font-semibold inline-flex items-center gap-1.5 transition-colors shadow-soft"
            >
              {isLast ? (
                <>
                  Los geht&rsquo;s
                  <Check className="w-4 h-4" />
                </>
              ) : (
                <>
                  Weiter
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * Imperatively replay the onboarding from anywhere (e.g., a Settings button).
 * Usage:
 *   import { replayOnboarding } from '@/components/shared/OnboardingTour'
 *   <button onClick={replayOnboarding}>Tour wiederholen</button>
 */
export function replayOnboarding() {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.removeItem(STORAGE_KEY)
  } catch { /* noop */ }
  window.dispatchEvent(new CustomEvent('mensaena:replay-onboarding'))
}
