'use client'

import dynamic from 'next/dynamic'
import { useState } from 'react'
import { Filter, MapPin, Locate, Layers } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Post } from '@/types'

// Dynamisch laden (no SSR – Leaflet benötigt Browser)
const MapComponent = dynamic(() => import('./MapComponent'), {
  ssr: false,
  loading: () => (
    <div className="flex-1 bg-warm-50 rounded-2xl flex items-center justify-center min-h-[400px]">
      <div className="text-center">
        <div className="w-12 h-12 border-3 border-primary-300 border-t-primary-600 rounded-full animate-spin mx-auto mb-3" />
        <p className="text-sm text-gray-500">Karte wird geladen…</p>
      </div>
    </div>
  ),
})

const filterTypes = [
  { key: 'all', label: 'Alle', emoji: '🗺️', color: 'bg-gray-100 text-gray-700 border-gray-200' },
  { key: 'help_needed', label: 'Hilfe gesucht', emoji: '🔴', color: 'bg-red-50 text-red-700 border-red-200' },
  { key: 'help_offered', label: 'Hilfe angeboten', emoji: '🟢', color: 'bg-primary-50 text-primary-700 border-primary-200' },
  { key: 'supply', label: 'Ressourcen', emoji: '🟡', color: 'bg-yellow-50 text-yellow-700 border-yellow-200' },
  { key: 'animal', label: 'Tiere', emoji: '🐾', color: 'bg-purple-50 text-purple-700 border-purple-200' },
  { key: 'housing', label: 'Wohnen', emoji: '🏡', color: 'bg-blue-50 text-blue-700 border-blue-200' },
  { key: 'crisis', label: 'Notfall', emoji: '🚑', color: 'bg-red-100 text-red-800 border-red-300' },
]

export default function MapView({ posts }: { posts: Post[] }) {
  const [activeFilter, setActiveFilter] = useState('all')
  const [selectedPost, setSelectedPost] = useState<Post | null>(null)
  const [showFilters, setShowFilters] = useState(false)

  const filteredPosts = activeFilter === 'all'
    ? posts
    : posts.filter((p) => p.type === activeFilter)

  return (
    <div className="space-y-4 h-full">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
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
              'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium border transition-all',
              showFilters
                ? 'bg-primary-100 text-primary-700 border-primary-300'
                : 'bg-white text-gray-600 border-warm-200 hover:bg-warm-50'
            )}
          >
            <Filter className="w-4 h-4" />
            Filter
          </button>
          <button className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-white text-gray-600 border border-warm-200 hover:bg-warm-50 transition-all">
            <Locate className="w-4 h-4" />
            Mein Standort
          </button>
        </div>
      </div>

      {/* Filters */}
      {showFilters && (
        <div className="flex flex-wrap gap-2 p-4 bg-white rounded-2xl border border-warm-100 shadow-soft animate-slide-up">
          {filterTypes.map((f) => (
            <button
              key={f.key}
              onClick={() => setActiveFilter(f.key)}
              className={cn(
                'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border transition-all',
                activeFilter === f.key
                  ? f.color + ' ring-2 ring-offset-1 ring-primary-400'
                  : 'bg-white text-gray-600 border-gray-200 hover:bg-warm-50'
              )}
            >
              <span>{f.emoji}</span>
              {f.label}
            </button>
          ))}
        </div>
      )}

      {/* Legend */}
      <div className="flex flex-wrap gap-3 text-xs text-gray-500">
        <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-red-500 inline-block" /> Hilfe gesucht</span>
        <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-green-500 inline-block" /> Hilfe angeboten</span>
        <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-yellow-500 inline-block" /> Ressourcen</span>
        <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-purple-500 inline-block" /> Tiere</span>
        <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-blue-500 inline-block" /> Wohnen</span>
      </div>

      {/* Map + Detail Panel */}
      <div className="flex gap-4 min-h-[520px]">
        {/* Map */}
        <div className={cn('flex-1 rounded-2xl overflow-hidden border border-warm-100 shadow-card', selectedPost ? 'lg:flex-[2]' : 'flex-1')}>
          <MapComponent
            posts={filteredPosts}
            onSelectPost={setSelectedPost}
            selectedPost={selectedPost}
          />
        </div>

        {/* Detail Panel */}
        {selectedPost && (
          <div className="hidden lg:block w-80 flex-shrink-0 animate-slide-in">
            <PostDetailPanel post={selectedPost} onClose={() => setSelectedPost(null)} />
          </div>
        )}
      </div>
    </div>
  )
}

function PostDetailPanel({ post, onClose }: { post: Post; onClose: () => void }) {
  return (
    <div className="card p-5 h-full overflow-y-auto">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-2">
          <MapPin className="w-4 h-4 text-primary-600" />
          <span className="text-xs font-medium text-primary-600">Details</span>
        </div>
        <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-lg leading-none">×</button>
      </div>

      <h3 className="font-semibold text-gray-900 mb-2">{post.title}</h3>
      <p className="text-sm text-gray-600 mb-4 leading-relaxed">{post.description}</p>

      <div className="space-y-2">
        {post.contact_phone && (
          <a href={`tel:${post.contact_phone}`}
            className="flex items-center gap-2 w-full p-3 bg-primary-50 text-primary-700 rounded-xl text-sm font-medium hover:bg-primary-100 transition-colors">
            📞 Anrufen: {post.contact_phone}
          </a>
        )}
        {post.contact_whatsapp && (
          <a href={`https://wa.me/${post.contact_whatsapp}`} target="_blank" rel="noopener noreferrer"
            className="flex items-center gap-2 w-full p-3 bg-green-50 text-green-700 rounded-xl text-sm font-medium hover:bg-green-100 transition-colors">
            💬 WhatsApp schreiben
          </a>
        )}
        {post.contact_email && (
          <a href={`mailto:${post.contact_email}`}
            className="flex items-center gap-2 w-full p-3 bg-trust-50 text-trust-500 rounded-xl text-sm font-medium hover:bg-trust-100 transition-colors">
            ✉️ E-Mail schreiben
          </a>
        )}
      </div>
    </div>
  )
}
