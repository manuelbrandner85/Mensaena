'use client'

import { useRef, type MouseEvent } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Heart, MessageCircle, Share2, MoreHorizontal } from 'lucide-react'
import { cn } from '@/lib/design-system'
import ProfilOrb from './ProfilOrb'
import CinemaBadge from './CinemaBadge'

type BadgeVariant = 'amber' | 'teal' | 'herzrot' | 'leben' | 'trust' | 'mute'

export interface NachbarschaftCardPost {
  id: string
  title: string
  content?: string
  category?: string
  categoryVariant?: BadgeVariant
  categoryIcon?: React.ReactNode
  author?: { name?: string | null; avatar?: string | null }
  time?: string
  image?: string | null
  tags?: string[]
  likeCount?: number
  commentCount?: number
  liked?: boolean
  pinned?: boolean
}

interface NachbarschaftCardProps {
  post: NachbarschaftCardPost
  onLike?: (id: string) => void
  compact?: boolean
  className?: string
}

export default function NachbarschaftCard({ post, onLike, compact, className }: NachbarschaftCardProps) {
  const ref = useRef<HTMLDivElement>(null)

  function trackMouse(e: MouseEvent) {
    const el = ref.current
    if (!el) return
    const rect = el.getBoundingClientRect()
    const x = ((e.clientX - rect.left) / rect.width) * 100
    const y = ((e.clientY - rect.top) / rect.height) * 100
    el.style.setProperty('--mx', `${x}%`)
    el.style.setProperty('--my', `${y}%`)
  }

  return (
    <div
      ref={ref}
      className={cn(
        'group relative bg-mn-elevated rounded-card border border-white/5 shadow-cinema-card',
        'hover:border-mn-bronze/15 hover:shadow-cinema-card-hover hover:scale-[1.003]',
        'transition-all duration-300 overflow-hidden',
        className,
      )}
      onMouseMove={trackMouse}
    >
      {/* Mouse-tracking amber glow */}
      <div
        className="pointer-events-none absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300"
        style={{
          background: 'radial-gradient(circle at var(--mx,50%) var(--my,50%), rgba(199,147,99,0.04) 0%, transparent 60%)',
        }}
        aria-hidden
      />

      <div className={cn('relative p-5', compact && 'p-4')}>
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-2.5">
            {post.category && (
              <CinemaBadge variant={post.categoryVariant ?? 'amber'} icon={post.categoryIcon}>
                {post.category}
              </CinemaBadge>
            )}
            {post.pinned && (
              <span className="text-[10px] font-mono text-mn-bronze uppercase tracking-wide">Gepinnt</span>
            )}
          </div>
          <button className="p-1 rounded-lg text-mn-ghost hover:text-mn-ink-soft hover:bg-mn-elevated/5 transition-colors" aria-label="Mehr Optionen">
            <MoreHorizontal className="w-4 h-4" />
          </button>
        </div>

        {/* Author */}
        {post.author && (
          <div className="flex items-center gap-2.5 mb-3">
            <ProfilOrb src={post.author.avatar} name={post.author.name} size="sm" />
            <div>
              <div className="text-sm font-medium text-mn-ink leading-none">{post.author.name}</div>
              {post.time && <div className="text-[11px] font-mono text-mn-mute mt-0.5">{post.time}</div>}
            </div>
          </div>
        )}

        {/* Content */}
        <Link href={`/posts/${post.id}`} className="block group/link">
          {post.title && (
            <h3 className="text-base font-semibold text-mn-ink mb-1.5 group-hover/link:text-mn-bronze transition-colors duration-200">
              {post.title}
            </h3>
          )}
          {post.content && !compact && (
            <p className="text-sm text-mn-ink-soft leading-relaxed line-clamp-3">{post.content}</p>
          )}
        </Link>

        {/* Image */}
        {post.image && !compact && (
          <div className="mt-3 rounded-xl overflow-hidden aspect-video relative">
            <Image src={post.image} alt={post.title} fill className="object-cover" sizes="(max-width: 768px) 100vw, 600px" />
          </div>
        )}

        {/* Tags */}
        {post.tags && post.tags.length > 0 && !compact && (
          <div className="flex flex-wrap gap-1.5 mt-3">
            {post.tags.map(tag => (
              <span key={tag} className="text-[11px] text-mn-mute bg-mn-surface px-2 py-0.5 rounded-full border border-white/5">
                #{tag}
              </span>
            ))}
          </div>
        )}

        {/* Actions */}
        <div className="flex items-center gap-1 mt-4 pt-3 border-t border-white/5">
          <button
            onClick={() => onLike?.(post.id)}
            className={cn(
              'flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm transition-all duration-150',
              post.liked
                ? 'text-mn-herzrot-warm bg-mn-herzrot/8'
                : 'text-mn-mute hover:text-mn-herzrot-warm hover:bg-mn-herzrot/5',
            )}
          >
            <Heart className={cn('w-4 h-4', post.liked && 'fill-mn-herzrot-warm')} />
            {post.likeCount != null && <span className="font-mono text-xs">{post.likeCount}</span>}
          </button>
          <Link
            href={`/posts/${post.id}#comments`}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-mn-mute hover:text-mn-teal-soft hover:bg-mn-teal/5 transition-all duration-150"
          >
            <MessageCircle className="w-4 h-4" />
            {post.commentCount != null && <span className="font-mono text-xs">{post.commentCount}</span>}
          </Link>
          <button className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-mn-mute hover:text-mn-ink-soft hover:bg-mn-elevated/5 transition-all duration-150 ml-auto">
            <Share2 className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  )
}
