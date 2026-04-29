'use client'

import { useState, useEffect, useRef, useCallback, type MouseEvent, type TouchEvent } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import {
  MapPin, Clock, Phone, MessageCircle, Bookmark, BookmarkCheck,
  ExternalLink, User, Send, Loader2, RefreshCw, ThumbsUp, ThumbsDown,
  MessageSquare,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { openOrCreateDM } from '@/lib/chat-utils'
import toast from 'react-hot-toast'
import { cn, formatRelativeTime, cleanPhone, truncateText } from '@/lib/utils'
import { getTypeConfig, type PostCardPost } from '@/lib/post-types'
import { handleSupabaseError } from '@/lib/errors'
import { useStore } from '@/store/useStore'
import TrustScoreBadge from '@/app/ratings/components/TrustScoreBadge'
import ReportButton from '@/components/shared/ReportButton'
import ThankYouButton from '@/components/shared/ThankYouButton'
import dynamic from 'next/dynamic'

const PostDistanceBadge = dynamic(() => import('@/components/posts/PostDistanceBadge'), { ssr: false })

// Re-export so existing consumers keep working
export type { PostCardPost } from '@/lib/post-types'

// ── Reaction helpers ──────────────────────────────────────────────────────────
type ReactionType = 'heart' | 'thanks' | 'support' | 'compassion'
const REACTIONS: { type: ReactionType; emoji: string; label: string }[] = [
  { type: 'heart',      emoji: '❤️', label: 'Herz' },
  { type: 'thanks',     emoji: '🙏', label: 'Danke' },
  { type: 'support',    emoji: '💪',  label: 'Stark' },
  { type: 'compassion', emoji: '🤗',  label: 'Mitgefühl' },
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
    daily: 'Täglich', weekly: 'Wöchentlich', biweekly: 'Alle 2 Wochen', monthly: 'Monatlich',
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
  const [voteScore, setVoteScore] = useState(0)
  const [myVote, setMyVote] = useState<1 | -1 | 0>(0)
  const [commentCount, setCommentCount] = useState(0)
  const [localStatus, setLocalStatus] = useState<string | undefined>(post.status)
  const cardRef = useRef<HTMLDivElement>(null)
  const reactingRef = useRef<Set<string>>(new Set())

  // Keep isSaved in sync with prop changes
  useEffect(() => { setIsSaved(savedIds.includes(post.id)) }, [savedIds, post.id])

  // Keep localStatus in sync with prop changes
  useEffect(() => { setLocalStatus(post.status) }, [post.status])

  // ── Load reactions + votes + comment count ─────────────────────────────────
  useEffect(() => {
    const supabase = createClient()
    // Reactions
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
    // Votes
    supabase
      .from('post_votes')
      .select('vote, user_id')
      .eq('post_id', post.id)
      .then(({ data, error }) => {
        if (error || !data) return
        let score = 0
        for (const v of data) {
          score += v.vote
          if (currentUserId && v.user_id === currentUserId) setMyVote(v.vote as 1 | -1)
        }
        setVoteScore(score)
      })
    // Comment count
    supabase
      .from('post_comments')
      .select('id', { count: 'exact', head: true })
      .eq('post_id', post.id)
      .then(({ count, error }) => {
        if (!error && count != null) setCommentCount(count)
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
  const URGENCY_MAP: Record<string, number> = { low: 0, medium: 1, high: 2, critical: 3 }
  const urgency = typeof post.urgency === 'string' ? (URGENCY_MAP[post.urgency] ?? (parseInt(post.urgency, 10) || 0)) : (post.urgency ?? 0)
  const href = `/dashboard/posts/${post.id}`
  const availability = computeAvailability(post.availability_days, post.availability_start, post.availability_end)

  // Privacy checks
  const canShowPhone = !isAnonymous && !!post.contact_phone && post.privacy_phone !== false
  const canShowEmail = !isAnonymous && !!post.contact_email && post.privacy_email !== false
  const canShowWhatsApp = !isAnonymous && !!post.contact_whatsapp && post.privacy_phone !== false

  // ── Handlers ────────────────────────────────────────────────────────────────
  const handleReaction = useCallback(async (type: ReactionType) => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden', { id: 'auth-required' }); return }
    // B19: in-flight guard to prevent rapid double-clicks queuing multiple DB calls
    const guardKey = `${post.id}:${type}`
    if (reactingRef.current.has(guardKey)) return
    reactingRef.current.add(guardKey)
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
    reactingRef.current.delete(guardKey)
    onReact?.(post.id, type)
  }, [currentUserId, myReaction, post.id, onReact])

  const handleVote = useCallback(async (vote: 1 | -1) => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden', { id: 'auth-required' }); return }
    const supabase = createClient()
    const prevVote = myVote
    const prevScore = voteScore

    if (myVote === vote) {
      // Remove vote (toggle off)
      setMyVote(0)
      setVoteScore(s => s - vote)
      const { error } = await supabase.from('post_votes').delete()
        .eq('post_id', post.id).eq('user_id', currentUserId)
      if (error) { setMyVote(prevVote); setVoteScore(prevScore) }
    } else {
      // Add or change vote
      setMyVote(vote)
      setVoteScore(s => s - prevVote + vote)
      const { error } = await supabase.from('post_votes').upsert(
        { post_id: post.id, user_id: currentUserId, vote },
        { onConflict: 'post_id,user_id' },
      )
      if (error) { setMyVote(prevVote); setVoteScore(prevScore) }
    }
  }, [currentUserId, myVote, voteScore, post.id])

  const handleSave = useCallback(async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden', { id: 'auth-required' }); return }
    const supabase = createClient()
    const prev = isSaved
    // Optimistic update
    setIsSaved(!prev)
    saveCb?.(post.id, !prev)
    if (prev) {
      const { error } = await supabase.from('saved_posts').delete()
        .eq('user_id', currentUserId).eq('post_id', post.id)
      if (error) { setIsSaved(prev); saveCb?.(post.id, prev); handleSupabaseError(error) }
      else toast.success('Beitrag entfernt')
    } else {
      const { error } = await supabase.from('saved_posts').insert({ user_id: currentUserId, post_id: post.id })
      if (error) { setIsSaved(prev); saveCb?.(post.id, prev); handleSupabaseError(error) }
      else toast.success('Beitrag gespeichert')
    }
  }, [currentUserId, isSaved, post.id, saveCb])

  const handleDM = useCallback(async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden', { id: 'auth-required' }); return }
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
        const prev = localStatus
        setLocalStatus('resolved')
        const { error } = await supabase.from('posts').update({ status: 'resolved' }).eq('id', post.id)
        if (handleSupabaseError(error)) {
          setLocalStatus(prev)
        } else {
          toast.success('Als erledigt markiert')
          window.dispatchEvent(new CustomEvent('post-status-changed', { detail: { id: post.id, status: 'resolved' } }))
        }
        break
      }
      case 'activate': {
        const supabase = createClient()
        const prev = localStatus
        setLocalStatus('active')
        const { error } = await supabase.from('posts').update({ status: 'active' }).eq('id', post.id)
        if (handleSupabaseError(error)) {
          setLocalStatus(prev)
        } else {
          toast.success('Wieder aktiv')
          window.dispatchEvent(new CustomEvent('post-status-changed', { detail: { id: post.id, status: 'active' } }))
        }
        break
      }
      case 'archive': {
        const supabase = createClient()
        const prev = localStatus
        setLocalStatus('archived')
        const { error } = await supabase.from('posts').update({ status: 'archived' }).eq('id', post.id)
        if (handleSupabaseError(error)) {
          setLocalStatus(prev)
        } else {
          toast.success('Archiviert')
          window.dispatchEvent(new CustomEvent('post-status-changed', { detail: { id: post.id, status: 'archived' } }))
        }
        break
      }
      case 'delete': {
        if (!confirm('Beitrag wirklich löschen?')) return
        const supabase = createClient()
        const { error } = await supabase.from('posts').delete().eq('id', post.id)
        if (handleSupabaseError(error)) break
        toast.success('Beitrag gelöscht')
        window.dispatchEvent(new CustomEvent('post-deleted', { detail: { id: post.id } }))
        break
      }
    }
  }, [handleSave, post.id, post.title, router, localStatus])

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
  const accentColor = urgency >= 3 ? '#C62828' : urgency === 2 ? '#F97316' : '#1EAAA6'

  return (
    <div
      ref={cardRef}
      className={cn(
        'spotlight hover-lift bg-white rounded-2xl overflow-hidden relative group/card',
        // Editorial chrome: thin stone border, refined shadow, subtle hover
        'border border-stone-200 shadow-soft transition-all duration-300',
        'hover:shadow-card hover:border-stone-300',
        urgency >= 3 && 'border-l-4 !border-l-emergency-500',
        urgency === 2 && 'border-l-4 !border-l-orange-400',
      )}
      onContextMenu={handleContextMenuEvent}
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
    >
      {/* Top accent line */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px] z-10"
        style={{ background: `linear-gradient(90deg, ${accentColor}, ${accentColor}33)` }}
      />
      {/* ── Urgency banner ────────────────────────────────────────── */}
      {urgency >= 3 && (
        <div className="relative flex items-center gap-1.5 px-4 py-1.5 bg-gradient-to-r from-red-600 to-red-500 text-white text-xs font-semibold animate-pulse overflow-hidden">
          <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />
          <span className="relative text-sm">&#x1F6A8;</span>
          <span className="relative">Kritisch – Sofortige Hilfe nötig</span>
        </div>
      )}
      {urgency === 2 && (
        <div className="relative flex items-center gap-1.5 px-4 py-1.5 bg-gradient-to-r from-orange-500 to-amber-500 text-white text-xs font-semibold overflow-hidden">
          <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />
          <span className="relative text-sm">&#x26A0;&#xFE0F;</span>
          <span className="relative">Dringend</span>
        </div>
      )}

      <div className="p-4">
        {/* ── Header row ─────────────────────────────────────────────── */}
        <div className="flex items-start justify-between gap-2 mb-3">
          <div className="flex items-center gap-2 min-w-0">
            {/* Avatar */}
            <div className={cn(
              'w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 overflow-hidden',
              isAnonymous ? 'bg-stone-200' : 'bg-primary-100',
            )}>
              {isAnonymous
                ? <span className="text-ink-500 text-sm font-bold">?</span>
                : post.profiles?.avatar_url
                  ? <img src={post.profiles.avatar_url} alt={`Profilbild von ${post.profiles?.name || 'Nutzer'}`} className="w-full h-full object-cover" />
                  : <User className="w-4 h-4 text-primary-600" />
              }
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-1">
                <p className="text-xs font-medium text-ink-700 truncate">
                  {isAnonymous ? 'Anonym' : (post.profiles?.name ?? 'Nutzer')}
                </p>
                {/* Verification badges */}
                {!isAnonymous && post.profiles && (
                  <>
                    {post.profiles.verified_email && (
                      <span title="E-Mail verifiziert" className="cursor-help text-xs">&#x2709;&#xFE0F;</span>
                    )}
                    {post.profiles.verified_phone && (
                      <span title="Telefon verifiziert" className="cursor-help text-xs">&#x1F4F1;</span>
                    )}
                    {post.profiles.verified_community && (
                      <span title="Community verifiziert" className="cursor-help text-xs">&#x1F91D;</span>
                    )}
                  </>
                )}
                {/* Trust Score Badge */}
                {!isAnonymous && post.profiles?.trust_score != null && post.profiles.trust_score > 0 && (
                  <TrustScoreBadge score={post.profiles.trust_score} count={post.profiles.trust_score_count} />
                )}
              </div>
              <div className="flex items-center gap-1 text-xs text-ink-400">
                <Clock className="w-3 h-3" />
                {formatRelativeTime(post.created_at)}
                {/* Urgency indicator */}
                {urgency === 1 && <span className="inline-block w-1.5 h-1.5 rounded-full bg-yellow-400 ml-1" title="Mittel" />}
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
                'inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full',
                availability.available ? 'bg-green-100 text-green-700' : 'bg-stone-100 text-ink-600',
              )}>
                <span className={cn('w-1.5 h-1.5 rounded-full', availability.available ? 'bg-green-500' : 'bg-stone-400')} />
                {availability.available ? 'Jetzt verfügbar' : `Nächste Verfügbarkeit: ${availability.nextLabel}`}
              </span>
            )}
            {/* Recurring badge */}
            {post.is_recurring && (
              <span className="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full bg-blue-50 text-blue-700">
                <RefreshCw className="w-3 h-3" />
                {recurringLabel(post.recurring_interval)}
              </span>
            )}
          </div>
        )}

        {/* ── Title ──────────────────────────────────────────────────── */}
        {detailLink ? (
          <Link href={href} className="block group/title">
            <h3 className="font-semibold text-ink-900 text-sm leading-snug group-hover/title:text-primary-700 transition-colors mb-1">
              {post.title}
            </h3>
          </Link>
        ) : (
          <h3 className="font-semibold text-ink-900 text-sm leading-snug mb-1">{post.title}</h3>
        )}

        {/* ── Description ────────────────────────────────────────────── */}
        {!compact && post.description && (
          <p className="text-sm text-ink-600 line-clamp-2 mb-3">
            {truncateText(post.description, 200)}
          </p>
        )}

        {/* ── Location ───────────────────────────────────────────────── */}
        {(post.location_text || (post.latitude && post.longitude)) && (
          <div className="flex items-center gap-2 mb-3 flex-wrap">
            {post.location_text && (
              <div className="flex items-center gap-1 text-xs text-ink-500">
                <MapPin className="w-3 h-3 flex-shrink-0" />
                <span className="truncate">{post.location_text}</span>
              </div>
            )}
            {post.latitude && post.longitude && (
              <PostDistanceBadge postLat={post.latitude} postLon={post.longitude} />
            )}
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
                      : 'bg-warm-50 text-ink-500 hover:bg-warm-100',
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
          <div className="flex items-center justify-between pt-3 border-t border-warm-100">
            <div className="flex items-center gap-1 flex-wrap">
              {/* Interest / Contact */}
              {!isOwn && post.user_id !== currentUserId && (
                <button
                  onClick={() => {
                    if (!currentUserId) { toast.error('Bitte zuerst anmelden', { id: 'auth-required' }); return }
                    setShowContactModal(true)
                  }}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-medium bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-200 transition-all active:scale-95 shadow-sm"
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
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-medium bg-violet-50 text-violet-700 hover:bg-violet-100 border border-violet-200 transition-all"
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
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-medium bg-green-50 text-green-700 hover:bg-green-100 transition-all"
                >
                  <MessageCircle className="w-3.5 h-3.5" /> WhatsApp
                </a>
              )}

              {/* Phone */}
              {canShowPhone && (
                <a
                  href={`tel:${cleanPhone(post.contact_phone!)}`}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-medium bg-blue-50 text-blue-700 hover:bg-blue-100 transition-all"
                >
                  <Phone className="w-3.5 h-3.5" /> Anrufen
                </a>
              )}
            </div>

            <div className="flex items-center gap-1">
              {/* Vote buttons */}
              <div className="flex items-center gap-0.5 mr-1">
                <button
                  onClick={() => handleVote(1)}
                  title="Hilfreich"
                  className={cn(
                    'p-1 rounded-lg transition-all',
                    myVote === 1 ? 'text-green-600 bg-green-50' : 'text-ink-400 hover:bg-warm-100 hover:text-green-600',
                  )}
                >
                  <ThumbsUp className="w-3.5 h-3.5" />
                </button>
                <span className={cn(
                  'text-xs font-semibold min-w-[18px] text-center tabular-nums',
                  voteScore > 0 ? 'text-green-600' : voteScore < 0 ? 'text-red-500' : 'text-ink-400',
                )}>
                  {voteScore}
                </span>
                <button
                  onClick={() => handleVote(-1)}
                  title="Nicht hilfreich"
                  className={cn(
                    'p-1 rounded-lg transition-all',
                    myVote === -1 ? 'text-red-500 bg-red-50' : 'text-ink-400 hover:bg-warm-100 hover:text-red-500',
                  )}
                >
                  <ThumbsDown className="w-3.5 h-3.5" />
                </button>
              </div>

              {/* Comment count */}
              {detailLink && (
                <Link
                  href={href}
                  className="flex items-center gap-1 p-1.5 rounded-lg hover:bg-warm-100 transition-colors text-ink-400 hover:text-primary-600"
                  title={`${commentCount} Kommentare`}
                >
                  <MessageSquare className="w-3.5 h-3.5" />
                  {commentCount > 0 && <span className="text-xs font-medium">{commentCount}</span>}
                </Link>
              )}

              {/* Bookmark */}
              <button
                onClick={handleSave}
                disabled={savingLoading}
                className="p-1.5 rounded-lg hover:bg-warm-100 transition-colors"
                title={isSaved ? 'Gespeichert' : 'Speichern'}
              >
                {isSaved
                  ? <BookmarkCheck className="w-4 h-4 text-primary-600" />
                  : <Bookmark className="w-4 h-4 text-ink-400" />
                }
              </button>

              {/* Thank-you (not on own posts, not on anonymous authors) */}
              {!isOwn && !isAnonymous && (
                <ThankYouButton
                  currentUserId={currentUserId}
                  toUserId={post.user_id}
                  postId={post.id}
                />
              )}

              {/* Report */}
              {currentUserId && currentUserId !== post.user_id && (
                <ReportButton contentType="post" contentId={post.id} compact />
              )}

              {/* Detail link */}
              {detailLink && (
                <Link href={href} className="p-1.5 rounded-lg hover:bg-warm-100 transition-colors" title="Details">
                  <ExternalLink className="w-4 h-4 text-ink-400" />
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
          currentStatus={localStatus}
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

  const onErr = (e: React.SyntheticEvent<HTMLImageElement>) => {
    e.currentTarget.style.display = 'none'
  }

  if (count === 1) {
    return (
      <Wrapper {...(wrapperProps as any)} className="block mb-3 overflow-hidden rounded-lg bg-warm-50">
        <img src={thumbUrl(urls[0])} alt="" className="w-full h-40 object-cover" loading="lazy" onError={onErr} />
      </Wrapper>
    )
  }

  if (count === 2) {
    return (
      <Wrapper {...(wrapperProps as any)} className="grid grid-cols-2 gap-1 mb-3 overflow-hidden rounded-lg">
        {urls.slice(0, 2).map((u, i) => (
          <img key={i} src={thumbUrl(u)} alt="" className="w-full h-32 object-cover bg-warm-50" loading="lazy" onError={onErr} />
        ))}
      </Wrapper>
    )
  }

  if (count === 3) {
    return (
      <Wrapper {...(wrapperProps as any)} className="grid grid-cols-3 gap-1 mb-3 overflow-hidden rounded-lg">
        <img src={thumbUrl(urls[0])} alt="" className="col-span-2 w-full h-32 object-cover bg-warm-50" loading="lazy" onError={onErr} />
        <div className="flex flex-col gap-1">
          {urls.slice(1, 3).map((u, i) => (
            <img key={i} src={thumbUrl(u)} alt="" className="w-full h-[calc(50%-2px)] object-cover bg-warm-50" loading="lazy" onError={onErr} />
          ))}
        </div>
      </Wrapper>
    )
  }

  // 4+
  return (
    <Wrapper {...(wrapperProps as any)} className="grid grid-cols-2 gap-1 mb-3 overflow-hidden rounded-lg relative">
      {urls.slice(0, 4).map((u, i) => (
        <img key={i} src={thumbUrl(u)} alt="" className="w-full h-24 object-cover bg-warm-50" loading="lazy" onError={onErr} />
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
    if (!currentUserId) { toast.error('Bitte zuerst anmelden', { id: 'auth-required' }); return }
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
            <p className="font-bold text-ink-900">Interesse zeigen</p>
            <p className="text-xs text-ink-500 mt-0.5 line-clamp-1">an: {postTitle}</p>
          </div>
          <button onClick={onClose} className="text-ink-400 hover:text-ink-600 text-lg leading-none">{'✕'}</button>
        </div>
        <div className="space-y-2">
          <textarea
            value={msg}
            onChange={e => setMsg(e.target.value.slice(0, maxLen))}
            placeholder="Kurze Nachricht (optional)..."
            rows={3}
            className="input resize-none text-sm w-full"
          />
          <p className="text-right text-xs text-ink-400">{msg.length}/{maxLen}</p>
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
function ContextMenu({ x, y, isOwn, currentStatus, onAction }: {
  x: number; y: number; isOwn: boolean; currentStatus?: string
  onAction: (action: string) => void
}) {
  const menuRef = useRef<HTMLDivElement>(null)

  // Adjust position to keep menu in viewport
  const style: React.CSSProperties = {
    position: 'fixed',
    left: Math.min(x, typeof window !== 'undefined' ? window.innerWidth - 200 : x),
    top: Math.min(y, typeof window !== 'undefined' ? window.innerHeight - 340 : y),
    zIndex: 60,
  }

  const items = [
    { key: 'save',   label: '💾 Speichern' },
    { key: 'share',  label: '📤 Teilen' },
    { key: 'report', label: '🚩 Melden' },
    { key: 'copy',   label: '🔗 Link kopieren' },
  ]

  const ownItems: { key: string; label: string }[] = [
    { key: 'edit', label: '✏️ Bearbeiten' },
  ]
  if (currentStatus !== 'resolved') {
    ownItems.push({ key: 'done', label: '✅ Als erledigt markieren' })
  }
  if (currentStatus === 'resolved' || currentStatus === 'archived') {
    ownItems.push({ key: 'activate', label: '🟢 Wieder aktivieren' })
  }
  if (currentStatus === 'active') {
    ownItems.push({ key: 'archive', label: '📦 Archivieren' })
  }
  ownItems.push({ key: 'delete', label: '🗑️ Löschen' })

  return (
    <div ref={menuRef} style={style} className="bg-white rounded-xl shadow-xl border border-stone-200 py-1 min-w-[180px]" onClick={e => e.stopPropagation()}>
      {items.map(item => (
        <button key={item.key} onClick={() => onAction(item.key)} className="w-full text-left px-4 py-2 text-sm hover:bg-warm-50 transition-colors">
          {item.label}
        </button>
      ))}
      {isOwn && (
        <>
          <div className="border-t border-stone-100 my-1" />
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
