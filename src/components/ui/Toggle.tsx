'use client'

import { cn } from '@/lib/design-system'

export interface ToggleProps {
  checked: boolean
  onChange: (checked: boolean) => void
  label?: string
  description?: string
  disabled?: boolean
  size?: 'sm' | 'md'
  className?: string
}

const trackSize = {
  sm: 'w-8 h-[18px]',
  md: 'w-11 h-6',
}

const thumbSize = {
  sm: 'w-3.5 h-3.5',
  md: 'w-5 h-5',
}

const thumbTranslate = {
  sm: 'translate-x-[14px]',
  md: 'translate-x-5',
}

export default function Toggle({
  checked,
  onChange,
  label,
  description,
  disabled = false,
  size = 'md',
  className,
}: ToggleProps) {
  return (
    <label
      className={cn(
        'inline-flex items-start gap-3 cursor-pointer select-none',
        disabled && 'opacity-50 pointer-events-none',
        className,
      )}
    >
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={cn(
          'relative inline-flex flex-shrink-0 rounded-full transition-colors duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400 focus-visible:ring-offset-2',
          trackSize[size],
          checked ? 'bg-primary-500' : 'bg-gray-200',
        )}
      >
        <span
          className={cn(
            'inline-block rounded-full bg-white shadow-sm transform transition-transform duration-200',
            thumbSize[size],
            checked ? thumbTranslate[size] : 'translate-x-0.5',
            'mt-[1px]',
          )}
        />
      </button>
      {(label || description) && (
        <div className="flex flex-col">
          {label && <span className="text-sm font-medium text-gray-900">{label}</span>}
          {description && <span className="text-xs text-gray-500 mt-0.5">{description}</span>}
        </div>
      )}
    </label>
  )
}
