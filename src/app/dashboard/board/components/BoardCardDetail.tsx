'use client'

import { useState, useEffect, useRef } from 'react'
import {
  X, Pin, MessageCircle, Send, Trash2, Clock, Shield,
  Copy, Flag, ExternalLink, Loader2,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import showToast from '@/components/ui/Toast'
import type { BoardPost, BoardComment } from '../hooks/useBoard'
import { COLOR_MAP, CATEGORY_LABELS, CATEGORY_ICONS } from '../hooks/useBoard'

interface BoardCardDetailProps {
  post: BoardPost
  userId?: string
  isPinned: boolean
  comments: BoardComment[]
  commentsLoading: boolean
  onClose: () => void
  onTogglePin: (postId: string) => void
  onAddComment: (postId: string, content: string) => Promise<void>
  onDeleteComment: (commentId: string, postId: string) => Promise<void>
  onLoadComments: (postId: string) => void
}

function getExpiryInfo(expiresAt: string | null): string | null {
  if (!expiresAt) return null
  const exp = new Date(expiresAt)
  const now = new Date()
  if (exp <= now) return 'Dieser Aushang ist abgelaufen.'
  const hoursLeft = (exp.getTime() - now.getTime()) / (1000 * 60 * 60)
  if (hoursLeft <= 24) return `Läuft in ${Math.ceil(hoursLeft)} Stunden ab`
  return `Läuft am ${exp.toLocaleDateString('de-DE')} ab`
}

export default function BoardCardDetail({
  post,
  userId,
  isPinned,
  comments,
  commentsLoading,
  onClose,
  onTogglePin,
  onAddComment,
  onDeleteComment,
  onLoadComments,
}: BoardCardDetailProps) {
  const [newComment, setNewComment] = useState('')
  const [sending, setSending] = useState(false)
  const commentsEndRef = useRef<HTMLDivElement>(null)
  const colors = COLOR_MAP[post.color] ?? COLOR_MAP.yellow
  const profileName = post.profiles?.display_name || post.profiles?.name || 'Anonym'
  const expiryInfo = getExpiryInfo(post.expires_at)

  useEffect(() => {
    onLoadComments(post.id)
  }, [post.id, onLoadComments])

  useEffect(() => {
    commentsEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [comments.length])

  const handleSendComment = async () => {
    if (!newComment.trim() || newComment.length > 300) return
    setSending(true)
    try {
      await onAddComment(post.id, newComment.trim())
      setNewComment('')
    } catch {
      showToast('Kommentar konnte nicht gesendet werden', 'error')
    } finally {
      setSending(false)
    }
  }

  const copyLink = () => {
    const url = `${window.location.origin}/dashboard/board?post=${post.id}`
    navigator.clipboard.writeText(url).then(() => showToast('Link kopiert!', 'success'))
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Overlay */}
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />

      {/* Sheet / Modal */}
      <div
        className={cn(
          'relative w-full sm:max-w-lg max-h-[90vh] bg-white rounded-t-2xl sm:rounded-2xl',
          'shadow-2xl flex flex-col animate-in slide-in-from-bottom-4 duration-300 overflow-hidden',
        )}
      >
        {/* Header */}
        <div className={cn('flex items-center justify-between p-4 border-b', colors.bg)}>
          <div className="flex items-center gap-2">
            <span className={cn('inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium', colors.badge)}>
              {CATEGORY_ICONS[post.category]} {CATEGORY_LABELS[post.category]}
            </span>
            {post.pinned && <span className="text-xs text-emerald-600 font-medium">📌 Angepinnt</span>}
          </div>
          <button onClick={onClose} className="p-1.5 rounded-full hover:bg-black/10 transition">
            <X className="w-5 h-5 text-gray-600" />
          </button>
        </div>

        {/* Content area (scrollable) */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {/* Full content */}
          <p className="text-sm text-gray-900 leading-relaxed whitespace-pre-wrap">{post.content}</p>

          {/* Image viewer */}
          {post.image_url && (
            <div className="rounded-lg overflow-hidden">
              <img
                src={post.image_url}
                alt="Bild zum Aushang"
                className="w-full max-h-64 object-contain bg-gray-100"
              />
            </div>
          )}

          {/* Contact box */}
          {post.contact_info && (
            <div className="bg-gray-50 rounded-lg p-3 border border-gray-200">
              <p className="text-xs text-gray-500 mb-1">Kontaktinfo</p>
              <p className="text-sm text-gray-800">{post.contact_info}</p>
            </div>
          )}

          {/* Expiry info */}
          {expiryInfo && (
            <div className="flex items-center gap-2 text-xs text-gray-500">
              <Clock className="w-3.5 h-3.5" />
              {expiryInfo}
            </div>
          )}

          {/* Meta info */}
          <div className="flex items-center gap-3 text-xs text-gray-500">
            <div className="flex items-center gap-1.5">
              {post.profiles?.avatar_url ? (
                <img src={post.profiles.avatar_url} alt="" className="w-5 h-5 rounded-full object-cover" />
              ) : (
                <div className="w-5 h-5 rounded-full bg-gray-300 flex items-center justify-center text-[10px]">
                  {profileName.charAt(0).toUpperCase()}
                </div>
              )}
              <span>{profileName}</span>
              {(post.profiles?.trust_score ?? 0) >= 70 && (
                <Shield className="w-3 h-3 text-emerald-500" title="Vertrauenswürdig" />
              )}
            </div>
            <span>·</span>
            <span>{formatRelativeTime(post.created_at)}</span>
          </div>

          {/* Action buttons */}
          <div className="flex items-center gap-2 flex-wrap">
            <button
              onClick={() => onTogglePin(post.id)}
              className={cn(
                'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition',
                isPinned
                  ? 'bg-emerald-100 text-emerald-700'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200',
              )}
            >
              <Pin className={cn('w-3.5 h-3.5', isPinned && 'fill-emerald-600')} />
              {isPinned ? 'Angepinnt' : 'Anpinnen'} ({post.pin_count})
            </button>
            <button
              onClick={copyLink}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition"
            >
              <Copy className="w-3.5 h-3.5" />
              Link kopieren
            </button>
            <button
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition"
              onClick={() => showToast('Meldung gesendet', 'success')}
            >
              <Flag className="w-3.5 h-3.5" />
              Melden
            </button>
          </div>

          {/* Comments section */}
          <div className="border-t border-gray-200 pt-4">
            <h4 className="text-sm font-semibold text-gray-800 mb-3 flex items-center gap-1.5">
              <MessageCircle className="w-4 h-4" />
              Kommentare ({post.comment_count})
            </h4>

            {commentsLoading ? (
              <div className="flex items-center justify-center py-6">
                <Loader2 className="w-5 h-5 animate-spin text-gray-400" />
              </div>
            ) : comments.length === 0 ? (
              <p className="text-xs text-gray-400 text-center py-4">
                Noch keine Kommentare. Schreib den ersten!
              </p>
            ) : (
              <div className="space-y-3 max-h-60 overflow-y-auto">
                {comments.map((c) => {
                  const cName = c.profiles?.display_name || c.profiles?.name || 'Anonym'
                  const isOwnComment = c.author_id === userId
                  return (
                    <div key={c.id} className="flex gap-2 group">
                      {c.profiles?.avatar_url ? (
                        <img src={c.profiles.avatar_url} alt="" className="w-6 h-6 rounded-full object-cover mt-0.5" />
                      ) : (
                        <div className="w-6 h-6 rounded-full bg-gray-200 flex items-center justify-center text-[10px] mt-0.5">
                          {cName.charAt(0).toUpperCase()}
                        </div>
                      )}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-medium text-gray-800">{cName}</span>
                          <span className="text-[10px] text-gray-400">{formatRelativeTime(c.created_at)}</span>
                          {isOwnComment && (
                            <button
                              onClick={() => onDeleteComment(c.id, post.id)}
                              className="opacity-0 group-hover:opacity-100 p-0.5 rounded hover:bg-red-50 transition"
                              title="Löschen"
                            >
                              <Trash2 className="w-3 h-3 text-red-400" />
                            </button>
                          )}
                        </div>
                        <p className="text-xs text-gray-700 mt-0.5">{c.content}</p>
                      </div>
                    </div>
                  )
                })}
                <div ref={commentsEndRef} />
              </div>
            )}
          </div>
        </div>

        {/* Comment input */}
        {userId && (
          <div className="border-t border-gray-200 p-3 flex items-center gap-2">
            <input
              type="text"
              value={newComment}
              onChange={(e) => setNewComment(e.target.value.slice(0, 300))}
              placeholder="Kommentar schreiben..."
              maxLength={300}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault()
                  handleSendComment()
                }
              }}
              className="flex-1 rounded-full border border-gray-200 px-3 py-2 text-sm
                         focus:outline-none focus:ring-2 focus:ring-emerald-500"
            />
            <button
              onClick={handleSendComment}
              disabled={!newComment.trim() || sending}
              className="p-2 rounded-full bg-emerald-600 text-white disabled:opacity-40 hover:bg-emerald-700 transition"
            >
              {sending ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <Send className="w-4 h-4" />
              )}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
