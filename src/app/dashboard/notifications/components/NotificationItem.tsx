'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import {
  MoreHorizontal, Eye, EyeOff, Trash2,
  MessageCircle, Handshake, Star, MapPin,
  MessageSquare, Info, Bot, AtSign, PartyPopper, Clock, Bell,
  MessageSquareText, Check, X,
} from 'lucide-react'
import Image from 'next/image'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'
import { formatRelativeTime, getNotificationColor, getNotificationCategoryLabel } from '@/lib/notifications'
import type { AppNotification } from '@/types'
import { useInteractionStore } from '@/app/dashboard/interactions/stores/useInteractionStore'

// ── Icon map ────────────────────────────────────────────────────────

const ICON_MAP: Record<string, typeof Bell> = {
  message: MessageCircle,
  interaction: Handshake,
  trust_rating: Star,
  post_nearby: MapPin,
  post_response: MessageSquare,
  system: Info,
  bot: Bot,
  mention: AtSign,
  welcome: PartyPopper,
  reminder: Clock,
  comment: MessageSquareText,
}

const COLOR_MAP: Record<string, { bg: string; icon: string; dot: string }> = {
  blue:    { bg: 'bg-blue-50',    icon: 'bg-blue-100 text-blue-600',    dot: 'bg-blue-500' },
  primary: { bg: 'bg-primary-50', icon: 'bg-primary-100 text-primary-600', dot: 'bg-primary-500' },
  amber:   { bg: 'bg-amber-50',   icon: 'bg-amber-100 text-amber-600',   dot: 'bg-amber-500' },
  purple:  { bg: 'bg-purple-50',  icon: 'bg-purple-100 text-purple-600',  dot: 'bg-purple-500' },
  indigo:  { bg: 'bg-indigo-50',  icon: 'bg-indigo-100 text-indigo-600',  dot: 'bg-indigo-500' },
  gray:    { bg: 'bg-stone-50',   icon: 'bg-stone-100 text-ink-600',     dot: 'bg-stone-400' },
  pink:    { bg: 'bg-pink-50',    icon: 'bg-pink-100 text-pink-600',     dot: 'bg-pink-500' },
  orange:  { bg: 'bg-orange-50',  icon: 'bg-orange-100 text-orange-600', dot: 'bg-orange-500' },
}

const BADGE_MAP: Record<string, string> = {
  blue:    'bg-blue-100 text-blue-700',
  primary: 'bg-primary-100 text-primary-700',
  amber:   'bg-amber-100 text-amber-700',
  purple:  'bg-purple-100 text-purple-700',
  indigo:  'bg-indigo-100 text-indigo-700',
  gray:    'bg-stone-100 text-ink-600',
  pink:    'bg-pink-100 text-pink-700',
  orange:  'bg-orange-100 text-orange-700',
}

// ── Quick Actions ────────────────────────────────────────────────────

function InteractionQuickActions({ notification, onMarkAsRead }: {
  notification: AppNotification
  onMarkAsRead: (id: string) => Promise<void>
}) {
  const [busy, setBusy] = useState<'accept' | 'decline' | null>(null)
  const [done, setDone] = useState<'accepted' | 'declined' | null>(null)
  const respondToInteraction = useInteractionStore((s) => s.respondToInteraction)

  const interactionId = notification.metadata?.interaction_id as string | undefined
  if (!interactionId) return null
  if (done) return (
    <span className={cn(
      'inline-flex items-center gap-1 text-xs font-medium mt-2',
      done === 'accepted' ? 'text-green-600' : 'text-ink-400',
    )}>
      {done === 'accepted' ? <Check className="w-3 h-3" /> : <X className="w-3 h-3" />}
      {done === 'accepted' ? 'Angenommen' : 'Abgelehnt'}
    </span>
  )

  async function respond(accept: boolean) {
    setBusy(accept ? 'accept' : 'decline')
    try {
      await respondToInteraction(interactionId!, accept)
      await onMarkAsRead(notification.id)
      setDone(accept ? 'accepted' : 'declined')
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="flex items-center gap-2 mt-3" onClick={(e) => e.stopPropagation()}>
      <button
        onClick={() => respond(true)}
        disabled={!!busy}
        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-primary-600 text-white text-xs font-medium hover:bg-primary-700 disabled:opacity-50 transition-colors"
      >
        <Check className="w-3.5 h-3.5" />
        {busy === 'accept' ? 'Wird angenommen…' : 'Annehmen'}
      </button>
      <button
        onClick={() => respond(false)}
        disabled={!!busy}
        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-stone-200 text-ink-600 text-xs font-medium hover:bg-stone-100 disabled:opacity-50 transition-colors"
      >
        <X className="w-3.5 h-3.5" />
        {busy === 'decline' ? 'Wird abgelehnt…' : 'Ablehnen'}
      </button>
    </div>
  )
}

// ── Props ───────────────────────────────────────────────────────────

interface Props {
  notification: AppNotification
  onMarkAsRead: (id: string) => Promise<void>
  onMarkAsUnread: (id: string) => Promise<void>
  onDelete: (id: string) => Promise<void>
}

export default function NotificationItem({ notification, onMarkAsRead, onMarkAsUnread, onDelete }: Props) {
  const router = useRouter()
  const [menuOpen, setMenuOpen] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  const n = notification
  const IconComp = ICON_MAP[n.category] || Bell
  const colorName = getNotificationColor(n.category)
  const colors = COLOR_MAP[colorName] || COLOR_MAP.gray
  const badgeClass = BADGE_MAP[colorName] || BADGE_MAP.gray
  const categoryLabel = getNotificationCategoryLabel(n.category)

  const handleBlur = () => {
    setTimeout(() => {
      if (menuRef.current && !menuRef.current.contains(document.activeElement)) {
        setMenuOpen(false)
      }
    }, 150)
  }

  const handleClick = () => {
    if (!n.read) onMarkAsRead(n.id)
    if (n.link) router.push(n.link)
  }

  const handleDelete = async (e: React.MouseEvent) => {
    e.stopPropagation()
    setMenuOpen(false)
    setDeleting(true)
    try {
      await onDelete(n.id)
    } catch {
      setDeleting(false)
      toast.error('Löschen fehlgeschlagen')
    }
  }

  return (
    <div
      className={cn(
        'group relative flex items-start gap-3 px-4 py-4 transition-all duration-200 border-b border-stone-100 last:border-0',
        n.read
          ? 'bg-white hover:bg-stone-50/80'
          : 'bg-primary-50/30 hover:bg-primary-50/60',
        n.link ? 'cursor-pointer' : 'cursor-default',
        deleting && 'opacity-40 pointer-events-none',
      )}
      onClick={handleClick}
      role={n.link ? 'button' : undefined}
      tabIndex={n.link ? 0 : undefined}
      onKeyDown={(e) => { if (e.key === 'Enter' && n.link) handleClick() }}
    >
      {/* ── Unread stripe ── */}
      {!n.read && (
        <div className="absolute left-0 top-3 bottom-3 w-0.5 rounded-r bg-primary-500" />
      )}

      {/* ── Avatar or Icon ── */}
      <div className="flex-shrink-0 mt-0.5">
        {n.actor_avatar ? (
          <div className="relative">
            <Image
              src={n.actor_avatar}
              alt={n.actor_name || ''}
              width={40}
              height={40}
              className="w-10 h-10 rounded-full object-cover ring-2 ring-white"
            />
            <div className={cn(
              'absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full flex items-center justify-center ring-2 ring-white',
              colors.icon,
            )}>
              <IconComp className="w-3 h-3" />
            </div>
          </div>
        ) : (
          <div className={cn(
            'w-10 h-10 rounded-xl flex items-center justify-center',
            colors.icon,
          )}>
            <IconComp className="w-5 h-5" />
          </div>
        )}
      </div>

      {/* ── Content ── */}
      <div className="flex-1 min-w-0 pr-8">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <p className={cn(
              'text-sm leading-snug',
              n.read ? 'text-ink-600' : 'text-ink-900 font-medium',
            )}>
              {n.actor_name && (
                <span className="font-semibold text-ink-900">{n.actor_name} </span>
              )}
              {n.title}
            </p>
            {n.content && (
              <p className="text-sm text-ink-400 line-clamp-2 mt-0.5 leading-snug">{n.content}</p>
            )}
          </div>
          {/* Unread dot */}
          {!n.read && (
            <div className={cn('w-2 h-2 rounded-full flex-shrink-0 mt-1.5', colors.dot)} />
          )}
        </div>

        {/* ── Meta ── */}
        <div className="flex items-center gap-2 mt-1.5 flex-wrap">
          <span className="text-xs text-ink-400 tabular-nums">
            {formatRelativeTime(n.created_at)}
          </span>
          <span className={cn('text-xs font-medium px-1.5 py-0.5 rounded-full', badgeClass)}>
            {categoryLabel}
          </span>
        </div>

        {/* ── Quick Actions for interaction_request ── */}
        {n.type === 'interaction_request' && !n.read && (
          <InteractionQuickActions notification={n} onMarkAsRead={onMarkAsRead} />
        )}
      </div>

      {/* ── Three-dot menu ── */}
      <div
        ref={menuRef}
        className="absolute right-3 top-3"
        onBlur={handleBlur}
      >
        <button
          onClick={(e) => { e.stopPropagation(); setMenuOpen((o) => !o) }}
          className={cn(
            'p-1.5 rounded-lg text-ink-400 hover:bg-stone-100 hover:text-ink-600 transition-all',
            'opacity-0 group-hover:opacity-100 focus:opacity-100',
            menuOpen && 'opacity-100 bg-stone-100',
          )}
          aria-label="Optionen"
        >
          <MoreHorizontal className="w-4 h-4" />
        </button>

        {menuOpen && (
          <div className="absolute right-0 top-full mt-1 w-52 bg-white rounded-xl shadow-card border border-stone-100 py-1 z-30 animate-scale-in">
            <button
              onClick={(e) => {
                e.stopPropagation()
                n.read ? onMarkAsUnread(n.id) : onMarkAsRead(n.id)
                setMenuOpen(false)
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2.5 text-sm text-ink-700 hover:bg-stone-50 transition-colors"
            >
              {n.read
                ? <EyeOff className="w-4 h-4 text-ink-400" />
                : <Eye className="w-4 h-4 text-ink-400" />
              }
              {n.read ? 'Als ungelesen markieren' : 'Als gelesen markieren'}
            </button>
            <div className="h-px bg-stone-100 mx-2 my-1" />
            <button
              onClick={handleDelete}
              className="w-full flex items-center gap-2.5 px-3 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors"
            >
              <Trash2 className="w-4 h-4" />
              Löschen
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
