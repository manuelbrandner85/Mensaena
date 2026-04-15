'use client'

import { useCallback, useEffect, useState, type ReactNode } from 'react'

/** Namespaced localStorage helper for feature widgets. */
export function useFeatureStorage<T>(key: string, initial: T): [T, (v: T | ((prev: T) => T)) => void] {
  const storageKey = `mensaena:feature:${key}`
  const [value, setValue] = useState<T>(initial)
  const [hydrated, setHydrated] = useState(false)

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(storageKey)
      if (raw) setValue(JSON.parse(raw) as T)
    } catch {
      /* ignore */
    }
    setHydrated(true)
  }, [storageKey])

  const update = useCallback(
    (next: T | ((prev: T) => T)) => {
      setValue(prev => {
        const resolved = typeof next === 'function' ? (next as (p: T) => T)(prev) : next
        try {
          window.localStorage.setItem(storageKey, JSON.stringify(resolved))
        } catch {
          /* ignore */
        }
        return resolved
      })
    },
    [storageKey],
  )

  return [hydrated ? value : initial, update]
}

/** Shared card frame for every feature widget. */
export function FeatureCard({
  icon,
  title,
  subtitle,
  accent = 'primary',
  children,
}: {
  icon: ReactNode
  title: string
  subtitle?: string
  accent?: 'primary' | 'rose' | 'amber' | 'sky' | 'violet' | 'red'
  children: ReactNode
}) {
  const accentMap: Record<string, string> = {
    primary: 'bg-primary-50 border-primary-100 text-primary-700',
    rose:    'bg-rose-50 border-rose-100 text-rose-700',
    amber:   'bg-amber-50 border-amber-100 text-amber-700',
    sky:     'bg-sky-50 border-sky-100 text-sky-700',
    violet:  'bg-violet-50 border-violet-100 text-violet-700',
    red:     'bg-red-50 border-red-100 text-red-700',
  }
  const iconCls = accentMap[accent]

  return (
    <div className="rounded-2xl border border-warm-200 bg-white shadow-soft p-5">
      <div className="flex items-start gap-3 mb-4">
        <div className={`w-10 h-10 rounded-xl border flex items-center justify-center flex-shrink-0 ${iconCls}`}>
          {icon}
        </div>
        <div className="min-w-0">
          <h3 className="text-sm font-bold text-gray-900">{title}</h3>
          {subtitle && <p className="text-xs text-gray-500 mt-0.5">{subtitle}</p>}
        </div>
      </div>
      {children}
    </div>
  )
}

/** Tiny pill button for feature widgets. */
export function PillButton({
  children,
  onClick,
  variant = 'primary',
  disabled,
  type = 'button',
}: {
  children: ReactNode
  onClick?: () => void
  variant?: 'primary' | 'ghost' | 'danger'
  disabled?: boolean
  type?: 'button' | 'submit'
}) {
  const base = 'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold transition-colors disabled:opacity-50'
  const styles: Record<string, string> = {
    primary: 'bg-primary-500 text-white hover:bg-primary-600',
    ghost: 'bg-stone-100 text-ink-700 hover:bg-stone-200',
    danger: 'bg-red-500 text-white hover:bg-red-600',
  }
  return (
    <button type={type} onClick={onClick} disabled={disabled} className={`${base} ${styles[variant]}`}>
      {children}
    </button>
  )
}
