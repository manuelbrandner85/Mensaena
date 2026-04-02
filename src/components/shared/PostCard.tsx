'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import {
  MapPin, Clock, Phone, MessageCircle, Bookmark, BookmarkCheck,
  Heart, ExternalLink, User, Flame, Send, CheckCircle, ThumbsUp, ThumbsDown,
  Mail, Loader2
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { openOrCreateDM } from '@/lib/chat-utils'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'

// Pin-Farben nach Typ (valid DB types: rescue, animal, housing, supply, mobility, sharing, community, crisis)
const TYPE_CONFIG: Record<string, { label: string; color: string; bg: string; dot: string }> = {
  rescue:    { label: 'Hilfe / Retten',  color: 'text-orange-700', bg: 'bg-orange-50 border-orange-200', dot: 'bg-orange-500' },
  animal:    { label: 'Tierhilfe',       color: 'text-pink-700',   bg: 'bg-pink-50 border-pink-200',     dot: 'bg-pink-500'   },
  housing:   { label: 'Wohnangebot',     color: 'text-blue-700',   bg: 'bg-blue-50 border-blue-200',     dot: 'bg-blue-500'   },
  supply:    { label: 'Versorgung',      color: 'text-yellow-700', bg: 'bg-yellow-50 border-yellow-200', dot: 'bg-yellow-500' },
  mobility:  { label: 'Mobilität',       color: 'text-indigo-700', bg: 'bg-indigo-50 border-indigo-200', dot: 'bg-indigo-500' },
  sharing:   { label: 'Teilen/Skill',    color: 'text-teal-700',   bg: 'bg-teal-50 border-teal-200',     dot: 'bg-teal-500'   },
  community: { label: 'Community',       color: 'text-violet-700', bg: 'bg-violet-50 border-violet-200', dot: 'bg-violet-500' },
  crisis:    { label: '⚠️ Notfall',      color: 'text-red-700',    bg: 'bg-red-100 border-red-400',      dot: 'bg-red-600'    },
  // Legacy fallbacks (these won't match DB but keep UI graceful)
  help_request: { label: 'Hilfe gesucht',   color: 'text-red-700',    bg: 'bg-red-50 border-red-200',    dot: 'bg-red-500'    },
  help_offer:   { label: 'Hilfe angeboten', color: 'text-green-700',  bg: 'bg-green-50 border-green-200', dot: 'bg-green-500'  },
  skill:        { label: 'Skill',           color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200', dot: 'bg-purple-500' },
  knowledge:    { label: 'Wissen',          color: 'text-emerald-700',bg: 'bg-emerald-50 border-emerald-200', dot: 'bg-emerald-500' },
  mental:       { label: 'Mentale Hilfe',   color: 'text-cyan-700',   bg: 'bg-cyan-50 border-cyan-200',   dot: 'bg-cyan-500'   },
}

export type PostCardPost = {
  id: string
  type: string
  category?: string
  title: string
  description?: string
  location_text?: string
  contact_phone?: string
  contact_whatsapp?: string
  urgency?: string
  created_at: string
  user_id: string
  is_anonymous?: boolean
  profiles?: { name?: string; avatar_url?: string }
  media_urls?: string[]
  tags?: string[]
  status?: string
}

interface PostCardProps {
  post: PostCardPost
  currentUserId?: string
  savedIds?: string[]
  onSaveToggle?: (id: string, saved: boolean) => void
  compact?: boolean
  showContact?: boolean
  detailHref?: string
}

export default function PostCard({
  post,
  currentUserId,
  savedIds = [],
  onSaveToggle,
  compact = false,
  showContact = true,
  detailHref,
}: PostCardProps) {
  const router = useRouter()
  const [saved, setSaved]             = useState(savedIds.includes(post.id))
  const [savingLoading, setSavingLoading] = useState(false)
  const [reacted, setReacted]         = useState(false)
  const [showMiniContact, setShowMiniContact] = useState(false)
  const [voteScore, setVoteScore]     = useState(0)
  const [userVote, setUserVote]       = useState<1 | -1 | 0>(0)
  const [dmLoading, setDmLoading]     = useState(false)

  // Load vote data for community posts
  useEffect(() => {
    if (post.type !== 'community') return
    const supabase = createClient()
    supabase.from('post_votes').select('vote, user_id').eq('post_id', post.id)
      .then(({ data }) => {
        if (!data) return
        const total = data.reduce((sum, v) => sum + (v.vote as number), 0)
        setVoteScore(total)
        if (currentUserId) {
          const myVote = data.find(v => v.user_id === currentUserId)
          if (myVote) setUserVote(myVote.vote as 1 | -1)
        }
      })
  }, [post.id, post.type, currentUserId])

  const isAnonymous = post.is_anonymous === true

  const handleVote = async (v: 1 | -1) => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    const supabase = createClient()
    const newVote: 0 | 1 | -1 = userVote === v ? 0 : v
    if (newVote === 0) {
      await supabase.from('post_votes').delete().eq('post_id', post.id).eq('user_id', currentUserId)
    } else {
      await supabase.from('post_votes').upsert({ post_id: post.id, user_id: currentUserId, vote: newVote }, { onConflict: 'post_id,user_id' })
    }
    setVoteScore(prev => prev + newVote - userVote)
    setUserVote(newVote)
  }

  const cfg = TYPE_CONFIG[post.type] ?? TYPE_CONFIG['help_offer']
  const isOwn = currentUserId === post.user_id
  const isUrgent = post.urgency === 'high' || post.type === 'crisis'

  const ago = (() => {
    const diff = Date.now() - new Date(post.created_at).getTime()
    const m = Math.floor(diff / 60000)
    if (m < 1) return 'gerade eben'
    if (m < 60) return `vor ${m} Min.`
    const h = Math.floor(m / 60)
    if (h < 24) return `vor ${h} Std.`
    return `vor ${Math.floor(h / 24)} Tagen`
  })()

  const handleSave = async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    setSavingLoading(true)
    const supabase = createClient()
    if (saved) {
      await supabase.from('saved_posts').delete()
        .eq('user_id', currentUserId).eq('post_id', post.id)
      setSaved(false)
      onSaveToggle?.(post.id, false)
      toast.success('Gespeichert entfernt')
    } else {
      await supabase.from('saved_posts').insert({ user_id: currentUserId, post_id: post.id })
      setSaved(true)
      onSaveToggle?.(post.id, true)
      toast.success('Beitrag gespeichert! 🔖')
    }
    setSavingLoading(false)
  }

  const handleReact = () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    if (isOwn) { toast('Das ist dein eigener Beitrag 😊'); return }
    setShowMiniContact(true)
  }

  const handleDM = async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    if (isOwn) { toast('Das ist dein eigener Beitrag 😊'); return }
    setDmLoading(true)
    try {
      const convId = await openOrCreateDM(currentUserId, post.user_id, post.id)
      if (convId) {
        router.push(`/dashboard/chat?conv=${convId}`)
      } else {
        toast.error('Konversation konnte nicht gestartet werden')
      }
    } finally {
      setDmLoading(false)
    }
  }

  const handleQuickContact = async (message: string) => {
    const supabase = createClient()
    const { error } = await supabase.from('interactions').upsert({
      post_id: post.id,
      helper_id: currentUserId,
      status: 'interested',
      message: message || 'Interesse gezeigt',
    }, { onConflict: 'post_id,helper_id' })
    if (!error) {
      setReacted(true)
      setShowMiniContact(false)
      toast.success('Interesse gemeldet! 🌿')
    }
  }

  const href = detailHref ?? `/dashboard/posts/${post.id}`

  return (
    <div className={cn(
      'bg-white rounded-2xl border shadow-sm overflow-hidden relative group/card',
      'transition-all duration-250',
      isUrgent ? 'border-red-300 ring-1 ring-red-200' : 'border-warm-200',
    )}
      style={{ transition: 'transform 0.25s cubic-bezier(0.34,1.2,0.64,1), box-shadow 0.25s ease' }}
      onMouseEnter={e => {
        const el = e.currentTarget as HTMLDivElement
        el.style.transform = 'translateY(-3px) scale(1.005)'
        el.style.boxShadow = '0 8px 24px rgba(0,0,0,0.10)'
      }}
      onMouseLeave={e => {
        const el = e.currentTarget as HTMLDivElement
        el.style.transform = ''
        el.style.boxShadow = ''
      }}
    >
      {/* Color accent left border on hover */}
      <div
        className="absolute left-0 top-2 bottom-2 w-1 rounded-r-full transition-transform duration-250 origin-center"
        style={{
          background: cfg.dot.replace('bg-', '').includes('-')
            ? `var(--tw-${cfg.dot.replace('bg-', '')}, #4CAF50)`
            : '#4CAF50',
          transform: 'scaleY(0)',
          transition: 'transform 0.25s cubic-bezier(0.34,1.56,0.64,1)',
        }}
        ref={el => {
          if (!el) return
          const parent = el.closest('[onmouseenter]') || el.parentElement
          // handled via CSS group
        }}
      />
      {/* Urgency Banner */}
      {isUrgent && (
        <div className="flex items-center gap-1.5 px-4 py-1.5 bg-red-500 text-white text-xs font-semibold">
          <Flame className="w-3 h-3 animate-pulse" /> DRINGEND
        </div>
      )}

      <div className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between gap-2 mb-3">
          <div className="flex items-center gap-2 min-w-0">
            {/* Avatar */}
            <div className="w-8 h-8 rounded-full bg-primary-100 flex items-center justify-center flex-shrink-0 overflow-hidden">
              {post.profiles?.avatar_url
                ? <img src={post.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                : <User className="w-4 h-4 text-primary-600" />
              }
            </div>
            <div className="min-w-0">
              <p className="text-xs font-medium text-gray-700 truncate">
                {isAnonymous ? '🔒 Anonym' : (post.profiles?.name ?? 'Nutzer')}
              </p>
              <div className="flex items-center gap-1 text-xs text-gray-400">
                <Clock className="w-3 h-3" />
                {ago}
              </div>
            </div>
          </div>
          {/* Type Badge */}
          <span className={cn('text-xs font-semibold px-2 py-0.5 rounded-full border flex-shrink-0', cfg.bg, cfg.color)}>
            <span className={cn('inline-block w-1.5 h-1.5 rounded-full mr-1', cfg.dot)} />
            {cfg.label}
          </span>
        </div>

        {/* Title */}
        <Link href={href} className="block group">
          <h3 className="font-semibold text-gray-900 text-sm leading-snug group-hover:text-primary-700 transition-colors mb-1">
            {post.title}
          </h3>
        </Link>

        {/* Description */}
        {!compact && post.description && (
          <p className="text-sm text-gray-600 line-clamp-2 mb-3">
            {post.description}
          </p>
        )}

        {/* Location */}
        {post.location_text && (
          <div className="flex items-center gap-1 text-xs text-gray-500 mb-3">
            <MapPin className="w-3 h-3 flex-shrink-0" />
            <span className="truncate">{post.location_text}</span>
          </div>
        )}

        {/* Tags */}
        {post.tags && post.tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mb-3">
            {post.tags.slice(0, 4).map(tag => (
              <span key={tag} className="tag text-xs cursor-default">
                #{tag}
              </span>
            ))}
          </div>
        )}

        {/* Media Preview */}
        {!compact && post.media_urls && post.media_urls.length > 0 && (
          <div className="flex gap-1 mb-3 overflow-hidden rounded-lg">
            {post.media_urls.slice(0, 3).map((url, i) => (
              <img key={i} src={url} alt="" className="h-20 w-20 object-cover rounded-lg flex-shrink-0" />
            ))}
          </div>
        )}

        {/* Actions */}
        <div className="flex items-center justify-between pt-2 border-t border-warm-100">
          <div className="flex items-center gap-1 flex-wrap">
            {/* Community-Voting nur für community-Posts */}
            {post.type === 'community' && (
              <div className="flex items-center gap-0.5 mr-1">
                <button onClick={() => handleVote(1)}
                  className={cn('vote-btn text-xs font-bold',
                    userVote === 1 ? 'bg-green-100 text-green-700' : 'text-gray-400 hover:bg-green-50 hover:text-green-600',
                    userVote === 1 && 'vote-btn-active')}>
                  <ThumbsUp className="w-3.5 h-3.5" />
                </button>
                <span className={cn('text-xs font-bold w-5 text-center transition-all',
                  voteScore > 0 ? 'text-green-600' : voteScore < 0 ? 'text-red-500' : 'text-gray-400')}>
                  {voteScore > 0 ? `+${voteScore}` : voteScore}
                </span>
                <button onClick={() => handleVote(-1)}
                  className={cn('vote-btn text-xs font-bold',
                    userVote === -1 ? 'bg-red-100 text-red-700' : 'text-gray-400 hover:bg-red-50 hover:text-red-600',
                    userVote === -1 && 'vote-btn-active')}>
                  <ThumbsDown className="w-3.5 h-3.5" />
                </button>
              </div>
            )}

            {/* Interesse zeigen */}
            {!isOwn && showContact && post.type !== 'community' && (
              <button
                onClick={handleReact}
                disabled={reacted}
                className={cn(
                  'flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium',
                  'transition-all duration-150 active:scale-90',
                  reacted
                    ? 'bg-green-100 text-green-700 cursor-default'
                    : 'bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-200 hover:scale-105'
                )}
              >
                {reacted
                  ? <><CheckCircle className="w-3.5 h-3.5 animate-bounce-in" /> Gemeldet</>
                  : <><Heart className="w-3.5 h-3.5" /> Interesse</>}
              </button>
            )}

            {/* Direkte Nachricht senden (nicht anonym, nicht eigener Post, nicht community) */}
            {!isOwn && showContact && !isAnonymous && post.type !== 'community' && (
              <button
                onClick={handleDM}
                disabled={dmLoading}
                title="Direkte Nachricht senden"
                className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all bg-violet-50 text-violet-700 hover:bg-violet-100 border border-violet-200"
              >
                {dmLoading
                  ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  : <Mail className="w-3.5 h-3.5" />}
                DM
              </button>
            )}

            {/* WhatsApp - nicht bei anonymem Post */}
            {showContact && post.contact_whatsapp && !isAnonymous && (
              <a
                href={`https://wa.me/${post.contact_whatsapp.replace(/\D/g, '')}`}
                target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-green-50 text-green-700 hover:bg-green-100 transition-all"
              >
                <MessageCircle className="w-3.5 h-3.5" />
                WhatsApp
              </a>
            )}

            {/* Telefon - nicht bei anonymem Post */}
            {showContact && post.contact_phone && !isAnonymous && (
              <a
                href={`tel:${post.contact_phone}`}
                className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-blue-50 text-blue-700 hover:bg-blue-100 transition-all"
              >
                <Phone className="w-3.5 h-3.5" />
                Anrufen
              </a>
            )}
          </div>

          <div className="flex items-center gap-1">
            {/* Speichern */}
            <button
              onClick={handleSave}
              disabled={savingLoading}
              className="icon-btn"
              title={saved ? 'Gespeichert' : 'Speichern'}
            >
              {saved
                ? <BookmarkCheck className="w-4 h-4 text-primary-600 animate-bounce-in" />
                : <Bookmark className="w-4 h-4" />}
            </button>

            {/* Detail-Link */}
            <Link
              href={href}
              className="icon-btn"
              title="Details & Kontakt"
            >
              <ExternalLink className="w-4 h-4" />
            </Link>
          </div>
        </div>
      </div>

      {/* Mini Kontakt-Modal */}
      {showMiniContact && (
        <MiniContactModal
          postTitle={post.title}
          contactWhatsapp={post.contact_whatsapp}
          contactPhone={post.contact_phone}
          isAnonymous={isAnonymous}
          onSend={handleQuickContact}
          onClose={() => setShowMiniContact(false)}
          onDetail={() => { setShowMiniContact(false); router.push(href) }}
          onDM={!isAnonymous ? () => { setShowMiniContact(false); handleDM() } : undefined}
        />
      )}
    </div>
  )
}

// ── Mini Kontakt-Modal (direkt in der Karte) ─────────────────────────────────
function MiniContactModal({
  postTitle, contactWhatsapp, contactPhone, isAnonymous,
  onSend, onClose, onDetail, onDM
}: {
  postTitle: string
  contactWhatsapp?: string
  contactPhone?: string
  isAnonymous?: boolean
  onSend: (msg: string) => void
  onClose: () => void
  onDetail: () => void
  onDM?: () => void
}) {
  const [msg, setMsg] = useState('')
  const waText = encodeURIComponent(`Hallo, ich habe deinen Beitrag "${postTitle}" auf Mensaena gesehen.`)

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-5 space-y-3 animate-scale-in" onClick={e => e.stopPropagation()}>
        <div className="flex items-start justify-between">
          <div>
            <p className="font-bold text-gray-900">Kontakt aufnehmen</p>
            <p className="text-xs text-gray-500 mt-0.5 line-clamp-1">{postTitle}</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-lg leading-none">✕</button>
        </div>

        {/* DM-Button – immer oben wenn nicht anonym */}
        {onDM && !isAnonymous && (
          <button onClick={onDM}
            className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-violet-600 text-white hover:bg-violet-700 transition-all">
            <Mail className="w-4 h-4" /> Direkte Nachricht (DM) senden
          </button>
        )}

        {/* Direktkontakt: WhatsApp + Telefon */}
        {!isAnonymous && (contactWhatsapp || contactPhone) && (
          <div className="flex gap-2">
            {contactWhatsapp && (
              <a href={`https://wa.me/${contactWhatsapp.replace(/\D/g,'')}?text=${waText}`}
                target="_blank" rel="noopener noreferrer"
                className="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-sm font-medium bg-green-600 text-white hover:bg-green-700 transition-all">
                <MessageCircle className="w-4 h-4" /> WhatsApp
              </a>
            )}
            {contactPhone && (
              <a href={`tel:${contactPhone}`}
                className="flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-sm font-medium bg-blue-600 text-white hover:bg-blue-700 transition-all">
                <Phone className="w-4 h-4" /> Anrufen
              </a>
            )}
          </div>
        )}

        {isAnonymous && (
          <p className="text-xs text-gray-500 text-center py-1 bg-warm-50 rounded-lg px-3">
            🔒 Dieser Beitrag ist anonym – nur Interesse melden möglich
          </p>
        )}

        {/* Interesse melden */}
        <div className="space-y-2">
          <textarea
            value={msg}
            onChange={e => setMsg(e.target.value)}
            placeholder="Kurze Nachricht (optional)…"
            rows={2}
            className="input resize-none text-sm w-full"
          />
          <button onClick={() => onSend(msg)}
            className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all">
            <Send className="w-4 h-4" /> Interesse melden
          </button>
        </div>

        <button onClick={onDetail}
          className="w-full text-center text-xs text-primary-600 hover:underline py-1">
          Vollständige Details & alle Kontaktoptionen →
        </button>
      </div>
    </div>
  )
}
