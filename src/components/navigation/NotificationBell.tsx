'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import {
  Bell, CheckCheck, X,
  MessageCircle, Handshake, Star, MapPin,
  MessageSquare, Info, Bot, AtSign, PartyPopper, Clock,
  AlertTriangle, Sparkles, Settings,
  Trash2,
} from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import { formatRelativeTime, getNotificationColor } from '@/lib/notifications'
import { useNotificationStore } from '@/store/useNotificationStore'
import { useMobile } from '@/hooks/mobile/useMobile'
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
  primary: 'bg-primary-100 text-primary-600',
  amber: 'bg-amber-100 text-amber-600',
  purple: 'bg-purple-100 text-purple-600',
  indigo: 'bg-indigo-100 text-indigo-600',
  gray: 'bg-stone-100 text-ink-600',
  pink: 'bg-pink-100 text-pink-600',
  orange: 'bg-orange-100 text-orange-600',
  red: 'bg-red-100 text-red-600',
}

// ── Category filter tabs ────────────────────────────────────────────

type FilterTab = 'all' | 'message' | 'interaction' | 'system'

const FILTER_TABS: { key: FilterTab; icon: typeof Bell }[] = [
  { key: 'all', icon: Bell },
  { key: 'message', icon: MessageCircle },
  { key: 'interaction', icon: Handshake },
  { key: 'system', icon: Info },
]

const TAB_CATEGORIES: Record<FilterTab, string[]> = {
  all: [],
  message: ['message', 'mention', 'comment'],
  interaction: ['interaction', 'post_response', 'trust_rating', 'new_match', 'match_partner_accepted', 'match_both_accepted', 'match_expiring'],
  system: ['system', 'bot', 'welcome', 'reminder', 'post_nearby', 'crisis'],
}

// ── Component ───────────────────────────────────────────────────────

export default function NotificationBell({ userId }: { userId?: string }) {
  const t = useTranslations('notifications')
  const router = useRouter()
  const ref = useRef<HTMLDivElement>(null)
  const { isDesktop } = useMobile()

  const tabLabels: Record<FilterTab, string> = useMemo(() => ({
    all: t('tabAll'),
    message: t('tabMessages'),
    interaction: t('tabInteractions'),
    system: t('tabSystem'),
  }), [t])
  const [open, setOpen] = useState(false)
  const [filter, setFilter] = useState<FilterTab>('all')

  // ── Store-backed state (single source of truth, single realtime channel) ─
  const notifications = useNotificationStore((s) => s.notifications)
  const unread = useNotificationStore((s) => s.unreadCount)
  const loading = useNotificationStore((s) => s.loading)
  const loadNotifications = useNotificationStore((s) => s.loadNotifications)
  const loadUnreadCounts = useNotificationStore((s) => s.loadUnreadCounts)
  const subscribeToRealtime = useNotificationStore((s) => s.subscribeToRealtime)
  const markAsReadStore = useNotificationStore((s) => s.markAsRead)
  const markAllAsReadStore = useNotificationStore((s) => s.markAllAsRead)
  const deleteNotificationStore = useNotificationStore((s) => s.deleteNotification)

  // ── Mount: wire userId, fetch counts, subscribe (deduplicated in store) ─
  useEffect(() => {
    if (!userId) return
    useNotificationStore.setState({ _userId: userId })
    loadUnreadCounts()
    subscribeToRealtime(userId)
    // Lazy: only load list if it's still empty
    if (useNotificationStore.getState().notifications.length === 0) {
      loadNotifications('all', 1)
    }
  }, [userId, subscribeToRealtime, loadUnreadCounts, loadNotifications])

  // ── Client-side visual filter (tabs only filter what's in the store) ──
  const filteredNotifications = useMemo(() => {
    const cats = TAB_CATEGORIES[filter]
    if (cats.length === 0) return notifications.slice(0, 20)
    return notifications.filter((n) => cats.includes(n.category)).slice(0, 20)
  }, [notifications, filter])

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
    await markAllAsReadStore()
  }

  // ── Mark single as read and navigate ──────────────────────────────
  const handleItemClick = async (n: AppNotification) => {
    if (!n.read) await markAsReadStore(n.id)
    setOpen(false)
    if (n.link) router.push(n.link)
  }

  // ── Delete single notification ────────────────────────────────────
  const handleDelete = async (e: React.MouseEvent, n: AppNotification) => {
    e.stopPropagation()
    await deleteNotificationStore(n.id)
  }

  // Mobile/tablet (< 1024px): click navigates directly to full page.
  // Uses useMobile (matchMedia + resize listener) so live resizing works.
  const handleBellClick = () => {
    if (!isDesktop) {
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
          'relative p-2 rounded-xl text-ink-500 hover:bg-warm-100 hover:text-ink-700 transition-colors',
          open && 'bg-warm-100 text-ink-700',
        )}
        title={t('buttonTitle')}
        aria-label={unread > 0 ? t('buttonAriaUnread', { count: unread }) : t('buttonTitle')}
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
          aria-label={t('center')}
        >
          {/* Header */}
          <div className="px-4 py-3 border-b border-warm-100">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <h3 className="font-semibold text-ink-900 text-sm">{t('title')}</h3>
                {unread > 0 && (
                  <span className="px-1.5 py-0.5 bg-red-100 text-red-600 text-xs font-bold rounded-full">
                    {unread} {t('new')}
                  </span>
                )}
              </div>
              <div className="flex items-center gap-1.5">
                {unread > 0 && (
                  <button
                    onClick={markAllRead}
                    className="flex items-center gap-1 text-xs text-primary-600 hover:text-primary-700 font-medium px-2 py-1 rounded-lg hover:bg-primary-50 transition-colors"
                    title={t('markAllReadTitle')}
                  >
                    <CheckCheck className="w-3.5 h-3.5" />
                    {t('markAllRead')}
                  </button>
                )}
                <Link
                  href="/dashboard/settings?tab=notifications"
                  onClick={() => setOpen(false)}
                  className="p-1.5 rounded-lg text-ink-400 hover:text-ink-600 hover:bg-stone-50 transition-colors"
                  title={t('settingsTitle')}
                >
                  <Settings className="w-3.5 h-3.5" />
                </Link>
                <button onClick={() => setOpen(false)} className="p-1.5 rounded-lg text-ink-400 hover:text-ink-600 hover:bg-stone-50 transition-colors">
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
                        ? 'bg-primary-100 text-primary-700 shadow-sm'
                        : 'text-ink-500 hover:bg-stone-100 hover:text-ink-700',
                    )}
                  >
                    <TabIcon className="w-3 h-3" />
                    {tabLabels[tab.key]}
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
            {loading && filteredNotifications.length === 0 ? (
              <div className="py-10 text-center">
                <div className="w-6 h-6 border-2 border-primary-200 border-t-primary-500 rounded-full animate-spin mx-auto mb-2" />
                <p className="text-xs text-ink-400">{t('loading')}</p>
              </div>
            ) : filteredNotifications.length === 0 ? (
              <div className="py-10 text-center">
                <Bell className="w-8 h-8 text-stone-300 mx-auto mb-2" />
                <p className="text-sm text-ink-400">{t('empty')}</p>
                <p className="text-xs text-stone-400 mt-1">
                  {filter !== 'all' ? t('emptyCategory') : t('emptyUpToDate')}
                </p>
              </div>
            ) : (
              filteredNotifications.map((n) => {
                const IconComp = ICON_MAP[n.category] || Bell
                const colorName = getNotificationColor(n.category)
                const colorClass = COLOR_MAP[colorName] || COLOR_MAP.gray

                return (
                  <button
                    key={n.id}
                    onClick={() => handleItemClick(n)}
                    className={cn(
                      'w-full text-left flex items-start gap-3 px-4 py-3 hover:bg-stone-50 transition-colors border-b border-warm-50 last:border-0 group relative',
                      !n.read && 'bg-primary-50/40',
                    )}
                  >
                    {/* Unread indicator bar */}
                    {!n.read && (
                      <div className="absolute left-0 top-0 bottom-0 w-0.5 bg-primary-500 rounded-r" />
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
                        n.read ? 'text-ink-600' : 'text-ink-900 font-medium',
                      )}>
                        {n.actor_name && <span className="font-semibold">{n.actor_name} </span>}
                        {n.title || n.content}
                      </p>
                      {n.content && n.title && (
                        <p className="text-xs text-ink-500 line-clamp-2 mt-0.5">{n.content}</p>
                      )}
                      <div className="flex items-center gap-2 mt-1">
                        <p className="text-[11px] text-ink-400">{formatRelativeTime(n.created_at)}</p>
                        {!n.read && (
                          <span className="text-xs font-semibold text-primary-600 bg-primary-100 px-1.5 py-0.5 rounded-full">
                            {t('newBadge')}
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex flex-col items-center gap-1 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        onClick={(e) => handleDelete(e, n)}
                        className="p-1 rounded-lg text-stone-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                        title={t('delete')}
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>

                    {/* Unread dot (fallback) */}
                    {!n.read && <div className="w-2 h-2 bg-primary-500 rounded-full mt-2 flex-shrink-0 group-hover:hidden" />}
                  </button>
                )
              })
            )}
          </div>

          {/* Footer */}
          <div className="px-4 py-2.5 border-t border-warm-100 flex items-center justify-between bg-stone-50/50">
            <Link
              href="/dashboard/notifications"
              onClick={() => setOpen(false)}
              className="text-sm text-primary-600 hover:text-primary-700 font-medium hover:underline"
            >
              {t('viewAll')}
            </Link>
            <span className="text-xs text-ink-400">
              {unread > 0
                ? t('countOfUnread', { shown: filteredNotifications.length, total: unread })
                : t('countOfAll', { shown: filteredNotifications.length })}
            </span>
          </div>
        </div>
      )}
    </div>
  )
}
