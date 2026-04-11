'use client'

import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { MessageCircle } from 'lucide-react'
import { Badge, Avatar, EmptyState } from '@/components/ui'
import type { UnreadMessage } from '../types'

interface UnreadMessagesProps {
  messages: UnreadMessage[]
}

function formatTimeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'jetzt'
  if (m < 60) return `${m}m`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h`
  const d = Math.floor(h / 24)
  return `${d}d`
}

export default function UnreadMessages({ messages }: UnreadMessagesProps) {
  const router = useRouter()
  const totalUnread = messages.reduce((sum, m) => sum + m.unreadCount, 0)

  return (
    <div>
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-semibold text-gray-900">Ungelesene Nachrichten</span>
        <div className="flex items-center gap-2">
          {totalUnread > 0 && (
            <Badge variant="red" size="sm">
              {totalUnread}
            </Badge>
          )}
          <Link href="/dashboard/chat" className="text-primary-600 text-xs font-medium hover:text-primary-700">
            Alle \u2192
          </Link>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center gap-3 p-6">
            <MessageCircle className="w-8 h-8 text-gray-300" />
            <p className="text-sm text-gray-400">Keine ungelesenen Nachrichten</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-50">
            {messages.map((msg) => (
              <button
                key={msg.conversationId}
                onClick={() => router.push(`/dashboard/chat?conv=${msg.conversationId}`)}
                className="w-full flex items-center gap-3 p-3 hover:bg-gray-50 cursor-pointer transition-colors text-left"
              >
                {/* Avatar */}
                <Avatar
                  src={msg.senderAvatarUrl}
                  name={msg.senderName}
                  size="sm"
                />

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">{msg.senderName}</p>
                  <p className="text-xs text-gray-500 truncate">{msg.lastMessageText}</p>
                </div>

                {/* Time + Badge */}
                <div className="flex flex-col items-end gap-1 flex-shrink-0">
                  <span className="text-[10px] text-gray-400">{formatTimeAgo(msg.timestamp)}</span>
                  {msg.unreadCount > 1 ? (
                    <Badge variant="danger" size="sm" animated>
                      {msg.unreadCount}
                    </Badge>
                  ) : (
                    <span className="w-2 h-2 bg-red-500 rounded-full" />
                  )}
                </div>
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
