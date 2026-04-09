'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import {
  MoreHorizontal, Eye, EyeOff, Trash2,
  MessageCircle, Handshake, Star, MapPin,
  MessageSquare, Info, Bot, AtSign, PartyPopper, Clock, Bell,
  MessageSquareText,
} from 'lucide-react'
import Image from 'next/image'
import { cn } from '@/lib/utils'
import { formatRelativeTime, getNotificationColor, getNotificationCategoryLabel } from '@/lib/notifications'
import type { AppNotification } from '@/types'

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

const COLOR_MAP: Record<string, string> = {
  blue: 'bg-blue-100 text-blue-600',
  emerald: 'bg-emerald-100 text-emerald-600',
  amber: 'bg-amber-100 text-amber-600',
  purple: 'bg-purple-100 text-purple-600',
  indigo: 'bg-indigo-100 text-indigo-600',
  gray: 'bg-gray-100 text-gray-600',
  pink: 'bg-pink-100 text-pink-600',
  orange: 'bg-orange-100 text-orange-600',
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
  const menuRef = useRef<HTMLDivElement>(null)

  const n = notification
  const IconComp = ICON_MAP[n.category] || Bell
  const colorName = getNotificationColor(n.category)
  const colorClass = COLOR_MAP[colorName] || COLOR_MAP.gray
  const categoryLabel = getNotificationCategoryLabel(n.category)

  // Close menu on outside click
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

  return (
    <div
      className={cn(
        'flex items-start gap-3 px-4 py-3 transition-colors cursor-pointer border-b border-gray-50 last:border-0 group',
        n.read
          ? 'hover:bg-gray-50'
          : 'bg-emerald-50/40 hover:bg-emerald-50/70',
      )}
      onClick={handleClick}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => { if (e.key === 'Enter') handleClick() }}
    >
      {/* ── Avatar or Category Icon ── */}
      <div className="flex-shrink-0 mt-0.5">
        {n.actor_avatar ? (
          <Image
            src={n.actor_avatar}
            alt={n.actor_name || ''}
            width={40}
            height={40}
            className="w-10 h-10 rounded-full object-cover"
          />
        ) : (
          <div className={cn('w-10 h-10 rounded-full flex items-center justify-center', colorClass)}>
            <IconComp className="w-5 h-5" />
          </div>
        )}
      </div>

      {/* ── Content ── */}
      <div className="flex-1 min-w-0">
        <div className="flex items-start gap-2">
          <div className="flex-1 min-w-0">
            {n.title && (
              <p className={cn(
                'text-sm font-medium truncate',
                n.read ? 'text-gray-700' : 'text-gray-900',
              )}>
                {n.actor_name && (
                  <span className="font-semibold">{n.actor_name} </span>
                )}
                {n.title}
              </p>
            )}
            {n.content && (
              <p className="text-sm text-gray-500 line-clamp-2 mt-0.5">{n.content}</p>
            )}
          </div>

          {/* ── Unread indicator ── */}
          {!n.read && (
            <div className="w-2 h-2 bg-emerald-500 rounded-full mt-1.5 flex-shrink-0" />
          )}
        </div>

        {/* ── Meta row ── */}
        <div className="flex items-center gap-2 mt-1.5">
          <span className="text-xs text-gray-400">{formatRelativeTime(n.created_at)}</span>
          <span className={cn(
            'text-[10px] font-medium px-1.5 py-0.5 rounded-full',
            colorClass,
          )}>
            {categoryLabel}
          </span>
        </div>
      </div>

      {/* ── Three-dot menu ── */}
      <div ref={menuRef} className="relative flex-shrink-0" onBlur={handleBlur}>
        <button
          onClick={(e) => { e.stopPropagation(); setMenuOpen((o) => !o) }}
          className="p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100"
          aria-label="Mehr Optionen"
        >
          <MoreHorizontal className="w-4 h-4" />
        </button>

        {menuOpen && (
          <div className="absolute right-0 top-full mt-1 w-48 bg-white rounded-xl shadow-xl border border-gray-100 py-1 z-30 animate-scale-in">
            <button
              onClick={(e) => {
                e.stopPropagation()
                n.read ? onMarkAsUnread(n.id) : onMarkAsRead(n.id)
                setMenuOpen(false)
              }}
              className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
            >
              {n.read ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              {n.read ? 'Als ungelesen markieren' : 'Als gelesen markieren'}
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation()
                onDelete(n.id)
                setMenuOpen(false)
              }}
              className="w-full flex items-center gap-2 px-3 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors"
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
