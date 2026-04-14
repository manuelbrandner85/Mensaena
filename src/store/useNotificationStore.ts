import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'
import type { AppNotification } from '@/types'
import type { RealtimeChannel } from '@supabase/supabase-js'

// ── Types ────────────────────────────────────────────────────────────

export type NotificationFilter = 'all' | 'message' | 'interaction' | 'trust_rating' | 'post_nearby' | 'post_response' | 'system' | 'comment'

export interface UnreadCounts {
  total: number
  message: number
  interaction: number
  trust_rating: number
  post_nearby: number
  post_response: number
  system: number
  comment: number
}

const DEFAULT_COUNTS: UnreadCounts = {
  total: 0, message: 0, interaction: 0, trust_rating: 0,
  post_nearby: 0, post_response: 0, system: 0, comment: 0,
}

const PAGE_SIZE = 20

// ── Actor profile cache ──────────────────────────────────────────────
// In-memory cache + debounced batch fetch to avoid N+1 queries when
// multiple realtime notifications arrive in quick succession.

interface CachedActor {
  name: string | null
  avatar_url: string | null
}

const actorProfileCache = new Map<string, CachedActor>()
let pendingActorIds = new Set<string>()
let pendingActorResolvers: Array<{ id: string; resolve: (a: CachedActor) => void }> = []
let pendingFlushTimer: ReturnType<typeof setTimeout> | null = null

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function flushActorFetch(supabase: any) {
  if (pendingActorIds.size === 0) return
  const ids = Array.from(pendingActorIds)
  const resolvers = pendingActorResolvers
  pendingActorIds = new Set()
  pendingActorResolvers = []

  const { data } = await supabase
    .from('profiles')
    .select('id, name, avatar_url')
    .in('id', ids)

  if (data) {
    for (const p of data as Array<{ id: string; name: string | null; avatar_url: string | null }>) {
      actorProfileCache.set(p.id, { name: p.name, avatar_url: p.avatar_url })
    }
  }
  // Mark missing as resolved-empty so we don't refetch
  for (const id of ids) {
    if (!actorProfileCache.has(id)) {
      actorProfileCache.set(id, { name: null, avatar_url: null })
    }
  }
  for (const r of resolvers) {
    r.resolve(actorProfileCache.get(r.id) || { name: null, avatar_url: null })
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function resolveActor(supabase: any, actorId: string): Promise<CachedActor> {
  const cached = actorProfileCache.get(actorId)
  if (cached) return Promise.resolve(cached)
  return new Promise((resolve) => {
    pendingActorIds.add(actorId)
    pendingActorResolvers.push({ id: actorId, resolve })
    if (pendingFlushTimer) clearTimeout(pendingFlushTimer)
    pendingFlushTimer = setTimeout(() => {
      pendingFlushTimer = null
      flushActorFetch(supabase)
    }, 200)
  })
}

// ── Store ────────────────────────────────────────────────────────────

interface NotificationState {
  notifications: AppNotification[]
  unreadCount: number
  unreadCounts: UnreadCounts
  activeFilter: NotificationFilter
  loading: boolean
  hasMore: boolean
  page: number
  _channel: RealtimeChannel | null
  _userId: string | null
}

interface NotificationActions {
  loadNotifications: (filter?: NotificationFilter, page?: number) => Promise<void>
  loadMore: () => Promise<void>
  markAsRead: (notificationId: string) => Promise<void>
  markAsUnread: (notificationId: string) => Promise<void>
  markAllAsRead: (category?: string) => Promise<number>
  deleteNotification: (notificationId: string) => Promise<void>
  deleteAll: (category?: string) => Promise<number>
  setFilter: (filter: NotificationFilter) => void
  loadUnreadCounts: () => Promise<void>
  subscribeToRealtime: (userId: string) => void
  unsubscribeFromRealtime: () => void
}

export const useNotificationStore = create<NotificationState & NotificationActions>()(
  (set, get) => ({
    notifications: [],
    unreadCount: 0,
    unreadCounts: DEFAULT_COUNTS,
    activeFilter: 'all',
    loading: false,
    hasMore: false,
    page: 1,
    _channel: null,
    _userId: null,

    // ── Load notifications ─────────────────────────────────────────
    loadNotifications: async (filter, page = 1) => {
      const userId = get()._userId
      if (!userId) return
      const currentFilter = filter ?? get().activeFilter

      set({ loading: page === 1 })

      const supabase = createClient()
      // Fetch PAGE_SIZE + 1 to detect "has more" without an extra empty request.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let query = (supabase.from('notifications') as any)
        .select('*, profiles!notifications_actor_id_fkey(name, avatar_url)')
        .eq('user_id', userId)
        .is('deleted_at', null)
        .order('created_at', { ascending: false })
        .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

      if (currentFilter !== 'all') {
        if (currentFilter === 'system') {
          query = query.in('category', ['system', 'bot', 'welcome', 'reminder', 'mention'])
        } else if (currentFilter === 'comment') {
          query = query.eq('category', 'comment')
        } else {
          query = query.eq('category', currentFilter)
        }
      }

      const { data, error } = await query

      if (error) {
        console.warn('[NotificationStore] load failed:', error.message)
        set({ loading: false })
        return
      }

      // We requested PAGE_SIZE + 1 rows; if we got that many, there is more.
      const rawRows = (data || []) as Record<string, unknown>[]
      const hasMore = rawRows.length > PAGE_SIZE
      const pageRows = hasMore ? rawRows.slice(0, PAGE_SIZE) : rawRows

      const mapped: AppNotification[] = pageRows.map((n) => ({
        ...n,
        actor_name: (n.profiles as Record<string, unknown>)?.name ?? null,
        actor_avatar: (n.profiles as Record<string, unknown>)?.avatar_url ?? null,
      })) as AppNotification[]

      // Warm the actor cache so realtime INSERTs don't refetch known actors
      for (const n of pageRows) {
        const actorId = n.actor_id as string | null
        const profile = n.profiles as Record<string, unknown> | null
        if (actorId && profile) {
          actorProfileCache.set(actorId, {
            name: (profile.name as string | null) ?? null,
            avatar_url: (profile.avatar_url as string | null) ?? null,
          })
        }
      }

      if (page === 1) {
        set({ notifications: mapped, loading: false, hasMore, page: 1 })
      } else {
        set((s) => ({
          notifications: [...s.notifications, ...mapped],
          loading: false,
          hasMore,
          page,
        }))
      }
    },

    // ── Load more ──────────────────────────────────────────────────
    loadMore: async () => {
      const nextPage = get().page + 1
      await get().loadNotifications(undefined, nextPage)
    },

    // ── Mark single as read ────────────────────────────────────────
    markAsRead: async (notificationId) => {
      const supabase = createClient()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (supabase.from('notifications') as any)
        .update({ read: true })
        .eq('id', notificationId)

      set((s) => {
        const found = s.notifications.find((n) => n.id === notificationId)
        const wasUnread = found && !found.read
        return {
          notifications: s.notifications.map((n) =>
            n.id === notificationId ? { ...n, read: true } : n,
          ),
          unreadCount: wasUnread ? Math.max(0, s.unreadCount - 1) : s.unreadCount,
        }
      })
    },

    // ── Mark single as unread ──────────────────────────────────────
    markAsUnread: async (notificationId) => {
      const supabase = createClient()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (supabase.from('notifications') as any)
        .update({ read: false })
        .eq('id', notificationId)

      set((s) => {
        const found = s.notifications.find((n) => n.id === notificationId)
        const wasRead = found?.read
        return {
          notifications: s.notifications.map((n) =>
            n.id === notificationId ? { ...n, read: false } : n,
          ),
          unreadCount: wasRead ? s.unreadCount + 1 : s.unreadCount,
        }
      })
    },

    // ── Mark all as read ───────────────────────────────────────────
    markAllAsRead: async (category) => {
      const userId = get()._userId
      if (!userId) return 0

      const supabase = createClient()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data } = await (supabase as any).rpc('mark_all_notifications_read', {
        p_user_id: userId,
        p_category: category || null,
      })
      const affected = ((data as unknown) as number) || 0

      set((s) => ({
        notifications: s.notifications.map((n) => {
          if (category && n.category !== category) return n
          return { ...n, read: true }
        }),
        unreadCount: category ? Math.max(0, s.unreadCount - affected) : 0,
      }))

      get().loadUnreadCounts()
      return affected
    },

    // ── Delete single ──────────────────────────────────────────────
    deleteNotification: async (notificationId) => {
      const supabase = createClient()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (supabase.from('notifications') as any)
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', notificationId)

      set((s) => {
        const removed = s.notifications.find((n) => n.id === notificationId)
        const wasUnread = removed && !removed.read
        return {
          notifications: s.notifications.filter((n) => n.id !== notificationId),
          unreadCount: wasUnread ? Math.max(0, s.unreadCount - 1) : s.unreadCount,
        }
      })
    },

    // ── Delete all ─────────────────────────────────────────────────
    deleteAll: async (category) => {
      const userId = get()._userId
      if (!userId) return 0

      const supabase = createClient()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data } = await (supabase as any).rpc('soft_delete_all_notifications', {
        p_user_id: userId,
        p_category: category || null,
      })
      const affected = ((data as unknown) as number) || 0

      set((s) => {
        if (!category) {
          // Wipe everything: list, total counter, per-category counters.
          return {
            notifications: [],
            unreadCount: 0,
            unreadCounts: { ...DEFAULT_COUNTS },
          }
        }
        // Single category: subtract the unread items in that category
        // from both the total and the per-category counter.
        const removedUnread = s.notifications.filter(
          (n) => n.category === category && !n.read,
        ).length
        const key = category as keyof UnreadCounts
        const nextCounts: UnreadCounts = { ...s.unreadCounts }
        if (key in nextCounts) {
          nextCounts[key] = Math.max(0, nextCounts[key] - removedUnread)
          nextCounts.total = Math.max(0, nextCounts.total - removedUnread)
        }
        return {
          notifications: s.notifications.filter((n) => n.category !== category),
          unreadCount: Math.max(0, s.unreadCount - removedUnread),
          unreadCounts: nextCounts,
        }
      })

      // Reconcile with the server in the background (covers items that
      // were not in the local snapshot because of pagination).
      get().loadUnreadCounts()
      return affected
    },

    // ── Set filter ─────────────────────────────────────────────────
    setFilter: (filter) => {
      set({ activeFilter: filter, page: 1, notifications: [] })
      get().loadNotifications(filter, 1)
    },

    // ── Load unread counts ─────────────────────────────────────────
    loadUnreadCounts: async () => {
      const userId = get()._userId
      if (!userId) return

      const supabase = createClient()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data } = await (supabase as any).rpc('get_notification_counts', {
        p_user_id: userId,
      })
      if (data) {
        const counts = data as UnreadCounts
        set({
          unreadCounts: counts,
          unreadCount: counts.total || 0,
        })
      }
    },

    // ── Realtime subscription ──────────────────────────────────────
    subscribeToRealtime: (userId) => {
      // Avoid duplicate subscriptions
      if (get()._channel) get().unsubscribeFromRealtime()

      set({ _userId: userId })

      const supabase = createClient()
      const channel = supabase
        .channel(`notifications-center:${userId}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'notifications',
            filter: `user_id=eq.${userId}`,
          },
          async (payload) => {
            const raw = payload.new as Record<string, unknown>

            // Resolve actor via cache + debounced batch fetch (avoids N+1)
            let actorName: string | null = null
            let actorAvatar: string | null = null
            if (raw.actor_id) {
              const actor = await resolveActor(supabase, raw.actor_id as string)
              actorName = actor.name
              actorAvatar = actor.avatar_url
            }

            const notification: AppNotification = {
              id: raw.id as string,
              user_id: raw.user_id as string,
              type: (raw.type as string) || 'system',
              category: (raw.category as AppNotification['category']) || 'system',
              title: (raw.title as string) || null,
              content: (raw.content as string) || null,
              link: (raw.link as string) || null,
              read: false,
              actor_id: (raw.actor_id as string) || null,
              metadata: (raw.metadata as Record<string, unknown>) || {},
              created_at: raw.created_at as string,
              deleted_at: null,
              actor_name: actorName,
              actor_avatar: actorAvatar,
            }

            set((s) => ({
              notifications: [notification, ...s.notifications],
              unreadCount: s.unreadCount + 1,
            }))
            get().loadUnreadCounts()

            // Dispatch custom event for toast display (handled by component)
            if (typeof window !== 'undefined') {
              window.dispatchEvent(
                new CustomEvent('mensaena-notification', { detail: notification }),
              )
            }
          },
        )
        .on(
          'postgres_changes',
          {
            event: 'UPDATE',
            schema: 'public',
            table: 'notifications',
            filter: `user_id=eq.${userId}`,
          },
          (payload) => {
            const updated = payload.new as Record<string, unknown>
            set((s) => ({
              notifications: s.notifications.map((n) =>
                n.id === updated.id
                  ? { ...n, read: updated.read as boolean }
                  : n,
              ),
            }))
          },
        )
        .subscribe()

      set({ _channel: channel })
    },

    // ── Unsubscribe ────────────────────────────────────────────────
    unsubscribeFromRealtime: () => {
      const channel = get()._channel
      if (channel) {
        const supabase = createClient()
        supabase.removeChannel(channel)
        set({ _channel: null })
      }
    },
  }),
)
