'use client'

import { useState, useEffect } from 'react'
import { Bell, BellOff } from 'lucide-react'
import { cn } from '@/lib/utils'
import { loadWasteSettings, saveWasteSettings } from './WasteSetupWizard'

const REMINDER_KEY = 'mensaena_waste_reminder'

export default function WasteReminderToggle() {
  const [enabled, setEnabled] = useState(false)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
    const settings = loadWasteSettings()
    if (settings) {
      setEnabled(settings.reminderEnabled)
    } else {
      const stored = localStorage.getItem(REMINDER_KEY)
      setEnabled(stored === 'true')
    }
  }, [])

  const toggle = () => {
    const next = !enabled
    setEnabled(next)
    // Persist in waste settings if available
    const settings = loadWasteSettings()
    if (settings) {
      saveWasteSettings({ ...settings, reminderEnabled: next })
    } else {
      localStorage.setItem(REMINDER_KEY, String(next))
    }
  }

  if (!mounted) return null

  return (
    <div className="flex items-center gap-3 px-4 py-3 bg-white rounded-xl border border-gray-100 shadow-soft">
      <div className={cn('w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0', enabled ? 'bg-amber-100' : 'bg-gray-100')}>
        {enabled
          ? <Bell className="w-4 h-4 text-amber-600" />
          : <BellOff className="w-4 h-4 text-gray-400" />}
      </div>

      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900">Push-Erinnerung am Vorabend</p>
        <p className="text-xs text-gray-500 mt-0.5">
          {enabled ? 'Aktiv – du wirst am Abend erinnert' : 'Deaktiviert'}
        </p>
      </div>

      <button
        type="button"
        onClick={toggle}
        role="switch"
        aria-checked={enabled}
        aria-label={enabled ? 'Erinnerung deaktivieren' : 'Erinnerung aktivieren'}
        className={cn(
          'relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200',
          'focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2',
          enabled ? 'bg-primary-600' : 'bg-gray-200',
        )}
      >
        <span
          className={cn(
            'inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition-transform duration-200',
            enabled ? 'translate-x-5' : 'translate-x-0',
          )}
        />
      </button>
    </div>
  )
}
