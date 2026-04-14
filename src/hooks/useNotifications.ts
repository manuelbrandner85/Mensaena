'use client'

import { useEffect, useMemo } from 'react'
import { useNotificationStore } from '@/store/useNotificationStore'
import type { AppNotification } from '@/types'

// ── Grouping types ───────────────────────────────────────────────────

export interface NotificationGroup {
  label: string
  notifications: AppNotification[]
}

// ── Date group helpers ───────────────────────────────────────────────

function getDateGroup(dateStr: string): string {
  const now = new Date()
  const date = new Date(dateStr)
  const dayMs = 86400000

  // Calendar-aligned boundaries (not elapsed time) so groups don't drift.
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const yesterdayStart = todayStart - dayMs

  // ISO week: Monday = start of week.
  // getDay(): 0 = Sun, 1 = Mon, ..., 6 = Sat → offset to Monday.
  const dow = now.getDay()
  const daysSinceMonday = (dow + 6) % 7
  const weekStart = todayStart - daysSinceMonday * dayMs

  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime()

  const dateTime = date.getTime()

  if (dateTime >= todayStart) return 'Heute'
  if (dateTime >= yesterdayStart) return 'Gestern'
  if (dateTime >= weekStart) return 'Diese Woche'
  if (dateTime >= monthStart) return 'Dieser Monat'
  return 'Älter'
}

const GROUP_ORDER = ['Heute', 'Gestern', 'Diese Woche', 'Dieser Monat', 'Älter']

function groupNotifications(notifications: AppNotification[]): NotificationGroup[] {
  const groups: Record<string, AppNotification[]> = {}

  for (const n of notifications) {
    const label = getDateGroup(n.created_at)
    if (!groups[label]) groups[label] = []
    groups[label].push(n)
  }

  return GROUP_ORDER
    .filter((label) => groups[label]?.length)
    .map((label) => ({ label, notifications: groups[label] }))
}

// ── Hook ─────────────────────────────────────────────────────────────

export function useNotifications(userId: string | undefined) {
  const {
    notifications,
    unreadCount,
    unreadCounts,
    activeFilter,
    loading,
    hasMore,
    loadNotifications,
    loadMore,
    markAsRead,
    markAsUnread,
    markAllAsRead,
    deleteNotification,
    deleteAll,
    setFilter,
    loadUnreadCounts,
    subscribeToRealtime,
    unsubscribeFromRealtime,
  } = useNotificationStore()

  // ── Mount / unmount ──────────────────────────────────────────────
  useEffect(() => {
    if (!userId) return

    // Set userId and load initial data
    useNotificationStore.setState({ _userId: userId })
    loadNotifications()
    loadUnreadCounts()
    subscribeToRealtime(userId)

    return () => {
      unsubscribeFromRealtime()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  // ── Grouped notifications ────────────────────────────────────────
  const groupedNotifications = useMemo(
    () => groupNotifications(notifications),
    [notifications],
  )

  return {
    notifications,
    groupedNotifications,
    unreadCount,
    unreadCounts,
    activeFilter,
    loading,
    hasMore,
    markAsRead,
    markAsUnread,
    markAllAsRead,
    deleteNotification,
    deleteAll,
    setFilter,
    loadMore,
  }
}
