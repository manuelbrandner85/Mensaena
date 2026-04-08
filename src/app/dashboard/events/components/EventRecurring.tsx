'use client'

import { Repeat } from 'lucide-react'
import { cn } from '@/lib/utils'

interface EventRecurringProps {
  enabled: boolean
  onToggle: (v: boolean) => void
  frequency: string
  onFrequencyChange: (v: string) => void
  until: string
  onUntilChange: (v: string) => void
}

export default function EventRecurring({
  enabled, onToggle, frequency, onFrequencyChange, until, onUntilChange,
}: EventRecurringProps) {
  const today = new Date()
  const minUntil = new Date(today)
  minUntil.setDate(minUntil.getDate() + 7)

  return (
    <div className="space-y-3">
      {/* Toggle */}
      <label className="flex items-center gap-3 cursor-pointer">
        <button
          type="button"
          onClick={() => onToggle(!enabled)}
          className={cn(
            'relative w-10 h-5 rounded-full transition-colors',
            enabled ? 'bg-emerald-600' : 'bg-gray-300',
          )}
        >
          <span
            className={cn(
              'absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform',
              enabled ? 'translate-x-5' : 'translate-x-0.5',
            )}
          />
        </button>
        <div className="flex items-center gap-1.5">
          <Repeat className="w-4 h-4 text-gray-600" />
          <span className="text-sm font-medium text-gray-700">Wiederkehrende Veranstaltung</span>
        </div>
      </label>

      {enabled && (
        <div className="pl-[52px] space-y-3">
          <div>
            <label className="text-sm text-gray-600 mb-1 block">Wiederholung</label>
            <select
              value={frequency}
              onChange={(e) => onFrequencyChange(e.target.value)}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
            >
              <option value="weekly">Wöchentlich</option>
              <option value="biweekly">Alle 2 Wochen</option>
              <option value="monthly">Monatlich</option>
            </select>
          </div>

          <div>
            <label className="text-sm text-gray-600 mb-1 block">Wiederholen bis</label>
            <input
              type="date"
              value={until}
              onChange={(e) => onUntilChange(e.target.value)}
              min={minUntil.toISOString().split('T')[0]}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
            />
          </div>
        </div>
      )}
    </div>
  )
}
