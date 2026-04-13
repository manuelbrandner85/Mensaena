'use client'

import { useState, useEffect } from 'react'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'

interface WelcomeHeaderProps {
  displayName: string
  memberSinceDays: number
}

export default function WelcomeHeader({ displayName, memberSinceDays }: WelcomeHeaderProps) {
  const [greeting, setGreeting] = useState({ text: 'Hallo', emoji: '👋' })
  const [dateStr, setDateStr] = useState('')

  useEffect(() => {
    const h = new Date().getHours()
    if (h < 12) setGreeting({ text: 'Guten Morgen', emoji: '☀️' })
    else if (h < 18) setGreeting({ text: 'Guten Tag', emoji: '👋' })
    else setGreeting({ text: 'Guten Abend', emoji: '🌙' })
    setDateStr(format(new Date(), "EEEE, d. MMMM yyyy", { locale: de }))
  }, [])

  return (
    <div className="mb-2">
      <h1 className="text-2xl md:text-3xl font-bold text-gray-900">
        {greeting.text}, {displayName}! {greeting.emoji}
      </h1>
      {dateStr && (
        <p className="text-sm text-gray-400 mt-0.5">{dateStr}</p>
      )}
      {memberSinceDays < 7 ? (
        <p className="text-primary-600 text-sm mt-1">
          Willkommen in deiner neuen Nachbarschaft! 🎉
        </p>
      ) : (
        <p className="text-gray-500 text-sm mt-1">
          Du bist seit {memberSinceDays} Tagen Teil der Nachbarschaft
        </p>
      )}
    </div>
  )
}
