'use client'

import { useState, useEffect } from 'react'

interface EventCountdownProps {
  startDate: string
  status: string
}

export default function EventCountdown({ startDate, status }: EventCountdownProps) {
  const [now, setNow] = useState(Date.now())

  const target = new Date(startDate).getTime()
  const diff = target - now
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
  const seconds = Math.floor((diff % (1000 * 60)) / 1000)

  const showSeconds = diff < 60 * 60 * 1000 // < 1 hour
  const isNear = diff < 60 * 60 * 1000

  useEffect(() => {
    const interval = setInterval(() => setNow(Date.now()), showSeconds ? 1000 : 60000)
    return () => clearInterval(interval)
  }, [showSeconds])

  // Only show for upcoming events within 7 days
  if (status !== 'upcoming' || diff <= 0 || days > 7) return null

  const boxClass = isNear
    ? 'bg-primary-50 text-primary-700'
    : 'bg-purple-50 text-purple-700'

  const labelClass = isNear ? 'text-primary-500' : 'text-purple-500'
  const numClass = isNear ? 'text-primary-700' : 'text-purple-700'

  return (
    <div className="flex items-center gap-3">
      <div className={`${boxClass} rounded-lg px-3 py-2 text-center min-w-[56px]`}>
        <div className={`text-xl font-bold ${numClass}`}>{days}</div>
        <div className={`text-xs ${labelClass}`}>Tage</div>
      </div>
      <div className={`${boxClass} rounded-lg px-3 py-2 text-center min-w-[56px]`}>
        <div className={`text-xl font-bold ${numClass}`}>{hours}</div>
        <div className={`text-xs ${labelClass}`}>Std</div>
      </div>
      <div className={`${boxClass} rounded-lg px-3 py-2 text-center min-w-[56px]`}>
        <div className={`text-xl font-bold ${numClass}`}>{minutes}</div>
        <div className={`text-xs ${labelClass}`}>Min</div>
      </div>
      {showSeconds && (
        <div className={`${boxClass} rounded-lg px-3 py-2 text-center min-w-[56px]`}>
          <div className={`text-xl font-bold ${numClass}`}>{seconds}</div>
          <div className={`text-xs ${labelClass}`}>Sek</div>
        </div>
      )}
    </div>
  )
}
