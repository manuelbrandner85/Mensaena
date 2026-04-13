'use client'

import { useEffect, useState } from 'react'
import { Handshake, ChevronRight } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useInteractions } from './hooks/useInteractions'
import InteractionStatsCard from './components/InteractionStatsCard'
import InteractionFilters from './components/InteractionFilters'
import InteractionsList from './components/InteractionsList'
import { InteractionListSkeleton } from './components/InteractionSkeleton'

export default function InteractionsPage() {
  const {
    interactions, stats, counts, loading, filter, hasMore,
    setFilter, loadMore, requestedCount, activeCount, awaitingRatingCount,
  } = useInteractions()

  const [currentUserId, setCurrentUserId] = useState<string | undefined>()

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) setCurrentUserId(user.id)
    })
  }, [])

  const handleAccept = async (id: string) => {
    const { useInteractionStore } = await import('./stores/useInteractionStore')
    await useInteractionStore.getState().respondToInteraction(id, true)
  }

  const handleDecline = async (id: string) => {
    const { useInteractionStore } = await import('./stores/useInteractionStore')
    await useInteractionStore.getState().respondToInteraction(id, false)
  }

  const handleStart = async (id: string) => {
    const { useInteractionStore } = await import('./stores/useInteractionStore')
    await useInteractionStore.getState().startProgress(id)
  }

  const handleComplete = async (id: string) => {
    const { useInteractionStore } = await import('./stores/useInteractionStore')
    await useInteractionStore.getState().completeInteraction(id)
  }

  const handleRate = (id: string) => {
    window.location.href = `/dashboard/interactions/${id}?rate=1`
  }

  if (loading && interactions.length === 0) {
    return (
      <div className="max-w-4xl mx-auto space-y-6">
        <div className="flex items-center gap-3">
          <Handshake className="w-7 h-7 text-primary-600" />
          <h1 className="text-2xl font-bold text-gray-900">Interaktionen</h1>
        </div>
        <InteractionListSkeleton />
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Handshake className="w-7 h-7 text-primary-600" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Interaktionen</h1>
            <p className="text-sm text-gray-500">Deine Hilfsanfragen und -angebote</p>
          </div>
        </div>

        {/* Count badges */}
        {(requestedCount > 0 || activeCount > 0 || awaitingRatingCount > 0) && (
          <div className="hidden sm:flex items-center gap-2">
            {requestedCount > 0 && (
              <span className="bg-blue-100 text-blue-800 text-xs font-medium px-2.5 py-1 rounded-full">
                {requestedCount} neu
              </span>
            )}
            {activeCount > 0 && (
              <span className="bg-amber-100 text-amber-800 text-xs font-medium px-2.5 py-1 rounded-full">
                {activeCount} aktiv
              </span>
            )}
            {awaitingRatingCount > 0 && (
              <span className="bg-primary-100 text-primary-800 text-xs font-medium px-2.5 py-1 rounded-full">
                {awaitingRatingCount} bewerten
              </span>
            )}
          </div>
        )}
      </div>

      {/* Status-Flow Anzeige */}
      <div className="bg-white border border-warm-200 rounded-2xl px-4 py-3">
        <p className="text-xs text-gray-400 mb-2 font-medium uppercase tracking-wide">Wie läuft eine Interaktion ab?</p>
        <div className="flex items-center gap-1 flex-wrap">
          {[
            { label: 'Angefragt',     color: 'bg-blue-100 text-blue-700' },
            { label: 'Akzeptiert',    color: 'bg-amber-100 text-amber-700' },
            { label: 'In Bearbeitung',color: 'bg-orange-100 text-orange-700' },
            { label: 'Erledigt',      color: 'bg-green-100 text-green-700' },
            { label: 'Bewertet',      color: 'bg-purple-100 text-purple-700' },
          ].map((step, i, arr) => (
            <div key={step.label} className="flex items-center gap-1">
              <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${step.color}`}>
                {step.label}
              </span>
              {i < arr.length - 1 && <ChevronRight className="w-3 h-3 text-gray-300 flex-shrink-0" />}
            </div>
          ))}
        </div>
      </div>

      {/* Stats */}
      <InteractionStatsCard stats={stats} loading={loading} />

      {/* Filters */}
      <InteractionFilters filter={filter} onFilterChange={setFilter} />

      {/* List */}
      <InteractionsList
        interactions={interactions}
        filter={filter}
        hasMore={hasMore}
        onLoadMore={loadMore}
        onAccept={handleAccept}
        onDecline={handleDecline}
        onStart={handleStart}
        onComplete={handleComplete}
        onRate={handleRate}
        currentUserId={currentUserId}
      />
    </div>
  )
}
