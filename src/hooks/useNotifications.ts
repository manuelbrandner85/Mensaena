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
  const diff = now.getTime() - date.getTime()
  const dayMs = 86400000

  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const dateTime = date.getTime()

  if (dateTime >= todayStart) return 'Heute'
  if (dateTime >= todayStart - dayMs) return 'Gestern'
  if (diff < 7 * dayMs) return 'Diese Woche'
  if (diff < 30 * dayMs) return 'Dieser Monat'
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
