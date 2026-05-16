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
        className="bg-gradient-to-br from-mn-bronze/8 to-mn-teal-soft/8 border-mn-bronze/20"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <PartyPopper className="w-5 h-5 text-mn-bronze" />
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
      className="bg-gradient-to-br from-mn-bronze/8 to-mn-teal-soft/8 border-mn-bronze/20"
    >
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-mn-ink">Dein Profil vervollständigen</span>
        <span className="text-sm font-bold text-mn-bronze">{progress.percentComplete}%</span>
      </div>

      {/* Progress bar */}
      <ProgressBar
        value={progress.percentComplete}
        color="primary"
        size="sm"
        className="mt-2"
      />

      {/* Steps */}
      <div className="mt-3 space-y-2">
        {sortedSteps.map((step) => (
          <div key={step.id} className="flex items-center gap-2.5">
            {step.done ? (
              <CheckCircle className="w-[18px] h-[18px] text-mn-bronze flex-shrink-0" />
            ) : (
              <Circle className="w-[18px] h-[18px] text-mn-ghost flex-shrink-0" />
            )}
            {step.done ? (
              <span className="text-sm text-mn-mute line-through">{step.label}</span>
            ) : (
              <button
                onClick={() => router.push(step.actionPath)}
                className="text-sm text-mn-ink-soft hover:text-mn-bronze cursor-pointer transition-colors text-left"
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
