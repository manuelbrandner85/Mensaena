'use client'

import { Loader2, CheckCircle2 } from 'lucide-react'
import NotificationGroupHeader from './NotificationGroupHeader'
import NotificationItem from './NotificationItem'
import type { NotificationGroup } from '@/hooks/useNotifications'

interface Props {
  groupedNotifications: NotificationGroup[]
  hasMore: boolean
  loading: boolean
  onLoadMore: () => Promise<void>
  onMarkAsRead: (id: string) => Promise<void>
  onMarkAsUnread: (id: string) => Promise<void>
  onDelete: (id: string) => Promise<void>
}

export default function NotificationList({
  groupedNotifications,
  hasMore,
  loading,
  onLoadMore,
  onMarkAsRead,
  onMarkAsUnread,
  onDelete,
}: Props) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden shadow-sm">
      {groupedNotifications.map((group) => (
        <div key={group.label}>
          <NotificationGroupHeader label={group.label} />
          {group.notifications.map((notification) => (
            <NotificationItem
              key={notification.id}
              notification={notification}
              onMarkAsRead={onMarkAsRead}
              onMarkAsUnread={onMarkAsUnread}
              onDelete={onDelete}
            />
          ))}
        </div>
      ))}

      {/* ── Load more / End of list ── */}
      <div className="px-4 py-3 text-center border-t border-gray-50">
        {hasMore ? (
          <button
            onClick={onLoadMore}
            disabled={loading}
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-primary-600 hover:bg-primary-50 rounded-xl transition-colors disabled:opacity-50"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                Laden…
              </>
            ) : (
              'Mehr laden'
            )}
          </button>
        ) : (
          <div className="flex items-center justify-center gap-2 text-xs text-gray-400 py-1">
            <CheckCircle2 className="w-3.5 h-3.5" />
            Alle Benachrichtigungen geladen
          </div>
        )}
      </div>
    </div>
  )
}
