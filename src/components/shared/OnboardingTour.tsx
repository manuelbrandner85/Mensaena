'use client'

import { useEffect, useState } from 'react'
import {
  Sparkles, Layers, HeartHandshake, LifeBuoy, Rocket, ChevronRight, X,
} from 'lucide-react'
import { useT } from '@/lib/i18n'

const STORAGE_KEY = 'mensaena-onboarding-seen-v1'

type Step = {
  titleKey: string
  textKey: string
  icon: React.ComponentType<{ className?: string }>
  gradient: string      // background gradient class chain
  accent: string        // accent text color
  emoji: string
}

const STEPS: Step[] = [
  {
    titleKey: 'onboarding.step1Title',
    textKey: 'onboarding.step1Text',
    icon: Sparkles,
    gradient: 'from-primary-700 via-primary-500 to-teal-400',
    accent: 'text-primary-50',
    emoji: '✨',
  },
  {
    titleKey: 'onboarding.step2Title',
    textKey: 'onboarding.step2Text',
    icon: Layers,
    gradient: 'from-ink-900 via-ink-800 to-trust-600',
    accent: 'text-warm-100',
    emoji: '🏠',
  },
  {
    titleKey: 'onboarding.step3Title',
    textKey: 'onboarding.step3Text',
    icon: HeartHandshake,
    gradient: 'from-trust-600 via-primary-600 to-primary-400',
    accent: 'text-primary-50',
    emoji: '🤝',
  },
  {
    titleKey: 'onboarding.step4Title',
    textKey: 'onboarding.step4Text',
    icon: LifeBuoy,
    gradient: 'from-emergency-600 via-emergency-500 to-orange-400',
    accent: 'text-red-50',
    emoji: '🚨',
  },
  {
    titleKey: 'onboarding.step5Title',
    textKey: 'onboarding.step5Text',
    icon: Rocket,
    gradient: 'from-primary-600 via-teal-500 to-primary-300',
    accent: 'text-primary-50',
    emoji: '🚀',
  },
]

export default function OnboardingTour() {
  const { t } = useT()
  const [open, setOpen] = useState(false)
  const [step, setStep] = useState(0)
  const [entering, setEntering] = useState(false)

  // Auto-open on first load if user has never seen it, and listen for
  // replay events from settings / palette.
  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      const seen = localStorage.getItem(STORAGE_KEY)
      if (!seen) {
        setTimeout(() => openTour(), 600)
      }
    } catch { /* ignore */ }

    const replay = () => openTour()
    window.addEventListener('mensaena:replay-onboarding', replay)
    return () => window.removeEventListener('mensaena:replay-onboarding', replay)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const openTour = () => {
    setStep(0)
    setOpen(true)
    setEntering(true)
    setTimeout(() => setEntering(false), 500)
  }

  const finish = () => {
    try { localStorage.setItem(STORAGE_KEY, String(Date.now())) } catch { /* ignore */ }
    setOpen(false)
  }

  // ESC to close
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') finish()
      if (e.key === 'ArrowRight') setStep((s) => Math.min(s + 1, STEPS.length - 1))
      if (e.key === 'ArrowLeft')  setStep((s) => Math.max(s - 1, 0))
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open])

  if (!open) return null

  const current = STEPS[step]
  const isLast = step === STEPS.length - 1
  const Icon = current.icon

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Onboarding"
      className="fixed inset-0 z-[2000] flex items-center justify-center"
    >
      {/* Backdrop */}
      <div className="absolute inset-0 bg-ink-900/80 backdrop-blur-md animate-fade-in" />

      {/* Cinematic gradient panel */}
      <div
        key={step}
        className={`relative w-full h-full md:w-[92vw] md:max-w-5xl md:h-[80vh] md:rounded-[36px] overflow-hidden shadow-2xl bg-gradient-to-br ${current.gradient} ${entering ? 'animate-scale-in' : 'animate-fade-in'}`}
      >
        {/* Animated ornament layers */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute -top-32 -left-32 w-96 h-96 rounded-full bg-white/10 blur-3xl animate-float-slow" />
          <div className="absolute -bottom-40 -right-24 w-[28rem] h-[28rem] rounded-full bg-white/10 blur-3xl animate-float-delayed" />
          <div className="absolute top-1/3 left-1/2 w-64 h-64 rounded-full bg-white/5 blur-2xl animate-float" />
          {/* Soft grid */}
          <div
            className="absolute inset-0 opacity-[0.07]"
            style={{
              backgroundImage:
                'linear-gradient(to right, rgba(255,255,255,0.6) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,0.6) 1px, transparent 1px)',
              backgroundSize: '48px 48px',
            }}
          />
        </div>

        {/* Close */}
        <button
          onClick={finish}
          aria-label={t('a11y.closeDialog')}
          className="absolute top-5 right-5 z-10 w-10 h-10 rounded-full bg-white/15 hover:bg-white/25 backdrop-blur-sm flex items-center justify-center text-white transition-all"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Content */}
        <div className="relative z-[1] flex flex-col justify-between h-full px-6 md:px-16 py-12 md:py-16 text-white">
          {/* Step number + emoji */}
          <div className="flex items-center gap-3 animate-slide-down">
            <div className="text-5xl md:text-6xl filter drop-shadow-lg">{current.emoji}</div>
            <div className="flex flex-col">
              <span className="text-[10px] uppercase tracking-[0.2em] opacity-70 font-medium">
                {step + 1} / {STEPS.length}
              </span>
              <span className="text-xs opacity-80 font-medium">Mensaena</span>
            </div>
          </div>

          {/* Title + text */}
          <div className="max-w-2xl">
            <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-white/15 backdrop-blur-sm mb-6 animate-bounce-in">
              <Icon className="w-7 h-7 text-white" />
            </div>
            <h1 className="font-display text-3xl sm:text-5xl md:text-6xl font-medium leading-tight tracking-tight mb-4 animate-slide-up">
              {t(current.titleKey)}
            </h1>
            <p className={`text-base sm:text-lg md:text-xl leading-relaxed max-w-xl opacity-95 animate-slide-up ${current.accent}`}>
              {t(current.textKey)}
            </p>
          </div>

          {/* Controls */}
          <div className="flex items-center justify-between gap-4 animate-slide-up">
            {/* Progress dots */}
            <div className="flex items-center gap-2">
              {STEPS.map((_, i) => (
                <button
                  key={i}
                  onClick={() => setStep(i)}
                  aria-label={`Step ${i + 1}`}
                  className={`h-1.5 rounded-full transition-all ${
                    i === step ? 'w-8 bg-white' : 'w-1.5 bg-white/40 hover:bg-white/70'
                  }`}
                />
              ))}
            </div>

            {/* Buttons */}
            <div className="flex items-center gap-2 sm:gap-3">
              <button
                onClick={finish}
                className="px-4 py-2.5 rounded-full text-xs sm:text-sm font-medium text-white/80 hover:text-white hover:bg-white/10 transition-all"
              >
                {t('onboarding.skip')}
              </button>
              <button
                onClick={() => (isLast ? finish() : setStep((s) => s + 1))}
                className="group inline-flex items-center gap-2 pl-5 pr-4 py-2.5 rounded-full bg-white text-ink-900 text-sm font-semibold shadow-lg hover:shadow-xl hover:scale-[1.03] active:scale-95 transition-all"
              >
                {isLast ? t('onboarding.finish') : t('onboarding.next')}
                <ChevronRight className="w-4 h-4 transition-transform group-hover:translate-x-0.5" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
