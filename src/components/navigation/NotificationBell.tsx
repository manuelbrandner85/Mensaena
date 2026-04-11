'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import {
  Bell, CheckCheck, X, Filter,
  MessageCircle, Handshake, Star, MapPin,
  MessageSquare, Info, Bot, AtSign, PartyPopper, Clock,
  AlertTriangle, Sparkles, Volume2, VolumeX, Settings,
  Trash2,
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
  comment: MessageSquare,
  new_match: Sparkles,
  match_partner_accepted: Handshake,
  match_both_accepted: Handshake,
  match_expiring: Clock,
  crisis: AlertTriangle,
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
  red: 'bg-red-100 text-red-600',
}

// ── Category filter tabs ────────────────────────────────────────────

type FilterTab = 'all' | 'message' | 'interaction' | 'system'

const FILTER_TABS: { key: FilterTab; label: string; icon: typeof Bell }[] = [
  { key: 'all', label: 'Alle', icon: Bell },
  { key: 'message', label: 'Nachrichten', icon: MessageCircle },
  { key: 'interaction', label: 'Interaktionen', icon: Handshake },
  { key: 'system', label: 'System', icon: Info },
]

const TAB_CATEGORIES: Record<FilterTab, string[]> = {
  all: [],
  message: ['message', 'mention', 'comment'],
  interaction: ['interaction', 'post_response', 'trust_rating', 'new_match', 'match_partner_accepted', 'match_both_accepted', 'match_expiring'],
  system: ['system', 'bot', 'welcome', 'reminder', 'post_nearby', 'crisis'],
}

// ── Component ───────────────────────────────────────────────────────

export default function NotificationBell({ userId }: { userId?: string }) {
  const router = useRouter()
  const ref = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)
  const [notifications, setNotifications] = useState<AppNotification[]>([])
  const [unread, setUnread] = useState(0)
  const [filter, setFilter] = useState<FilterTab>('all')
  const [loading, setLoading] = useState(false)

  // ── Load notifications ──────────────────────────────────────────────
  const loadNotifications = useCallback(async () => {
    if (!userId) return
    setLoading(true)
    const supabase = createClient()

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let query = (supabase.from('notifications') as any)
      .select('*, profiles!notifications_actor_id_fkey(name, avatar_url)')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(20)

    // Apply category filter
    const cats = TAB_CATEGORIES[filter]
    if (cats.length > 0) {
      query = query.in('category', cats)
    }

    const { data } = await query

    if (data) {
      const mapped: AppNotification[] = data.map((n: Record<string, unknown>) => ({
        ...n,
        actor_name: (n.profiles as Record<string, unknown>)?.name ?? null,
        actor_avatar: (n.profiles as Record<string, unknown>)?.avatar_url ?? null,
      })) as AppNotification[]
      setNotifications(mapped)
    }

    // Unread count (all categories, not filtered)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { count } = await (supabase.from('notifications') as any)
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('read', false)
      .is('deleted_at', null)

    setUnread(count ?? 0)
    setLoading(false)
  }, [userId, filter])

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

  // Reload on filter change
  useEffect(() => {
    if (open) loadNotifications()
  }, [filter, open, loadNotifications])

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  // Close on escape
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
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

  // ── Delete single notification ────────────────────────────────────
  const handleDelete = async (e: React.MouseEvent, n: AppNotification) => {
    e.stopPropagation()
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await (supabase.from('notifications') as any)
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', n.id)
    setNotifications((prev) => prev.filter((x) => x.id !== n.id))
    if (!n.read) setUnread((prev) => Math.max(0, prev - 1))
  }

  // Mobile: click navigates directly
  const handleBellClick = () => {
    if (typeof window !== 'undefined' && window.innerWidth < 1024) {
      router.push('/dashboard/notifications')
      return
    }
    setOpen((o) => !o)
  }

  // Count unread per filter (for tab badges)
  const getUnreadForFilter = (tab: FilterTab) => {
    if (tab === 'all') return unread
    const cats = TAB_CATEGORIES[tab]
    return notifications.filter((n) => !n.read && cats.includes(n.category)).length
  }

  return (
    <div ref={ref} className="relative">
      {/* ── Bell button ── */}
      <button
        onClick={handleBellClick}
        className={cn(
          'relative p-2 rounded-xl text-gray-500 hover:bg-warm-100 hover:text-gray-700 transition-colors',
          open && 'bg-warm-100 text-gray-700',
        )}
        title="Benachrichtigungen"
        aria-label={`Benachrichtigungen${unread > 0 ? ` (${unread} ungelesen)` : ''}`}
        aria-expanded={open}
        aria-haspopup="true"
      >
        <Bell className={cn('w-5 h-5', unread > 0 && 'animate-[ring_0.5s_ease-out]')} />
        {unread > 0 && (
          <span className="absolute top-0.5 right-0.5 w-4.5 h-4.5 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-badge-pop shadow-sm">
            {unread > 99 ? '99+' : unread}
          </span>
        )}
      </button>

      {/* ── Desktop Notification Center Dropdown ── */}
      {open && (
        <div
          className="absolute right-0 top-full mt-2 w-[420px] bg-white rounded-2xl shadow-2xl border border-warm-200 z-50 overflow-hidden animate-scale-in"
          role="dialog"
          aria-label="Benachrichtigungs-Center"
        >
          {/* Header */}
          <div className="px-4 py-3 border-b border-warm-100">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <h3 className="font-semibold text-gray-900 text-sm">Benachrichtigungen</h3>
                {unread > 0 && (
                  <span className="px-1.5 py-0.5 bg-red-100 text-red-600 text-[10px] font-bold rounded-full">
                    {unread} neu
                  </span>
                )}
              </div>
              <div className="flex items-center gap-1.5">
                {unread > 0 && (
                  <button
                    onClick={markAllRead}
                    className="flex items-center gap-1 text-xs text-emerald-600 hover:text-emerald-700 font-medium px-2 py-1 rounded-lg hover:bg-emerald-50 transition-colors"
                    title="Alle als gelesen markieren"
                  >
                    <CheckCheck className="w-3.5 h-3.5" />
                    Alle gelesen
                  </button>
                )}
                <Link
                  href="/dashboard/settings?tab=notifications"
                  onClick={() => setOpen(false)}
                  className="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-50 transition-colors"
                  title="Benachrichtigungs-Einstellungen"
                >
                  <Settings className="w-3.5 h-3.5" />
                </Link>
                <button onClick={() => setOpen(false)} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-50 transition-colors">
                  <X className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>

            {/* Category filter tabs */}
            <div className="flex gap-1">
              {FILTER_TABS.map((tab) => {
                const TabIcon = tab.icon
                const tabUnread = getUnreadForFilter(tab.key)
                return (
                  <button
                    key={tab.key}
                    onClick={() => setFilter(tab.key)}
                    className={cn(
                      'flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all',
                      filter === tab.key
                        ? 'bg-emerald-100 text-emerald-700 shadow-sm'
                        : 'text-gray-500 hover:bg-gray-100 hover:text-gray-700',
                    )}
                  >
                    <TabIcon className="w-3 h-3" />
                    {tab.label}
                    {tabUnread > 0 && tab.key !== 'all' && (
                      <span className="w-4 h-4 bg-red-500 text-white text-[8px] font-bold rounded-full flex items-center justify-center">
                        {tabUnread > 9 ? '9+' : tabUnread}
                      </span>
                    )}
                  </button>
                )
              })}
            </div>
          </div>

          {/* Notification list */}
          <div className="max-h-[420px] overflow-y-auto">
            {loading && notifications.length === 0 ? (
              <div className="py-10 text-center">
                <div className="w-6 h-6 border-2 border-emerald-200 border-t-emerald-500 rounded-full animate-spin mx-auto mb-2" />
                <p className="text-xs text-gray-400">Laden...</p>
              </div>
            ) : notifications.length === 0 ? (
              <div className="py-10 text-center">
                <Bell className="w-8 h-8 text-gray-200 mx-auto mb-2" />
                <p className="text-sm text-gray-400">Keine Benachrichtigungen</p>
                <p className="text-xs text-gray-300 mt-1">
                  {filter !== 'all' ? 'Keine Benachrichtigungen in dieser Kategorie' : 'Du bist auf dem neuesten Stand!'}
                </p>
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
                      'w-full text-left flex items-start gap-3 px-4 py-3 hover:bg-gray-50 transition-colors border-b border-warm-50 last:border-0 group relative',
                      !n.read && 'bg-emerald-50/40',
                    )}
                  >
                    {/* Unread indicator bar */}
                    {!n.read && (
                      <div className="absolute left-0 top-0 bottom-0 w-0.5 bg-emerald-500 rounded-r" />
                    )}

                    {/* Avatar or icon */}
                    <div className="flex-shrink-0 mt-0.5">
                      {n.actor_avatar ? (
                        <Image
                          src={n.actor_avatar}
                          alt={n.actor_name || ''}
                          width={36}
                          height={36}
                          className="w-9 h-9 rounded-full object-cover ring-2 ring-white shadow-sm"
                        />
                      ) : (
                        <div className={cn('w-9 h-9 rounded-full flex items-center justify-center shadow-sm', colorClass)}>
                          <IconComp className="w-4 h-4" />
                        </div>
                      )}
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <p className={cn(
                        'text-sm leading-snug',
                        n.read ? 'text-gray-600' : 'text-gray-900 font-medium',
                      )}>
                        {n.actor_name && <span className="font-semibold">{n.actor_name} </span>}
                        {n.title || n.content}
                      </p>
                      {n.content && n.title && (
                        <p className="text-xs text-gray-500 line-clamp-2 mt-0.5">{n.content}</p>
                      )}
                      <div className="flex items-center gap-2 mt-1">
                        <p className="text-[11px] text-gray-400">{formatRelativeTime(n.created_at)}</p>
                        {!n.read && (
                          <span className="text-[10px] font-semibold text-emerald-600 bg-emerald-100 px-1.5 py-0.5 rounded-full">
                            Neu
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex flex-col items-center gap-1 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        onClick={(e) => handleDelete(e, n)}
                        className="p-1 rounded-lg text-gray-300 hover:text-red-500 hover:bg-red-50 transition-colors"
                        title="Löschen"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>

                    {/* Unread dot (fallback) */}
                    {!n.read && <div className="w-2 h-2 bg-emerald-500 rounded-full mt-2 flex-shrink-0 group-hover:hidden" />}
                  </button>
                )
              })
            )}
          </div>

          {/* Footer */}
          <div className="px-4 py-2.5 border-t border-warm-100 flex items-center justify-between bg-gray-50/50">
            <Link
              href="/dashboard/notifications"
              onClick={() => setOpen(false)}
              className="text-sm text-emerald-600 hover:text-emerald-700 font-medium hover:underline"
            >
              Alle ansehen
            </Link>
            <span className="text-[10px] text-gray-400">
              {notifications.length} von {unread > 0 ? `${unread} ungelesen` : 'allen'}
            </span>
          </div>
        </div>
      )}
    </div>
  )
}
