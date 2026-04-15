'use client'

/* ═══════════════════════════════════════════════════════════════════════
   MENSAENA – Onboarding Tour
   Cinematic 6-step welcome tour for first-time users.
   - Gated on localStorage key `mensaena:onboarding-completed-v1`
   - Replayable via `replayOnboarding()` helper or `mensaena:replay-onboarding` event
   - Keyboard: →/← navigate, Esc skip
   ═══════════════════════════════════════════════════════════════════════ */

import { useEffect, useRef, useState } from 'react'
import {
  Sparkles,
  Compass,
  Map,
  PlusCircle,
  MessageCircle,
  Users,
  ArrowLeft,
  ArrowRight,
  X,
  type LucideIcon,
} from 'lucide-react'

const STORAGE_KEY = 'mensaena:onboarding-completed-v1'
const REPLAY_EVENT = 'mensaena:replay-onboarding'

type Tint =
  | 'teal'
  | 'mint'
  | 'sky'
  | 'sunrise'
  | 'forest'
  | 'violet'

interface Step {
  icon: LucideIcon
  eyebrow: string
  title: string
  body: string
  tint: Tint
}

const STEPS: Step[] = [
  {
    icon: Sparkles,
    eyebrow: 'Willkommen',
    title: 'Schön, dass du da bist.',
    body:
      'Mensaena ist dein Ort für gelebte Nachbarschaftshilfe. In sechs kurzen Schritten zeigen wir dir, wie du dich sicher und mühelos einfindest.',
    tint: 'teal',
  },
  {
    icon: Compass,
    eyebrow: 'Dein Dashboard',
    title: 'Der Überblick auf einen Blick.',
    body:
      'Im Dashboard findest du alle wichtigen Informationen auf einen Blick: neue Anfragen, Angebote aus deiner Nachbarschaft und persönliche Empfehlungen.',
    tint: 'mint',
  },
  {
    icon: Map,
    eyebrow: 'Die Karte',
    title: 'Hilfe in deiner Umgebung.',
    body:
      'Auf der interaktiven Karte siehst du, wo in deiner Nähe gerade Hilfe gebraucht oder angeboten wird. Klick auf einen Pin und lerne deine Nachbarn kennen.',
    tint: 'sky',
  },
  {
    icon: PlusCircle,
    eyebrow: 'Dein erster Beitrag',
    title: 'Teile, was du bieten oder suchen kannst.',
    body:
      'Egal ob du Werkzeug verleihst, beim Einkauf helfen willst oder selbst Unterstützung brauchst – ein Beitrag ist in wenigen Sekunden erstellt.',
    tint: 'sunrise',
  },
  {
    icon: MessageCircle,
    eyebrow: 'Nachrichten',
    title: 'Direkt miteinander sprechen.',
    body:
      'Alles, was zwischen Nachbarn passiert, läuft über sichere Direktnachrichten. Freundlich, respektvoll, DSGVO-konform.',
    tint: 'forest',
  },
  {
    icon: Users,
    eyebrow: 'Gemeinschaft',
    title: 'Gemeinsam stark.',
    body:
      'Mensaena lebt vom Miteinander. Sei respektvoll, hilfsbereit und offen – dann wirst du schnell merken, wie herzlich deine Nachbarschaft ist.',
    tint: 'violet',
  },
]

const TINT_BG: Record<Tint, string> = {
  teal: 'from-primary-500/25 via-primary-400/15 to-transparent',
  mint: 'from-emerald-400/25 via-teal-300/15 to-transparent',
  sky: 'from-sky-400/25 via-blue-300/15 to-transparent',
  sunrise: 'from-amber-400/25 via-orange-300/15 to-transparent',
  forest: 'from-green-500/25 via-emerald-400/15 to-transparent',
  violet: 'from-violet-500/25 via-purple-400/15 to-transparent',
}

const TINT_ICON: Record<Tint, string> = {
  teal: 'bg-primary-500/15 text-primary-700 ring-primary-500/30',
  mint: 'bg-emerald-500/15 text-emerald-700 ring-emerald-500/30',
  sky: 'bg-sky-500/15 text-sky-700 ring-sky-500/30',
  sunrise: 'bg-amber-500/15 text-amber-700 ring-amber-500/30',
  forest: 'bg-green-600/15 text-green-700 ring-green-600/30',
  violet: 'bg-violet-500/15 text-violet-700 ring-violet-500/30',
}

/** Trigger the onboarding tour again from anywhere in the app. */
export function replayOnboarding() {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.removeItem(STORAGE_KEY)
  } catch {
    /* ignore */
  }
  window.dispatchEvent(new CustomEvent(REPLAY_EVENT))
}

export default function OnboardingTour() {
  const [open, setOpen] = useState(false)
  const [index, setIndex] = useState(0)
  const timerRef = useRef<number | null>(null)

  // ── Initial: open tour if never completed, with cinematic delay ──
  useEffect(() => {
    if (typeof window === 'undefined') return
    let completed = false
    try {
      completed = window.localStorage.getItem(STORAGE_KEY) === '1'
    } catch {
      /* ignore */
    }
    if (completed) return

    timerRef.current = window.setTimeout(() => {
      setIndex(0)
      setOpen(true)
    }, 600)

    return () => {
      if (timerRef.current) window.clearTimeout(timerRef.current)
    }
  }, [])

  // ── Listen for replay event ──
  useEffect(() => {
    const handler = () => {
      setIndex(0)
      setOpen(true)
    }
    window.addEventListener(REPLAY_EVENT, handler)
    return () => window.removeEventListener(REPLAY_EVENT, handler)
  }, [])

  // ── Body scroll lock while open ──
  useEffect(() => {
    if (!open) return
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = prev
    }
  }, [open])

  // ── Keyboard navigation ──
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') {
        e.preventDefault()
        next()
      } else if (e.key === 'ArrowLeft') {
        e.preventDefault()
        prev()
      } else if (e.key === 'Escape') {
        e.preventDefault()
        complete()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, index])

  const complete = () => {
    try {
      window.localStorage.setItem(STORAGE_KEY, '1')
    } catch {
      /* ignore */
    }
    setOpen(false)
  }

  const next = () => {
    if (index < STEPS.length - 1) {
      setIndex((i) => i + 1)
    } else {
      complete()
    }
  }

  const prev = () => {
    if (index > 0) setIndex((i) => i - 1)
  }

  if (!open) return null

  const step = STEPS[index]
  const Icon = step.icon
  const isLast = index === STEPS.length - 1
  const isFirst = index === 0

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6 animate-fade-in"
      role="dialog"
      aria-modal="true"
      aria-labelledby="onboarding-title"
    >
      {/* Backdrop */}
      <button
        type="button"
        aria-label="Tour überspringen"
        onClick={complete}
        className="absolute inset-0 bg-ink-950/60 backdrop-blur-md"
      />

      {/* Card */}
      <div className="relative w-full max-w-lg overflow-hidden rounded-3xl border border-white/40 bg-paper shadow-2xl animate-slide-up">
        {/* Ambient gradient */}
        <div
          className={`pointer-events-none absolute inset-0 bg-gradient-to-br ${TINT_BG[step.tint]}`}
          aria-hidden="true"
        />

        {/* Close */}
        <button
          type="button"
          onClick={complete}
          className="absolute top-4 right-4 z-10 p-2 rounded-full text-ink-500 hover:text-ink-800 hover:bg-stone-100 transition-colors"
          aria-label="Tour schließen"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="relative p-7 sm:p-10">
          {/* Icon */}
          <div
            className={`inline-flex items-center justify-center w-14 h-14 rounded-2xl ring-1 ${TINT_ICON[step.tint]} mb-5 shadow-sm`}
          >
            <Icon className="w-7 h-7" />
          </div>

          {/* Eyebrow */}
          <p className="text-[11px] uppercase tracking-[0.18em] font-semibold text-primary-700/80 mb-2">
            {step.eyebrow} · {index + 1}/{STEPS.length}
          </p>

          {/* Title */}
          <h2
            id="onboarding-title"
            className="font-display text-2xl sm:text-3xl font-medium text-ink-900 tracking-tight mb-3 leading-tight"
          >
            {step.title}
          </h2>

          {/* Body */}
          <p className="text-sm sm:text-base text-ink-700 leading-relaxed mb-8">
            {step.body}
          </p>

          {/* Progress dots */}
          <div className="flex items-center gap-1.5 mb-7">
            {STEPS.map((_, i) => (
              <button
                key={i}
                type="button"
                onClick={() => setIndex(i)}
                aria-label={`Zu Schritt ${i + 1} springen`}
                className={`h-1.5 rounded-full transition-all ${
                  i === index
                    ? 'w-8 bg-primary-600'
                    : i < index
                      ? 'w-1.5 bg-primary-400'
                      : 'w-1.5 bg-stone-300 hover:bg-stone-400'
                }`}
              />
            ))}
          </div>

          {/* Actions */}
          <div className="flex items-center justify-between gap-3">
            <button
              type="button"
              onClick={complete}
              className="text-xs font-medium text-ink-500 hover:text-ink-800 transition-colors px-2 py-2"
            >
              Überspringen
            </button>

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={prev}
                disabled={isFirst}
                className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-medium border border-stone-200 text-ink-700 hover:bg-stone-100 transition-all disabled:opacity-40 disabled:cursor-not-allowed min-h-[44px]"
              >
                <ArrowLeft className="w-4 h-4" />
                Zurück
              </button>
              <button
                type="button"
                onClick={next}
                className="flex items-center gap-1.5 px-5 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all shadow-sm min-h-[44px]"
              >
                {isLast ? 'Los geht\u2019s' : 'Weiter'}
                {!isLast && <ArrowRight className="w-4 h-4" />}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
