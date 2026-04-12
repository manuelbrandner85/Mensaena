'use client'

import { useState } from 'react'
import { FileText } from 'lucide-react'
import Link from 'next/link'
import { Button, EmptyState, IconButton, SectionHeader } from '@/components/ui'
import { RefreshCw } from 'lucide-react'
import type { ActivityItem } from '../types'
import ActivityFeedItem from './ActivityFeedItem'

interface ActivityFeedProps {
  activities: ActivityItem[]
  onRefresh: () => void
  refreshing: boolean
}

export default function ActivityFeed({ activities, onRefresh, refreshing }: ActivityFeedProps) {
  const [showCount, setShowCount] = useState(10)

  const visible = activities.slice(0, showCount)
  const hasMore = activities.length > showCount

  return (
    <div>
      <SectionHeader
        title="Was passiert ist"
        action={
          <IconButton
            icon={<RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />}
            label="Aktualisieren"
            variant="subtle"
            size="sm"
            onClick={onRefresh}
            disabled={refreshing}
          />
        }
      />

      <div className="bg-white rounded-xl border border-gray-100 divide-y divide-gray-50 overflow-hidden">
        {visible.length === 0 ? (
          <EmptyState
            icon={<FileText className="w-7 h-7 text-gray-300" />}
            title="Noch keine Aktivitäten"
            description="Erstelle einen Beitrag oder schau auf die Karte!"
            action={
              <Button size="sm" onClick={() => {}}>
                <Link href="/dashboard/create">Beitrag erstellen</Link>
              </Button>
            }
            className="border-0 rounded-none"
          />
        ) : (
          <>
            {visible.map((activity) => (
              <ActivityFeedItem key={activity.id} activity={activity} />
            ))}
            {hasMore && (
              <button
                onClick={() => setShowCount((c) => c + 5)}
                className="w-full py-3 text-sm font-medium text-primary-600 hover:bg-primary-50 transition-colors"
              >
                Mehr anzeigen
              </button>
            )}
          </>
        )}
      </div>
    </div>
  )
}
