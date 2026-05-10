'use client'

import { useEffect } from 'react'
import { X } from 'lucide-react'
import { cn } from '@/lib/design-system'

interface CinemaModalProps {
  open: boolean
  onClose: () => void
  title?: string
  children: React.ReactNode
  className?: string
  size?: 'sm' | 'md' | 'lg'
}

const widths = { sm: 'max-w-sm', md: 'max-w-lg', lg: 'max-w-2xl' }

export default function CinemaModal({ open, onClose, title, children, className, size = 'md' }: CinemaModalProps) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = ''
    }
  }, [open, onClose])

  if (!open) return null

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center p-4" role="dialog" aria-modal>
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm animate-fade-in"
        onClick={onClose}
        aria-hidden
      />
      <div
        className={cn(
          'relative w-full bg-mn-raised rounded-modal shadow-cinema-raised border border-white/5',
          'animate-slide-up p-6',
          widths[size],
          className,
        )}
      >
        {title && (
          <div className="flex items-center justify-between mb-5">
            <h2
              className="text-xl font-semibold text-mn-ink"
              style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif' }}
            >
              {title}
            </h2>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-mn-mute hover:bg-mn-elevated/5 hover:text-mn-ink transition-colors"
              aria-label="Schließen"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        )}
        {!title && (
          <button
            onClick={onClose}
            className="absolute top-4 right-4 p-1.5 rounded-lg text-mn-mute hover:bg-mn-elevated/5 hover:text-mn-ink transition-colors"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        )}
        {children}
      </div>
    </div>
  )
}
