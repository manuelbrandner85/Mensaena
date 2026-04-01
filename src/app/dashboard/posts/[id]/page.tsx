'use client'
export const runtime = 'edge'

import { useEffect, useState, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  ArrowLeft, MapPin, Clock, Phone, MessageCircle, Heart, User,
  Flame, CheckCircle, XCircle, Send, Users, AlertTriangle, Star,
  ExternalLink, Share2, Flag, Bookmark, BookmarkCheck
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'

const TYPE_CONFIG: Record<string, { label: string; color: string; bg: string; gradient: string }> = {
  help_request:  { label: 'Hilfe gesucht',   color: 'text-red-700',    bg: 'bg-red-50 border-red-200',    gradient: 'from-red-500 to-rose-600'     },
  help_offer:    { label: 'Hilfe angeboten', color: 'text-green-700',  bg: 'bg-green-50 border-green-200', gradient: 'from-green-500 to-emerald-600' },
  rescue:        { label: 'Retter-Angebot',  color: 'text-orange-700', bg: 'bg-orange-50 border-orange-200', gradient: 'from-orange-500 to-amber-600' },
  animal:        { label: 'Tierhilfe',       color: 'text-pink-700',   bg: 'bg-pink-50 border-pink-200',   gradient: 'from-pink-500 to-rose-500'    },
  housing:       { label: 'Wohnangebot',     color: 'text-blue-700',   bg: 'bg-blue-50 border-blue-200',   gradient: 'from-blue-500 to-indigo-600'  },
  supply:        { label: 'Versorgung',      color: 'text-yellow-700', bg: 'bg-yellow-50 border-yellow-200', gradient: 'from-yellow-500 to-amber-500' },
  skill:         { label: 'Skill',           color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200', gradient: 'from-purple-500 to-violet-600' },
  sharing:       { label: 'Tauschen',        color: 'text-teal-700',   bg: 'bg-teal-50 border-teal-200',   gradient: 'from-teal-500 to-cyan-600'    },
  community:     { label: 'Community',       color: 'text-violet-700', bg: 'bg-violet-50 border-violet-200', gradient: 'from-violet-500 to-purple-600' },
  crisis:        { label: 'NOTFALL',         color: 'text-red-700',    bg: 'bg-red-100 border-red-400',    gradient: 'from-red-600 to-red-700'      },
  knowledge:     { label: 'Wissen',          color: 'text-emerald-700',bg: 'bg-emerald-50 border-emerald-200', gradient: 'from-emerald-500 to-teal-600' },
  mental:        { label: 'Mentale Hilfe',   color: 'text-cyan-700',   bg: 'bg-cyan-50 border-cyan-200',   gradient: 'from-cyan-500 to-blue-500'    },
  mobility:      { label: 'Mobilität',       color: 'text-indigo-700', bg: 'bg-indigo-50 border-indigo-200', gradient: 'from-indigo-500 to-blue-600' },
}

type Post = {
  id: string; type: string; category?: string; title: string; description?: string
  location_text?: string; contact_phone?: string; contact_whatsapp?: string
  contact_email?: string; urgency?: string; created_at: string; user_id: string
  status?: string; image_urls?: string[]
  profiles?: { name?: string; avatar_url?: string; trust_score?: number; bio?: string; location?: string }
}

type Interaction = {
  id: string; helper_id: string; status: string; message?: string; created_at: string
  profiles?: { name?: string; avatar_url?: string }
}

export default function PostDetailPage() {
  const { id } = useParams<{ id: string }>()
  const router = useRouter()

  const [post, setPost]                   = useState<Post | null>(null)
  const [interactions, setInteractions]   = useState<Interaction[]>([])
  const [currentUserId, setCurrentUserId] = useState<string>()
  const [myInteraction, setMyInteraction] = useState<Interaction | null>(null)
  const [saved, setSaved]                 = useState(false)
  const [loading, setLoading]             = useState(true)
  const [showContactModal, setShowContactModal] = useState(false)
  const [savingLoading, setSavingLoading] = useState(false)

  const load = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setCurrentUserId(user.id)

    const [postRes, interactRes, savedRes] = await Promise.all([
      supabase.from('posts')
        .select('*, profiles(name, avatar_url, trust_score, bio, location)')
        .eq('id', id).single(),
      supabase.from('interactions')
        .select('*, profiles(name, avatar_url)')
        .eq('post_id', id)
        .order('created_at', { ascending: false }),
      user ? supabase.from('saved_posts')
        .select('id').eq('user_id', user.id).eq('post_id', id).maybeSingle() : null,
    ])

    if (postRes.error || !postRes.data) { router.replace('/dashboard/posts'); return }
    setPost(postRes.data)
    setInteractions(interactRes.data ?? [])
    setSaved(!!savedRes?.data)

    if (user) {
      const mine = (interactRes.data ?? []).find((i: Interaction) => i.helper_id === user.id)
      setMyInteraction(mine ?? null)
    }
    setLoading(false)
  }, [id, router])

  useEffect(() => { load() }, [load])

  const handleSave = async () => {
    if (!currentUserId) return
    setSavingLoading(true)
    const supabase = createClient()
    if (saved) {
      await supabase.from('saved_posts').delete().eq('user_id', currentUserId).eq('post_id', id)
      setSaved(false); toast.success('Gespeichert entfernt')
    } else {
      await supabase.from('saved_posts').insert({ user_id: currentUserId, post_id: id })
      setSaved(true); toast.success('Beitrag gespeichert! 🔖')
    }
    setSavingLoading(false)
  }

  const handleShare = () => {
    if (navigator.share) {
      navigator.share({ title: post?.title, url: window.location.href })
    } else {
      navigator.clipboard.writeText(window.location.href)
      toast.success('Link kopiert!')
    }
  }

  const handleInteractionStatus = async (interactionId: string, status: 'accepted' | 'declined') => {
    const supabase = createClient()
    await supabase.from('interactions').update({ status }).eq('id', interactionId)
    toast.success(status === 'accepted' ? 'Helfer angenommen! ✅' : 'Abgelehnt')
    load()
  }

  if (loading) return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
    </div>
  )
  if (!post) return null

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

  const pendingCount  = interactions.filter(i => i.status === 'interested').length
  const acceptedCount = interactions.filter(i => i.status === 'accepted').length

  return (
    <div className="max-w-3xl space-y-5 animate-fade-in">

      {/* Back */}
      <button onClick={() => router.back()}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 transition-colors">
        <ArrowLeft className="w-4 h-4" /> Zurück
      </button>

      {/* Header Card */}
      <div className={cn('rounded-2xl overflow-hidden shadow-sm border',
        isUrgent ? 'border-red-300' : 'border-warm-200')}>

        {isUrgent && (
          <div className="flex items-center gap-2 px-5 py-2 bg-red-500 text-white text-sm font-bold">
            <Flame className="w-4 h-4 animate-pulse" /> DRINGEND – Sofortiger Handlungsbedarf
          </div>
        )}

        <div className={cn('p-6 bg-gradient-to-br text-white', cfg.gradient)}>
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1">
              <span className="inline-block text-xs font-semibold bg-white/20 px-3 py-1 rounded-full mb-3">
                {cfg.label}
              </span>
              <h1 className="text-2xl font-bold leading-tight mb-2">{post.title}</h1>
              <div className="flex flex-wrap items-center gap-3 text-white/80 text-sm">
                {post.location_text && (
                  <span className="flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5" /> {post.location_text}
                  </span>
                )}
                <span className="flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5" /> {ago}
                </span>
                {pendingCount > 0 && (
                  <span className="flex items-center gap-1 bg-white/20 px-2 py-0.5 rounded-full text-xs">
                    <Users className="w-3 h-3" /> {pendingCount} Meldungen
                  </span>
                )}
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={handleSave} disabled={savingLoading}
                className="p-2 rounded-xl bg-white/20 hover:bg-white/30 transition-all"
                title={saved ? 'Gespeichert' : 'Speichern'}>
                {saved ? <BookmarkCheck className="w-5 h-5" /> : <Bookmark className="w-5 h-5" />}
              </button>
              <button onClick={handleShare}
                className="p-2 rounded-xl bg-white/20 hover:bg-white/30 transition-all">
                <Share2 className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="bg-white p-6 space-y-5">

          {/* Beschreibung */}
          {post.description && (
            <p className="text-gray-700 leading-relaxed whitespace-pre-wrap">{post.description}</p>
          )}

          {/* Bilder */}
          {post.image_urls && post.image_urls.length > 0 && (
            <div className="flex gap-2 flex-wrap">
              {post.image_urls.map((url, i) => (
                <img key={i} src={url} alt=""
                  className="h-36 w-36 object-cover rounded-xl border border-warm-200 cursor-pointer hover:opacity-90 transition-opacity"
                  onClick={() => window.open(url, '_blank')} />
              ))}
            </div>
          )}

          {/* Autor-Info */}
          <div className="flex items-center gap-3 p-4 bg-warm-50 rounded-xl border border-warm-200">
            <div className="w-12 h-12 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden flex-shrink-0">
              {post.profiles?.avatar_url
                ? <img src={post.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                : <User className="w-6 h-6 text-primary-600" />}
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-gray-900">{post.profiles?.name ?? 'Nutzer'}</p>
              {post.profiles?.location && (
                <p className="text-xs text-gray-500 flex items-center gap-1">
                  <MapPin className="w-3 h-3" /> {post.profiles.location}
                </p>
              )}
              {post.profiles?.trust_score != null && (
                <div className="flex items-center gap-1 mt-0.5">
                  {[1,2,3,4,5].map(s => (
                    <Star key={s} className={cn('w-3 h-3', s <= (post.profiles?.trust_score ?? 0)
                      ? 'fill-yellow-400 text-yellow-400' : 'text-gray-300')} />
                  ))}
                  <span className="text-xs text-gray-500 ml-1">Vertrauen</span>
                </div>
              )}
            </div>
            {isOwn && (
              <span className="text-xs bg-primary-100 text-primary-700 px-2 py-1 rounded-full font-medium">
                Dein Beitrag
              </span>
            )}
          </div>

          {/* Kontaktmöglichkeiten (immer sichtbar für fremde Posts) */}
          {!isOwn && (
            <div className="space-y-3">
              <h3 className="font-semibold text-gray-900 text-sm">Direkt Kontakt aufnehmen</h3>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
                {/* Interesse melden */}
                <button
                  onClick={() => setShowContactModal(true)}
                  disabled={!!myInteraction}
                  className={cn('flex items-center justify-center gap-2 px-4 py-3 rounded-xl font-medium text-sm transition-all',
                    myInteraction
                      ? 'bg-green-50 text-green-700 border border-green-200 cursor-default'
                      : 'bg-primary-600 hover:bg-primary-700 text-white shadow-sm hover:shadow-md'
                  )}>
                  <Heart className={cn('w-4 h-4', myInteraction && 'fill-green-600')} />
                  {myInteraction ? 'Interesse gemeldet ✓' : 'Interesse melden'}
                </button>

                {/* WhatsApp */}
                {post.contact_whatsapp && (
                  <a href={`https://wa.me/${post.contact_whatsapp.replace(/\D/g, '')}?text=${encodeURIComponent(`Hallo, ich habe deinen Beitrag "${post.title}" auf Mensaena gesehen.`)}`}
                    target="_blank" rel="noopener noreferrer"
                    className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl font-medium text-sm bg-green-600 hover:bg-green-700 text-white transition-all shadow-sm hover:shadow-md">
                    <MessageCircle className="w-4 h-4" /> WhatsApp
                  </a>
                )}

                {/* Anrufen */}
                {post.contact_phone && (
                  <a href={`tel:${post.contact_phone}`}
                    className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl font-medium text-sm bg-blue-600 hover:bg-blue-700 text-white transition-all shadow-sm hover:shadow-md">
                    <Phone className="w-4 h-4" /> {post.contact_phone}
                  </a>
                )}
              </div>

              {myInteraction && (
                <div className="flex items-start gap-3 p-3 bg-green-50 border border-green-200 rounded-xl text-sm text-green-800">
                  <CheckCircle className="w-4 h-4 mt-0.5 flex-shrink-0 text-green-600" />
                  <div>
                    <p className="font-semibold">Du hast dein Interesse gemeldet!</p>
                    {myInteraction.message && <p className="text-green-700 mt-0.5">„{myInteraction.message}"</p>}
                    <p className="text-green-600 text-xs mt-1">
                      Status: {myInteraction.status === 'accepted' ? '✅ Angenommen' :
                               myInteraction.status === 'declined' ? '❌ Abgelehnt' : '⏳ Ausstehend'}
                    </p>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Eigener Post: Wer hat sich gemeldet */}
          {isOwn && interactions.length > 0 && (
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-gray-900">
                  Meldungen ({interactions.length})
                </h3>
                <div className="flex gap-2 text-xs">
                  {pendingCount > 0 && <span className="bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full">{pendingCount} neu</span>}
                  {acceptedCount > 0 && <span className="bg-green-100 text-green-700 px-2 py-0.5 rounded-full">{acceptedCount} angenommen</span>}
                </div>
              </div>
              <div className="space-y-2">
                {interactions.map(interaction => (
                  <InteractionRow
                    key={interaction.id}
                    interaction={interaction}
                    onAccept={() => handleInteractionStatus(interaction.id, 'accepted')}
                    onDecline={() => handleInteractionStatus(interaction.id, 'declined')}
                    post={post}
                  />
                ))}
              </div>
            </div>
          )}

          {isOwn && interactions.length === 0 && (
            <div className="text-center py-6 bg-warm-50 rounded-xl border border-warm-200">
              <Users className="w-8 h-8 text-gray-300 mx-auto mb-2" />
              <p className="text-sm text-gray-500">Noch keine Meldungen</p>
              <p className="text-xs text-gray-400 mt-1">Andere Nutzer können ihr Interesse melden</p>
            </div>
          )}

          {/* Report */}
          {!isOwn && (
            <button className="flex items-center gap-1 text-xs text-gray-400 hover:text-red-500 transition-colors">
              <Flag className="w-3.5 h-3.5" /> Beitrag melden
            </button>
          )}
        </div>
      </div>

      {/* Kontakt-Modal */}
      {showContactModal && (
        <ContactModal
          post={post}
          currentUserId={currentUserId!}
          onClose={() => setShowContactModal(false)}
          onSent={() => { setShowContactModal(false); load() }}
        />
      )}
    </div>
  )
}

// ── Interaction Row ──────────────────────────────────────────────────────────
function InteractionRow({ interaction, onAccept, onDecline, post }: {
  interaction: Interaction
  onAccept: () => void
  onDecline: () => void
  post: Post
}) {
  const whatsappMsg = encodeURIComponent(
    `Hallo ${interaction.profiles?.name ?? ''}, danke für deine Meldung zu "${post.title}" auf Mensaena!${interaction.message ? ` Deine Nachricht: "${interaction.message}"` : ''}`
  )

  return (
    <div className="flex items-start gap-3 p-3 bg-white border border-warm-200 rounded-xl">
      <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden flex-shrink-0">
        {interaction.profiles?.avatar_url
          ? <img src={interaction.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
          : <User className="w-4 h-4 text-primary-600" />}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="font-semibold text-sm text-gray-900">
            {interaction.profiles?.name ?? 'Nutzer'}
          </span>
          <span className={cn('text-xs px-2 py-0.5 rounded-full font-medium',
            interaction.status === 'accepted'  ? 'bg-green-100 text-green-700' :
            interaction.status === 'declined'  ? 'bg-red-100 text-red-700' :
                                                 'bg-amber-100 text-amber-700')}>
            {interaction.status === 'accepted' ? '✅ Angenommen' :
             interaction.status === 'declined' ? '❌ Abgelehnt' : '⏳ Neu'}
          </span>
        </div>
        {interaction.message && (
          <p className="text-sm text-gray-600 mt-0.5 italic">„{interaction.message}"</p>
        )}
        <p className="text-xs text-gray-400 mt-0.5">
          {new Date(interaction.created_at).toLocaleDateString('de-AT', { day:'2-digit', month:'2-digit', hour:'2-digit', minute:'2-digit' })}
        </p>
      </div>
      {interaction.status === 'interested' && (
        <div className="flex flex-col gap-1 flex-shrink-0">
          <button onClick={onAccept}
            className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-green-600 text-white hover:bg-green-700 transition-all">
            <CheckCircle className="w-3.5 h-3.5" /> Annehmen
          </button>
          <button onClick={onDecline}
            className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition-all">
            <XCircle className="w-3.5 h-3.5" /> Ablehnen
          </button>
        </div>
      )}
      {interaction.status === 'accepted' && post.contact_whatsapp && (
        <a href={`https://wa.me/${post.contact_whatsapp.replace(/\D/g,'')}?text=${whatsappMsg}`}
          target="_blank" rel="noopener noreferrer"
          className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-green-50 text-green-700 hover:bg-green-100 transition-all flex-shrink-0">
          <MessageCircle className="w-3.5 h-3.5" /> Kontakt
        </a>
      )}
    </div>
  )
}

// ── Contact Modal ────────────────────────────────────────────────────────────
function ContactModal({ post, currentUserId, onClose, onSent }: {
  post: Post
  currentUserId: string
  onClose: () => void
  onSent: () => void
}) {
  const [message, setMessage] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    const supabase = createClient()

    const { error } = await supabase.from('interactions').upsert({
      post_id: post.id,
      helper_id: currentUserId,
      status: 'interested',
      message: message.trim() || null,
    }, { onConflict: 'post_id,helper_id' })

    setLoading(false)
    if (error) { toast.error('Fehler: ' + error.message); return }
    toast.success('Interesse gemeldet! Der Ersteller wird benachrichtigt 🌿')
    onSent()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 animate-fade-in">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between p-5 border-b border-warm-100">
          <div>
            <h2 className="text-lg font-bold text-gray-900">Interesse melden</h2>
            <p className="text-sm text-gray-500 mt-0.5">für: {post.title}</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-warm-100 text-gray-500 transition-colors">
            ✕
          </button>
        </div>
        <form onSubmit={handleSend} className="p-5 space-y-4">
          <div>
            <label className="label">Nachricht (optional)</label>
            <textarea
              value={message}
              onChange={e => setMessage(e.target.value)}
              placeholder={`z.B. "Hallo, ich kann helfen! Bin verfügbar ab…" oder "Ich interessiere mich, bitte meld dich!"`}
              rows={4}
              className="input resize-none"
            />
          </div>

          {/* Hinweis auf Direktkontakt */}
          {(post.contact_whatsapp || post.contact_phone) && (
            <div className="p-3 bg-blue-50 border border-blue-200 rounded-xl text-sm text-blue-800">
              <p className="font-semibold mb-1">💬 Oder direkt Kontakt aufnehmen:</p>
              <div className="flex gap-2 flex-wrap">
                {post.contact_whatsapp && (
                  <a href={`https://wa.me/${post.contact_whatsapp.replace(/\D/g,'')}?text=${encodeURIComponent(`Hallo, ich habe deinen Beitrag "${post.title}" auf Mensaena gesehen.`)}`}
                    target="_blank" rel="noopener noreferrer"
                    className="flex items-center gap-1 text-xs bg-green-600 text-white px-3 py-1.5 rounded-lg hover:bg-green-700 transition-all">
                    <MessageCircle className="w-3.5 h-3.5" /> WhatsApp
                  </a>
                )}
                {post.contact_phone && (
                  <a href={`tel:${post.contact_phone}`}
                    className="flex items-center gap-1 text-xs bg-blue-600 text-white px-3 py-1.5 rounded-lg hover:bg-blue-700 transition-all">
                    <Phone className="w-3.5 h-3.5" /> {post.contact_phone}
                  </a>
                )}
              </div>
            </div>
          )}

          <div className="flex gap-3">
            <button type="button" onClick={onClose} className="btn-secondary flex-1">Abbrechen</button>
            <button type="submit" disabled={loading} className="btn-primary flex-1">
              {loading
                ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                : <><Send className="w-4 h-4" /> Interesse melden</>}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
