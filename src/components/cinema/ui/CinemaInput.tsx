'use client'

import { forwardRef, useState, useId, type InputHTMLAttributes, type TextareaHTMLAttributes } from 'react'
import { Eye, EyeOff, Search } from 'lucide-react'
import { cn } from '@/lib/design-system'

// ── Text Input ─────────────────────────────────────────────────────────────────

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string
  error?: string
  helper?: string
  leadingIcon?: React.ReactNode
  trailingIcon?: React.ReactNode
  variant?: 'default' | 'search'
}

export const CinemaInput = forwardRef<HTMLInputElement, InputProps>(function CinemaInput(
  { label, error, helper, leadingIcon, trailingIcon, variant = 'default', className, type, ...props }, ref
) {
  const id = useId()
  const [showPw, setShowPw] = useState(false)
  const isPassword = type === 'password'
  const isSearch   = variant === 'search'

  return (
    <div className="w-full">
      {label && (
        <label
          htmlFor={id}
          className="block mb-1.5 text-sm font-medium transition-colors duration-150"
          style={{ color: error ? 'rgba(239,68,68,0.85)' : 'rgba(245,240,232,0.60)' }}
        >
          {label}
        </label>
      )}
      <div className="relative flex items-center">
        {(leadingIcon || isSearch) && (
          <span className="absolute left-3.5 text-mn-ghost pointer-events-none">
            {leadingIcon ?? <Search className="w-4 h-4" />}
          </span>
        )}
        <input
          ref={ref}
          id={id}
          type={isPassword ? (showPw ? 'text' : 'password') : type}
          className={cn(
            'w-full bg-mn-surface border rounded-input text-mn-ink placeholder:text-mn-ghost',
            'px-4 py-2.5 text-sm',
            'transition-all duration-150',
            'focus:outline-none focus:border-mn-bronze/30 focus:shadow-input-focus',
            error ? 'border-mn-herzrot/40 focus:shadow-[0_0_0_3px_rgba(239,68,68,0.08)]' : 'border-white/7',
            (leadingIcon || isSearch) && 'pl-10',
            (trailingIcon || isPassword) && 'pr-10',
            className,
          )}
          {...props}
        />
        {isPassword && (
          <button
            type="button"
            tabIndex={-1}
            onClick={() => setShowPw(v => !v)}
            className="absolute right-3.5 text-mn-ghost hover:text-mn-ink-soft transition-colors"
            aria-label={showPw ? 'Passwort verbergen' : 'Passwort anzeigen'}
          >
            {showPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        )}
        {trailingIcon && !isPassword && (
          <span className="absolute right-3.5 text-mn-ghost pointer-events-none">{trailingIcon}</span>
        )}
      </div>
      {(error || helper) && (
        <p className={cn('mt-1.5 text-xs', error ? 'text-mn-herzrot-warm' : 'text-mn-mute')}>
          {error ?? helper}
        </p>
      )}
    </div>
  )
})

// ── Textarea ───────────────────────────────────────────────────────────────────

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string
  error?: string
  helper?: string
}

export const CinemaTextarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function CinemaTextarea(
  { label, error, helper, className, ...props }, ref
) {
  const id = useId()
  return (
    <div className="w-full">
      {label && (
        <label htmlFor={id} className="block mb-1.5 text-sm font-medium" style={{ color: 'rgba(245,240,232,0.60)' }}>
          {label}
        </label>
      )}
      <textarea
        ref={ref}
        id={id}
        className={cn(
          'w-full bg-mn-surface border rounded-input text-mn-ink placeholder:text-mn-ghost',
          'px-4 py-3 text-sm resize-none',
          'transition-all duration-150',
          'focus:outline-none focus:border-mn-bronze/30 focus:shadow-input-focus',
          error ? 'border-mn-herzrot/40' : 'border-white/7',
          className,
        )}
        {...props}
      />
      {(error || helper) && (
        <p className={cn('mt-1.5 text-xs', error ? 'text-mn-herzrot-warm' : 'text-mn-mute')}>
          {error ?? helper}
        </p>
      )}
    </div>
  )
})
