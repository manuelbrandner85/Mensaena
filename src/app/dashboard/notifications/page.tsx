'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Bell, MapPin, Sparkles } from 'lucide-react'
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

  if (authLoading || (loading && notifications.length === 0)) {
    return (
      <div className="max-w-2xl mx-auto">
        <div className="mb-8 animate-pulse">
          <div className="h-4 w-32 bg-mn-surface rounded mb-4" />
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-mn-surface" />
            <div className="flex-1 pt-1">
              <div className="h-7 w-48 bg-mn-surface rounded mb-2" />
              <div className="h-4 w-64 bg-mn-elevated rounded" />
            </div>
          </div>
        </div>
        <NotificationSkeleton />
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto">

      {/* ── Header ── */}
      <header className="mb-6">
        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
          <div className="flex items-start gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-primary-100 to-primary-50 border border-mn-amber/20/60 flex items-center justify-center flex-shrink-0 shadow-sm">
              <Bell className="w-5.5 h-5.5 text-mn-amber" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-mn-ink flex items-center gap-2.5 leading-tight">
                Benachrichtigungen
                {unreadCount > 0 && (
                  <span className="inline-flex items-center justify-center text-[10px] font-bold rounded-full min-w-[20px] h-5 px-1.5 bg-mn-amber text-white tabular-nums">
                    {unreadCount > 99 ? '99+' : unreadCount}
                  </span>
                )}
              </h1>
              <p className="text-sm text-mn-mute mt-0.5">
                {unreadCount > 0
                  ? `${unreadCount} ungelesen${unreadCount > 1 ? 'e' : 'e'} Meldung${unreadCount > 1 ? 'en' : ''}`
                  : 'Alles auf dem neuesten Stand'}
              </p>
            </div>
          </div>
          <div className="flex-shrink-0 self-start">
            <NotificationActions
              activeFilter={activeFilter}
              unreadCount={unreadCount}
              onMarkAllRead={markAllAsRead}
              onDeleteAll={deleteAll}
            />
          </div>
        </div>
      </header>

      {/* ── Filter Pills ── */}
      <div className="mb-4">
        <NotificationFilters
          activeFilter={activeFilter}
          unreadCounts={unreadCounts}
          onFilterChange={setFilter}
        />
      </div>

      {/* ── List or Empty State ── */}
      {notifications.length === 0 && !loading ? (
        <div className="bg-mn-elevated rounded-2xl border border-white/5 py-16 text-center shadow-cinema-card">
          <div className="w-16 h-16 rounded-2xl bg-mn-elevated flex items-center justify-center mx-auto mb-4">
            {activeFilter !== 'all'
              ? <Sparkles className="w-7 h-7 text-mn-ghost" />
              : <Bell className="w-7 h-7 text-mn-ghost" />
            }
          </div>
          <h2 className="text-base font-semibold text-mn-ink-soft mb-1.5">
            {activeFilter !== 'all'
              ? 'Nichts in dieser Kategorie'
              : 'Alles gelesen'}
          </h2>
          <p className="text-sm text-mn-mute mb-6 max-w-xs mx-auto leading-relaxed">
            {activeFilter !== 'all'
              ? 'In dieser Kategorie gibt es aktuell keine Benachrichtigungen.'
              : 'Sobald es Neuigkeiten aus deiner Gemeinschaft gibt, erscheinen sie hier.'}
          </p>
          {activeFilter === 'all' && (
            <Link
              href="/dashboard/map"
              className="inline-flex items-center gap-2 px-4 py-2 bg-mn-amber text-white text-sm font-medium rounded-xl hover:bg-primary-700 transition-colors shadow-sm"
            >
              <MapPin className="w-4 h-4" />
              Karte erkunden
            </Link>
          )}
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

      {/* ── Preferences ── */}
      {userId && (
        <div className="mt-8">
          <NotificationPreferences userId={userId} />
        </div>
      )}
    </div>
  )
}
