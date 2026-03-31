'use client'

import { useState } from 'react'
import Link from 'next/link'
import {
  MapPin, Clock, Phone, MessageCircle, Bookmark, BookmarkCheck,
  AlertTriangle, Heart, ExternalLink, User, Flame
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'

// Pin-Farben nach Typ
const TYPE_CONFIG: Record<string, { label: string; color: string; bg: string; dot: string }> = {
  help_request:  { label: 'Hilfe gesucht',   color: 'text-red-700',    bg: 'bg-red-50 border-red-200',    dot: 'bg-red-500'    },
  help_offer:    { label: 'Hilfe angeboten', color: 'text-green-700',  bg: 'bg-green-50 border-green-200', dot: 'bg-green-500'  },
  rescue:        { label: 'Retter-Angebot',  color: 'text-orange-700', bg: 'bg-orange-50 border-orange-200', dot: 'bg-orange-500' },
  animal:        { label: 'Tierhilfe',       color: 'text-pink-700',   bg: 'bg-pink-50 border-pink-200',   dot: 'bg-pink-500'   },
  housing:       { label: 'Wohnangebot',     color: 'text-blue-700',   bg: 'bg-blue-50 border-blue-200',   dot: 'bg-blue-500'   },
  supply:        { label: 'Versorgung',      color: 'text-yellow-700', bg: 'bg-yellow-50 border-yellow-200', dot: 'bg-yellow-500' },
  skill:         { label: 'Skill',           color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200', dot: 'bg-purple-500' },
  mobility:      { label: 'Mobilität',       color: 'text-indigo-700', bg: 'bg-indigo-50 border-indigo-200', dot: 'bg-indigo-500' },
  sharing:       { label: 'Tauschen',        color: 'text-teal-700',   bg: 'bg-teal-50 border-teal-200',   dot: 'bg-teal-500'   },
  community:     { label: 'Community',       color: 'text-violet-700', bg: 'bg-violet-50 border-violet-200', dot: 'bg-violet-500' },
  crisis:        { label: '⚠️ Notfall',      color: 'text-red-700',    bg: 'bg-red-100 border-red-400',    dot: 'bg-red-600'    },
  knowledge:     { label: 'Wissen',          color: 'text-emerald-700',bg: 'bg-emerald-50 border-emerald-200', dot: 'bg-emerald-500' },
  mental:        { label: 'Mentale Hilfe',   color: 'text-cyan-700',   bg: 'bg-cyan-50 border-cyan-200',   dot: 'bg-cyan-500'   },
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
  profiles?: { name?: string; avatar_url?: string }
  media_urls?: string[]
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
  const [saved, setSaved] = useState(savedIds.includes(post.id))
  const [savingLoading, setSavingLoading] = useState(false)
  const [reacted, setReacted] = useState(false)

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

  const handleReact = async () => {
    if (!currentUserId) { toast.error('Bitte zuerst anmelden'); return }
    if (isOwn) { toast('Das ist dein eigener Beitrag'); return }
    const supabase = createClient()
    const { error } = await supabase.from('interactions').upsert({
      post_id: post.id,
      helper_id: currentUserId,
      status: 'interested',
      message: 'Interesse gezeigt',
    }, { onConflict: 'post_id,helper_id' })
    if (!error) {
      setReacted(true)
      toast.success('Interesse gezeigt! Der Ersteller wird benachrichtigt 🌿')
    }
  }

  const href = detailHref ?? `/dashboard/posts/${post.id}`

  return (
    <div className={cn(
      'bg-white rounded-2xl border shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden',
      isUrgent ? 'border-red-300 ring-1 ring-red-200' : 'border-warm-200',
    )}>
      {/* Urgency Banner */}
      {isUrgent && (
        <div className="flex items-center gap-1.5 px-4 py-1.5 bg-red-500 text-white text-xs font-semibold">
          <Flame className="w-3 h-3" /> DRINGEND
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
                {post.profiles?.name ?? 'Nutzer'}
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
          <div className="flex items-center gap-1">
            {/* Interesse zeigen */}
            {!isOwn && showContact && (
              <button
                onClick={handleReact}
                disabled={reacted}
                className={cn(
                  'flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all',
                  reacted
                    ? 'bg-primary-100 text-primary-700 cursor-default'
                    : 'bg-primary-50 text-primary-700 hover:bg-primary-100'
                )}
              >
                <Heart className={cn('w-3.5 h-3.5', reacted && 'fill-primary-600')} />
                {reacted ? 'Gemeldet' : 'Ich helfe'}
              </button>
            )}

            {/* WhatsApp */}
            {showContact && post.contact_whatsapp && (
              <a
                href={`https://wa.me/${post.contact_whatsapp.replace(/\D/g, '')}`}
                target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-green-50 text-green-700 hover:bg-green-100 transition-all"
              >
                <MessageCircle className="w-3.5 h-3.5" />
                WhatsApp
              </a>
            )}

            {/* Telefon */}
            {showContact && post.contact_phone && (
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
              className="p-1.5 rounded-lg text-gray-400 hover:text-primary-600 hover:bg-primary-50 transition-all"
              title={saved ? 'Gespeichert' : 'Speichern'}
            >
              {saved ? <BookmarkCheck className="w-4 h-4 text-primary-600" /> : <Bookmark className="w-4 h-4" />}
            </button>

            {/* Detail-Link */}
            <Link
              href={href}
              className="p-1.5 rounded-lg text-gray-400 hover:text-primary-600 hover:bg-primary-50 transition-all"
              title="Details"
            >
              <ExternalLink className="w-4 h-4" />
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}
