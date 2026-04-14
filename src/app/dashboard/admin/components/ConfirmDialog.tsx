'use client'

import { useEffect, useRef } from 'react'
import { AlertTriangle, Trash2, Ban, X } from 'lucide-react'

export type ConfirmVariant = 'danger' | 'warning' | 'info'

export interface ConfirmDialogProps {
  open: boolean
  title: string
  message: string
  /** Optional extra input field (e.g. ban reason) */
  inputLabel?: string
  inputPlaceholder?: string
  inputValue?: string
  onInputChange?: (v: string) => void
  confirmLabel?: string
  cancelLabel?: string
  variant?: ConfirmVariant
  onConfirm: () => void
  onCancel: () => void
}

const VARIANT_STYLES: Record<ConfirmVariant, { bg: string; icon: React.ReactNode; btn: string }> = {
  danger:  { bg: 'bg-red-50',    icon: <Trash2 className="w-6 h-6 text-red-600" />,    btn: 'bg-red-600 hover:bg-red-700 text-white' },
  warning: { bg: 'bg-orange-50', icon: <Ban className="w-6 h-6 text-orange-600" />,    btn: 'bg-orange-500 hover:bg-orange-600 text-white' },
  info:    { bg: 'bg-blue-50',   icon: <AlertTriangle className="w-6 h-6 text-blue-600" />, btn: 'bg-blue-600 hover:bg-blue-700 text-white' },
}

export default function ConfirmDialog({
  open,
  title,
  message,
  inputLabel,
  inputPlaceholder,
  inputValue,
  onInputChange,
  confirmLabel = 'Bestätigen',
  cancelLabel  = 'Abbrechen',
  variant      = 'danger',
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  const cancelRef = useRef<HTMLButtonElement>(null)
  const { bg, icon, btn } = VARIANT_STYLES[variant]

  // Focus cancel button on open (safer default)
  useEffect(() => {
    if (open) {
      setTimeout(() => cancelRef.current?.focus(), 50)
    }
  }, [open])

  // Escape key closes
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onCancel() }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open, onCancel])

  if (!open) return null

  return (
    <div
      className="fixed inset-0 bg-black/50 z-[100] flex items-center justify-center p-4"
      onClick={e => { if (e.target === e.currentTarget) onCancel() }}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden">
        {/* Header */}
        <div className={`${bg} px-6 py-5 flex items-start gap-4`}>
          <div className="shrink-0 mt-0.5">{icon}</div>
          <div className="flex-1 min-w-0">
            <h3 className="font-bold text-gray-900 text-base">{title}</h3>
            <p className="text-sm text-gray-600 mt-1 leading-relaxed">{message}</p>
          </div>
          <button onClick={onCancel} className="shrink-0 p-1 rounded-lg hover:bg-black/10 text-gray-500 transition-colors">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Optional input */}
        {inputLabel && onInputChange && (
          <div className="px-6 pt-4 pb-2">
            <label className="block text-xs font-semibold text-gray-500 mb-1">{inputLabel}</label>
            <input
              type="text"
              value={inputValue ?? ''}
              onChange={e => onInputChange(e.target.value)}
              placeholder={inputPlaceholder}
              className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
              autoFocus
            />
          </div>
        )}

        {/* Actions */}
        <div className="px-6 py-4 flex gap-3">
          <button
            ref={cancelRef}
            onClick={onCancel}
            className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors"
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            disabled={!!inputLabel && !inputValue?.trim()}
            className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold transition-colors disabled:opacity-40 ${btn}`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
