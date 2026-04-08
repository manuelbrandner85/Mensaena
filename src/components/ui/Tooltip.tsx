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
            'absolute z-tooltip px-2.5 py-1.5 text-xs font-medium text-white bg-gray-800 rounded-lg shadow-lg whitespace-nowrap pointer-events-none animate-fade-in',
            positionStyles[position],
            className,
          )}
        >
          {content}
        </div>
      )}
    </div>
  )
}
