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
        <header>
          <div className="meta-label meta-label--subtle mb-4">§ 06 / Interaktionen</div>
          <h1 className="page-title">Interaktionen</h1>
          <p className="page-subtitle mt-2">Deine Hilfsanfragen und <span className="text-accent">-angebote</span>.</p>
          <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
        </header>
        <InteractionListSkeleton />
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Editorial header */}
      <header>
        <div className="meta-label meta-label--subtle mb-4">§ 06 / Interaktionen</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-primary-50 border border-primary-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Handshake className="w-6 h-6 text-primary-700" />
            </div>
            <div>
              <h1 className="page-title">Interaktionen</h1>
              <p className="page-subtitle mt-2">Deine Hilfsanfragen und <span className="text-accent">-angebote</span>.</p>
            </div>
          </div>

          {(requestedCount > 0 || activeCount > 0 || awaitingRatingCount > 0) && (
            <div className="hidden sm:flex items-center gap-2 flex-shrink-0 text-xs tracking-wide">
              {requestedCount > 0 && (
                <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200 text-ink-700">
                  <span className="font-serif italic tabular-nums">{requestedCount}</span> neu
                </span>
              )}
              {activeCount > 0 && (
                <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-amber-50 border border-amber-100 text-amber-800">
                  <span className="font-serif italic tabular-nums">{activeCount}</span> aktiv
                </span>
              )}
              {awaitingRatingCount > 0 && (
                <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-purple-50 border border-purple-100 text-purple-800">
                  <span className="font-serif italic tabular-nums">{awaitingRatingCount}</span> bewerten
                </span>
              )}
            </div>
          )}
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

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
