'use client'

import { Siren } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Props {
  onClick: () => void
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

export default function SOSButton({ onClick, size = 'lg', className }: Props) {
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
        'transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-red-200',
        sizeClasses[size],
        className,
      )}
      aria-label="SOS - Notruf"
    >
      {/* Pulsating ring */}
      <span className="absolute inset-0 rounded-full bg-red-500 animate-ping opacity-30" aria-hidden="true" />
      <span className="absolute inset-0 rounded-full bg-red-500 animate-pulse opacity-20" aria-hidden="true" />
      <Siren className={cn('relative z-10', iconClasses[size])} />
    </button>
  )
}
