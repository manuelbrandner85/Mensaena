'use client'

import { useState } from 'react'
import { Bell, X } from 'lucide-react'
import { cn } from '@/lib/utils'

interface EventReminderProps {
  eventId: string
  isAttending: boolean
  reminderSet: boolean
  reminderMinutes: number
  onSetReminder: (eventId: string, minutes: number) => Promise<void>
  onRemoveReminder: (eventId: string) => Promise<void>
}

const REMINDER_OPTIONS = [
  { label: '15 Min. vorher', value: 15 },
  { label: '30 Min. vorher', value: 30 },
  { label: '1 Stunde vorher', value: 60 },
  { label: '2 Stunden vorher', value: 120 },
  { label: '1 Tag vorher', value: 1440 },
]

export default function EventReminder({
  eventId, isAttending, reminderSet, reminderMinutes,
  onSetReminder, onRemoveReminder,
}: EventReminderProps) {
  const [saving, setSaving] = useState(false)

  if (!isAttending) return null

  const handleChange = async (minutes: number) => {
    setSaving(true)
    try {
      await onSetReminder(eventId, minutes)
    } finally {
      setSaving(false)
    }
  }

  const handleRemove = async () => {
    setSaving(true)
    try {
      await onRemoveReminder(eventId)
    } finally {
      setSaving(false)
    }
  }

  if (!reminderSet) {
    return (
      <button
        onClick={() => handleChange(60)}
        disabled={saving}
        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium border border-gray-200 text-gray-600 hover:bg-gray-50 transition disabled:opacity-50"
      >
        <Bell className="w-3.5 h-3.5" />
        Erinnerung setzen
      </button>
    )
  }

  return (
    <div className="flex items-center gap-2">
      <Bell className="w-4 h-4 text-purple-600" />
      <select
        value={reminderMinutes}
        onChange={(e) => handleChange(Number(e.target.value))}
        disabled={saving}
        className="text-sm border border-gray-200 rounded-lg px-2 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-purple-500 disabled:opacity-50"
      >
        {REMINDER_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>{opt.label}</option>
        ))}
      </select>
      <button
        onClick={handleRemove}
        disabled={saving}
        className="p-1 rounded-full hover:bg-gray-100 transition disabled:opacity-50"
        title="Erinnerung entfernen"
      >
        <X className="w-3.5 h-3.5 text-gray-400" />
      </button>
    </div>
  )
}
