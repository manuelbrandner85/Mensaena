'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { CheckCircle, Circle, PartyPopper, X } from 'lucide-react'
import { cn } from '@/lib/design-system'
import { Card, ProgressBar, IconButton } from '@/components/ui'
import type { OnboardingProgress } from '../types'

interface OnboardingChecklistProps {
  progress: OnboardingProgress
}

export default function OnboardingChecklist({ progress }: OnboardingChecklistProps) {
  const router = useRouter()
  const [dismissed, setDismissed] = useState(false)

  // Don't render if completed and dismissed (or was already completed from start)
  if (progress.completed && !dismissed) {
    // Show congratulations briefly
    return (
      <Card
        variant="flat"
        padding="md"
        className="bg-gradient-to-br from-primary-50 to-teal-50 border-primary-200"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <PartyPopper className="w-5 h-5 text-primary-600" />
            <span className="text-sm font-semibold text-primary-900">Dein Profil ist komplett! 🎉</span>
          </div>
          <IconButton
            icon={<X className="w-4 h-4" />}
            label="Schließen"
            variant="primary"
            size="xs"
            onClick={() => setDismissed(true)}
          />
        </div>
      </Card>
    )
  }

  if (progress.completed || dismissed) return null

  // Sort: undone first, then done
  const sortedSteps = [...progress.steps].sort((a, b) => {
    if (a.done === b.done) return 0
    return a.done ? 1 : -1
  })

  return (
    <Card
      variant="flat"
      padding="md"
      className="bg-gradient-to-br from-blue-50 to-indigo-50 border-blue-100"
    >
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-ink-900">Dein Profil vervollständigen</span>
        <span className="text-sm font-bold text-blue-700">{progress.percentComplete}%</span>
      </div>

      {/* Progress bar */}
      <ProgressBar
        value={progress.percentComplete}
        color="info"
        size="sm"
        className="mt-2"
      />

      {/* Steps */}
      <div className="mt-3 space-y-2">
        {sortedSteps.map((step) => (
          <div key={step.id} className="flex items-center gap-2.5">
            {step.done ? (
              <CheckCircle className="w-[18px] h-[18px] text-primary-500 flex-shrink-0" />
            ) : (
              <Circle className="w-[18px] h-[18px] text-stone-400 flex-shrink-0" />
            )}
            {step.done ? (
              <span className="text-sm text-ink-500 line-through">{step.label}</span>
            ) : (
              <button
                onClick={() => router.push(step.actionPath)}
                className="text-sm text-ink-700 hover:text-blue-700 cursor-pointer transition-colors text-left"
              >
                {step.label}
              </button>
            )}
          </div>
        ))}
      </div>
    </Card>
  )
}
