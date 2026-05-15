'use client'

import { useId } from 'react'
import { cn } from '@/lib/design-system'

interface CinemaToggleProps {
  checked: boolean
  onChange: (v: boolean) => void
  label?: string
  description?: string
  disabled?: boolean
  className?: string
}

export default function CinemaToggle({ checked, onChange, label, description, disabled, className }: CinemaToggleProps) {
  const id = useId()

  return (
    <div className={cn('flex items-start gap-3', className)}>
      <button
        id={id}
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => !disabled && onChange(!checked)}
        className={cn(
          'relative inline-flex shrink-0 h-6 w-11 rounded-full border-2 border-transparent',
          'transition-colors duration-200 ease-in-out cursor-pointer',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-mn-bronze focus-visible:ring-offset-2 focus-visible:ring-offset-mn-void',
          checked ? 'bg-mn-bronze' : 'bg-mn-surface',
          disabled && 'opacity-50 cursor-not-allowed',
        )}
      >
        <span
          className={cn(
            'pointer-events-none inline-block h-5 w-5 rounded-full bg-mn-elevated shadow',
            'transform transition-transform duration-200 ease-in-out',
            checked ? 'translate-x-5' : 'translate-x-0',
          )}
        />
      </button>
      {(label || description) && (
        <label htmlFor={id} className="cursor-pointer">
          {label && <div className="text-sm font-medium text-mn-ink">{label}</div>}
          {description && <div className="text-xs text-mn-mute mt-0.5">{description}</div>}
        </label>
      )}
    </div>
  )
}
