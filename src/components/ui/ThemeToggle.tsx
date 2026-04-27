'use client'

import { Sun, Moon, Monitor } from 'lucide-react'
import { useTheme, type ThemeMode } from '@/hooks/useTheme'
import { cn } from '@/lib/utils'

const OPTIONS: { value: ThemeMode; icon: React.ReactNode; label: string }[] = [
  { value: 'light',  icon: <Sun   className="w-3.5 h-3.5" />, label: 'Hell'   },
  { value: 'system', icon: <Monitor className="w-3.5 h-3.5" />, label: 'Auto' },
  { value: 'dark',   icon: <Moon  className="w-3.5 h-3.5" />, label: 'Dunkel' },
]

interface ThemeToggleProps {
  /** Show text labels next to icons. Default: icons only. */
  showLabels?: boolean
  className?: string
}

export default function ThemeToggle({ showLabels = false, className }: ThemeToggleProps) {
  const { mode, setMode } = useTheme()

  return (
    <div
      className={cn(
        'inline-flex items-center gap-0.5 p-1 rounded-xl bg-stone-100 dark:bg-stone-800 border border-stone-200 dark:border-stone-700',
        className,
      )}
      role="radiogroup"
      aria-label="Farbschema"
    >
      {OPTIONS.map((opt) => {
        const active = mode === opt.value
        return (
          <button
            key={opt.value}
            role="radio"
            aria-checked={active}
            aria-label={opt.label}
            onClick={() => setMode(opt.value)}
            className={cn(
              'flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all',
              active
                ? 'bg-white dark:bg-stone-700 text-ink-900 dark:text-stone-100 shadow-sm'
                : 'text-ink-500 dark:text-stone-400 hover:text-ink-700 dark:hover:text-stone-200',
            )}
          >
            {opt.icon}
            {showLabels && <span>{opt.label}</span>}
          </button>
        )
      })}
    </div>
  )
}
