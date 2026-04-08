'use client'

import { useState, useEffect, useRef, useCallback, type MouseEvent, type TouchEvent } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import {
  MapPin, Clock, Phone, MessageCircle, Bookmark, BookmarkCheck,
  ExternalLink, User, Send, Loader2, RefreshCw,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { openOrCreateDM } from '@/lib/chat-utils'
import toast from 'react-hot-toast'
import { cn, formatRelativeTime, cleanPhone, truncateText } from '@/lib/utils'
import { getTypeConfig, type PostCardPost } from '@/lib/post-types'
import { handleSupabaseError } from '@/lib/errors'
import { useStore } from '@/store/useStore'
import TrustScoreBadge from '@/app/ratings/components/TrustScoreBadge'

// Re-export so existing consumers keep working
export type { PostCardPost } from '@/lib/post-types'

// ── Reaction helpers ──────────────────────────────────────────────────────────
type ReactionType = 'heart' | 'thanks' | 'support' | 'compassion'
const REACTIONS: { type: ReactionType; emoji: string; label: string }[] = [
  { type: 'heart',      emoji: '\u2764\uFE0F', label: 'Herz' },
  { type: 'thanks',     emoji: '\uD83D\uDE4F', label: 'Danke' },
  { type: 'support',    emoji: '\uD83D\uDCAA',  label: 'Stark' },
  { type: 'compassion', emoji: '\uD83E\uDD17',  label: 'Mitgefuehl' },
]

const WEEKDAYS_DE = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag']
const WEEKDAYS_SHORT = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa']

// ── Props ─────────────────────────────────────────────────────────────────────
interface PostCardProps {
  post: PostCardPost
  currentUserId?: string
  savedIds?: string[]
  onSave?: (id: string, saved: boolean) => void
  /** @deprecated Use onSave instead */
  onSaveToggle?: (id: string, saved: boolean) => void
  onReact?: (id: string, type: ReactionType) => void
  compact?: boolean
  showActions?: boolean
  detailLink?: boolean
}

// ── Availability helper ───────────────────────────────────────────────────────
function computeAvailability(days?: string[], start?: string, end?: string): { available: boolean; nextLabel: string } | null {
  if (!days || days.length === 0) return null
  const now = new Date()
  const todayName = WEEKDAYS_DE[now.getDay()]
  const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
  const isToday = days.includes(todayName) || days.includes(WEEKDAYS_SHORT[now.getDay()])
  if (isToday) {
    const afterStart = !start || currentTime >= start
    const beforeEnd = !end || currentTime <= end
    if (afterStart && beforeEnd) return { available: true, nextLabel: '' }
  }
  // Find next available day
  for (let i = 1; i <= 7; i++) {
    const idx = (now.getDay() + i) % 7
    const dayName = WEEKDAYS_DE[idx]
    const dayShort = WEEKDAYS_SHORT[idx]
    if (days.includes(dayName) || days.includes(dayShort)) {
      return { available: false, nextLabel: `${dayShort} ${start ?? ''}`.trim() }
    }
  }
  return null
}

// ── Recurring label ───────────────────────────────────────────────────────────
function recurringLabel(interval?: string): string {
  if (!interval) return 'Wiederkehrend'
  const map: Record<string, string> = {
    daily: 'Taeglich', weekly: 'Woechentlich', biweekly: 'Alle 2 Wochen', monthly: 'Monatlich',
  }
  return map[interval] ?? interval
}

// ── Main Component ────────────────────────────────────────────────────────────
export default function PostCard({
  post,
  currentUserId,
  savedIds = [],
  onSave,
  onSaveToggle,
  onReact,
  compact = false,
  showActions = true,
  detailLink = true,
}: PostCardProps) {
  const router = useRouter()
  const store = useStore()
  const saveCb = onSave ?? onSaveToggle

  // ── State ───────────────────────────────────────────────────────────────────
  const [isSaved, setIsSaved] = useState(savedIds.includes(post.id))
  const [savingLoading, setSavingLoading] = useState(false)
  const [reactions, setReactions] = useState<Record<ReactionType, number>>({ heart: 0, thanks: 0, support: 0, compassion: 0 })
  const [myReaction, setMyReaction] = useState<ReactionType | null>(null)
  const [showContactModal, setShowContactModal] = useState(false)
  const [showContextMenu, setShowContextMenu] = useState(false)
  const [contextMenuPosition, setContextMenuPosition] = useState({ x: 0, y: 0 })
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const [dmLoading, setDmLoading] = useState(false)
  const cardRef = useRef<HTMLDivElement>(null)

  // Keep isSaved in sync with prop changes
  useEffect(() => { setIsSaved(savedIds.includes(post.id)) }, [savedIds, post.id])

  // ── Load reactions ──────────────────────────────────────────────────────────
  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('post_reactions')
      .select('reaction_type, user_id')
      .eq('post_id', post.id)
      .then(({ data, error }) => {
        if (error || !data) return
        const counts: Record<ReactionType, number> = { heart: 0, thanks: 0, support: 0, compassion: 0 }
        for (const r of data) {
          const t = r.reaction_type as ReactionType
          if (t in counts) counts[t]++
          if (currentUserId && r.user_id === currentUserId) setMyReaction(t)
        }
        setReactions(counts)
      })
  }, [post.id, currentUserId])

  // ── Close context menu on outside click ─────────────────────────────────────
  useEffect(() => {
    if (!showContextMenu) return
    const handler = () => setShowContextMenu(false)
    window.addEventListener('click', handler)
    return () => window.removeEventListener('click', handler)
  }, [showContextMenu])

  // ── Derived ─────────────────────────────────────────────────────────────────
  const cfg = getTypeConfig(post.type)
  const isOwn = currentUserId === post.user_id
  const isAnonymous = post.is_anonymous === true
  const urgency = typeof post.urgency === 'string' ? parseInt(post.urgency, 10) || 0 : (post.urgency ?? 0)
  const href = `/dashboard/posts/${post.id}`
  const availability = computeAvailability(post.availability_days, post.availability_start, post.availability_end)

  // Privacy checks
  const canShowPhone = !isAnonymous && !!post.contact_phone && post.privacy_phone !== false
  const canShowEmail = !isAnonymous && !!post.contact_email && post.privacy_email !== false
  const canShowWhatsApp = !isAnonymous && !!post.contact_whatsapp && post.privacy_phone !== false

  // ── Handlers ────────────────────────────────────────────────────────────────
  const handleReaction = useCallback(async (type: ReactionType) => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    const supabase = createClient()
    const prev = myReaction

    // Optimistic update
    if (prev === type) {
      // Remove reaction
      setMyReaction(null)
      setReactions(r => ({ ...r, [type]: Math.max(0, r[type] - 1) }))
      const { error } = await supabase.from('post_reactions').delete()
        .eq('post_id', post.id).eq('user_id', currentUserId)
      if (handleSupabaseError(error)) {
        // Rollback
        setMyReaction(prev)
        setReactions(r => ({ ...r, [type]: r[type] + 1 }))
      }
    } else {
      // Add or change reaction
      setMyReaction(type)
      setReactions(r => {
        const next = { ...r, [type]: r[type] + 1 }
        if (prev) next[prev] = Math.max(0, next[prev] - 1)
        return next
      })
      const { error } = await supabase.from('post_reactions').upsert(
        { post_id: post.id, user_id: currentUserId, reaction_type: type },
        { onConflict: 'post_id,user_id' },
      )
      if (handleSupabaseError(error)) {
        // Rollback
        setMyReaction(prev)
        setReactions(r => {
          const next = { ...r, [type]: Math.max(0, r[type] - 1) }
          if (prev) next[prev] = next[prev] + 1
          return next
        })
      }
    }
    onReact?.(post.id, type)
  }, [currentUserId, myReaction, post.id, onReact])

  const handleSave = useCallback(async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    setSavingLoading(true)
    const supabase = createClient()
    if (isSaved) {
      const { error } = await supabase.from('saved_posts').delete()
        .eq('user_id', currentUserId).eq('post_id', post.id)
      if (!handleSupabaseError(error)) {
        setIsSaved(false)
        saveCb?.(post.id, false)
        toast.success('Beitrag entfernt')
      }
    } else {
      const { error } = await supabase.from('saved_posts').insert({ user_id: currentUserId, post_id: post.id })
      if (!handleSupabaseError(error)) {
        setIsSaved(true)
        saveCb?.(post.id, true)
        toast.success('Beitrag gespeichert')
      }
    }
    setSavingLoading(false)
  }, [currentUserId, isSaved, post.id, saveCb])

  const handleDM = useCallback(async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    if (isOwn || isAnonymous) return
    setDmLoading(true)
    try {
      const convId = await openOrCreateDM(currentUserId, post.user_id, post.id)
      if (convId) router.push(`/dashboard/chat?conv=${convId}`)
      else toast.error('Konversation konnte nicht gestartet werden')
    } finally {
      setDmLoading(false)
    }
  }, [currentUserId, isOwn, isAnonymous, post.user_id, post.id, router])

  // ── Context menu ────────────────────────────────────────────────────────────
  const openContextMenu = useCallback((x: number, y: number) => {
    setContextMenuPosition({ x, y })
    setShowContextMenu(true)
  }, [])

  const handleContextMenuEvent = useCallback((e: MouseEvent) => {
    e.preventDefault()
    openContextMenu(e.clientX, e.clientY)
  }, [openContextMenu])

  const handleTouchStart = useCallback((e: TouchEvent) => {
    const touch = e.touches[0]
    longPressTimer.current = setTimeout(() => {
      openContextMenu(touch.clientX, touch.clientY)
    }, 600)
  }, [openContextMenu])

  const handleTouchEnd = useCallback(() => {
    if (longPressTimer.current) { clearTimeout(longPressTimer.current); longPressTimer.current = null }
  }, [])

  const handleContextAction = useCallback(async (action: string) => {
    setShowContextMenu(false)
    switch (action) {
      case 'save': handleSave(); break
      case 'share':
        if (navigator.share) {
          navigator.share({ title: post.title, url: `${window.location.origin}/dashboard/posts/${post.id}` }).catch(() => {})
        } else {
          await navigator.clipboard.writeText(`${window.location.origin}/dashboard/posts/${post.id}`)
          toast.success('Link kopiert!')
        }
        break
      case 'report': toast('Meldung gesendet. Danke!'); break
      case 'copy':
        await navigator.clipboard.writeText(`${window.location.origin}/dashboard/posts/${post.id}`)
        toast.success('Link kopiert!')
        break
      case 'edit': router.push(`/dashboard/posts/${post.id}?edit=1`); break
      case 'done': {
        const supabase = createClient()
        const { error } = await supabase.from('posts').update({ status: 'resolved' }).eq('id', post.id)
        if (!handleSupabaseError(error)) toast.success('Als erledigt markiert')
        break
      }
      case 'delete': {
        if (!confirm('Beitrag wirklich loeschen?')) return
        const supabase = createClient()
        const { error } = await supabase.from('posts').delete().eq('id', post.id)
        if (!handleSupabaseError(error)) toast.success('Beitrag geloescht')
        break
      }
    }
  }, [handleSave, post.id, post.title, router])

  // ── Image layout helper ─────────────────────────────────────────────────────
  const mediaUrls = post.media_urls?.filter(Boolean) ?? []
  const thumbUrl = (url: string) => {
    // Check for thumb_ variant
    const parts = url.split('/')
    const fname = parts[parts.length - 1]
    if (fname.startsWith('thumb_')) return url
    parts[parts.length - 1] = `thumb_${fname}`
    return parts.join('/')
  }

  // ── Render ──────────────────────────────────────────────────────────────────
  return (
    <div
      ref={cardRef}
      className={cn(
        'bg-white rounded-2xl shadow-sm overflow-hidden relative group/card',
        'transition-all duration-200 hover:shadow-md hover:-translate-y-[2px]',
        urgency >= 3 && 'border-l-4 border-red-500',
        urgency < 3 && 'border border-warm-200',
      )}
      onContextMenu={handleContextMenuEvent}
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
    >
      {/* ── Urgency banner (level 3) ────────────────────────────────── */}
      {urgency >= 3 && (
        <div className="flex items-center gap-1.5 px-4 py-1.5 bg-red-500 text-white text-xs font-semibold animate-pulse">
          <span className="text-sm">&#x1F6A8;</span> Dringend
        </div>
      )}

      <div className="p-4">
        {/* ── Header row ─────────────────────────────────────────────── */}
        <div className="flex items-start justify-between gap-2 mb-3">
          <div className="flex items-center gap-2 min-w-0">
            {/* Avatar */}
            <div className={cn(
              'w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 overflow-hidden',
              isAnonymous ? 'bg-gray-200' : 'bg-primary-100',
            )}>
              {isAnonymous
                ? <span className="text-gray-500 text-sm font-bold">?</span>
                : post.profiles?.avatar_url
                  ? <img src={post.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                  : <User className="w-4 h-4 text-primary-600" />
              }
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-1">
                <p className="text-xs font-medium text-gray-700 truncate">
                  {isAnonymous ? 'Anonym' : (post.profiles?.name ?? 'Nutzer')}
                </p>
                {/* Verification badges */}
                {!isAnonymous && post.profiles && (
                  <>
                    {post.profiles.verified_email && (
                      <span title="E-Mail verifiziert" className="cursor-help text-[10px]">&#x2709;&#xFE0F;</span>
                    )}
                    {post.profiles.verified_phone && (
                      <span title="Telefon verifiziert" className="cursor-help text-[10px]">&#x1F4F1;</span>
                    )}
                    {post.profiles.verified_community && (
                      <span title="Community verifiziert" className="cursor-help text-[10px]">&#x1F91D;</span>
                    )}
                  </>
                )}
                {/* Trust Score Badge */}
                {!isAnonymous && post.profiles?.trust_score != null && post.profiles.trust_score > 0 && (
                  <TrustScoreBadge score={post.profiles.trust_score} count={post.profiles.trust_score_count} />
                )}
              </div>
              <div className="flex items-center gap-1 text-xs text-gray-400">
                <Clock className="w-3 h-3" />
                {formatRelativeTime(post.created_at)}
                {/* Urgency dot (level 2) */}
                {urgency === 2 && <span className="inline-block w-1.5 h-1.5 rounded-full bg-yellow-400 ml-1" />}
              </div>
            </div>
          </div>

          {/* Type badge */}
          <span className={cn('text-xs font-semibold px-2 py-0.5 rounded-full border flex-shrink-0 whitespace-nowrap', cfg.bg, cfg.color)}>
            <span className="mr-1">{cfg.emoji}</span>
            {cfg.label}
          </span>
        </div>

        {/* ── Badges row ─────────────────────────────────────────────── */}
        {(availability || post.is_recurring) && (
          <div className="flex flex-wrap gap-1.5 mb-2">
            {/* Availability badge */}
            {availability && (
              <span className={cn(
                'inline-flex items-center gap-1 text-[10px] font-medium px-2 py-0.5 rounded-full',
                availability.available ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600',
              )}>
                <span className={cn('w-1.5 h-1.5 rounded-full', availability.available ? 'bg-green-500' : 'bg-gray-400')} />
                {availability.available ? 'Jetzt verfuegbar' : `Naechste Verfuegbarkeit: ${availability.nextLabel}`}
              </span>
            )}
            {/* Recurring badge */}
            {post.is_recurring && (
              <span className="inline-flex items-center gap-1 text-[10px] font-medium px-2 py-0.5 rounded-full bg-blue-50 text-blue-700">
                <RefreshCw className="w-3 h-3" />
                {recurringLabel(post.recurring_interval)}
              </span>
            )}
          </div>
        )}

        {/* ── Title ──────────────────────────────────────────────────── */}
        {detailLink ? (
          <Link href={href} className="block group/title">
            <h3 className="font-semibold text-gray-900 text-sm leading-snug group-hover/title:text-primary-700 transition-colors mb-1">
              {post.title}
            </h3>
          </Link>
        ) : (
          <h3 className="font-semibold text-gray-900 text-sm leading-snug mb-1">{post.title}</h3>
        )}

        {/* ── Description ────────────────────────────────────────────── */}
        {!compact && post.description && (
          <p className="text-sm text-gray-600 line-clamp-2 mb-3">
            {truncateText(post.description, 200)}
          </p>
        )}

        {/* ── Location ───────────────────────────────────────────────── */}
        {post.location_text && (
          <div className="flex items-center gap-1 text-xs text-gray-500 mb-3">
            <MapPin className="w-3 h-3 flex-shrink-0" />
            <span className="truncate">{post.location_text}</span>
          </div>
        )}

        {/* ── Tags ───────────────────────────────────────────────────── */}
        {post.tags && post.tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mb-3">
            {post.tags.slice(0, 4).map(tag => (
              <span key={tag} className="tag text-xs cursor-default">#{tag}</span>
            ))}
          </div>
        )}

        {/* ── Image preview ──────────────────────────────────────────── */}
        {!compact && mediaUrls.length > 0 && (
          <ImagePreview urls={mediaUrls} thumbUrl={thumbUrl} href={detailLink ? href : undefined} />
        )}
        {compact && mediaUrls.length > 0 && (
          <div className="flex gap-1 mb-3">
            {mediaUrls.slice(0, 3).map((url, i) => (
              <img key={i} src={thumbUrl(url)} alt="" className="h-8 w-8 rounded object-cover flex-shrink-0" loading="lazy" />
            ))}
          </div>
        )}

        {/* ── Quick reactions (non-compact only) ─────────────────────── */}
        {!compact && (
          <div className="flex items-center gap-1 mb-3">
            {REACTIONS.map(r => {
              const isActive = myReaction === r.type
              const count = reactions[r.type]
              return (
                <button
                  key={r.type}
                  onClick={() => handleReaction(r.type)}
                  title={r.label}
                  className={cn(
                    'flex items-center gap-0.5 px-2 py-1 rounded-full text-xs transition-all',
                    isActive
                      ? 'bg-primary-100 text-primary-800 ring-1 ring-primary-300 scale-105'
                      : 'bg-warm-50 text-gray-500 hover:bg-warm-100',
                  )}
                >
                  <span>{r.emoji}</span>
                  {count > 0 && <span className="font-medium">{count}</span>}
                </button>
              )
            })}
          </div>
        )}

        {/* ── Actions bar ────────────────────────────────────────────── */}
        {showActions && (
          <div className="flex items-center justify-between pt-2 border-t border-warm-100">
            <div className="flex items-center gap-1 flex-wrap">
              {/* Interest / Contact */}
              {!isOwn && post.user_id !== currentUserId && (
                <button
                  onClick={() => {
                    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
                    setShowContactModal(true)
                  }}
                  className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-200 transition-all active:scale-95"
                >
                  <Send className="w-3.5 h-3.5" /> Interesse zeigen
                </button>
              )}

              {/* DM button */}
              {!isOwn && !isAnonymous && post.user_id !== currentUserId && (
                <button
                  onClick={handleDM}
                  disabled={dmLoading}
                  title="Direkte Nachricht senden"
                  className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-violet-50 text-violet-700 hover:bg-violet-100 border border-violet-200 transition-all"
                >
                  {dmLoading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <MessageCircle className="w-3.5 h-3.5" />}
                  DM
                </button>
              )}

              {/* WhatsApp */}
              {canShowWhatsApp && (
                <a
                  href={`https://wa.me/${cleanPhone(post.contact_whatsapp!)}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-green-50 text-green-700 hover:bg-green-100 transition-all"
                >
                  <MessageCircle className="w-3.5 h-3.5" /> WhatsApp
                </a>
              )}

              {/* Phone */}
              {canShowPhone && (
                <a
                  href={`tel:${cleanPhone(post.contact_phone!)}`}
                  className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-blue-50 text-blue-700 hover:bg-blue-100 transition-all"
                >
                  <Phone className="w-3.5 h-3.5" /> Anrufen
                </a>
              )}
            </div>

            <div className="flex items-center gap-1">
              {/* Bookmark */}
              <button
                onClick={handleSave}
                disabled={savingLoading}
                className="p-1.5 rounded-lg hover:bg-warm-100 transition-colors"
                title={isSaved ? 'Gespeichert' : 'Speichern'}
              >
                {isSaved
                  ? <BookmarkCheck className="w-4 h-4 text-primary-600" />
                  : <Bookmark className="w-4 h-4 text-gray-400" />
                }
              </button>

              {/* Detail link */}
              {detailLink && (
                <Link href={href} className="p-1.5 rounded-lg hover:bg-warm-100 transition-colors" title="Details">
                  <ExternalLink className="w-4 h-4 text-gray-400" />
                </Link>
              )}
            </div>
          </div>
        )}
      </div>

      {/* ── Mini Contact Modal ────────────────────────────────────── */}
      {showContactModal && (
        <MiniContactModal
          postTitle={post.title}
          postId={post.id}
          currentUserId={currentUserId}
          onClose={() => setShowContactModal(false)}
        />
      )}

      {/* ── Context Menu ──────────────────────────────────────────── */}
      {showContextMenu && (
        <ContextMenu
          x={contextMenuPosition.x}
          y={contextMenuPosition.y}
          isOwn={isOwn}
          onAction={handleContextAction}
        />
      )}
    </div>
  )
}

// ── Image Preview Component ───────────────────────────────────────────────────
function ImagePreview({ urls, thumbUrl, href }: { urls: string[]; thumbUrl: (u: string) => string; href?: string }) {
  const count = urls.length
  const Wrapper = href ? Link : 'div'
  const wrapperProps = href ? { href } : {}

  if (count === 1) {
    return (
      <Wrapper {...(wrapperProps as any)} className="block mb-3 overflow-hidden rounded-lg">
        <img src={thumbUrl(urls[0])} alt="" className="w-full h-40 object-cover" loading="lazy" />
      </Wrapper>
    )
  }

  if (count === 2) {
    return (
      <Wrapper {...(wrapperProps as any)} className="grid grid-cols-2 gap-1 mb-3 overflow-hidden rounded-lg">
        {urls.slice(0, 2).map((u, i) => (
          <img key={i} src={thumbUrl(u)} alt="" className="w-full h-32 object-cover" loading="lazy" />
        ))}
      </Wrapper>
    )
  }

  if (count === 3) {
    return (
      <Wrapper {...(wrapperProps as any)} className="grid grid-cols-3 gap-1 mb-3 overflow-hidden rounded-lg">
        <img src={thumbUrl(urls[0])} alt="" className="col-span-2 w-full h-32 object-cover" loading="lazy" />
        <div className="flex flex-col gap-1">
          {urls.slice(1, 3).map((u, i) => (
            <img key={i} src={thumbUrl(u)} alt="" className="w-full h-[calc(50%-2px)] object-cover" loading="lazy" />
          ))}
        </div>
      </Wrapper>
    )
  }

  // 4+
  return (
    <Wrapper {...(wrapperProps as any)} className="grid grid-cols-2 gap-1 mb-3 overflow-hidden rounded-lg relative">
      {urls.slice(0, 4).map((u, i) => (
        <img key={i} src={thumbUrl(u)} alt="" className="w-full h-24 object-cover" loading="lazy" />
      ))}
      {count > 4 && (
        <div className="absolute bottom-1 right-1 bg-black/60 text-white text-xs font-bold px-2 py-0.5 rounded-full">
          +{count - 4}
        </div>
      )}
    </Wrapper>
  )
}

// ── Mini Contact Modal ────────────────────────────────────────────────────────
function MiniContactModal({ postTitle, postId, currentUserId, onClose }: {
  postTitle: string
  postId: string
  currentUserId?: string
  onClose: () => void
}) {
  const [msg, setMsg] = useState('')
  const [sending, setSending] = useState(false)
  const maxLen = 500

  const handleSend = async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    setSending(true)
    const supabase = createClient()
    const { error } = await supabase.from('interactions').insert({
      post_id: postId,
      helper_id: currentUserId,
      status: 'pending',
      message: msg || 'Interesse gezeigt',
    })
    setSending(false)
    if (handleSupabaseError(error)) return
    toast.success('Interesse gemeldet!')
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-5 space-y-3" onClick={e => e.stopPropagation()}>
        <div className="flex items-start justify-between">
          <div>
            <p className="font-bold text-gray-900">Interesse zeigen</p>
            <p className="text-xs text-gray-500 mt-0.5 line-clamp-1">an: {postTitle}</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-lg leading-none">{'\u2715'}</button>
        </div>
        <div className="space-y-2">
          <textarea
            value={msg}
            onChange={e => setMsg(e.target.value.slice(0, maxLen))}
            placeholder="Kurze Nachricht (optional)..."
            rows={3}
            className="input resize-none text-sm w-full"
          />
          <p className="text-right text-[10px] text-gray-400">{msg.length}/{maxLen}</p>
          <button
            onClick={handleSend}
            disabled={sending}
            className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50"
          >
            {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
            Interesse melden
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Context Menu ──────────────────────────────────────────────────────────────
function ContextMenu({ x, y, isOwn, onAction }: {
  x: number; y: number; isOwn: boolean; onAction: (action: string) => void
}) {
  const menuRef = useRef<HTMLDivElement>(null)

  // Adjust position to keep menu in viewport
  const style: React.CSSProperties = {
    position: 'fixed',
    left: Math.min(x, typeof window !== 'undefined' ? window.innerWidth - 200 : x),
    top: Math.min(y, typeof window !== 'undefined' ? window.innerHeight - 300 : y),
    zIndex: 60,
  }

  const items = [
    { key: 'save',   label: '\uD83D\uDCBE Speichern' },
    { key: 'share',  label: '\uD83D\uDCE4 Teilen' },
    { key: 'report', label: '\uD83D\uDEA9 Melden' },
    { key: 'copy',   label: '\uD83D\uDD17 Link kopieren' },
  ]

  const ownItems = [
    { key: 'edit',   label: '\u270F\uFE0F Bearbeiten' },
    { key: 'done',   label: '\u2705 Als erledigt markieren' },
    { key: 'delete', label: '\uD83D\uDDD1\uFE0F Loeschen' },
  ]

  return (
    <div ref={menuRef} style={style} className="bg-white rounded-xl shadow-xl border border-gray-200 py-1 min-w-[180px]" onClick={e => e.stopPropagation()}>
      {items.map(item => (
        <button key={item.key} onClick={() => onAction(item.key)} className="w-full text-left px-4 py-2 text-sm hover:bg-warm-50 transition-colors">
          {item.label}
        </button>
      ))}
      {isOwn && (
        <>
          <div className="border-t border-gray-100 my-1" />
          {ownItems.map(item => (
            <button key={item.key} onClick={() => onAction(item.key)} className="w-full text-left px-4 py-2 text-sm hover:bg-warm-50 transition-colors">
              {item.label}
            </button>
          ))}
        </>
      )}
    </div>
  )
}
