'use client'

import dynamic from 'next/dynamic'
import { useState, useCallback } from 'react'
import { Filter, MapPin, Locate } from 'lucide-react'
import { cn, POST_TYPE_META, POST_TYPES } from '@/lib/utils'
import { MobileSheet } from '@/components/mobile'
import MapLayerControl from './MapLayerControl'
import type { OverpassLayer } from '@/lib/services/overpass'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyPost = Record<string, any>

// Dynamisch laden (no SSR – Leaflet benötigt Browser)
const MapComponent = dynamic(() => import('./MapComponent'), {
  ssr: false,
  loading: () => (
    <div className="flex-1 bg-warm-50 rounded-2xl md:rounded-2xl flex items-center justify-center min-h-[400px]">
      <div className="text-center">
        <div className="w-12 h-12 border-3 border-primary-300 border-t-primary-600 rounded-full animate-spin mx-auto mb-3" />
        <p className="text-sm text-gray-500">Karte wird geladen…</p>
      </div>
    </div>
  ),
})

// Unified filter list: derived from POST_TYPE_META so map markers,
// filter pills and legend can never drift apart again.
const filterTypes: { key: string; label: string; emoji: string; color: string }[] = [
  { key: 'all', label: 'Alle', emoji: '🗺️', color: '#64748B' },
  ...POST_TYPES.map(t => ({
    key: t,
    label: POST_TYPE_META[t].label,
    emoji: POST_TYPE_META[t].emoji,
    color: POST_TYPE_META[t].color,
  })),
]

export default function MapView({ posts }: { posts: AnyPost[] }) {
  const [activeFilter, setActiveFilter] = useState('all')
  const [selectedPost, setSelectedPost] = useState<AnyPost | null>(null)
  const [showFilters, setShowFilters] = useState(false)
  const [showMobileDetail, setShowMobileDetail] = useState(false)
  const [showMobileFilters, setShowMobileFilters] = useState(false)
  const [activeLayers, setActiveLayers] = useState<Set<OverpassLayer>>(() => new Set())
  const [loadingLayers, setLoadingLayers] = useState<Set<OverpassLayer>>(() => new Set())

  const handleSelectPost = useCallback((post: AnyPost | null) => {
    setSelectedPost(post)
    if (post) setShowMobileDetail(true)
  }, [])

  const handleToggleLayer = useCallback((layer: OverpassLayer) => {
    setActiveLayers((prev) => {
      const next = new Set(prev)
      if (next.has(layer)) next.delete(layer)
      else next.add(layer)
      return next
    })
  }, [])

  const filteredPosts = activeFilter === 'all'
    ? posts
    : posts.filter((p) => p.type === activeFilter)

  return (
    <div className="space-y-4 h-full">
      {/* Mobile compact header */}
      <div className="md:hidden flex items-center justify-between gap-2">
        <div>
          <h1 className="text-lg font-bold text-gray-900">Interaktive Karte</h1>
          <p className="text-xs text-gray-500 mt-0.5">{filteredPosts.length} Beiträge in deiner Umgebung</p>
        </div>
        <button
          onClick={() => setShowMobileFilters(true)}
          className={cn(
            'flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-medium border shadow-soft transition-all flex-shrink-0',
            activeFilter !== 'all'
              ? 'bg-primary-50 text-primary-700 border-primary-200'
              : 'bg-white text-gray-600 border-warm-200',
          )}
        >
          <Filter className="w-3.5 h-3.5" />
          Filter
          {activeFilter !== 'all' && <span className="w-1.5 h-1.5 rounded-full bg-primary-500 flex-shrink-0" />}
        </button>
      </div>

      {/* Desktop header */}
      <div className="hidden md:flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Interaktive Karte</h1>
          <p className="text-sm text-gray-600 mt-0.5">
            {filteredPosts.length} Beiträge in deiner Umgebung
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={cn(
              'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium border transition-all touch-target',
              showFilters
                ? 'bg-primary-100 text-primary-700 border-primary-300'
                : 'bg-white text-gray-600 border-warm-200 hover:bg-warm-50'
            )}
          >
            <Filter className="w-4 h-4" />
            Filter
          </button>
          <button className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-white text-gray-600 border border-warm-200 hover:bg-warm-50 transition-all touch-target">
            <Locate className="w-4 h-4" />
            Mein Standort
          </button>
        </div>
      </div>

      {/* Desktop Filters */}
      {showFilters && (
        <div className="hidden md:flex flex-wrap gap-2 p-4 bg-white rounded-2xl border border-warm-100 shadow-soft animate-slide-up">
          {filterTypes.map((f) => {
            const active = activeFilter === f.key
            return (
              <button
                key={f.key}
                onClick={() => setActiveFilter(f.key)}
                className={cn(
                  'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border transition-all touch-target',
                  active ? 'text-white shadow-soft' : 'bg-white text-gray-600 border-gray-200 hover:bg-warm-50',
                )}
                style={active ? { background: f.color, borderColor: f.color } : undefined}
              >
                <span>{f.emoji}</span>
                {f.label}
              </button>
            )
          })}
        </div>
      )}

      {/* Desktop Legend – covers every post type in POST_TYPE_META */}
      <div className="hidden md:flex flex-wrap gap-x-4 gap-y-2 text-xs text-gray-600">
        {POST_TYPES.map(t => {
          const meta = POST_TYPE_META[t]
          return (
            <span key={t} className="flex items-center gap-1.5">
              <span
                className="w-4 h-4 rounded-full inline-flex items-center justify-center text-[9px] leading-none border-2 border-white shadow-soft"
                style={{ background: meta.color }}
              >
                <span className="drop-shadow-sm">{meta.emoji}</span>
              </span>
              {meta.label}
            </span>
          )
        })}
      </div>

      {/* Map + Detail Panel */}
      <div className="flex gap-4 min-h-[calc(100dvh-8rem)] md:min-h-[520px]">
        {/* Map – full viewport on mobile */}
        <div className={cn(
          'flex-1 overflow-hidden border border-warm-100 shadow-card relative',
          'rounded-none -mx-4 md:mx-0 md:rounded-2xl',
          selectedPost ? 'lg:flex-[2]' : 'flex-1'
        )}>
          <MapComponent
            posts={filteredPosts}
            onSelectPost={handleSelectPost}
            selectedPost={selectedPost}
            activeLayers={activeLayers}
            onLoadingChange={setLoadingLayers}
          />
          <MapLayerControl
            activeLayers={activeLayers}
            loadingLayers={loadingLayers}
            onToggle={handleToggleLayer}
          />
        </div>

        {/* Desktop Detail Panel */}
        {selectedPost && (
          <div className="hidden lg:block w-80 flex-shrink-0 animate-slide-in">
            <PostDetailPanel post={selectedPost} onClose={() => setSelectedPost(null)} />
          </div>
        )}
      </div>

      {/* Mobile FABs */}
      <div className="fixed bottom-6 right-4 z-30 flex flex-col gap-3 md:hidden">
        {/* Filter FAB */}
        <button
          onClick={() => setShowMobileFilters(true)}
          className="w-12 h-12 rounded-full bg-white shadow-lg border border-gray-200 flex items-center justify-center text-gray-700 active:scale-90 transition-transform"
          aria-label="Filter"
        >
          <Filter className="w-5 h-5" />
        </button>
        {/* Locate FAB */}
        <button
          className="w-12 h-12 rounded-full bg-primary-500 shadow-lg flex items-center justify-center text-white active:scale-90 transition-transform"
          aria-label="Mein Standort"
        >
          <Locate className="w-5 h-5" />
        </button>
      </div>

      {/* Mobile Filter BottomSheet */}
      <MobileSheet
        open={showMobileFilters}
        onClose={() => setShowMobileFilters(false)}
        title="Filter"
        snapPoints={[55]}
      >
        <div className="space-y-5">
          {/* Filter pills */}
          <div className="flex flex-wrap gap-2">
            {filterTypes.map((f) => {
              const active = activeFilter === f.key
              return (
                <button
                  key={f.key}
                  onClick={() => {
                    setActiveFilter(f.key)
                    setShowMobileFilters(false)
                  }}
                  className={cn(
                    'flex items-center gap-1.5 px-4 py-2.5 rounded-full text-sm font-medium border transition-all touch-target',
                    active ? 'text-white shadow-soft' : 'bg-white text-gray-600 border-gray-200',
                  )}
                  style={active ? { background: f.color, borderColor: f.color } : undefined}
                >
                  <span>{f.emoji}</span>
                  {f.label}
                </button>
              )
            })}
          </div>

          {/* Legende */}
          <div>
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Legende</p>
            <div className="flex flex-wrap gap-x-4 gap-y-2">
              {POST_TYPES.map(t => {
                const meta = POST_TYPE_META[t]
                return (
                  <span key={t} className="flex items-center gap-1.5 text-xs text-gray-600">
                    <span
                      className="w-4 h-4 rounded-full inline-flex items-center justify-center text-[9px] leading-none border-2 border-white shadow-soft flex-shrink-0"
                      style={{ background: meta.color }}
                    >
                      <span className="drop-shadow-sm">{meta.emoji}</span>
                    </span>
                    {meta.label}
                  </span>
                )
              })}
            </div>
          </div>
        </div>
      </MobileSheet>

      {/* Mobile Post Detail BottomSheet */}
      <MobileSheet
        open={showMobileDetail && !!selectedPost}
        onClose={() => {
          setShowMobileDetail(false)
          setSelectedPost(null)
        }}
        title="Details"
        snapPoints={[50, 90]}
      >
        {selectedPost && (
          <PostDetailPanel
            post={selectedPost}
            onClose={() => {
              setShowMobileDetail(false)
              setSelectedPost(null)
            }}
          />
        )}
      </MobileSheet>
    </div>
  )
}

function PostDetailPanel({ post, onClose }: { post: AnyPost; onClose: () => void }) {
  return (
    <div className="md:card md:p-5 md:h-full overflow-y-auto">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-2">
          <MapPin className="w-4 h-4 text-primary-600" />
          <span className="text-xs font-medium text-primary-600">Details</span>
        </div>
        <button onClick={onClose} className="hidden md:block text-gray-400 hover:text-gray-600 text-lg leading-none">×</button>
      </div>

      <h3 className="font-semibold text-gray-900 mb-2">{post.title}</h3>
      <p className="text-sm text-gray-600 mb-4 leading-relaxed">{post.description}</p>

      <div className="space-y-2">
        {post.contact_phone && (
          <a href={`tel:${post.contact_phone}`}
            className="flex items-center gap-2 w-full p-3 bg-primary-50 text-primary-700 rounded-xl text-sm font-medium hover:bg-primary-100 transition-colors touch-target">
            📞 Anrufen: {post.contact_phone}
          </a>
        )}
        {post.contact_whatsapp && (
          <a href={`https://wa.me/${post.contact_whatsapp}`} target="_blank" rel="noopener noreferrer"
            className="flex items-center gap-2 w-full p-3 bg-green-50 text-green-700 rounded-xl text-sm font-medium hover:bg-green-100 transition-colors touch-target">
            💬 WhatsApp schreiben
          </a>
        )}
        {post.contact_email && (
          <a href={`mailto:${post.contact_email}`}
            className="flex items-center gap-2 w-full p-3 bg-trust-50 text-trust-500 rounded-xl text-sm font-medium hover:bg-trust-100 transition-colors touch-target">
            ✉️ E-Mail schreiben
          </a>
        )}
      </div>
    </div>
  )
}
