'use client'

import { useState, useEffect } from 'react'

interface WelcomeHeaderProps {
  displayName: string
  memberSinceDays: number
}

export default function WelcomeHeader({ displayName, memberSinceDays }: WelcomeHeaderProps) {
  const [greeting, setGreeting] = useState({ text: 'Hallo', accent: 'Tag' })
  const [dateStr, setDateStr] = useState('')

  useEffect(() => {
    const h = new Date().getHours()
    if (h < 12) setGreeting({ text: 'Guten', accent: 'Morgen' })
    else if (h < 18) setGreeting({ text: 'Guten', accent: 'Tag' })
    else setGreeting({ text: 'Guten', accent: 'Abend' })
    // Native Intl replaces date-fns (~14 kB bundle savings)
    const now = new Date()
    const weekday = new Intl.DateTimeFormat('de-DE', { weekday: 'long' }).format(now)
    const dayMonthYear = new Intl.DateTimeFormat('de-DE', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    }).format(now)
    setDateStr(`${weekday} · ${dayMonthYear}`)
  }, [])

  return (
    <header className="mb-2">
      {dateStr && (
        <div className="meta-label meta-label--subtle mb-3">
          {dateStr}
        </div>
      )}
      <h1 className="page-title">
        {greeting.text} <span className="text-accent">{greeting.accent}</span>, {displayName}.
      </h1>
      {memberSinceDays < 7 ? (
        <p className="page-subtitle mt-3">
          Willkommen in deiner neuen Nachbarschaft.
        </p>
      ) : (
        <p className="page-subtitle mt-3">
          Tag <span className="font-display italic text-ink-700">{memberSinceDays}</span> deiner Reise in dieser Gemeinschaft.
        </p>
      )}
    </header>
  )
}
