'use client'

import { useEffect, useState, useCallback, useRef } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  ArrowLeft, MapPin, Clock, Phone, MessageCircle, MessageSquare,
  User, Send, Users, ChevronLeft, ChevronRight, X, MoreHorizontal,
  Bookmark, BookmarkCheck, Share2, Flag, Trash2, CheckCircle, XCircle,
  Loader2, Calendar, RefreshCw, ExternalLink, Mail, Copy, ArrowRight,
  Edit3, Reply, ThumbsUp, ThumbsDown, CornerDownRight,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { openOrCreateDM } from '@/lib/chat-utils'
import toast from 'react-hot-toast'
import { cn, formatRelativeTime, cleanPhone, truncateText } from '@/lib/utils'
import { getTypeConfig, type PostCardPost } from '@/lib/post-types'
import { handleSupabaseError } from '@/lib/errors'
import { useStore } from '@/store/useStore'
import PostCard from '@/components/shared/PostCard'
import { MobileImageViewer } from '@/components/mobile'
import TrustScoreBadge from '@/app/ratings/components/TrustScoreBadge'
import CompleteInteractionButton from '@/app/ratings/components/CompleteInteractionButton'
import RatingModal from '@/app/ratings/components/RatingModal'

// ── Types ─────────────────────────────────────────────────────────────────────
interface Post {
  id: string; type: string; category?: string; title: string; description?: string
  location_text?: string; lat?: number; lng?: number
  contact_phone?: string; contact_whatsapp?: string; contact_email?: string
  urgency?: number | string; created_at: string; user_id: string
  status?: string; media_urls?: string[]; tags?: string[]
  is_anonymous?: boolean; is_recurring?: boolean; recurring_interval?: string
  availability_days?: string[]; availability_start?: string; availability_end?: string
  privacy_phone?: boolean; privacy_email?: boolean
  profiles?: {
    name?: string; avatar_url?: string; bio?: string; trust_score?: number
    verified_email?: boolean; verified_phone?: boolean; verified_community?: boolean
    privacy_phone?: boolean; privacy_email?: boolean
  }
}

interface Interaction {
  id: string; helper_id: string; status: string; message?: string
  reason?: string; created_at: string
  profiles?: { name?: string; avatar_url?: string; trust_score?: number }
}

type ReactionType = 'heart' | 'thanks' | 'support' | 'compassion'
const REACTIONS: { type: ReactionType; emoji: string; label: string }[] = [
  { type: 'heart',      emoji: '❤️', label: 'Herz' },
  { type: 'thanks',     emoji: '🙏', label: 'Danke' },
  { type: 'support',    emoji: '💪',  label: 'Unterstuetzung' },
  { type: 'compassion', emoji: '🤗',  label: 'Mitgefühl' },
]

const REPORT_REASONS = [
  'Spam', 'Beleidigung', 'Betrug', 'Falsche Angaben', 'Gefaehrdung', 'Sonstiges',
]

const DECLINE_REASONS = [
  'Bereits vergeben', 'Passt leider nicht', 'Andere Loesung gefunden',
]

const QUICK_MESSAGES = [
  'Ich kann helfen!',
  'Wann wird die Hilfe benoetigt?',
  'Ich habe Erfahrung damit',
  'Kann ich mehr Details erfahren?',
]

const WEEKDAYS_DE = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag']
const WEEKDAYS_SHORT = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa']

// ── Helpers ───────────────────────────────────────────────────────────────────
function haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

function computeAvailability(days?: string[], start?: string, end?: string) {
  if (!days || days.length === 0) return null
  const now = new Date()
  const todayName = WEEKDAYS_DE[now.getDay()]
  const time = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
  const isToday = days.includes(todayName) || days.includes(WEEKDAYS_SHORT[now.getDay()])
  if (isToday && (!start || time >= start) && (!end || time <= end)) {
    return { available: true, label: 'Jetzt verfügbar' }
  }
  for (let i = 1; i <= 7; i++) {
    const idx = (now.getDay() + i) % 7
    if (days.includes(WEEKDAYS_DE[idx]) || days.includes(WEEKDAYS_SHORT[idx])) {
      return { available: false, label: `Nächste Verfügbarkeit: ${WEEKDAYS_SHORT[idx]} ${start ?? ''}`.trim() }
    }
  }
  return null
}

function recurringLabel(interval?: string): string {
  const map: Record<string, string> = {
    daily: 'Taeglich', weekly: 'Woechentlich', biweekly: 'Alle 2 Wochen', monthly: 'Monatlich',
  }
  return map[interval ?? ''] ?? interval ?? 'Wiederkehrend'
}

// ── Trust Score SVG ───────────────────────────────────────────────────────────
function TrustCircle({ score, size = 44 }: { score: number; size?: number }) {
  const r = (size - 6) / 2
  const c = 2 * Math.PI * r
  const pct = Math.min(Math.max(score / 100, 0), 1)
  const strokeColor = pct > 0.6 ? '#22c55e' : pct > 0.3 ? '#eab308' : '#ef4444'
  return (
    <svg width={size} height={size} className="flex-shrink-0">
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#e5e7eb" strokeWidth={3} />
      <circle
        cx={size / 2} cy={size / 2} r={r} fill="none"
        stroke={strokeColor}
        strokeWidth={3}
        strokeDasharray={`${c * pct} ${c * (1 - pct)}`}
        strokeLinecap="round"
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      <text x={size / 2} y={size / 2 + 4} textAnchor="middle" fontSize={12} fontWeight={600} fill="#374151">
        {score}
      </text>
    </svg>
  )
}

// ── Main Component ────────────────────────────────────────────────────────────
export default function PostDetailPage() {
  const { id } = useParams<{ id: string }>()
  const router = useRouter()
  const store = useStore()
  const interactionsSectionRef = useRef<HTMLDivElement>(null)

  // ── State ───────────────────────────────────────────────────────────────────
  const [post, setPost] = useState<Post | null>(null)
  const [interactions, setInteractions] = useState<Interaction[]>([])
  const [similarPosts, setSimilarPosts] = useState<PostCardPost[]>([])
  const [similarLabel, setSimilarLabel] = useState('Ähnliche Beiträge in deiner Nähe')
  const [isSaved, setIsSaved] = useState(false)
  const [reactions, setReactions] = useState<Record<ReactionType, number>>({
    heart: 0, thanks: 0, support: 0, compassion: 0,
  })
  const [myReaction, setMyReaction] = useState<ReactionType | null>(null)
  const [isOwner, setIsOwner] = useState(false)
  const [currentUserId, setCurrentUserId] = useState<string | null>(null)
  const [showContactModal, setShowContactModal] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [showShareMenu, setShowShareMenu] = useState(false)
  const [showReportModal, setShowReportModal] = useState(false)
  const [lightboxOpen, setLightboxOpen] = useState(false)
  const [lightboxIndex, setLightboxIndex] = useState(0)
  const [loading, setLoading] = useState(true)
  const [showMoreMenu, setShowMoreMenu] = useState(false)
  const [descExpanded, setDescExpanded] = useState(false)
  const [dmLoading, setDmLoading] = useState(false)
  const [savedIds, setSavedIds] = useState<string[]>([])
  const [voteScore, setVoteScore] = useState(0)
  const [myVote, setMyVote] = useState<1 | -1 | 0>(0)
  const [upvotes, setUpvotes] = useState(0)
  const [downvotes, setDownvotes] = useState(0)
  const [shareCount, setShareCount] = useState(0)

  // ── Load data ───────────────────────────────────────────────────────────────
  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    const uid = user?.id ?? null
    setCurrentUserId(uid)

    // Load post with profile fields
    const { data: postData, error: postErr } = await supabase
      .from('posts')
      .select('*, profiles(name, avatar_url, bio, trust_score, verified_email, verified_phone, verified_community, privacy_phone, privacy_email)')
      .eq('id', id)
      .single()

    if (postErr || !postData) {
      router.replace('/dashboard/posts')
      return
    }
    setPost(postData as Post)
    setIsOwner(uid === postData.user_id)

    // Parallel loads: interactions, reactions, saved status
    const [interactRes, reactRes, savedRes] = await Promise.all([
      supabase
        .from('interactions')
        .select('*, profiles(name, avatar_url, trust_score)')
        .eq('post_id', id)
        .order('created_at', { ascending: false }),
      supabase
        .from('post_reactions')
        .select('reaction_type, user_id')
        .eq('post_id', id),
      uid
        ? supabase.from('saved_posts').select('id').eq('user_id', uid).eq('post_id', id).maybeSingle()
        : null,
    ])

    // Interactions - sort: pending first, then accepted, then declined
    if (!handleSupabaseError(interactRes.error)) {
      const ints = (interactRes.data ?? []) as Interaction[]
      const order: Record<string, number> = { pending: 0, interested: 0, accepted: 1, declined: 2 }
      ints.sort((a, b) => (order[a.status] ?? 3) - (order[b.status] ?? 3))
      setInteractions(ints)
    }

    // Reactions
    if (!handleSupabaseError(reactRes.error)) {
      const counts: Record<ReactionType, number> = { heart: 0, thanks: 0, support: 0, compassion: 0 }
      for (const r of (reactRes.data ?? [])) {
        const t = r.reaction_type as ReactionType
        if (t in counts) counts[t]++
        if (uid && r.user_id === uid) setMyReaction(t)
      }
      setReactions(counts)
    }

    // Saved status
    setIsSaved(!!savedRes?.data)
    if (uid) {
      const { data: allSaved } = await supabase.from('saved_posts').select('post_id').eq('user_id', uid)
      setSavedIds((allSaved ?? []).map((s: any) => s.post_id))
    }

    // Votes
    const { data: votesData } = await supabase
      .from('post_votes')
      .select('vote, user_id')
      .eq('post_id', id)
    if (votesData) {
      let score = 0; let ups = 0; let downs = 0
      for (const v of votesData) {
        score += v.vote
        if (v.vote === 1) ups++; else downs++
        if (uid && v.user_id === uid) setMyVote(v.vote as 1 | -1)
      }
      setVoteScore(score); setUpvotes(ups); setDownvotes(downs)
    }

    // Share count
    const { count: shareCountVal } = await supabase
      .from('post_shares')
      .select('id', { count: 'exact', head: true })
      .eq('post_id', id)
    if (shareCountVal != null) setShareCount(shareCountVal)

    // Similar posts (same type, distance < 10 km)
    const { data: similar } = await supabase
      .from('posts')
      .select('id, title, type, urgency, location_text, lat, lng, created_at, media_urls, user_id, tags, description, is_anonymous, profiles(name, avatar_url)')
      .eq('status', 'active')
      .eq('type', postData.type)
      .neq('id', id)
      .order('created_at', { ascending: false })
      .limit(10)

    let simPosts = (similar ?? []) as PostCardPost[]

    // Filter by distance if geo data available
    if (simPosts.length > 0 && postData.lat && postData.lng) {
      simPosts = simPosts
        .map(p => ({
          ...p,
          _dist: (p.lat && p.lng) ? haversine(postData.lat!, postData.lng!, p.lat!, p.lng!) : 9999,
        }))
        .sort((a: any, b: any) => a._dist - b._dist)
        .filter((p: any) => p._dist < 10 || simPosts.length <= 3)
    }

    if (simPosts.length > 0) {
      setSimilarPosts(simPosts.slice(0, 3))
      setSimilarLabel('Ähnliche Beiträge in deiner Nähe')
    } else {
      // Fallback: latest 3 posts
      const { data: recent } = await supabase
        .from('posts')
        .select('id, title, type, urgency, location_text, lat, lng, created_at, media_urls, user_id, tags, description, is_anonymous, profiles(name, avatar_url)')
        .eq('status', 'active')
        .neq('id', id)
        .order('created_at', { ascending: false })
        .limit(3)
      setSimilarPosts((recent ?? []) as PostCardPost[])
      setSimilarLabel('Neueste Beiträge')
    }

    setLoading(false)
  }, [id, router])

  useEffect(() => { loadData() }, [loadData])

  // ── Close menus on outside click ────────────────────────────────────────────
  useEffect(() => {
    if (!showMoreMenu && !showShareMenu) return
    const handler = () => { setShowMoreMenu(false); setShowShareMenu(false) }
    window.addEventListener('click', handler)
    return () => window.removeEventListener('click', handler)
  }, [showMoreMenu, showShareMenu])

  // ── Loading ─────────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
      </div>
    )
  }
  if (!post) return null

  // ── Derived values ─────────────────────────────────────────────────────────
  const cfg = getTypeConfig(post.type)
  const urgency = typeof post.urgency === 'string' ? parseInt(post.urgency, 10) || 0 : (post.urgency ?? 0)
  const isAnonymous = post.is_anonymous === true
  const mediaUrls = post.media_urls?.filter(Boolean) ?? []
  const pageUrl = typeof window !== 'undefined' ? `${window.location.origin}/dashboard/posts/${post.id}` : ''
  const totalReactions = Object.values(reactions).reduce((s, v) => s + v, 0)
  const pendingCount = interactions.filter(i => i.status === 'pending' || i.status === 'interested').length
  const availability = computeAvailability(post.availability_days, post.availability_start, post.availability_end)

  // Privacy checks
  const canShowPhone = !isAnonymous && !!post.contact_phone &&
    post.profiles?.privacy_phone !== false && post.privacy_phone !== false
  const canShowEmail = !isAnonymous && !!post.contact_email &&
    post.profiles?.privacy_email !== false && post.privacy_email !== false
  const canShowWhatsApp = !isAnonymous && !!post.contact_whatsapp &&
    post.profiles?.privacy_phone !== false && post.privacy_phone !== false

  // ── Handlers ────────────────────────────────────────────────────────────────
  const handleSave = async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    const supabase = createClient()
    if (isSaved) {
      const { error } = await supabase.from('saved_posts').delete().eq('user_id', currentUserId).eq('post_id', id)
      if (!handleSupabaseError(error)) {
        setIsSaved(false)
        toast.success('Beitrag entfernt')
      }
    } else {
      const { error } = await supabase.from('saved_posts').insert({ user_id: currentUserId, post_id: id })
      if (!handleSupabaseError(error)) {
        setIsSaved(true)
        toast.success('Beitrag gespeichert')
      }
    }
  }

  const handleReaction = async (type: ReactionType) => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    const supabase = createClient()
    const prev = myReaction

    if (prev === type) {
      // Remove reaction (optimistic)
      setMyReaction(null)
      setReactions(r => ({ ...r, [type]: Math.max(0, r[type] - 1) }))
      const { error } = await supabase.from('post_reactions').delete()
        .eq('post_id', post.id).eq('user_id', currentUserId)
      if (handleSupabaseError(error)) {
        setMyReaction(prev)
        setReactions(r => ({ ...r, [type]: r[type] + 1 }))
      }
    } else {
      // Add or change reaction (optimistic)
      setMyReaction(type)
      setReactions(r => {
        const n = { ...r, [type]: r[type] + 1 }
        if (prev) n[prev] = Math.max(0, n[prev] - 1)
        return n
      })
      const { error } = await supabase.from('post_reactions').upsert(
        { post_id: post.id, user_id: currentUserId, reaction_type: type },
        { onConflict: 'post_id,user_id' },
      )
      if (handleSupabaseError(error)) {
        setMyReaction(prev)
        setReactions(r => {
          const n = { ...r, [type]: Math.max(0, r[type] - 1) }
          if (prev) n[prev] = n[prev] + 1
          return n
        })
      }
    }
  }

  const handleVote = async (vote: 1 | -1) => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    const supabase = createClient()
    const prevVote = myVote
    const prevScore = voteScore
    const prevUp = upvotes
    const prevDown = downvotes

    if (myVote === vote) {
      // Remove vote
      setMyVote(0)
      setVoteScore(s => s - vote)
      if (vote === 1) setUpvotes(u => u - 1); else setDownvotes(d => d - 1)
      const { error } = await supabase.from('post_votes').delete()
        .eq('post_id', id).eq('user_id', currentUserId)
      if (error) { setMyVote(prevVote); setVoteScore(prevScore); setUpvotes(prevUp); setDownvotes(prevDown) }
    } else {
      // Add or change vote
      setMyVote(vote)
      setVoteScore(s => s - prevVote + vote)
      if (vote === 1) { setUpvotes(u => u + 1); if (prevVote === -1) setDownvotes(d => d - 1) }
      else { setDownvotes(d => d + 1); if (prevVote === 1) setUpvotes(u => u - 1) }
      const { error } = await supabase.from('post_votes').upsert(
        { post_id: id, user_id: currentUserId, vote },
        { onConflict: 'post_id,user_id' },
      )
      if (error) { setMyVote(prevVote); setVoteScore(prevScore); setUpvotes(prevUp); setDownvotes(prevDown) }
    }
  }

  const handleDM = async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    if (isOwner || isAnonymous) return
    setDmLoading(true)
    try {
      const convId = await openOrCreateDM(currentUserId, post.user_id, post.id)
      if (convId) router.push(`/dashboard/chat?conv=${convId}`)
      else toast.error('Konversation konnte nicht gestartet werden')
    } finally {
      setDmLoading(false)
    }
  }

  const handleDelete = async () => {
    const supabase = createClient()
    // Delete stored images
    if (mediaUrls.length > 0) {
      const paths = mediaUrls.map(u => {
        try { return new URL(u).pathname.split('/').pop() ?? '' } catch { return '' }
      }).filter(Boolean)
      if (paths.length > 0) {
        await supabase.storage.from('post-images').remove(paths)
      }
    }
    const { error } = await supabase.from('posts').delete().eq('id', post.id)
    if (!handleSupabaseError(error)) {
      toast.success('Beitrag gelöscht')
      router.push('/dashboard/posts')
    }
    setShowDeleteConfirm(false)
  }

  const handleMarkDone = async () => {
    const supabase = createClient()
    const { error } = await supabase.from('posts').update({ status: 'resolved' }).eq('id', post.id)
    if (!handleSupabaseError(error)) toast.success('Als erledigt markiert')
    setShowMoreMenu(false)
  }

  const handleInteractionStatus = async (
    intId: string,
    status: 'accepted' | 'declined',
    reason?: string,
  ) => {
    const supabase = createClient()
    const update: Record<string, string> = { status }
    if (reason) update.reason = reason
    const { error } = await supabase.from('interactions').update(update).eq('id', intId)
    if (!handleSupabaseError(error)) {
      if (status === 'accepted') {
        toast.success('Helfer angenommen!')
        // Create DM conversation with the helper
        const int = interactions.find(i => i.id === intId)
        if (int && currentUserId) {
          openOrCreateDM(currentUserId, int.helper_id, post.id)
        }
      } else {
        toast.success('Abgelehnt')
      }
      loadData()
    }
  }

  // ── Render ──────────────────────────────────────────────────────────────────
  return (
    <div className="max-w-3xl mx-auto space-y-5 animate-fade-in pb-12">

      {/* ── Back + Breadcrumb ──────────────────────────────────────── */}
      <nav className="flex items-center gap-2 text-sm flex-wrap">
        <Link
          href="/dashboard/posts"
          className="flex items-center gap-1.5 text-gray-500 hover:text-gray-800 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" /> Zurück
        </Link>
        <span className="text-gray-300">/</span>
        <Link href="/dashboard/posts" className="text-gray-400 hover:text-gray-600 transition-colors">
          Beiträge
        </Link>
        <span className="text-gray-300">&gt;</span>
        <span className="text-gray-400">{cfg.label}</span>
        <span className="text-gray-300">&gt;</span>
        <span className="text-gray-600 truncate max-w-[180px]">{truncateText(post.title, 35)}</span>
      </nav>

      {/* ── Header Card ────────────────────────────────────────────── */}
      <div className={cn(
        'bg-white rounded-2xl shadow-sm relative overflow-hidden',
        urgency >= 3 && 'border-l-4 border-red-500',
      )}>
        {/* Urgency 3 red banner */}
        {urgency >= 3 && (
          <div className="flex items-center gap-1.5 px-5 py-2 bg-red-500 text-white text-sm font-bold animate-pulse">
            <span>&#x1F6A8;</span> Dringend
          </div>
        )}

        <div className="p-6">
          {/* Type badge + more menu */}
          <div className="flex items-start justify-between gap-3 mb-4">
            <span className={cn(
              'inline-flex items-center gap-1.5 text-sm font-semibold px-3 py-1 rounded-full border',
              cfg.bg, cfg.color,
            )}>
              <span>{cfg.emoji}</span> {cfg.label}
            </span>

            {/* More menu */}
            <div className="relative">
              <button
                onClick={e => { e.stopPropagation(); setShowMoreMenu(!showMoreMenu) }}
                className="p-2 rounded-lg hover:bg-warm-100 transition-colors"
                aria-label="Optionen"
              >
                <MoreHorizontal className="w-5 h-5 text-gray-500" />
              </button>
              {showMoreMenu && (
                <div
                  className="absolute right-0 top-10 bg-white rounded-xl shadow-xl border border-gray-200 py-1 min-w-[200px] z-30"
                  onClick={e => e.stopPropagation()}
                >
                  <button
                    onClick={() => { handleSave(); setShowMoreMenu(false) }}
                    className="w-full text-left px-4 py-2.5 text-sm hover:bg-warm-50 transition-colors flex items-center gap-2"
                  >
                    {isSaved ? <BookmarkCheck className="w-4 h-4" /> : <Bookmark className="w-4 h-4" />}
                    {isSaved ? 'Gespeichert' : 'Speichern'}
                  </button>
                  <button
                    onClick={() => { setShowShareMenu(true); setShowMoreMenu(false) }}
                    className="w-full text-left px-4 py-2.5 text-sm hover:bg-warm-50 transition-colors flex items-center gap-2"
                  >
                    <Share2 className="w-4 h-4" /> Teilen
                  </button>
                  {!isOwner && (
                    <button
                      onClick={() => { setShowReportModal(true); setShowMoreMenu(false) }}
                      className="w-full text-left px-4 py-2.5 text-sm hover:bg-warm-50 transition-colors flex items-center gap-2"
                    >
                      <Flag className="w-4 h-4" /> Melden
                    </button>
                  )}
                  {isOwner && (
                    <>
                      <div className="border-t border-gray-100 my-1" />
                      <button
                        onClick={() => { router.push(`/dashboard/posts/${post.id}?edit=1`); setShowMoreMenu(false) }}
                        className="w-full text-left px-4 py-2.5 text-sm hover:bg-warm-50 transition-colors flex items-center gap-2"
                      >
                        <Edit3 className="w-4 h-4" /> Bearbeiten
                      </button>
                      <button
                        onClick={handleMarkDone}
                        className="w-full text-left px-4 py-2.5 text-sm hover:bg-warm-50 transition-colors flex items-center gap-2"
                      >
                        <CheckCircle className="w-4 h-4" /> Als erledigt markieren
                      </button>
                      <button
                        onClick={() => { setShowDeleteConfirm(true); setShowMoreMenu(false) }}
                        className="w-full text-left px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors flex items-center gap-2"
                      >
                        <Trash2 className="w-4 h-4" /> Löschen
                      </button>
                    </>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Title + urgency badge */}
          <div className="flex items-start gap-3 mb-3">
            <h1 className="text-2xl font-bold text-gray-900 flex-1 leading-tight">{post.title}</h1>
            {urgency >= 3 && (
              <span className="inline-flex items-center gap-1 px-3 py-1 bg-red-500 text-white text-xs font-bold rounded-full animate-pulse flex-shrink-0">
                &#x1F6A8; Dringend
              </span>
            )}
          </div>

          {/* Badges row: recurring, availability */}
          <div className="flex flex-wrap items-center gap-2 mb-3">
            {post.is_recurring && (
              <span className="inline-flex items-center gap-1 text-xs font-medium px-2.5 py-1 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                <RefreshCw className="w-3 h-3" /> {recurringLabel(post.recurring_interval)}
              </span>
            )}
            {availability && (
              <span className={cn(
                'inline-flex items-center gap-1 text-xs font-medium px-2.5 py-1 rounded-full',
                availability.available ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600',
              )}>
                <Calendar className="w-3 h-3" />
                {availability.label}
              </span>
            )}
            {post.availability_days && post.availability_days.length > 0 && (
              <span className="inline-flex items-center gap-1 text-xs text-gray-500">
                <Calendar className="w-3 h-3" />
                Verfügbar: {post.availability_days.join(', ')}
                {post.availability_start && post.availability_end
                  ? ` ${post.availability_start}–${post.availability_end}`
                  : ''}
              </span>
            )}
          </div>

          {/* Meta line: location, time, urgency 2 dot, owner interest badge */}
          <div className="flex flex-wrap items-center gap-3 text-sm text-gray-500">
            {post.location_text && (
              <span className="flex items-center gap-1">
                <MapPin className="w-3.5 h-3.5" /> {post.location_text}
              </span>
            )}
            <span className="flex items-center gap-1">
              <Clock className="w-3.5 h-3.5" /> {formatRelativeTime(post.created_at)}
              {/* Urgency 2 yellow dot */}
              {urgency === 2 && (
                <span className="inline-block w-2 h-2 rounded-full bg-yellow-400 ml-1" />
              )}
            </span>
            {isOwner && pendingCount > 0 && (
              <button
                onClick={() => interactionsSectionRef.current?.scrollIntoView({ behavior: 'smooth' })}
                className="flex items-center gap-1 bg-orange-100 text-orange-700 px-2.5 py-0.5 rounded-full text-xs font-medium hover:bg-orange-200 transition-colors"
              >
                <Users className="w-3 h-3" /> {pendingCount} Interessenten
              </button>
            )}
          </div>
        </div>
      </div>

      {/* ── Image Gallery ──────────────────────────────────────────── */}
      {mediaUrls.length > 0 && (
        <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
          <ImageGallery
            urls={mediaUrls}
            onOpen={(idx) => { setLightboxIndex(idx); setLightboxOpen(true) }}
          />
        </div>
      )}

      {/* ── Description ────────────────────────────────────────────── */}
      {post.description && (
        <div className="bg-white rounded-2xl shadow-sm p-6">
          <div className="text-gray-700 leading-relaxed whitespace-pre-wrap">
            {!descExpanded && post.description.length > 500
              ? truncateText(post.description, 500)
              : post.description}
          </div>
          {post.description.length > 500 && (
            <button
              onClick={() => setDescExpanded(!descExpanded)}
              className="mt-2 text-sm text-primary-600 hover:text-primary-700 font-medium"
            >
              {descExpanded ? 'Weniger anzeigen' : 'Mehr anzeigen'}
            </button>
          )}
        </div>
      )}

      {/* ── Tag Chips ──────────────────────────────────────────────── */}
      {post.tags && post.tags.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {post.tags.map(tag => (
            <span key={tag} className="bg-gray-100 text-gray-700 rounded-full px-3 py-1 text-sm font-medium">
              #{tag}
            </span>
          ))}
        </div>
      )}

      {/* ── Quick Reactions ────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-6">
        <div className="flex items-center gap-2 mb-3 flex-wrap">
          {REACTIONS.map(r => {
            const isActive = myReaction === r.type
            const count = reactions[r.type]
            return (
              <button
                key={r.type}
                onClick={() => handleReaction(r.type)}
                title={r.label}
                className={cn(
                  'flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-medium transition-all',
                  isActive
                    ? 'bg-primary-100 text-primary-800 ring-2 ring-primary-300 scale-105'
                    : 'bg-warm-50 text-gray-600 hover:bg-warm-100',
                )}
              >
                <span className="text-lg">{r.emoji}</span>
                {count > 0 && <span>{count}</span>}
              </button>
            )
          })}
        </div>
        <p className="text-xs text-gray-400">{totalReactions} Reaktionen insgesamt</p>

        {/* Vote buttons */}
        <div className="flex items-center gap-4 mt-4 pt-4 border-t border-warm-100">
          <span className="text-sm font-medium text-gray-700">Hilfreich?</span>
          <div className="flex items-center gap-2">
            <button
              onClick={() => handleVote(1)}
              className={cn(
                'flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all',
                myVote === 1
                  ? 'bg-green-100 text-green-700 ring-1 ring-green-300'
                  : 'bg-warm-50 text-gray-500 hover:bg-green-50 hover:text-green-600',
              )}
            >
              <ThumbsUp className="w-4 h-4" />
              {upvotes > 0 && <span>{upvotes}</span>}
            </button>
            <button
              onClick={() => handleVote(-1)}
              className={cn(
                'flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all',
                myVote === -1
                  ? 'bg-red-100 text-red-600 ring-1 ring-red-300'
                  : 'bg-warm-50 text-gray-500 hover:bg-red-50 hover:text-red-500',
              )}
            >
              <ThumbsDown className="w-4 h-4" />
              {downvotes > 0 && <span>{downvotes}</span>}
            </button>
          </div>
          <span className={cn(
            'text-sm font-bold',
            voteScore > 0 ? 'text-green-600' : voteScore < 0 ? 'text-red-500' : 'text-gray-400',
          )}>
            {voteScore > 0 ? '+' : ''}{voteScore} Punkte
          </span>
        </div>
      </div>

      {/* ── Author Info Card ───────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-6">
        <div className="flex items-center gap-4">
          {/* Avatar */}
          <div className={cn(
            'w-16 h-16 rounded-full flex items-center justify-center overflow-hidden flex-shrink-0',
            isAnonymous ? 'bg-gray-200' : 'bg-primary-100',
          )}>
            {isAnonymous
              ? <span className="text-gray-500 text-2xl font-bold">?</span>
              : post.profiles?.avatar_url
                ? <img src={post.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                : <User className="w-8 h-8 text-primary-600" />
            }
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1 flex-wrap">
              <p className="font-bold text-gray-900 text-lg">
                {isAnonymous ? 'Anonymer Nutzer' : (post.profiles?.name ?? 'Nutzer')}
              </p>
              {/* Verification badges */}
              {!isAnonymous && post.profiles && (
                <>
                  {post.profiles.verified_email && (
                    <span title="E-Mail verifiziert" className="cursor-help">&#x2709;&#xFE0F;</span>
                  )}
                  {post.profiles.verified_phone && (
                    <span title="Telefon verifiziert" className="cursor-help">&#x1F4F1;</span>
                  )}
                  {post.profiles.verified_community && (
                    <span title="Community verifiziert" className="cursor-help">&#x1F91D;</span>
                  )}
                </>
              )}
            </div>
            {/* Short bio (100 chars) */}
            {!isAnonymous && post.profiles?.bio && (
              <p className="text-sm text-gray-500">{truncateText(post.profiles.bio, 100)}</p>
            )}
            {/* Profile link */}
            {!isAnonymous && (
              <Link
                href={`/dashboard/profile/${post.user_id}`}
                className="text-sm text-primary-600 hover:text-primary-700 font-medium mt-1 inline-block"
              >
                Profil anzeigen
              </Link>
            )}
          </div>
          {/* Trust score badge */}
          {!isAnonymous && post.profiles?.trust_score != null && post.profiles.trust_score > 0 && (
            <TrustScoreBadge score={post.profiles.trust_score} size="md" />
          )}
          {/* Owner badge */}
          {isOwner && (
            <span className="text-xs bg-primary-100 text-primary-700 px-3 py-1 rounded-full font-medium flex-shrink-0">
              Dein Beitrag
            </span>
          )}
        </div>
      </div>

      {/* ── Contact Options (non-owner only) ───────────────────────── */}
      {!isOwner && !isAnonymous && (
        <div className="bg-white rounded-2xl shadow-sm p-6 space-y-4">
          <h3 className="font-bold text-gray-900">Kontakt aufnehmen</h3>
          <div className="space-y-3">
            {/* Interest / "Interesse zeigen" */}
            <button
              onClick={() => {
                if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
                setShowContactModal(true)
              }}
              className="w-full flex items-start gap-4 p-4 border border-gray-200 rounded-xl hover:border-primary-300 hover:bg-primary-50/30 transition-colors text-left"
            >
              <div className="w-10 h-10 rounded-lg bg-primary-100 flex items-center justify-center flex-shrink-0">
                <MessageCircle className="w-5 h-5 text-primary-600" />
              </div>
              <div>
                <p className="font-semibold text-gray-900">Interesse zeigen</p>
                <p className="text-sm text-gray-500 mt-0.5">Schreibe dem Autor eine Nachricht</p>
              </div>
            </button>

            {/* Direct Message */}
            <button
              onClick={handleDM}
              disabled={dmLoading}
              className="w-full flex items-start gap-4 p-4 border border-gray-200 rounded-xl hover:border-violet-300 hover:bg-violet-50/30 transition-colors text-left"
            >
              <div className="w-10 h-10 rounded-lg bg-violet-100 flex items-center justify-center flex-shrink-0">
                {dmLoading
                  ? <Loader2 className="w-5 h-5 text-violet-600 animate-spin" />
                  : <MessageSquare className="w-5 h-5 text-violet-600" />
                }
              </div>
              <div>
                <p className="font-semibold text-gray-900">Direktnachricht senden</p>
                <p className="text-sm text-gray-500 mt-0.5">Öffnet einen privaten Chat</p>
              </div>
            </button>

            {/* WhatsApp */}
            {canShowWhatsApp && (
              <a
                href={`https://wa.me/${cleanPhone(post.contact_whatsapp!)}`}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-start gap-4 p-4 border border-green-200 rounded-xl hover:border-green-400 hover:bg-green-50/30 transition-colors"
              >
                <div className="w-10 h-10 rounded-lg bg-green-100 flex items-center justify-center flex-shrink-0">
                  <Phone className="w-5 h-5 text-green-600" />
                </div>
                <div>
                  <p className="font-semibold text-gray-900">WhatsApp</p>
                  <p className="text-sm text-gray-500 mt-0.5">
                    {post.contact_whatsapp}
                  </p>
                </div>
              </a>
            )}

            {/* Phone */}
            {canShowPhone && (
              <a
                href={`tel:${cleanPhone(post.contact_phone!)}`}
                className="w-full flex items-start gap-4 p-4 border border-gray-200 rounded-xl hover:border-blue-300 hover:bg-blue-50/30 transition-colors"
              >
                <div className="w-10 h-10 rounded-lg bg-blue-100 flex items-center justify-center flex-shrink-0">
                  <Phone className="w-5 h-5 text-blue-600" />
                </div>
                <div>
                  <p className="font-semibold text-gray-900">Anrufen</p>
                  <p className="text-sm text-gray-500 mt-0.5">{post.contact_phone}</p>
                </div>
              </a>
            )}
          </div>
        </div>
      )}

      {/* ── Interaction Management (owner only) ────────────────────── */}
      <div ref={interactionsSectionRef}>
        {isOwner && (
          <div className="bg-white rounded-2xl shadow-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900">Interessenten ({interactions.length})</h3>
              {pendingCount > 0 && (
                <span className="text-xs bg-orange-100 text-orange-700 px-2.5 py-0.5 rounded-full font-medium">
                  {pendingCount} offen
                </span>
              )}
            </div>
            {interactions.length === 0 ? (
              <div className="text-center py-8 bg-warm-50 rounded-xl border border-warm-200">
                <Users className="w-10 h-10 text-gray-300 mx-auto mb-2" />
                <p className="text-sm text-gray-500">Noch keine Meldungen</p>
                <p className="text-xs text-gray-400 mt-1">Andere Nutzer können ihr Interesse melden</p>
              </div>
            ) : (
              <div className="space-y-3">
                {interactions.map(interaction => (
                  <InteractionRow
                    key={interaction.id}
                    interaction={interaction}
                    onAccept={() => handleInteractionStatus(interaction.id, 'accepted')}
                    onDecline={(reason) => handleInteractionStatus(interaction.id, 'declined', reason)}
                  />
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Similar Posts ───────────────────────────────────────────── */}
      {similarPosts.length > 0 && (
        <div className="bg-white rounded-2xl shadow-sm p-6">
          <h3 className="font-bold text-gray-900 mb-4">{similarLabel}</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {similarPosts.map(p => (
              <PostCard
                key={p.id}
                post={p}
                currentUserId={currentUserId ?? undefined}
                savedIds={savedIds}
                compact
              />
            ))}
          </div>
          <Link
            href="/dashboard/posts"
            className="flex items-center gap-1 text-sm text-primary-600 hover:text-primary-700 font-medium mt-4"
          >
            Alle Beiträge anzeigen <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>
      )}

      {/* ── Modals ──────────────────────────────────────────────────── */}
      {showContactModal && (
        <ContactModal
          postId={post.id}
          postTitle={post.title}
          currentUserId={currentUserId!}
          onClose={() => setShowContactModal(false)}
          onSent={() => { setShowContactModal(false); loadData() }}
        />
      )}
      {showShareMenu && (
        <ShareMenu
          url={pageUrl}
          title={post.title}
          description={post.description}
          postId={post.id}
          userId={currentUserId}
          shareCount={shareCount}
          onClose={() => setShowShareMenu(false)}
        />
      )}
      {showReportModal && (
        <ReportModal
          postId={post.id}
          currentUserId={currentUserId!}
          onClose={() => setShowReportModal(false)}
        />
      )}
      {showDeleteConfirm && (
        <DeleteConfirmModal
          onConfirm={handleDelete}
          onCancel={() => setShowDeleteConfirm(false)}
        />
      )}
      {/* Mobile-optimized fullscreen image viewer with pinch-to-zoom */}
      <MobileImageViewer
        images={mediaUrls}
        initialIndex={lightboxIndex}
        open={lightboxOpen}
        onClose={() => setLightboxOpen(false)}
        alt={post.title}
      />

      {/* ── Comments Section ──────────────────────────────────────── */}
      <CommentsSection postId={post.id} currentUserId={currentUserId} postOwnerId={post.user_id} />

      {/* Rating modal */}
      {currentUserId && <RatingModal currentUserId={currentUserId} />}
    </div>
  )
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMENTS SECTION
// ═══════════════════════════════════════════════════════════════════════════════

interface Comment {
  id: string
  post_id: string
  user_id: string
  parent_id: string | null
  content: string
  is_edited: boolean
  created_at: string
  updated_at: string
  profiles?: { name?: string; avatar_url?: string }
}

function CommentsSection({ postId, currentUserId, postOwnerId }: {
  postId: string; currentUserId: string | null; postOwnerId: string
}) {
  const [comments, setComments] = useState<Comment[]>([])
  const [newComment, setNewComment] = useState('')
  const [replyTo, setReplyTo] = useState<string | null>(null)
  const [replyText, setReplyText] = useState('')
  const [editId, setEditId] = useState<string | null>(null)
  const [editText, setEditText] = useState('')
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const [showAll, setShowAll] = useState(false)
  const maxLen = 2000

  const loadComments = useCallback(async () => {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('post_comments')
      .select('*, profiles(name, avatar_url)')
      .eq('post_id', postId)
      .order('created_at', { ascending: true })
    if (!error) setComments(data ?? [])
    setLoading(false)
  }, [postId])

  useEffect(() => { loadComments() }, [loadComments])

  const handleSubmit = async (parentId: string | null = null) => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    const text = parentId ? replyText.trim() : newComment.trim()
    if (!text) { toast.error('Kommentar darf nicht leer sein'); return }
    if (text.length > maxLen) { toast.error(`Maximal ${maxLen} Zeichen`); return }

    setSending(true)
    const supabase = createClient()
    const { error } = await supabase.from('post_comments').insert({
      post_id: postId,
      user_id: currentUserId,
      parent_id: parentId,
      content: text,
    })
    setSending(false)
    if (error) { toast.error('Fehler: ' + error.message); return }

    toast.success('Kommentar gepostet')
    if (parentId) { setReplyTo(null); setReplyText('') }
    else { setNewComment('') }
    loadComments()
  }

  const handleEdit = async (commentId: string) => {
    if (!editText.trim()) return
    const supabase = createClient()
    const { error } = await supabase.from('post_comments')
      .update({ content: editText.trim(), is_edited: true })
      .eq('id', commentId)
    if (error) { toast.error('Fehler: ' + error.message); return }
    toast.success('Kommentar aktualisiert')
    setEditId(null); setEditText('')
    loadComments()
  }

  const handleDelete = async (commentId: string) => {
    const supabase = createClient()
    const { error } = await supabase.from('post_comments').delete().eq('id', commentId)
    if (error) { toast.error('Fehler: ' + error.message); return }
    toast.success('Kommentar gelöscht')
    loadComments()
  }

  // Build tree: top-level + replies
  const topLevel = comments.filter(c => !c.parent_id)
  const replies = (parentId: string) => comments.filter(c => c.parent_id === parentId)
  const displayComments = showAll ? topLevel : topLevel.slice(0, 5)

  return (
    <div className="bg-white rounded-2xl shadow-sm p-6 space-y-5">
      <div className="flex items-center justify-between">
        <h3 className="font-bold text-gray-900 flex items-center gap-2">
          <MessageCircle className="w-5 h-5 text-primary-600" />
          Kommentare ({comments.length})
        </h3>
      </div>

      {/* New comment form */}
      {currentUserId ? (
        <div className="space-y-2">
          <textarea
            value={newComment}
            onChange={e => setNewComment(e.target.value.slice(0, maxLen))}
            placeholder="Schreibe einen Kommentar..."
            rows={3}
            className="input resize-none w-full text-sm"
          />
          <div className="flex items-center justify-between">
            <span className="text-[10px] text-gray-400">{newComment.length}/{maxLen}</span>
            <button
              onClick={() => handleSubmit(null)}
              disabled={sending || !newComment.trim()}
              className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50"
            >
              {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
              Kommentieren
            </button>
          </div>
        </div>
      ) : (
        <p className="text-sm text-gray-500 italic">Melde dich an, um zu kommentieren.</p>
      )}

      {/* Comment list */}
      {loading ? (
        <div className="flex justify-center py-6">
          <div className="w-6 h-6 border-3 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
        </div>
      ) : comments.length === 0 ? (
        <div className="text-center py-6 bg-warm-50 rounded-xl border border-warm-200">
          <MessageCircle className="w-8 h-8 text-gray-300 mx-auto mb-2" />
          <p className="text-sm text-gray-500">Noch keine Kommentare</p>
          <p className="text-xs text-gray-400 mt-0.5">Sei der Erste!</p>
        </div>
      ) : (
        <div className="space-y-4">
          {displayComments.map(comment => (
            <div key={comment.id}>
              <CommentItem
                comment={comment}
                currentUserId={currentUserId}
                postOwnerId={postOwnerId}
                isReplyTarget={replyTo === comment.id}
                editId={editId}
                editText={editText}
                replyText={replyText}
                sending={sending}
                onReply={() => { setReplyTo(replyTo === comment.id ? null : comment.id); setReplyText('') }}
                onReplyTextChange={setReplyText}
                onReplySubmit={() => handleSubmit(comment.id)}
                onEdit={() => { setEditId(comment.id); setEditText(comment.content) }}
                onEditTextChange={setEditText}
                onEditSubmit={() => handleEdit(comment.id)}
                onEditCancel={() => { setEditId(null); setEditText('') }}
                onDelete={() => handleDelete(comment.id)}
                maxLen={maxLen}
              />
              {/* Replies */}
              {replies(comment.id).length > 0 && (
                <div className="ml-8 mt-2 space-y-2 border-l-2 border-warm-200 pl-4">
                  {replies(comment.id).map(reply => (
                    <CommentItem
                      key={reply.id}
                      comment={reply}
                      currentUserId={currentUserId}
                      postOwnerId={postOwnerId}
                      isReply
                      editId={editId}
                      editText={editText}
                      sending={sending}
                      onEdit={() => { setEditId(reply.id); setEditText(reply.content) }}
                      onEditTextChange={setEditText}
                      onEditSubmit={() => handleEdit(reply.id)}
                      onEditCancel={() => { setEditId(null); setEditText('') }}
                      onDelete={() => handleDelete(reply.id)}
                      maxLen={maxLen}
                    />
                  ))}
                </div>
              )}
            </div>
          ))}

          {/* Show more */}
          {topLevel.length > 5 && !showAll && (
            <button
              onClick={() => setShowAll(true)}
              className="w-full text-center text-sm text-primary-600 hover:text-primary-700 font-medium py-2"
            >
              Alle {topLevel.length} Kommentare anzeigen
            </button>
          )}
        </div>
      )}
    </div>
  )
}

// ── Single Comment Item ──────────────────────────────────────────────────────
function CommentItem({
  comment, currentUserId, postOwnerId,
  isReplyTarget, isReply,
  editId, editText, replyText, sending,
  onReply, onReplyTextChange, onReplySubmit,
  onEdit, onEditTextChange, onEditSubmit, onEditCancel,
  onDelete, maxLen,
}: {
  comment: Comment
  currentUserId: string | null
  postOwnerId: string
  isReplyTarget?: boolean
  isReply?: boolean
  editId: string | null
  editText: string
  replyText?: string
  sending: boolean
  onReply?: () => void
  onReplyTextChange?: (t: string) => void
  onReplySubmit?: () => void
  onEdit: () => void
  onEditTextChange: (t: string) => void
  onEditSubmit: () => void
  onEditCancel: () => void
  onDelete: () => void
  maxLen: number
}) {
  const isOwn = currentUserId === comment.user_id
  const isPostOwner = currentUserId === postOwnerId
  const isEditing = editId === comment.id

  return (
    <div className={cn(
      'flex gap-3 group',
      isReply ? 'py-2' : 'py-3',
    )}>
      {/* Avatar */}
      <Link href={`/dashboard/profile/${comment.user_id}`} className="flex-shrink-0">
        <div className={cn(
          'rounded-full bg-primary-100 flex items-center justify-center overflow-hidden',
          isReply ? 'w-8 h-8' : 'w-10 h-10',
        )}>
          {comment.profiles?.avatar_url
            ? <img src={comment.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
            : <User className={cn('text-primary-600', isReply ? 'w-4 h-4' : 'w-5 h-5')} />
          }
        </div>
      </Link>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap mb-0.5">
          <Link
            href={`/dashboard/profile/${comment.user_id}`}
            className="text-sm font-semibold text-gray-900 hover:text-primary-700 transition-colors"
          >
            {comment.profiles?.name ?? 'Nutzer'}
          </Link>
          {comment.user_id === postOwnerId && (
            <span className="text-[10px] bg-primary-100 text-primary-700 px-1.5 py-0.5 rounded-full font-medium">
              Autor
            </span>
          )}
          <span className="text-xs text-gray-400">
            {formatRelativeTime(comment.created_at)}
            {comment.is_edited && ' (bearbeitet)'}
          </span>
        </div>

        {isEditing ? (
          <div className="space-y-2">
            <textarea
              value={editText}
              onChange={e => onEditTextChange(e.target.value.slice(0, maxLen))}
              rows={2}
              className="input resize-none w-full text-sm"
            />
            <div className="flex gap-2">
              <button
                onClick={onEditSubmit}
                className="text-xs px-3 py-1 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
              >
                Speichern
              </button>
              <button
                onClick={onEditCancel}
                className="text-xs px-3 py-1 bg-gray-100 text-gray-600 rounded-lg hover:bg-gray-200 transition-colors"
              >
                Abbrechen
              </button>
            </div>
          </div>
        ) : (
          <p className="text-sm text-gray-700 whitespace-pre-wrap leading-relaxed">
            {comment.content}
          </p>
        )}

        {/* Actions */}
        {!isEditing && (
          <div className="flex items-center gap-3 mt-1.5 opacity-0 group-hover:opacity-100 transition-opacity">
            {!isReply && onReply && currentUserId && (
              <button
                onClick={onReply}
                className="flex items-center gap-1 text-xs text-gray-500 hover:text-primary-600 transition-colors"
              >
                <Reply className="w-3.5 h-3.5" /> Antworten
              </button>
            )}
            {isOwn && (
              <button
                onClick={onEdit}
                className="flex items-center gap-1 text-xs text-gray-500 hover:text-primary-600 transition-colors"
              >
                <Edit3 className="w-3.5 h-3.5" /> Bearbeiten
              </button>
            )}
            {(isOwn || isPostOwner) && (
              <button
                onClick={onDelete}
                className="flex items-center gap-1 text-xs text-gray-500 hover:text-red-600 transition-colors"
              >
                <Trash2 className="w-3.5 h-3.5" /> Löschen
              </button>
            )}
          </div>
        )}

        {/* Inline reply form */}
        {isReplyTarget && currentUserId && (
          <div className="mt-3 flex gap-2">
            <div className="flex-1">
              <textarea
                value={replyText}
                onChange={e => onReplyTextChange?.(e.target.value.slice(0, maxLen))}
                placeholder="Antwort schreiben..."
                rows={2}
                className="input resize-none w-full text-sm"
                autoFocus
              />
            </div>
            <div className="flex flex-col gap-1">
              <button
                onClick={onReplySubmit}
                disabled={sending || !(replyText?.trim())}
                className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-primary-600 text-white hover:bg-primary-700 disabled:opacity-50 transition-all"
              >
                {sending ? <Loader2 className="w-3 h-3 animate-spin" /> : <Send className="w-3 h-3" />}
                Senden
              </button>
              <button
                onClick={onReply}
                className="text-xs text-gray-500 hover:text-gray-700 px-3 py-1"
              >
                Abbrechen
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUB-COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

// ── Image Gallery ─────────────────────────────────────────────────────────────
function ImageGallery({ urls, onOpen }: { urls: string[]; onOpen: (idx: number) => void }) {
  if (urls.length === 1) {
    return (
      <img
        src={urls[0]}
        alt=""
        className="w-full max-h-[420px] object-cover cursor-pointer hover:opacity-95 transition-opacity"
        loading="lazy"
        onClick={() => onOpen(0)}
      />
    )
  }
  if (urls.length === 2) {
    return (
      <div className="grid grid-cols-2 gap-1">
        {urls.map((u, i) => (
          <img
            key={i} src={u} alt=""
            className="w-full h-64 object-cover cursor-pointer hover:opacity-95 transition-opacity"
            loading="lazy"
            onClick={() => onOpen(i)}
          />
        ))}
      </div>
    )
  }
  if (urls.length === 3) {
    return (
      <div className="grid grid-cols-3 gap-1">
        <img
          src={urls[0]} alt=""
          className="col-span-2 w-full h-64 object-cover cursor-pointer hover:opacity-95 transition-opacity"
          loading="lazy"
          onClick={() => onOpen(0)}
        />
        <div className="flex flex-col gap-1">
          {urls.slice(1, 3).map((u, i) => (
            <img
              key={i} src={u} alt=""
              className="w-full flex-1 object-cover cursor-pointer hover:opacity-95 transition-opacity"
              loading="lazy"
              onClick={() => onOpen(i + 1)}
            />
          ))}
        </div>
      </div>
    )
  }
  // 4+ images
  return (
    <div className="grid grid-cols-2 gap-1 relative">
      {urls.slice(0, 4).map((u, i) => (
        <img
          key={i} src={u} alt=""
          className="w-full h-48 object-cover cursor-pointer hover:opacity-95 transition-opacity"
          loading="lazy"
          onClick={() => onOpen(i)}
        />
      ))}
      {urls.length > 4 && (
        <div
          className="absolute bottom-2 right-2 bg-black/60 text-white text-sm font-bold px-3 py-1 rounded-full cursor-pointer hover:bg-black/80 transition-colors"
          onClick={() => onOpen(4)}
        >
          +{urls.length - 4}
        </div>
      )}
    </div>
  )
}

// ── Lightbox ──────────────────────────────────────────────────────────────────
function Lightbox({ urls, index, onClose, onChange }: {
  urls: string[]; index: number; onClose: () => void; onChange: (i: number) => void
}) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft' && index > 0) onChange(index - 1)
      if (e.key === 'ArrowRight' && index < urls.length - 1) onChange(index + 1)
    }
    window.addEventListener('keydown', handler)
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', handler)
      document.body.style.overflow = ''
    }
  }, [index, urls.length, onClose, onChange])

  return (
    <div
      className="fixed inset-0 bg-black/90 z-50 flex items-center justify-center"
      onClick={onClose}
    >
      {/* Close button */}
      <button
        onClick={onClose}
        className="absolute top-4 right-4 text-white/80 hover:text-white p-2 z-10 rounded-full hover:bg-white/10 transition-colors"
        aria-label="Schliessen"
      >
        <X className="w-6 h-6" />
      </button>

      {/* Previous */}
      {index > 0 && (
        <button
          onClick={e => { e.stopPropagation(); onChange(index - 1) }}
          className="absolute left-4 text-white/80 hover:text-white p-2 rounded-full hover:bg-white/10 transition-colors"
          aria-label="Vorheriges Bild"
        >
          <ChevronLeft className="w-8 h-8" />
        </button>
      )}

      {/* Next */}
      {index < urls.length - 1 && (
        <button
          onClick={e => { e.stopPropagation(); onChange(index + 1) }}
          className="absolute right-4 text-white/80 hover:text-white p-2 rounded-full hover:bg-white/10 transition-colors"
          aria-label="Nächstes Bild"
        >
          <ChevronRight className="w-8 h-8" />
        </button>
      )}

      {/* Image */}
      <img
        src={urls[index]}
        alt=""
        className="max-w-[90vw] max-h-[90vh] object-contain select-none"
        onClick={e => e.stopPropagation()}
        draggable={false}
      />

      {/* Counter */}
      <div className="absolute bottom-6 left-1/2 -translate-x-1/2 text-white/70 text-sm bg-black/40 px-3 py-1 rounded-full">
        {index + 1} / {urls.length}
      </div>
    </div>
  )
}

// ── Contact Modal ─────────────────────────────────────────────────────────────
function ContactModal({ postId, postTitle, currentUserId, onClose, onSent }: {
  postId: string; postTitle: string; currentUserId: string
  onClose: () => void; onSent: () => void
}) {
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const maxLen = 500

  const handleSend = async () => {
    setSending(true)
    const supabase = createClient()
    const { error } = await supabase.from('interactions').insert({
      post_id: postId,
      helper_id: currentUserId,
      message: message.trim() || 'Interesse gezeigt',
      status: 'pending',
    })
    setSending(false)
    if (handleSupabaseError(error)) return
    toast.success('Interesse wurde gesendet!')
    onSent()
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md animate-slide-up"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between p-5 border-b border-warm-100">
          <div>
            <h2 className="text-lg font-bold text-gray-900">Interesse zeigen</h2>
            <p className="text-sm text-gray-500 mt-0.5 line-clamp-1">
              an: {postTitle}
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl hover:bg-warm-100 text-gray-500 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <div>
            <textarea
              value={message}
              onChange={e => setMessage(e.target.value.slice(0, maxLen))}
              placeholder="Schreibe eine kurze Nachricht..."
              rows={4}
              className="input resize-none w-full"
            />
            <p className="text-right text-[10px] text-gray-400 mt-1">{message.length}/{maxLen}</p>
          </div>
          {/* Suggestion chips */}
          <div className="flex flex-wrap gap-2">
            {QUICK_MESSAGES.map(qm => (
              <button
                key={qm}
                onClick={() => setMessage(qm)}
                className="text-xs bg-warm-50 hover:bg-warm-100 text-gray-600 px-3 py-1.5 rounded-full border border-warm-200 transition-colors"
              >
                {qm}
              </button>
            ))}
          </div>
          <button
            onClick={handleSend}
            disabled={sending}
            className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50"
          >
            {sending
              ? <Loader2 className="w-4 h-4 animate-spin" />
              : <Send className="w-4 h-4" />
            }
            Nachricht senden
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Share Menu with Tracking ─────────────────────────────────────────────────
function ShareMenu({ url, title, description, postId, userId, shareCount, onClose }: {
  url: string; title: string; description?: string
  postId: string; userId?: string | null; shareCount: number
  onClose: () => void
}) {
  const canNativeShare = typeof navigator !== 'undefined' && !!navigator.share

  const trackShare = async (platform: string) => {
    const supabase = createClient()
    await supabase.from('post_shares').insert({
      post_id: postId,
      user_id: userId || null,
      platform,
    }).then(() => {}) // fire and forget
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-5 space-y-2 animate-slide-up"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-bold text-gray-900">Teilen</h3>
          {shareCount > 0 && (
            <span className="text-xs text-gray-400">{shareCount}x geteilt</span>
          )}
        </div>

        {/* Copy link */}
        <button
          onClick={() => {
            navigator.clipboard.writeText(url)
            trackShare('copy')
            toast.success('Link kopiert!')
            onClose()
          }}
          className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-warm-50 transition-colors text-left"
        >
          <Copy className="w-5 h-5 text-gray-500" />
          <span className="text-sm">Link kopieren</span>
        </button>

        {/* WhatsApp share */}
        <a
          href={`https://wa.me/?text=${encodeURIComponent('Schau dir das an: ' + title + ' ' + url)}`}
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => { trackShare('whatsapp'); onClose() }}
          className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-warm-50 transition-colors"
        >
          <MessageCircle className="w-5 h-5 text-green-600" />
          <span className="text-sm">WhatsApp teilen</span>
        </a>

        {/* Email share */}
        <a
          href={`mailto:?subject=${encodeURIComponent(title)}&body=${encodeURIComponent('Schau dir diesen Beitrag auf Mensaena an: ' + url)}`}
          onClick={() => { trackShare('email'); onClose() }}
          className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-warm-50 transition-colors"
        >
          <Mail className="w-5 h-5 text-blue-600" />
          <span className="text-sm">Per E-Mail teilen</span>
        </a>

        {/* Native share */}
        {canNativeShare && (
          <button
            onClick={() => {
              navigator.share({
                title,
                text: description?.substring(0, 100),
                url,
              }).catch(() => {})
              trackShare('native')
              onClose()
            }}
            className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-warm-50 transition-colors text-left"
          >
            <Share2 className="w-5 h-5 text-gray-500" />
            <span className="text-sm">Teilen</span>
          </button>
        )}

        <button
          onClick={onClose}
          className="w-full text-center text-sm text-gray-400 hover:text-gray-600 pt-2"
        >
          Abbrechen
        </button>
      </div>
    </div>
  )
}

// ── Report Modal ──────────────────────────────────────────────────────────────
function ReportModal({ postId, currentUserId, onClose }: {
  postId: string; currentUserId: string; onClose: () => void
}) {
  const [reason, setReason] = useState('')
  const [comment, setComment] = useState('')
  const [sending, setSending] = useState(false)

  const handleReport = async () => {
    if (!reason) { toast.error('Bitte waehle einen Grund'); return }
    setSending(true)
    const supabase = createClient()
    const { error } = await supabase.from('reports').insert({
      reporter_id: currentUserId,
      content_type: 'post',
      content_id: postId,
      reason,
      comment: comment.trim() || null,
    })
    setSending(false)
    if (handleSupabaseError(error)) return
    toast.success('Danke für deine Meldung. Wir prüfen den Beitrag.')
    onClose()
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md animate-slide-up"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between p-5 border-b border-warm-100">
          <h2 className="text-lg font-bold text-gray-900">Beitrag melden</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-warm-100 text-gray-500 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="p-5 space-y-4">
          {/* Radio reasons */}
          <div className="space-y-2">
            {REPORT_REASONS.map(r => (
              <label
                key={r}
                className={cn(
                  'flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-colors',
                  reason === r
                    ? 'border-primary-400 bg-primary-50'
                    : 'border-gray-200 hover:bg-warm-50',
                )}
              >
                <input
                  type="radio"
                  name="report-reason"
                  value={r}
                  checked={reason === r}
                  onChange={() => setReason(r)}
                  className="accent-primary-600"
                />
                <span className="text-sm text-gray-700">{r}</span>
              </label>
            ))}
          </div>
          {/* Optional comment */}
          <textarea
            value={comment}
            onChange={e => setComment(e.target.value.slice(0, 500))}
            placeholder="Optionaler Kommentar..."
            rows={3}
            className="input resize-none w-full"
          />
          <p className="text-right text-[10px] text-gray-400">{comment.length}/500</p>
          <div className="flex gap-3">
            <button
              onClick={onClose}
              className="flex-1 py-2.5 rounded-xl text-sm font-medium border border-gray-200 hover:bg-warm-50 transition-colors"
            >
              Abbrechen
            </button>
            <button
              onClick={handleReport}
              disabled={sending || !reason}
              className="flex-1 py-2.5 rounded-xl text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors disabled:opacity-50"
            >
              {sending ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Melden'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

// ── Delete Confirmation Modal ─────────────────────────────────────────────────
function DeleteConfirmModal({ onConfirm, onCancel }: {
  onConfirm: () => void; onCancel: () => void
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
      onClick={onCancel}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4 animate-scale-in"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
            <Trash2 className="w-5 h-5 text-red-600" />
          </div>
          <h3 className="font-bold text-gray-900 text-lg">Beitrag löschen?</h3>
        </div>
        <p className="text-sm text-gray-600">
          Bist du sicher, dass du diesen Beitrag löschen möchtest? Diese Aktion kann nicht rueckgaengig gemacht werden.
          Alle Bilder und Meldungen werden ebenfalls entfernt.
        </p>
        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 py-2.5 rounded-xl text-sm font-medium border border-gray-200 hover:bg-warm-50 transition-colors"
          >
            Abbrechen
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 py-2.5 rounded-xl text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors"
          >
            Endgueltig löschen
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Interaction Row ───────────────────────────────────────────────────────────
function InteractionRow({ interaction, onAccept, onDecline }: {
  interaction: Interaction
  onAccept: () => void
  onDecline: (reason?: string) => void
}) {
  const [showDeclineMenu, setShowDeclineMenu] = useState(false)
  const router = useRouter()

  return (
    <div className="flex items-start gap-3 p-4 bg-white border border-warm-200 rounded-xl">
      {/* Avatar */}
      <Link href={`/dashboard/profile/${interaction.helper_id}`} className="flex-shrink-0">
        <div className="w-12 h-12 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden">
          {interaction.profiles?.avatar_url
            ? <img src={interaction.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
            : <User className="w-6 h-6 text-primary-600" />
          }
        </div>
      </Link>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap mb-1">
          <Link
            href={`/dashboard/profile/${interaction.helper_id}`}
            className="font-semibold text-sm text-gray-900 hover:text-primary-700 transition-colors"
          >
            {interaction.profiles?.name ?? 'Nutzer'}
          </Link>
          {/* Trust badge */}
          {interaction.profiles?.trust_score != null && (
            <span className="text-xs bg-warm-100 text-gray-600 px-2 py-0.5 rounded-full">
              Vertrauen: {interaction.profiles.trust_score}
            </span>
          )}
        </div>
        {/* Message */}
        {interaction.message && (
          <p className="text-sm text-gray-600 italic mb-1">
            &#x201E;{interaction.message}&#x201C;
          </p>
        )}
        {/* Timestamp */}
        <p className="text-xs text-gray-400">
          {new Date(interaction.created_at).toLocaleDateString('de-AT', {
            day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
          })}
        </p>
      </div>

      {/* Action buttons */}
      <div className="flex-shrink-0">
        {(interaction.status === 'pending' || interaction.status === 'interested') && (
          <div className="flex flex-col gap-1.5 relative">
            <button
              onClick={onAccept}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-green-600 text-white hover:bg-green-700 transition-all"
            >
              <CheckCircle className="w-3.5 h-3.5" /> Akzeptieren
            </button>
            <div className="relative">
              <button
                onClick={() => setShowDeclineMenu(!showDeclineMenu)}
                className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition-all w-full justify-center"
              >
                <XCircle className="w-3.5 h-3.5" /> Ablehnen
              </button>
              {showDeclineMenu && (
                <div className="absolute top-full right-0 mt-1 bg-white rounded-xl shadow-xl border border-gray-200 py-1 min-w-[180px] z-20">
                  {DECLINE_REASONS.map(r => (
                    <button
                      key={r}
                      onClick={() => { onDecline(r); setShowDeclineMenu(false) }}
                      className="w-full text-left px-4 py-2 text-xs hover:bg-warm-50 transition-colors"
                    >
                      {r}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
        {interaction.status === 'accepted' && (
          <div className="text-center space-y-1.5">
            <span className="inline-block text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-medium">
              &#x2705; Akzeptiert
            </span>
            <button
              onClick={() => router.push('/dashboard/chat')}
              className="text-xs text-primary-600 hover:text-primary-700 font-medium block"
            >
              Chat öffnen
            </button>
          </div>
        )}
        {interaction.status === 'completed' && (
          <span className="inline-block text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full font-medium">
            Abgeschlossen
          </span>
        )}
        {interaction.status === 'declined' && (
          <span className="inline-block text-xs bg-gray-100 text-gray-500 px-2 py-1 rounded-full font-medium">
            &#x274C; Abgelehnt{interaction.reason ? `: ${interaction.reason}` : ''}
          </span>
        )}
      </div>
    </div>
  )
}
