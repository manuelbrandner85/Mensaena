'use client'

import { useState, useEffect } from 'react'
import { X, Lightbulb } from 'lucide-react'

interface Step {
  icon: string
  title: string
  text: string
}

interface OnboardingHintProps {
  /** Unique key stored in localStorage – hint shows once per key */
  storageKey: string
  title: string
  steps: Step[]
  accentColor?: string
}

/**
 * Zeigt beim ersten Besuch eines Moduls einen kurzen 3-Schritt-Tipp.
 * Wird nach dem Schließen dauerhaft ausgeblendet (localStorage).
 */
export default function OnboardingHint({
  storageKey,
  title,
  steps,
  accentColor = 'amber',
}: OnboardingHintProps) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    try {
      const seen = localStorage.getItem(`onboarding_${storageKey}`)
      if (!seen) setVisible(true)
    } catch {
      // localStorage not available (SSR / private mode)
    }
  }, [storageKey])

  const dismiss = () => {
    setVisible(false)
    try { localStorage.setItem(`onboarding_${storageKey}`, '1') } catch { /* ignore */ }
  }

  if (!visible) return null

  const colors: Record<string, { bg: string; border: string; icon: string; btn: string }> = {
    amber:  { bg: 'bg-amber-50',   border: 'border-amber-200',  icon: 'text-amber-500',  btn: 'bg-amber-500 hover:bg-amber-600'  },
    violet: { bg: 'bg-violet-50',  border: 'border-violet-200', icon: 'text-violet-500', btn: 'bg-violet-500 hover:bg-violet-600' },
    teal:   { bg: 'bg-teal-50',    border: 'border-teal-200',   icon: 'text-teal-500',   btn: 'bg-teal-500 hover:bg-teal-600'    },
    blue:   { bg: 'bg-blue-50',    border: 'border-blue-200',   icon: 'text-blue-500',   btn: 'bg-blue-500 hover:bg-blue-600'    },
    green:  { bg: 'bg-green-50',   border: 'border-green-200',  icon: 'text-green-500',  btn: 'bg-green-500 hover:bg-green-600'  },
    purple: { bg: 'bg-purple-50',  border: 'border-purple-200', icon: 'text-purple-500', btn: 'bg-purple-500 hover:bg-purple-600' },
  }
  const c = colors[accentColor] ?? colors.amber

  return (
    <div className={`rounded-2xl border ${c.bg} ${c.border} p-4 animate-fade-in`}>
      <div className="flex items-start justify-between gap-2 mb-3">
        <div className="flex items-center gap-2">
          <Lightbulb className={`w-4 h-4 flex-shrink-0 ${c.icon}`} />
          <p className="text-sm font-bold text-gray-900">{title}</p>
        </div>
        <button
          onClick={dismiss}
          className="text-gray-400 hover:text-gray-600 transition-colors flex-shrink-0 p-0.5"
          aria-label="Schließen"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      <div className="grid grid-cols-3 gap-2 mb-3">
        {steps.map((step, i) => (
          <div key={i} className="bg-white/80 rounded-xl p-2.5 text-center border border-white">
            <div className="text-xl mb-1">{step.icon}</div>
            <p className="text-xs font-semibold text-gray-800 leading-tight">{step.title}</p>
            <p className="text-[10px] text-gray-500 mt-0.5 leading-tight">{step.text}</p>
          </div>
        ))}
      </div>

      <button
        onClick={dismiss}
        className={`w-full py-2 ${c.btn} text-white text-sm font-semibold rounded-xl transition-colors`}
      >
        Verstanden – loslegen!
      </button>
    </div>
  )
}
