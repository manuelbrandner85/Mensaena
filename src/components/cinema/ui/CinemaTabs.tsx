'use client'

import { useRef, useState, useEffect } from 'react'
import { cn } from '@/lib/design-system'

interface Tab {
  id: string
  label: string
  icon?: React.ReactNode
  badge?: number
}

interface CinemaTabsProps {
  tabs: Tab[]
  active: string
  onChange: (id: string) => void
  className?: string
}

export default function CinemaTabs({ tabs, active, onChange, className }: CinemaTabsProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [indicator, setIndicator] = useState({ left: 0, width: 0 })

  useEffect(() => {
    const container = containerRef.current
    if (!container) return
    const btn = container.querySelector<HTMLButtonElement>(`[data-tab="${active}"]`)
    if (!btn) return
    const containerRect = container.getBoundingClientRect()
    const btnRect = btn.getBoundingClientRect()
    setIndicator({
      left: btnRect.left - containerRect.left,
      width: btnRect.width,
    })
  }, [active])

  return (
    <div ref={containerRef} className={cn('relative flex border-b border-white/5', className)}>
      {/* Sliding amber indicator */}
      <div
        className="absolute bottom-0 h-0.5 bg-mn-bronze rounded-full transition-all duration-300"
        style={{ left: indicator.left, width: indicator.width }}
        aria-hidden
      />
      {tabs.map(tab => (
        <button
          key={tab.id}
          data-tab={tab.id}
          onClick={() => onChange(tab.id)}
          className={cn(
            'relative flex items-center gap-1.5 px-4 py-3 text-sm font-medium transition-colors duration-200',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-mn-bronze focus-visible:ring-inset',
            active === tab.id ? 'text-mn-bronze' : 'text-mn-mute hover:text-mn-ink-soft',
          )}
        >
          {tab.icon}
          {tab.label}
          {tab.badge != null && tab.badge > 0 && (
            <span className="ml-1 min-w-[18px] h-[18px] px-1 rounded-full bg-mn-herzrot text-white text-[10px] font-mono flex items-center justify-center">
              {tab.badge > 99 ? '99+' : tab.badge}
            </span>
          )}
        </button>
      ))}
    </div>
  )
}
