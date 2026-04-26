'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { MapPin, ArrowRight } from 'lucide-react'
import { cn } from '@/lib/design-system'
import { categoryColors } from '@/lib/design-system/tokens'
import { Badge, Button, EmptyState, Avatar, SectionHeader } from '@/components/ui'
import type { NearbyPost } from '../types'

interface NearbyPostsProps {
  posts: NearbyPost[]
  userHasLocation: boolean
}

const typeLabels: Record<string, string> = {
  help_needed: 'Hilfe gesucht',
  help_offered: 'Hilfe angeboten',
  crisis: 'Notfall',
  animal: 'Tiere',
  housing: 'Wohnen',
  supply: 'Versorgung',
  mobility: 'Mobilität',
  sharing: 'Teilen',
  community: 'Community',
  rescue: 'Retter',
}

// Warm accent per post type for card top-border
const typeAccent: Record<string, string> = {
  help_needed: '#C62828',
  crisis:      '#C62828',
  help_offered:'#1EAAA6',
  animal:      '#F59E0B',
  housing:     '#8B5CF6',
  supply:      '#3B82F6',
  mobility:    '#10B981',
  sharing:     '#1EAAA6',
  community:   '#4F6D8A',
  rescue:      '#EF4444',
}

function formatTimeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'gerade eben'
  if (m < 60) return `vor ${m}m`
  const h = Math.floor(m / 60)
  if (h < 24) return `vor ${h}h`
  const d = Math.floor(h / 24)
  if (d < 7) return `vor ${d}d`
  const w = Math.floor(d / 7)
  if (w < 5) return `vor ${w}w`
  return new Date(iso).toLocaleDateString('de-DE')
}

export default function NearbyPosts({ posts, userHasLocation }: NearbyPostsProps) {
  const router = useRouter()

  if (!userHasLocation) {
    return (
      <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex items-start gap-3">
        <MapPin className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
        <div className="flex-1">
          <p className="text-sm font-medium text-amber-900">
            Hinterlege deinen Standort um Beiträge in deiner Nähe zu sehen
          </p>
          <Link
            href="/dashboard/settings"
            className="inline-flex items-center gap-1 mt-2 text-sm font-medium text-amber-700 hover:text-amber-900 transition-colors"
          >
            Standort einstellen <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>
      </div>
    )
  }

  if (posts.length === 0) {
    return (
      <EmptyState
        title="Noch keine Beiträge in deiner Nähe"
        description="Sei der Erste!"
        action={
          <Button size="sm" onClick={() => router.push('/dashboard/create')}>
            Beitrag erstellen
          </Button>
        }
      />
    )
  }

  return (
    <div>
      <SectionHeader
        title="In deiner Nähe"
        action={
          <Link
            href="/dashboard/map"
            className="text-primary-600 text-sm font-medium hover:text-primary-700 transition-colors flex items-center gap-1"
          >
            Alle anzeigen <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        }
      />

      <div className="relative">
        <div className="overflow-x-auto flex gap-3 snap-x snap-mandatory pb-2 no-scrollbar">
          {posts.map((post) => {
            const cat = categoryColors[post.type]
            const accent = typeAccent[post.type] ?? '#1EAAA6'
            return (
              <button
                key={post.id}
                onClick={() => router.push(`/dashboard/posts/${post.id}`)}
                className={cn(
                  'spotlight tilt snap-center min-w-[272px] max-w-[310px] flex-shrink-0 text-left',
                  'bg-white rounded-2xl border border-stone-100 p-4',
                  'hover-lift cursor-pointer overflow-hidden relative',
                )}
              >
                {/* Top accent line */}
                <div
                  className="absolute top-0 left-0 right-0 h-[3px] rounded-t-2xl"
                  style={{ background: `linear-gradient(90deg, ${accent}, ${accent}44)` }}
                />

                {/* Subtle glow on hover via radial gradient overlay */}
                <div
                  className="absolute inset-0 opacity-0 hover:opacity-100 transition-opacity duration-300 pointer-events-none rounded-2xl"
                  style={{ background: `radial-gradient(circle at 50% 0%, ${accent}10, transparent 70%)` }}
                />

                {/* Category + Time */}
                <div className="flex items-center gap-2 mt-1">
                  <Badge
                    variant={post.type === 'help_needed' || post.type === 'crisis' ? 'red' : 'primary'}
                    size="sm"
                    className={cat ? cn(cat.bg, cat.text) : undefined}
                  >
                    {typeLabels[post.type] ?? post.type}
                  </Badge>
                  <span className="text-xs text-ink-400 ml-auto">{formatTimeAgo(post.created_at)}</span>
                </div>

                {/* Title */}
                <p className="font-semibold text-sm line-clamp-2 mt-2.5 text-ink-900 leading-snug">
                  {post.title}
                </p>

                {/* Description */}
                {post.description && (
                  <p className="text-ink-500 text-xs line-clamp-2 mt-1.5 leading-relaxed">
                    {post.description}
                  </p>
                )}

                {/* Author + Distance */}
                <div className="flex items-center gap-2 mt-3 pt-3 border-t border-gray-50/80">
                  <Avatar
                    src={post.author_avatar}
                    name={post.author_name}
                    size="xs"
                  />
                  <span className="text-xs text-ink-500 truncate flex-1">
                    {post.author_name ?? 'Anonym'}
                  </span>
                  {post.distance_km !== null && (
                    <span className="text-xs font-semibold flex-shrink-0" style={{ color: accent }}>
                      {post.distance_km.toLocaleString('de-DE', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} km
                    </span>
                  )}
                </div>
              </button>
            )
          })}
          <div className="min-w-[16px] flex-shrink-0" aria-hidden />
        </div>

        {/* Right fade gradient */}
        <div className="absolute top-0 right-0 bottom-2 w-16 bg-gradient-to-l from-background to-transparent pointer-events-none" />
      </div>
    </div>
  )
}
