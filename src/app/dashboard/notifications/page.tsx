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
import { NotificationsDigest } from '@/components/features/admin'

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
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 08 / Benachrichtigungen</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-rose-50 border border-rose-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Bell className="w-6 h-6 text-rose-600" />
            </div>
            <div>
              <h1 className="page-title flex items-center gap-3">
                Benachrichtigungen
                {unreadCount > 0 && (
                  <span className="inline-flex items-center justify-center text-[11px] font-semibold rounded-full min-w-[22px] h-[22px] px-1.5 bg-ink-800 text-paper tracking-wide">
                    {unreadCount > 99 ? '99+' : unreadCount}
                  </span>
                )}
              </h1>
              <p className="page-subtitle mt-2">Neues aus deiner <span className="text-accent">Gemeinschaft</span>.</p>
            </div>
          </div>
          <div className="flex-shrink-0">
            <NotificationActions
              activeFilter={activeFilter}
              unreadCount={unreadCount}
              onMarkAllRead={markAllAsRead}
              onDeleteAll={deleteAll}
            />
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div className="mb-4">
        <NotificationsDigest />
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
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-primary-600 text-white text-sm font-medium rounded-xl hover:bg-primary-700 transition-colors"
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
