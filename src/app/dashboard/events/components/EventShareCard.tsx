'use client'

import { useState } from 'react'
import { Share2, Copy, Check } from 'lucide-react'
import type { EventItem } from '../hooks/useEvents'
import { formatEventDate, EVENT_CATEGORIES } from '../hooks/useEvents'

interface EventShareCardProps {
  event: EventItem
}

export default function EventShareCard({ event }: EventShareCardProps) {
  const [copied, setCopied] = useState(false)
  const [showMenu, setShowMenu] = useState(false)

  const url = typeof window !== 'undefined'
    ? `${window.location.origin}/dashboard/events/${event.id}`
    : ''

  const catInfo = EVENT_CATEGORIES[event.category]
  const shareText = [
    `${catInfo.emoji} ${event.title}`,
    `📅 ${formatEventDate(event.start_date, event.end_date, event.is_all_day)}`,
    event.location_name ? `📍 ${event.location_name}` : null,
    event.attendee_count > 0 ? `👥 ${event.attendee_count} Teilnehmer` : null,
    `🔗 ${url}`,
    '',
    'Erstellt auf Mensaena',
  ].filter(Boolean).join('\n')

  const copyText = async () => {
    try {
      await navigator.clipboard.writeText(shareText)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {}
  }

  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(url)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {}
  }

  const nativeShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({ title: event.title, text: shareText, url })
      } catch {}
    }
  }

  return (
    <div className="relative">
      <button
        onClick={() => setShowMenu(!showMenu)}
        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium border border-gray-200 text-gray-600 hover:bg-gray-50 transition"
      >
        <Share2 className="w-3.5 h-3.5" />
        Teilen
      </button>

      {showMenu && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setShowMenu(false)} />
          <div className="absolute right-0 top-full mt-1 bg-white rounded-lg shadow-lg border border-gray-200 z-20 min-w-[180px] py-1">
            <button
              onClick={() => { copyLink(); setShowMenu(false) }}
              className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
              Link kopieren
            </button>
            <button
              onClick={() => { copyText(); setShowMenu(false) }}
              className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
            >
              <Copy className="w-3.5 h-3.5" />
              Text kopieren
            </button>
            {typeof navigator !== 'undefined' && 'share' in navigator && (
              <button
                onClick={() => { nativeShare(); setShowMenu(false) }}
                className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
              >
                <Share2 className="w-3.5 h-3.5" />
                Teilen...
              </button>
            )}
          </div>
        </>
      )}
    </div>
  )
}
