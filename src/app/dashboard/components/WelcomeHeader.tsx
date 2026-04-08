'use client'

import { useState, useEffect } from 'react'

interface WelcomeHeaderProps {
  displayName: string
  memberSinceDays: number
}

export default function WelcomeHeader({ displayName, memberSinceDays }: WelcomeHeaderProps) {
  const [greeting, setGreeting] = useState({ text: 'Hallo', emoji: '\uD83D\uDC4B' })

  useEffect(() => {
    const h = new Date().getHours()
    if (h < 12) setGreeting({ text: 'Guten Morgen', emoji: '\u2600\uFE0F' })
    else if (h < 18) setGreeting({ text: 'Guten Tag', emoji: '\uD83D\uDC4B' })
    else setGreeting({ text: 'Guten Abend', emoji: '\uD83C\uDF19' })
  }, [])

  return (
    <div className="mb-2">
      <h1 className="text-2xl md:text-3xl font-bold text-gray-900">
        {greeting.text}, {displayName}! {greeting.emoji}
      </h1>
      {memberSinceDays < 7 ? (
        <p className="text-primary-600 text-sm mt-1">
          Willkommen in deiner neuen Nachbarschaft! \uD83C\uDF89
        </p>
      ) : (
        <p className="text-gray-500 text-sm mt-1">
          Du bist seit {memberSinceDays} Tagen Teil der Nachbarschaft
        </p>
      )}
    </div>
  )
}
