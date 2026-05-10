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
      <div
        className="relative bg-mn-elevated border border-mn-amber/20 rounded-2xl p-4 flex items-start gap-3 overflow-hidden"
        style={{ boxShadow: '0 4px 16px rgba(0,0,0,0.4), 0 0 32px rgba(245,158,11,0.08) inset' }}
      >
        <div className="absolute top-0 left-[10%] right-[10%] h-px pointer-events-none"
          style={{ background: 'linear-gradient(90deg, transparent, rgba(245,158,11,0.40), transparent)' }}
          aria-hidden="true"
        />
        <MapPin className="w-5 h-5 text-mn-amber flex-shrink-0 mt-0.5" />
        <div className="flex-1">
          <p className="text-sm font-medium text-mn-ink">
            Hinterlege deinen Standort um Beiträge in deiner Nähe zu sehen
          </p>
          <Link
            href="/dashboard/settings"
            className="inline-flex items-center gap-1 mt-2 text-sm font-medium text-mn-amber hover:text-mn-amber-warm transition-colors focus:outline-none focus-visible:underline rounded"
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
            className="text-mn-amber text-sm font-medium hover:text-mn-amber transition-colors flex items-center gap-1"
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
                aria-label={post.title}
                className={cn(
                  'spotlight tilt group/post snap-center min-w-[272px] max-w-[310px] flex-shrink-0 text-left',
                  'bg-mn-elevated rounded-2xl border border-white/5 p-4',
                  'hover-lift cursor-pointer overflow-hidden relative',
                  'transition-all duration-300 hover:border-white/10',
                  'focus:outline-none focus-visible:ring-2 focus-visible:ring-mn-amber focus-visible:ring-offset-2 focus-visible:ring-offset-mn-void',
                )}
                style={{ boxShadow: '0 4px 16px rgba(0,0,0,0.35), 0 1px 0 rgba(255,255,255,0.04) inset' }}
              >
                {/* Top accent line */}
                <div
                  className="absolute top-0 left-0 right-0 h-[3px] rounded-t-2xl"
                  style={{ background: `linear-gradient(90deg, ${accent}, ${accent}44)` }}
                />

                {/* Cinema spotlight on hover */}
                <div
                  className="absolute inset-0 opacity-0 group-hover/post:opacity-100 transition-opacity duration-500 pointer-events-none rounded-2xl"
                  style={{ background: `radial-gradient(ellipse at 50% 0%, ${accent}25, transparent 60%)` }}
                  aria-hidden="true"
                />
                {/* Edge amber glow on hover */}
                <div
                  className="absolute inset-0 opacity-0 group-hover/post:opacity-100 transition-opacity duration-500 pointer-events-none rounded-2xl"
                  style={{ boxShadow: `0 0 32px ${accent}30 inset` }}
                  aria-hidden="true"
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
                  <span className="text-xs text-mn-mute ml-auto">{formatTimeAgo(post.created_at)}</span>
                </div>

                {/* Title */}
                <p className="font-semibold text-sm line-clamp-2 mt-2.5 text-mn-ink leading-snug">
                  {post.title}
                </p>

                {/* Description */}
                {post.description && (
                  <p className="text-mn-mute text-xs line-clamp-2 mt-1.5 leading-relaxed">
                    {post.description}
                  </p>
                )}

                {/* Author + Distance */}
                <div className="flex items-center gap-2 mt-3 pt-3 border-t border-white/5/80">
                  <Avatar
                    src={post.author_avatar}
                    name={post.author_name}
                    size="xs"
                  />
                  <span className="text-xs text-mn-mute truncate flex-1">
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
        <div className="absolute top-0 right-0 bottom-2 w-16 bg-gradient-to-l from-mn-void to-transparent pointer-events-none" />
      </div>
    </div>
  )
}
