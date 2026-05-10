'use client'

import { useState, type ReactNode } from 'react'
import { cn } from '@/lib/design-system'

export interface TooltipProps {
  content: string
  children: ReactNode
  position?: 'top' | 'bottom' | 'left' | 'right'
  className?: string
}

const positionStyles = {
  top:    'bottom-full left-1/2 -translate-x-1/2 mb-2',
  bottom: 'top-full left-1/2 -translate-x-1/2 mt-2',
  left:   'right-full top-1/2 -translate-y-1/2 mr-2',
  right:  'left-full top-1/2 -translate-y-1/2 ml-2',
} as const

export default function Tooltip({
  content,
  children,
  position = 'top',
  className,
}: TooltipProps) {
  const [show, setShow] = useState(false)

  return (
    <div
      className="relative inline-flex"
      onMouseEnter={() => setShow(true)}
      onMouseLeave={() => setShow(false)}
      onFocus={() => setShow(true)}
      onBlur={() => setShow(false)}
    >
      {children}
      {show && (
        <div
          role="tooltip"
          className={cn(
            'absolute z-tooltip px-3 py-2 text-xs font-medium text-paper rounded-xl whitespace-nowrap pointer-events-none animate-fade-in',
            positionStyles[position],
            className,
          )}
          style={{
            background: 'linear-gradient(150deg, rgba(14,26,25,0.96) 0%, rgba(11,30,29,0.98) 100%)',
            border: '1px solid rgba(255,255,255,0.08)',
            backdropFilter: 'blur(8px) saturate(140%)',
            WebkitBackdropFilter: 'blur(8px) saturate(140%)',
            boxShadow:
              '0 0 0 0.5px rgba(0,0,0,0.05), 0 4px 12px rgba(0,0,0,0.18), 0 0 24px rgba(30,170,166,0.12), inset 0 1px 0 rgba(255,255,255,0.08)',
          }}
        >
          {content}
        </div>
      )}
    </div>
  )
}
