'use client'

import { useState, useEffect } from 'react'
import { ChevronDown, ChevronUp, Loader2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { invalidateNotificationPrefs } from '@/lib/notifications'
import toast from 'react-hot-toast'

interface Props {
  userId: string
}

interface Prefs {
  notify_new_messages: boolean
  notify_new_interactions: boolean
  notify_nearby_posts: boolean
  notify_trust_ratings: boolean
  notify_system: boolean
}

const PREF_LABELS: { key: keyof Prefs; label: string }[] = [
  { key: 'notify_new_messages', label: 'Neue Nachrichten' },
  { key: 'notify_new_interactions', label: 'Beitrags-Interaktionen' },
  { key: 'notify_nearby_posts', label: 'Beiträge in der Nähe' },
  { key: 'notify_trust_ratings', label: 'Vertrauens-Bewertungen' },
  { key: 'notify_system', label: 'System-Benachrichtigungen' },
]

export default function NotificationPreferences({ userId }: Props) {
  const [open, setOpen] = useState(false)
  const [prefs, setPrefs] = useState<Prefs | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('profiles')
      .select('notify_new_messages, notify_new_interactions, notify_nearby_posts, notify_trust_ratings, notify_system')
      .eq('id', userId)
      .single()
      .then(({ data }) => {
        if (data) {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const d = data as any
          setPrefs({
            notify_new_messages: d.notify_new_messages ?? true,
            notify_new_interactions: d.notify_new_interactions ?? true,
            notify_nearby_posts: d.notify_nearby_posts ?? true,
            notify_trust_ratings: d.notify_trust_ratings ?? true,
            notify_system: d.notify_system ?? true,
          })
        }
      })
  }, [userId])

  const toggle = async (key: keyof Prefs) => {
    if (!prefs) return
    const newVal = !prefs[key]
    setPrefs({ ...prefs, [key]: newVal })
    setSaving(true)

    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (supabase.from('profiles') as any)
      .update({ [key]: newVal })
      .eq('id', userId)

    setSaving(false)
    if (error) {
      toast.error('Einstellung konnte nicht gespeichert werden')
      setPrefs({ ...prefs, [key]: !newVal }) // revert
    } else {
      invalidateNotificationPrefs(userId)
      toast.success('Einstellung gespeichert')
    }
  }

  return (
    <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
      {/* Toggle header */}
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between px-4 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
      >
        <span className="flex items-center gap-2">
          Schnell-Einstellungen
          {saving && <Loader2 className="w-3.5 h-3.5 animate-spin text-gray-400" />}
        </span>
        {open ? <ChevronUp className="w-4 h-4 text-gray-400" /> : <ChevronDown className="w-4 h-4 text-gray-400" />}
      </button>

      {open && prefs && (
        <div className="px-4 pb-4 space-y-1">
          {PREF_LABELS.map(({ key, label }) => (
            <label
              key={key}
              className="flex items-center justify-between py-2 cursor-pointer"
            >
              <span className="text-sm text-gray-600">{label}</span>
              <button
                type="button"
                role="switch"
                aria-checked={prefs[key]}
                onClick={() => toggle(key)}
                className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  prefs[key] ? 'bg-primary-500' : 'bg-gray-300'
                }`}
              >
                <span
                  className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow-sm transition-transform ${
                    prefs[key] ? 'translate-x-4' : 'translate-x-0.5'
                  }`}
                />
              </button>
            </label>
          ))}
          <p className="text-xs text-gray-400 pt-1">
            Weitere Einstellungen findest du unter{' '}
            <a href="/dashboard/settings" className="text-primary-600 hover:underline">
              Einstellungen
            </a>
          </p>
        </div>
      )}
    </div>
  )
}
