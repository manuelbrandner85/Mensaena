'use client'

import { Sparkles, PlusCircle, Settings } from 'lucide-react'
import Link from 'next/link'
import type { MatchFilter } from '../types'

interface MatchEmptyStateProps {
  filter: MatchFilter
  onOpenPreferences?: () => void
}

const filterMessages: Record<string, { title: string; description: string }> = {
  all: {
    title: 'Noch keine Matches',
    description:
      'Erstelle einen Beitrag, um automatisch mit passenden Angeboten oder Gesuchen gematcht zu werden.',
  },
  suggested: {
    title: 'Keine Vorschläge',
    description: 'Aktuell gibt es keine neuen Matching-Vorschläge für dich.',
  },
  pending: {
    title: 'Keine offenen Matches',
    description: 'Du hast keine Matches, die auf eine Antwort warten.',
  },
  accepted: {
    title: 'Keine akzeptierten Matches',
    description: 'Akzeptiere Vorschläge, um hier deine aktiven Matches zu sehen.',
  },
  declined: {
    title: 'Keine abgelehnten Matches',
    description: 'Abgelehnte Matches werden hier angezeigt.',
  },
  expired: {
    title: 'Keine abgelaufenen Matches',
    description: 'Matches, die nicht beantwortet wurden, erscheinen hier.',
  },
  completed: {
    title: 'Noch keine Erfolge',
    description: 'Abgeschlossene Matches werden hier angezeigt. Starte jetzt!',
  },
  cancelled: {
    title: 'Keine abgebrochenen Matches',
    description: 'Hier werden abgebrochene Matches angezeigt.',
  },
}

export default function MatchEmptyState({ filter, onOpenPreferences }: MatchEmptyStateProps) {
  const msg = filterMessages[filter] || filterMessages.all

  return (
    <div className="flex flex-col items-center justify-center py-12 px-4 text-center">
      <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-indigo-50 to-purple-50 flex items-center justify-center mb-4">
        <Sparkles className="w-8 h-8 text-indigo-400" />
      </div>

      <h3 className="text-lg font-semibold text-gray-800 mb-2">{msg.title}</h3>
      <p className="text-sm text-gray-500 max-w-sm mb-6">{msg.description}</p>

      <div className="flex flex-col sm:flex-row items-center gap-3">
        <Link
          href="/dashboard/create"
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-indigo-600 text-white text-sm font-medium rounded-xl hover:bg-indigo-700 transition-colors"
        >
          <PlusCircle className="w-4 h-4" />
          Beitrag erstellen
        </Link>

        {onOpenPreferences && (
          <button
            onClick={onOpenPreferences}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-white text-gray-700 text-sm font-medium rounded-xl border border-gray-200 hover:bg-gray-50 transition-colors"
          >
            <Settings className="w-4 h-4" />
            Einstellungen
          </button>
        )}
      </div>
    </div>
  )
}
