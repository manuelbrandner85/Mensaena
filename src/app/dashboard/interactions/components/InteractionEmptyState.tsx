'use client'

import Link from 'next/link'
import { Handshake, HandHeart, HelpCircle, Trophy, Map } from 'lucide-react'
import type { InteractionFilter } from '../types'

interface Props {
  filter: InteractionFilter
}

export default function InteractionEmptyState({ filter }: Props) {
  if (filter.status === 'completed') {
    return (
      <div className="text-center py-16 px-4">
        <Trophy className="w-16 h-16 text-amber-400 mx-auto mb-4" />
        <h3 className="text-lg font-semibold text-gray-800 mb-2">Alle Interaktionen abgeschlossen</h3>
        <p className="text-gray-500 max-w-sm mx-auto">Gut gemacht! Du hast alle Interaktionen erfolgreich abgeschlossen.</p>
      </div>
    )
  }

  if (filter.role === 'helper') {
    return (
      <div className="text-center py-16 px-4">
        <HandHeart className="w-16 h-16 text-blue-400 mx-auto mb-4" />
        <h3 className="text-lg font-semibold text-gray-800 mb-2">Du hilfst noch niemandem</h3>
        <p className="text-gray-500 max-w-sm mx-auto mb-4">Schau dich um – jemand braucht deine Hilfe!</p>
        <Link href="/dashboard/map" className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors">
          <Map className="w-4 h-4" /> Zur Karte
        </Link>
      </div>
    )
  }

  if (filter.role === 'helped') {
    return (
      <div className="text-center py-16 px-4">
        <HelpCircle className="w-16 h-16 text-purple-400 mx-auto mb-4" />
        <h3 className="text-lg font-semibold text-gray-800 mb-2">Du hast noch keine Hilfe angefragt</h3>
        <p className="text-gray-500 max-w-sm mx-auto mb-4">Keine Scheu – dafuer sind wir da!</p>
        <Link href="/dashboard/posts" className="inline-flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg text-sm font-medium hover:bg-purple-700 transition-colors">
          <HelpCircle className="w-4 h-4" /> Beitraege ansehen
        </Link>
      </div>
    )
  }

  return (
    <div className="text-center py-16 px-4">
      <Handshake className="w-16 h-16 text-emerald-400 mx-auto mb-4" />
      <h3 className="text-lg font-semibold text-gray-800 mb-2">Noch keine Interaktionen</h3>
      <p className="text-gray-500 max-w-sm mx-auto mb-4">Entdecke Hilfsangebote in deiner Naehe und biete deine Hilfe an!</p>
      <Link href="/dashboard/map" className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors">
        <Map className="w-4 h-4" /> Zur Karte
      </Link>
    </div>
  )
}
