'use client'

import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

/**
 * SettingsSectionProps – exported interface per spec.
 */
export interface SettingsSectionProps {
  title: string
  description?: string
  children: ReactNode
  danger?: boolean
  icon?: ReactNode
  className?: string
}

/**
 * SettingsSection – Card with title, optional description, optional icon, and children.
 * danger=true → red border + red title (Gefahrenzone)
 */
export default function SettingsSection({
  title,
  description,
  children,
  danger = false,
  icon,
  className,
}: SettingsSectionProps) {
  const accent = danger ? '#C62828' : '#1EAAA6'
  return (
    <div className={cn(
      'relative bg-white rounded-2xl shadow-soft border p-6 pt-7 overflow-hidden transition-shadow hover:shadow-card',
      danger ? 'border-red-200 bg-red-50/30' : 'border-stone-100',
      className,
    )}>
      {/* Top accent line */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: `linear-gradient(90deg, ${accent}, ${accent}33)` }}
      />
      <div className="relative mb-5">
        <div className="flex items-center gap-2">
          {icon && <span className="flex-shrink-0">{icon}</span>}
          <h3 className={cn(
            'font-semibold text-base',
            danger ? 'text-red-700' : 'text-ink-900',
          )}>
            {title}
          </h3>
        </div>
        {description && (
          <p className={cn('text-xs text-ink-500 mt-0.5', icon && 'ml-6')}>
            {description}
          </p>
        )}
      </div>
      <div className="relative">{children}</div>
    </div>
  )
}

/**
 * Toggle – 44×44px touch target, accessible with keyboard focus.
 */
export function Toggle({ value, onChange, disabled }: {
  value: boolean
  onChange: (v: boolean) => void
  disabled?: boolean
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={value}
      onClick={() => !disabled && onChange(!value)}
      disabled={disabled}
      className={cn(
        // 44px min touch target via min-w/min-h
        'relative inline-flex h-7 w-12 items-center rounded-full transition-colors duration-200',
        'focus:outline-none focus:ring-2 focus:ring-primary-400 focus:ring-offset-2',
        'min-w-[44px] min-h-[44px] p-[8.5px]',
        value ? 'bg-primary-600' : 'bg-stone-200',
        disabled && 'opacity-50 cursor-not-allowed',
      )}
      style={{ minWidth: 44, minHeight: 44 }}
    >
      <span className="sr-only">Toggle</span>
      <span
        className={cn(
          'inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform duration-200',
          value ? 'translate-x-5' : 'translate-x-0',
        )}
      />
    </button>
  )
}

/**
 * SettingRow – Row with label, optional description, and a right-side control.
 * min-h 44px for touch targets.
 */
export function SettingRow({ label, description, children }: {
  label: string
  description?: string
  children: ReactNode
}) {
  return (
    <div className="flex items-center justify-between py-3 border-b border-stone-100 last:border-0 gap-4 min-h-[44px]">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-ink-900">{label}</p>
        {description && <p className="text-xs text-ink-500 mt-0.5">{description}</p>}
      </div>
      <div className="flex-shrink-0">{children}</div>
    </div>
  )
}
