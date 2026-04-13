'use client'

import { Siren } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Props {
  onClick: () => void
  size?: 'sm' | 'md' | 'lg'
  variant?: 'round' | 'header'
  className?: string
}

export default function SOSButton({ onClick, size = 'lg', variant = 'round', className }: Props) {
  // Round variant (legacy, used in modals etc.)
  if (variant === 'round') {
    const sizeClasses = {
      sm: 'w-10 h-10',
      md: 'w-14 h-14',
      lg: 'w-20 h-20',
    }
    const iconClasses = {
      sm: 'w-5 h-5',
      md: 'w-7 h-7',
      lg: 'w-10 h-10',
    }

    return (
      <button
        onClick={onClick}
        className={cn(
          'relative rounded-full bg-red-600 text-white flex items-center justify-center',
          'shadow-xl shadow-red-300 hover:bg-red-700 active:scale-95',
          'transition-all duration-200 focus:outline-none',
          'ring-4 ring-red-300/40 animate-[sosRing_2s_ease-in-out_infinite]',
          sizeClasses[size],
          className,
        )}
        aria-label="SOS - Notruf"
      >
        <span className="absolute inset-0 rounded-full bg-red-500 animate-ping opacity-30" aria-hidden="true" />
        <span className="absolute inset-0 rounded-full bg-red-500 animate-pulse opacity-20" aria-hidden="true" />
        <Siren className={cn('relative z-10', iconClasses[size])} />
      </button>
    )
  }

  // Header variant – rectangular, subtle blink
  return (
    <button
      onClick={onClick}
      className={cn(
        'relative flex items-center gap-1.5 px-3 py-1.5 rounded-lg',
        'bg-red-600 text-white text-xs font-bold',
        'hover:bg-red-700 active:scale-[0.97]',
        'transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-red-300',
        'animate-sos-blink',
        className,
      )}
      aria-label="SOS - Notruf"
    >
      <Siren className="w-4 h-4 relative z-10" />
      <span className="relative z-10 hidden sm:inline">SOS</span>
    </button>
  )
}
