'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Bell, MapPin } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useNotifications } from '@/hooks/useNotifications'

import NotificationFilters from './components/NotificationFilters'
import NotificationActions from './components/NotificationActions'
import NotificationList from './components/NotificationList'
import NotificationSkeleton from './components/NotificationSkeleton'
import NotificationPreferences from './components/NotificationPreferences'
import Link from 'next/link'

export default function NotificationsPage() {
  const router = useRouter()
  const [userId, setUserId] = useState<string | undefined>(undefined)
  const [authLoading, setAuthLoading] = useState(true)

  // ── Auth guard ──────────────────────────────────────────────────────
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session?.user) {
        router.replace('/auth?mode=login')
        return
      }
      setUserId(session.user.id)
      setAuthLoading(false)
    })
  }, [router])

  const {
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
  } = useNotifications(userId)

  // ── Loading state ───────────────────────────────────────────────────
  if (authLoading || (loading && notifications.length === 0)) {
    return (
      <div className="max-w-2xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold text-gray-900">Benachrichtigungen</h1>
          </div>
        </div>
        <NotificationSkeleton />
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto">
      {/* ── Header ── */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold text-gray-900">Benachrichtigungen</h1>
          {unreadCount > 0 && (
            <span className="bg-red-500 text-white text-xs font-bold rounded-full min-w-[22px] h-[22px] px-1.5 flex items-center justify-center">
              {unreadCount > 99 ? '99+' : unreadCount}
            </span>
          )}
        </div>
        <NotificationActions
          activeFilter={activeFilter}
          unreadCount={unreadCount}
          onMarkAllRead={markAllAsRead}
          onDeleteAll={deleteAll}
        />
      </div>

      {/* ── Filters ── */}
      <div className="mb-4">
        <NotificationFilters
          activeFilter={activeFilter}
          unreadCounts={unreadCounts}
          onFilterChange={setFilter}
        />
      </div>

      {/* ── List or Empty State ── */}
      {notifications.length === 0 && !loading ? (
        <div className="bg-white rounded-2xl border border-gray-100 py-16 text-center">
          <Bell className="w-12 h-12 text-gray-200 mx-auto mb-3" />
          <h2 className="text-lg font-semibold text-gray-700 mb-1">Keine Benachrichtigungen</h2>
          <p className="text-sm text-gray-400 mb-6 max-w-sm mx-auto">
            {activeFilter !== 'all'
              ? 'Keine Benachrichtigungen in dieser Kategorie.'
              : 'Sobald es etwas Neues gibt, wirst du hier benachrichtigt.'}
          </p>
          <Link
            href="/dashboard/map"
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 text-white text-sm font-medium rounded-xl hover:bg-emerald-700 transition-colors"
          >
            <MapPin className="w-4 h-4" />
            Karte erkunden
          </Link>
        </div>
      ) : (
        <NotificationList
          groupedNotifications={groupedNotifications}
          hasMore={hasMore}
          loading={loading}
          onLoadMore={loadMore}
          onMarkAsRead={markAsRead}
          onMarkAsUnread={markAsUnread}
          onDelete={deleteNotification}
        />
      )}

      {/* ── Quick Preferences ── */}
      {userId && (
        <div className="mt-8">
          <NotificationPreferences userId={userId} />
        </div>
      )}
    </div>
  )
}
