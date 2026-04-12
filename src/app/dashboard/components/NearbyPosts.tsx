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
      <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 flex items-start gap-3">
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
        <div className="overflow-x-auto flex gap-4 snap-x snap-mandatory pb-2 no-scrollbar">
          {posts.map((post) => {
            const cat = categoryColors[post.type]
            return (
              <button
                key={post.id}
                onClick={() => router.push(`/dashboard/posts/${post.id}`)}
                className="snap-center min-w-[280px] max-w-[320px] bg-white rounded-xl border border-gray-100 p-4 hover:shadow-md transition-shadow cursor-pointer flex-shrink-0 text-left"
              >
                {/* Category + Time */}
                <div className="flex items-center gap-2">
                  <Badge
                    variant={post.type === 'help_needed' || post.type === 'crisis' ? 'red' : 'primary'}
                    size="sm"
                    className={cat ? cn(cat.bg, cat.text) : undefined}
                  >
                    {typeLabels[post.type] ?? post.type}
                  </Badge>
                  <span className="text-xs text-gray-400">{formatTimeAgo(post.created_at)}</span>
                </div>

                {/* Title */}
                <p className="font-semibold text-sm line-clamp-2 mt-2 text-gray-900">
                  {post.title}
                </p>

                {/* Description */}
                {post.description && (
                  <p className="text-gray-600 text-xs line-clamp-2 mt-1">
                    {post.description}
                  </p>
                )}

                {/* Author + Distance */}
                <div className="flex items-center gap-2 mt-3 pt-3 border-t border-gray-50">
                  <Avatar
                    src={post.author_avatar}
                    name={post.author_name}
                    size="xs"
                  />
                  <span className="text-xs text-gray-500 truncate flex-1">
                    {post.author_name ?? 'Anonym'}
                  </span>
                  {post.distance_km !== null && (
                    <span className="text-xs text-primary-600 font-medium flex-shrink-0">
                      {post.distance_km.toLocaleString('de-DE', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} km
                    </span>
                  )}
                </div>
              </button>
            )
          })}
          {/* Padding at end for last card */}
          <div className="min-w-[16px] flex-shrink-0" aria-hidden />
        </div>

        {/* Right fade gradient */}
        <div className="absolute top-0 right-0 bottom-2 w-12 bg-gradient-to-l from-background to-transparent pointer-events-none" />
      </div>
    </div>
  )
}
