'use client'
// FEATURE: Code-Splitting — extrahiert aus ChatView.tsx
import { useState, useEffect } from 'react'

// BUG-FIX: Sekunden-Ticker isoliert — eigener State/Timer verhindert globale ChatView-Re-Renders
export default function LiveCountdown({ targetDate }: { targetDate: string }) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(t)
  }, [])
  const diff = new Date(targetDate).getTime() - now
  if (diff <= 0) return <span className="text-green-600 font-bold">JETZT LIVE!</span>
  const h = Math.floor(diff / 3600000)
  const m = Math.floor((diff % 3600000) / 60000)
  const s = Math.floor((diff % 60000) / 1000)
  return <span>{h > 0 ? `${h}h ` : ''}{String(m).padStart(2, '0')}:{String(s).padStart(2, '0')}</span>
}
