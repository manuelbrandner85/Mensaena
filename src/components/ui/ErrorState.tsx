'use client'

import { AlertTriangle, RefreshCw } from 'lucide-react'
import { cn } from '@/lib/design-system'
import Button from './Button'

export interface ErrorStateProps {
  title?: string
  message?: string
  onRetry?: () => void
  retryLabel?: string
  className?: string
}

export default function ErrorState({
  title = 'Etwas ist schiefgelaufen',
  message,
  onRetry,
  retryLabel = 'Erneut versuchen',
  className,
}: ErrorStateProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center text-center py-12 px-6',
        className,
      )}
      role="alert"
    >
      <div className="w-14 h-14 rounded-2xl bg-red-50 flex items-center justify-center mb-4">
        <AlertTriangle className="w-7 h-7 text-red-500" />
      </div>
      <h3 className="text-sm font-semibold text-ink-900 mb-1">{title}</h3>
      {message && (
        <p className="text-sm text-red-600 max-w-xs mb-4">{message}</p>
      )}
      {onRetry && (
        <Button
          variant="primary"
          size="sm"
          icon={<RefreshCw className="w-4 h-4" />}
          onClick={onRetry}
        >
          {retryLabel}
        </Button>
      )}
    </div>
  )
}
