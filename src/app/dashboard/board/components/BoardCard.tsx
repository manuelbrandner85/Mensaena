'use client'

import { useState } from 'react'
import { Pin, MessageCircle, MoreVertical, Pencil, Trash2, Clock, Shield } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime, truncateText } from '@/lib/utils'
import type { BoardPost } from '../hooks/useBoard'
import { COLOR_MAP, CATEGORY_LABELS, CATEGORY_ICONS } from '../hooks/useBoard'

interface BoardCardProps {
  post: BoardPost
  userId?: string
  isPinned: boolean
  isNew?: boolean
  onTogglePin: (postId: string) => void
  onOpenDetail: (post: BoardPost) => void
  onEdit?: (post: BoardPost) => void
  onDelete?: (postId: string) => void
}

function getExpiryBadge(expiresAt: string | null): { label: string; color: string } | null {
  if (!expiresAt) return null
  const now = Date.now()
  const exp = new Date(expiresAt).getTime()
  const hoursLeft = (exp - now) / (1000 * 60 * 60)
  if (hoursLeft <= 0) return { label: 'Abgelaufen', color: 'bg-red-100 text-red-700' }
  if (hoursLeft <= 24) return { label: `${Math.ceil(hoursLeft)} Std. übrig`, color: 'bg-orange-100 text-orange-700' }
  const daysLeft = Math.ceil(hoursLeft / 24)
  if (daysLeft <= 3) return { label: `${daysLeft} Tage übrig`, color: 'bg-yellow-100 text-yellow-700' }
  return { label: `${daysLeft} Tage übrig`, color: 'bg-stone-100 text-ink-600' }
}

export default function BoardCard({
  post,
  userId,
  isPinned,
  isNew,
  onTogglePin,
  onOpenDetail,
  onEdit,
  onDelete,
}: BoardCardProps) {
  const [menuOpen, setMenuOpen] = useState(false)
  const colors = COLOR_MAP[post.color] ?? COLOR_MAP.yellow
  const expiryBadge = getExpiryBadge(post.expires_at)
  const isOwn = userId === post.author_id
  const profileName = post.profiles?.display_name || post.profiles?.name || 'Anonym'
  const trustScore = post.profiles?.trust_score ?? 0

  return (
    <article
      className={cn(
        'break-inside-avoid rounded-xl border-2 p-4 transition-all duration-300 cursor-pointer',
        colors.bg,
        colors.border,
        post.pinned && 'ring-2 ring-primary-400 ring-offset-1',
        isNew && 'animate-pulse ring-2 ring-blue-400',
      )}
      onClick={() => onOpenDetail(post)}
    >
      {/* Top badges row */}
      <div className="flex items-center gap-2 flex-wrap mb-2">
        {/* Category badge */}
        <span className={cn('inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium', colors.badge)}>
          <span>{CATEGORY_ICONS[post.category]}</span>
          {CATEGORY_LABELS[post.category]}
        </span>

        {/* Expiry badge */}
        {expiryBadge && (
          <span className={cn('inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium', expiryBadge.color)}>
            <Clock className="w-3 h-3" />
            {expiryBadge.label}
          </span>
        )}

        {/* Pinned indicator */}
        {post.pinned && (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-primary-100 text-primary-700">
            📌 Angepinnt
          </span>
        )}
      </div>

      {/* Content */}
      <p className={cn('text-sm leading-relaxed mb-2 whitespace-pre-wrap', colors.text)}>
        {truncateText(post.content, 180)}
        {post.content.length > 180 && (
          <button
            onClick={(e) => {
              e.stopPropagation()
              onOpenDetail(post)
            }}
            className="text-primary-600 hover:text-primary-700 font-medium ml-1"
          >
            mehr lesen
          </button>
        )}
      </p>

      {/* Images (media_urls bevorzugt, image_url als Fallback) */}
      {(() => {
        const imgs = (post.media_urls?.length ? post.media_urls : post.image_url ? [post.image_url] : [])
        if (!imgs.length) return null
        return (
          <div className={`mb-3 rounded-lg overflow-hidden grid gap-1 ${imgs.length > 1 ? 'grid-cols-2' : ''}`}>
            {imgs.slice(0, 3).map((src, i) => (
              <img key={i} src={src} alt="" className="w-full h-32 object-cover" loading="lazy"
                onError={(e) => { e.currentTarget.style.display = 'none' }} />
            ))}
          </div>
        )
      })()}

      {/* Contact */}
      {post.contact_info && (
        <div className="text-xs text-ink-600 bg-white/60 rounded-lg px-2 py-1 mb-2">
          📞 {post.contact_info}
        </div>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between mt-3 pt-3 border-t border-black/10">
        {/* Author */}
        <div className="flex items-center gap-2 min-w-0">
          {post.profiles?.avatar_url ? (
            <img
              src={post.profiles.avatar_url}
              alt={profileName}
              className="w-6 h-6 rounded-full object-cover"
            />
          ) : (
            <div className="w-6 h-6 rounded-full bg-stone-300 flex items-center justify-center text-xs text-ink-600">
              {profileName.charAt(0).toUpperCase()}
            </div>
          )}
          <span className="text-xs text-ink-600 truncate">{profileName}</span>
          {trustScore >= 70 && (
            <Shield className="w-3.5 h-3.5 text-primary-500 flex-shrink-0" aria-label="Vertrauenswürdig" />
          )}
        </div>

        {/* Actions */}
        <div className="flex items-center gap-3" onClick={(e) => e.stopPropagation()}>
          {/* Pin */}
          <button
            onClick={() => onTogglePin(post.id)}
            className={cn(
              'flex items-center gap-1 text-xs transition',
              isPinned ? 'text-primary-600 font-semibold' : 'text-ink-500 hover:text-primary-600',
            )}
            title={isPinned ? 'Pin entfernen' : 'Anpinnen'}
          >
            <Pin className={cn('w-3.5 h-3.5', isPinned && 'fill-primary-600')} />
            {post.pin_count > 0 && <span>{post.pin_count}</span>}
          </button>

          {/* Comments */}
          <button
            onClick={() => onOpenDetail(post)}
            className="flex items-center gap-1 text-xs text-ink-500 hover:text-primary-600 transition"
          >
            <MessageCircle className="w-3.5 h-3.5" />
            {post.comment_count > 0 && <span>{post.comment_count}</span>}
          </button>

          {/* Time */}
          <span className="text-xs text-ink-400">{formatRelativeTime(post.created_at)}</span>

          {/* Own post menu */}
          {isOwn && (
            <div className="relative">
              <button
                onClick={() => setMenuOpen(!menuOpen)}
                className="p-1 rounded-full hover:bg-black/10 transition"
              >
                <MoreVertical className="w-4 h-4 text-ink-500" />
              </button>
              {menuOpen && (
                <div className="absolute right-0 top-full mt-1 bg-white rounded-lg shadow-lg border border-stone-200 z-20 min-w-[140px]">
                  <button
                    onClick={() => {
                      setMenuOpen(false)
                      onEdit?.(post)
                    }}
                    className="flex items-center gap-2 w-full px-3 py-2 text-sm text-ink-700 hover:bg-stone-50"
                  >
                    <Pencil className="w-3.5 h-3.5" />
                    Bearbeiten
                  </button>
                  <button
                    onClick={() => {
                      setMenuOpen(false)
                      onDelete?.(post.id)
                    }}
                    className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-600 hover:bg-red-50"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    Löschen
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </article>
  )
}
