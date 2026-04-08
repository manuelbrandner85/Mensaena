'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import {
  Bell, CheckCheck, X,
  MessageCircle, Handshake, Star, MapPin,
  MessageSquare, Info, Bot, AtSign, PartyPopper, Clock,
} from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { formatRelativeTime, getNotificationColor } from '@/lib/notifications'
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

// ── Component ───────────────────────────────────────────────────────

export default function NotificationBell({ userId }: { userId?: string }) {
  const router = useRouter()
  const ref = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)
  const [notifications, setNotifications] = useState<AppNotification[]>([])
  const [unread, setUnread] = useState(0)

  // ── Load last 5 unread + realtime ──────────────────────────────────
  const loadNotifications = useCallback(async () => {
    if (!userId) return
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { data } = await (supabase.from('notifications') as any)
      .select('*, profiles!notifications_actor_id_fkey(name, avatar_url)')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(5)

    if (data) {
      const mapped: AppNotification[] = data.map((n: Record<string, unknown>) => ({
        ...n,
        actor_name: (n.profiles as Record<string, unknown>)?.name ?? null,
        actor_avatar: (n.profiles as Record<string, unknown>)?.avatar_url ?? null,
      })) as AppNotification[]
      setNotifications(mapped)
    }

    // Unread count (all, not just 5)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { count } = await (supabase.from('notifications') as any)
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('read', false)
      .is('deleted_at', null)

    setUnread(count ?? 0)
  }, [userId])

  useEffect(() => {
    loadNotifications()
    if (!userId) return

    const supabase = createClient()
    const channel = supabase
      .channel(`bell-notifs:${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${userId}`,
      }, () => {
        loadNotifications()
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [userId, loadNotifications])

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  // ── Mark all as read ──────────────────────────────────────────────
  const markAllRead = async () => {
    if (!userId) return
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await (supabase.from('notifications') as any)
      .update({ read: true })
      .eq('user_id', userId)
      .eq('read', false)
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
    setUnread(0)
  }

  // ── Mark single as read and navigate ──────────────────────────────
  const handleItemClick = async (n: AppNotification) => {
    if (!n.read) {
      const supabase = createClient()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (supabase.from('notifications') as any)
        .update({ read: true })
        .eq('id', n.id)
      setNotifications((prev) => prev.map((x) => x.id === n.id ? { ...x, read: true } : x))
      setUnread((prev) => Math.max(0, prev - 1))
    }
    setOpen(false)
    if (n.link) router.push(n.link)
  }

  // Mobile: click navigates directly
  const handleBellClick = () => {
    // On small screens navigate directly
    if (typeof window !== 'undefined' && window.innerWidth < 1024) {
      router.push('/dashboard/notifications')
      return
    }
    setOpen((o) => !o)
  }

  return (
    <div ref={ref} className="relative">
      {/* ── Bell button ── */}
      <button
        onClick={handleBellClick}
        className="relative p-2 rounded-xl text-gray-500 hover:bg-warm-100 hover:text-gray-700 transition-colors"
        title="Benachrichtigungen"
        aria-label={`Benachrichtigungen${unread > 0 ? ` (${unread} ungelesen)` : ''}`}
      >
        <Bell className="w-5 h-5" />
        {unread > 0 && (
          <span className="absolute top-0.5 right-0.5 w-4 h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-badge-pop">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>

      {/* ── Desktop dropdown ── */}
      {open && (
        <div className="absolute right-0 top-full mt-2 w-96 bg-white rounded-2xl shadow-2xl border border-warm-200 z-50 overflow-hidden animate-scale-in">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 border-b border-warm-100">
            <h3 className="font-semibold text-gray-900 text-sm">Benachrichtigungen</h3>
            <div className="flex items-center gap-2">
              {unread > 0 && (
                <button
                  onClick={markAllRead}
                  className="flex items-center gap-1 text-xs text-emerald-600 hover:text-emerald-700 font-medium"
                  title="Alle als gelesen markieren"
                >
                  <CheckCheck className="w-3.5 h-3.5" />
                  Alle gelesen
                </button>
              )}
              <button onClick={() => setOpen(false)} className="text-gray-400 hover:text-gray-600">
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Notification list */}
          <div className="max-h-80 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="py-10 text-center">
                <Bell className="w-8 h-8 text-gray-200 mx-auto mb-2" />
                <p className="text-sm text-gray-400">Keine Benachrichtigungen</p>
              </div>
            ) : (
              notifications.map((n) => {
                const IconComp = ICON_MAP[n.category] || Bell
                const colorName = getNotificationColor(n.category)
                const colorClass = COLOR_MAP[colorName] || COLOR_MAP.gray

                return (
                  <button
                    key={n.id}
                    onClick={() => handleItemClick(n)}
                    className={cn(
                      'w-full text-left flex items-start gap-3 px-4 py-3 hover:bg-gray-50 transition-colors border-b border-warm-50 last:border-0',
                      !n.read && 'bg-emerald-50/40',
                    )}
                  >
                    {/* Avatar or icon */}
                    <div className="flex-shrink-0 mt-0.5">
                      {n.actor_avatar ? (
                        <Image
                          src={n.actor_avatar}
                          alt={n.actor_name || ''}
                          width={36}
                          height={36}
                          className="w-9 h-9 rounded-full object-cover"
                        />
                      ) : (
                        <div className={cn('w-9 h-9 rounded-full flex items-center justify-center', colorClass)}>
                          <IconComp className="w-4 h-4" />
                        </div>
                      )}
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <p className={cn(
                        'text-sm truncate',
                        n.read ? 'text-gray-600' : 'text-gray-900 font-medium',
                      )}>
                        {n.actor_name && <span className="font-semibold">{n.actor_name} </span>}
                        {n.title || n.content}
                      </p>
                      {n.content && n.title && (
                        <p className="text-xs text-gray-500 truncate mt-0.5">{n.content}</p>
                      )}
                      <p className="text-xs text-gray-400 mt-0.5">{formatRelativeTime(n.created_at)}</p>
                    </div>

                    {!n.read && <div className="w-2 h-2 bg-emerald-500 rounded-full mt-2 flex-shrink-0" />}
                  </button>
                )
              })
            )}
          </div>

          {/* Footer */}
          <div className="px-4 py-2.5 border-t border-warm-100 text-center">
            <Link
              href="/dashboard/notifications"
              onClick={() => setOpen(false)}
              className="text-sm text-emerald-600 hover:text-emerald-700 font-medium hover:underline"
            >
              Alle Benachrichtigungen ansehen
            </Link>
          </div>
        </div>
      )}
    </div>
  )
}
