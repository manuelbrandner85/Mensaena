'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Sparkles, Lightbulb, RefreshCw } from 'lucide-react'
import { Card, IconButton } from '@/components/ui'

const FALLBACK_TIPS = [
  'Hast du heute schon die Karte gecheckt? Vielleicht braucht jemand in deiner Nähe Hilfe!',
  'Ein Lächeln kostet nichts – schreib deinem Nachbarn eine nette Nachricht.',
  'Teile deine Fähigkeiten! Im Skill-Netzwerk kannst du anderen helfen und Neues lernen.',
  'Kleine Gesten, große Wirkung: Biete Einkaufshilfe in deiner Nachbarschaft an.',
  'Kennst du die Zeitbank? Tausche Zeit statt Geld mit deinen Nachbarn!',
]

interface BotTipCardProps {
  tipText: string | null
}

export default function BotTipCard({ tipText }: BotTipCardProps) {
  const [currentTip, setCurrentTip] = useState(tipText)

  if (!currentTip) return null

  const handleNextTip = () => {
    const randomTip = FALLBACK_TIPS[Math.floor(Math.random() * FALLBACK_TIPS.length)]
    setCurrentTip(randomTip)
  }

  return (
    <Card
      variant="flat"
      padding="md"
      className="bg-gradient-to-br from-primary-50 to-primary-100/50 border-primary-200/50"
    >
      {/* Header */}
      <div className="flex items-center gap-2">
        <div className="w-7 h-7 rounded-full bg-primary-200 flex items-center justify-center">
          <Sparkles className="w-4 h-4 text-primary-700" />
        </div>
        <span className="text-sm font-semibold text-primary-800">MensaenaBot</span>
        <Lightbulb className="w-4 h-4 text-primary-600 ml-auto" />
      </div>

      {/* Tip */}
      <p className="text-sm text-primary-900 mt-2 leading-relaxed">
        {currentTip}
      </p>

      {/* Actions */}
      <div className="flex justify-between items-center mt-3">
        <Link
          href="/dashboard/chat"
          className="text-xs text-primary-700 hover:text-primary-900 font-medium transition-colors"
        >
          Chat mit Bot →
        </Link>
        <button
          onClick={handleNextTip}
          className="flex items-center gap-1 text-xs text-primary-600 hover:text-primary-800 transition-colors"
        >
          <RefreshCw className="w-3 h-3" />
          Nächster Tipp
        </button>
      </div>
    </Card>
  )
}
