'use client'

import { forwardRef, type TextareaHTMLAttributes } from 'react'
import { cn } from '@/lib/design-system'

export interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string
  error?: string
  hint?: string
  maxLength?: number
  showCount?: boolean
}

const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ label, error, hint, maxLength, showCount = false, value, className, id, ...rest }, ref) => {
    const inputId = id || label?.toLowerCase().replace(/\s/g, '-')
    const charCount = typeof value === 'string' ? value.length : 0

    return (
      <div className="w-full">
        {label && (
          <label htmlFor={inputId} className="label">
            {label}
          </label>
        )}
        <textarea
          ref={ref}
          id={inputId}
          value={value}
          maxLength={maxLength}
          className={cn(
            'input resize-none',
            error && 'input-error',
            className,
          )}
          aria-invalid={!!error || undefined}
          aria-describedby={error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined}
          {...rest}
        />
        <div className="flex justify-between mt-1">
          {error ? (
            <p id={`${inputId}-error`} className="form-error" role="alert">
              {error}
            </p>
          ) : hint ? (
            <p id={`${inputId}-hint`} className="text-xs text-gray-400">
              {hint}
            </p>
          ) : (
            <span />
          )}
          {showCount && maxLength && (
            <p className="text-xs text-gray-400">
              {charCount}/{maxLength}
            </p>
          )}
        </div>
      </div>
    )
  },
)

Textarea.displayName = 'Textarea'
export default Textarea
