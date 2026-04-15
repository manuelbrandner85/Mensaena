'use client'

import { useRef, useState, useEffect } from 'react'
import { Heart, FileText, Handshake, Bookmark } from 'lucide-react'
import { CountUp } from '@/components/ui'
import type { UserStats } from '../types'

interface StatsCardsProps {
  stats: UserStats
}

const cards = [
  { key: 'peopleHelped' as const, icon: Heart, label: 'Menschen geholfen', accent: '#1EAAA6' },
  { key: 'postsCreated' as const, icon: FileText, label: 'Beiträge erstellt', accent: '#3B82F6' },
  { key: 'interactionsCompleted' as const, icon: Handshake, label: 'Interaktionen', accent: '#8B5CF6' },
  { key: 'savedPostsCount' as const, icon: Bookmark, label: 'Gespeichert', accent: '#F59E0B' },
]

export default function StatsCards({ stats }: StatsCardsProps) {
  const ref = useRef<HTMLDivElement>(null)
  const [inView, setInView] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const obs = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setInView(true); obs.disconnect() } },
      { threshold: 0.25 }
    )
    obs.observe(el)
    return () => obs.disconnect()
  }, [])

  const allZero = cards.every((c) => stats[c.key] === 0)

  if (allZero) {
    return (
      <div className="gradient-border rounded-2xl overflow-hidden">
        <div className="bg-white p-5 text-center">
          <p className="text-2xl mb-2">🌱</p>
          <p className="text-sm font-semibold text-gray-900">Dein Abenteuer beginnt!</p>
          <p className="text-xs text-gray-500 mt-1">Erstelle einen Beitrag oder hilf jemandem, um deine Statistiken zu füllen.</p>
        </div>
      </div>
    )
  }

  return (
    <div ref={ref} className="cinematic-stat-grid rounded-2xl shadow-soft overflow-hidden">
      {cards.map((card, i) => {
        const Icon = card.icon
        return (
          <div key={card.key} className="cinematic-stat-cell reveal" style={{ animationDelay: `${i * 80}ms` }}>
            {/* Accent line top */}
            <div
              className="absolute top-0 left-0 right-0 h-px opacity-60"
              style={{ background: `linear-gradient(90deg, ${card.accent}55, transparent)` }}
            />
            <div
              className="w-7 h-7 rounded-lg flex items-center justify-center mb-3"
              style={{ background: `${card.accent}18` }}
            >
              <Icon className="w-3.5 h-3.5" style={{ color: card.accent }} />
            </div>
            <div className="display-numeral text-2xl font-bold text-gray-900 leading-none">
              {inView
                ? <CountUp to={stats[card.key]} duration={900 + i * 120} />
                : <span>0</span>
              }
            </div>
            <p className="text-xs text-gray-500 mt-1.5 leading-snug">{card.label}</p>
          </div>
        )
      })}
    </div>
  )
}
