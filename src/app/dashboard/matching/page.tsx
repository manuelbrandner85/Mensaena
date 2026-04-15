'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { Sparkles, Settings, RefreshCw } from 'lucide-react'
import { cn } from '@/lib/design-system'
import { useMatching } from './hooks/useMatching'
import OnboardingHint from '@/components/shared/OnboardingHint'
import MatchDashboard from './components/MatchDashboard'
import MatchFilters from './components/MatchFilters'
import MatchSuggestionCard from './components/MatchSuggestionCard'
import MatchSuggestionDetail from './components/MatchSuggestionDetail'
import MatchEmptyState from './components/MatchEmptyState'
import MatchSkeleton from './components/MatchSkeleton'
import { MatchCardSkeleton } from './components/MatchSkeleton'
import PreferencesModal from './components/PreferencesModal'
import type { Match } from './types'
import { MatchingInterests } from '@/components/features/daily'

export default function MatchingPage() {
  const {
    matches,
    preferences,
    counts,
    filter,
    loading,
    loadingMore,
    hasMore,
    respondingId,
    userId,
    acceptMatch,
    declineMatch,
    openChat,
    refresh,
    setFilter,
    loadMore,
    markAsSeen,
    updatePreferences,
  } = useMatching()

  const [selectedMatch, setSelectedMatch] = useState<Match | null>(null)
  const [showPreferences, setShowPreferences] = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const observerRef = useRef<IntersectionObserver | null>(null)
  const loadMoreRef = useRef<HTMLDivElement>(null)

  // ── Infinite scroll observer ──────────────────────────────────
  useEffect(() => {
    const el = loadMoreRef.current
    if (!el) return

    observerRef.current = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && hasMore && !loadingMore) {
          loadMore()
        }
      },
      { rootMargin: '200px' },
    )

    observerRef.current.observe(el)

    return () => {
      if (observerRef.current) {
        observerRef.current.disconnect()
      }
    }
  }, [hasMore, loadingMore, loadMore])

  // ── Refresh handler ───────────────────────────────────────────
  const handleRefresh = useCallback(async () => {
    setRefreshing(true)
    await refresh()
    setRefreshing(false)
  }, [refresh])

  // ── Accept with detail close ──────────────────────────────────
  const handleAcceptFromDetail = useCallback(
    async (matchId: string) => {
      const result = await acceptMatch(matchId)
      if (result.success && result.conversation_id) {
        setSelectedMatch(null)
        openChat(result.conversation_id)
      }
    },
    [acceptMatch, openChat],
  )

  const handleDeclineFromDetail = useCallback(
    async (matchId: string) => {
      await declineMatch(matchId)
      setSelectedMatch(null)
    },
    [declineMatch],
  )

  // ── Loading state ─────────────────────────────────────────────
  if (loading && matches.length === 0) {
    return (
      <div className="max-w-3xl mx-auto">
        <header className="mb-8">
          <div className="meta-label meta-label--subtle mb-4">§ 10 / Matching</div>
          <h1 className="page-title">Matching</h1>
          <p className="page-subtitle mt-2">Automatische <span className="text-accent">Vorschläge</span> für passende Angebote und Gesuche.</p>
          <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
        </header>
        <MatchSkeleton />
      </div>
    )
  }

  return (
    <div className="max-w-3xl mx-auto pb-4">
      {/* Onboarding – nur beim ersten Besuch */}
      <div className="mb-5">
        <OnboardingHint
          storageKey="matching"
          title="So funktioniert das Matching"
          accentColor="blue"
          steps={[
            { icon: '🔍', title: 'Automatisch', text: 'Wir finden passende Angebote & Gesuche für dich' },
            { icon: '✅', title: 'Annehmen', text: 'Akzeptiere Vorschläge – ein Chat öffnet sich' },
            { icon: '⚙️', title: 'Anpassen', text: 'Stelle deine Präferenzen ein für bessere Treffer' },
          ]}
        />
      </div>

      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 10 / Matching</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-indigo-50 border border-indigo-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Sparkles className="w-6 h-6 text-indigo-600" />
            </div>
            <div>
              <h1 className="page-title">Matching</h1>
              <p className="page-subtitle mt-2">Automatische <span className="text-accent">Vorschläge</span> für passende Angebote und Gesuche.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0">
            <button
              onClick={handleRefresh}
              disabled={refreshing}
              className="p-2.5 rounded-full text-ink-400 hover:bg-stone-100 hover:text-ink-700 transition"
              aria-label="Aktualisieren"
            >
              <RefreshCw className={cn('w-4 h-4', refreshing && 'animate-spin')} />
            </button>
            <button
              onClick={() => setShowPreferences(true)}
              className="p-2.5 rounded-full text-ink-400 hover:bg-stone-100 hover:text-ink-700 transition"
              aria-label="Einstellungen"
            >
              <Settings className="w-4 h-4" />
            </button>
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      {/* Stats dashboard */}
      <div className="mb-4">
        <MatchDashboard counts={counts} loading={loading} />
      </div>

      <div className="mb-4">
        <MatchingInterests />
      </div>

      {/* Matching disabled banner */}
      {preferences && !preferences.matching_enabled && (
        <div className="mb-4 p-4 bg-amber-50 border border-amber-200 rounded-xl">
          <p className="text-sm text-amber-800 font-medium">
            Matching ist deaktiviert
          </p>
          <p className="text-xs text-amber-600 mt-1">
            Aktiviere Matching in den Einstellungen, um automatische Vorschläge zu erhalten.
          </p>
          <button
            onClick={() => setShowPreferences(true)}
            className="mt-2 text-xs font-medium text-amber-700 underline hover:text-amber-800"
          >
            Einstellungen öffnen
          </button>
        </div>
      )}

      {/* Filter tabs */}
      <div className="mb-4">
        <MatchFilters active={filter} counts={counts} onChange={setFilter} />
      </div>

      {/* Match list */}
      {matches.length === 0 ? (
        <MatchEmptyState
          filter={filter}
          onOpenPreferences={() => setShowPreferences(true)}
        />
      ) : (
        <div className="space-y-3">
          {matches.map((match) => (
            <MatchSuggestionCard
              key={match.id}
              match={match}
              userId={userId || ''}
              respondingId={respondingId}
              onAccept={acceptMatch}
              onDecline={declineMatch}
              onOpenChat={openChat}
              onOpenDetail={setSelectedMatch}
              onMarkAsSeen={markAsSeen}
            />
          ))}

          {/* Load more trigger */}
          <div ref={loadMoreRef} className="h-4" />

          {/* Loading more spinner */}
          {loadingMore && (
            <div className="space-y-3">
              <MatchCardSkeleton />
              <MatchCardSkeleton />
            </div>
          )}

          {/* No more items */}
          {!hasMore && matches.length > 0 && (
            <p className="text-center text-xs text-gray-400 py-4">
              Keine weiteren Matches
            </p>
          )}
        </div>
      )}

      {/* Detail modal */}
      {selectedMatch && userId && (
        <MatchSuggestionDetail
          match={selectedMatch}
          userId={userId}
          respondingId={respondingId}
          onClose={() => setSelectedMatch(null)}
          onAccept={handleAcceptFromDetail}
          onDecline={handleDeclineFromDetail}
          onOpenChat={(convId) => {
            setSelectedMatch(null)
            openChat(convId)
          }}
        />
      )}

      {/* Preferences modal */}
      {showPreferences && (
        <PreferencesModal
          preferences={preferences}
          onSave={updatePreferences}
          onClose={() => setShowPreferences(false)}
        />
      )}
    </div>
  )
}
