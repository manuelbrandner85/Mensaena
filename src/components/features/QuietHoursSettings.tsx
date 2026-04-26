'use client'

import { useEffect, useState } from 'react'
import { Moon, Save, Loader2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { handleSupabaseError } from '@/lib/errors'

/**
 * QuietHoursSettings – echte Ruhezeiten im Profil.
 * Speichert `quiet_hours_enabled`, `quiet_hours_start`, `quiet_hours_end`
 * direkt in der `profiles`-Tabelle. Wird beim Versand von Push-Nachrichten
 * serverseitig ausgewertet (vorhandene Push-Infrastruktur liest diese Felder
 * über `getNotificationPrefs`).
 */
export default function QuietHoursSettings({ userId }: { userId: string }) {
  const [enabled, setEnabled] = useState(false)
  const [start, setStart] = useState('22:00')
  const [end, setEnd] = useState('07:00')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const supabase = createClient()
      const { data, error } = await supabase
        .from('profiles')
        .select('quiet_hours_enabled, quiet_hours_start, quiet_hours_end')
        .eq('id', userId)
        .maybeSingle()
      if (cancelled) return
      if (!error && data) {
        setEnabled(!!data.quiet_hours_enabled)
        if (data.quiet_hours_start) setStart(String(data.quiet_hours_start).slice(0, 5))
        if (data.quiet_hours_end) setEnd(String(data.quiet_hours_end).slice(0, 5))
      }
      setLoading(false)
    })()
    return () => { cancelled = true }
  }, [userId])

  const save = async () => {
    setSaving(true)
    const supabase = createClient()
    const { error } = await supabase
      .from('profiles')
      .update({
        quiet_hours_enabled: enabled,
        quiet_hours_start: start,
        quiet_hours_end: end,
      })
      .eq('id', userId)
    setSaving(false)
    if (handleSupabaseError(error)) return
    toast.success('Ruhezeiten gespeichert')
  }

  if (loading) {
    return (
      <div className="bg-white rounded-2xl shadow-sm border border-stone-100 p-6 animate-pulse">
        <div className="h-5 w-40 bg-stone-200 rounded mb-3" />
        <div className="h-3 w-64 bg-stone-100 rounded mb-5" />
        <div className="h-10 bg-stone-100 rounded-xl" />
      </div>
    )
  }

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-stone-100 p-6">
      <div className="flex items-start gap-3 mb-5">
        <div className="w-10 h-10 rounded-xl bg-indigo-50 border border-indigo-100 text-indigo-700 flex items-center justify-center flex-shrink-0">
          <Moon className="w-5 h-5" />
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="font-semibold text-base text-ink-900">Ruhezeiten</h3>
          <p className="text-xs text-ink-500 mt-0.5">
            Während deiner Ruhezeiten werden Push-Benachrichtigungen stummgeschaltet. Dringende Notfälle
            (Krisen, Silent-Alarm) werden weiterhin zugestellt.
          </p>
        </div>
      </div>

      <div className="flex items-center justify-between py-3 border-b border-stone-100">
        <div>
          <p className="text-sm font-medium text-ink-900">Ruhezeiten aktivieren</p>
          <p className="text-xs text-ink-500 mt-0.5">Benachrichtigungen stumm in diesem Zeitfenster</p>
        </div>
        <button
          type="button"
          role="switch"
          aria-checked={enabled}
          onClick={() => setEnabled(v => !v)}
          className={`relative inline-flex h-7 w-12 items-center rounded-full transition-colors ${
            enabled ? 'bg-primary-600' : 'bg-stone-200'
          }`}
        >
          <span className="sr-only">Ruhezeiten aktivieren</span>
          <span
            className={`inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform ${
              enabled ? 'translate-x-6' : 'translate-x-1'
            }`}
          />
        </button>
      </div>

      <div className={`grid grid-cols-2 gap-3 mt-4 transition-opacity ${enabled ? 'opacity-100' : 'opacity-50 pointer-events-none'}`}>
        <label className="text-xs">
          <span className="block text-ink-600 mb-1">Von</span>
          <input
            type="time"
            value={start}
            onChange={e => setStart(e.target.value)}
            className="w-full h-11 px-3 border border-stone-200 rounded-xl text-sm focus:border-primary-400 focus:outline-none focus:ring-2 focus:ring-primary-100"
          />
        </label>
        <label className="text-xs">
          <span className="block text-ink-600 mb-1">Bis</span>
          <input
            type="time"
            value={end}
            onChange={e => setEnd(e.target.value)}
            className="w-full h-11 px-3 border border-stone-200 rounded-xl text-sm focus:border-primary-400 focus:outline-none focus:ring-2 focus:ring-primary-100"
          />
        </label>
      </div>

      <div className="mt-5 flex justify-end">
        <button
          type="button"
          onClick={save}
          disabled={saving}
          className="inline-flex items-center gap-2 px-4 h-11 bg-primary-600 text-white text-sm font-medium rounded-xl hover:bg-primary-700 transition-colors disabled:opacity-60"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          Speichern
        </button>
      </div>
    </div>
  )
}
