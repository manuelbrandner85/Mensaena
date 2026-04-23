'use client'

import { UserX, Loader2 } from 'lucide-react'
import { useState } from 'react'
import { useTranslations } from 'next-intl'
import { formatRelativeTime } from '@/lib/utils'
import type { BlockedUser } from '../types'

interface Props {
  blockedUsers: BlockedUser[]
  onUnblock: (blockId: string) => Promise<boolean>
}

export default function BlockedUsersList({ blockedUsers, onUnblock }: Props) {
  const t = useTranslations('blockedUsersList')
  const [unblocking, setUnblocking] = useState<string | null>(null)

  const handleUnblock = async (blockId: string) => {
    setUnblocking(blockId)
    await onUnblock(blockId)
    setUnblocking(null)
  }

  if (blockedUsers.length === 0) {
    return (
      <div className="text-center py-6">
        <UserX className="w-8 h-8 text-gray-300 mx-auto mb-2" />
        <p className="text-sm text-gray-500">{t('noBlocked')}</p>
      </div>
    )
  }

  return (
    <div className="space-y-2">
      {blockedUsers.map(block => (
        <div key={block.id} className="flex items-center justify-between p-3 rounded-xl bg-warm-50">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center overflow-hidden">
              {block.profiles?.avatar_url ? (
                <img src={block.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
              ) : (
                <UserX className="w-4 h-4 text-gray-400" />
              )}
            </div>
            <div>
              <p className="text-sm font-medium text-gray-900">
                {block.profiles?.name ?? t('unknownUser')}
              </p>
              <p className="text-xs text-gray-400">
                {t('blockedAt', { time: formatRelativeTime(block.created_at) })}
              </p>
            </div>
          </div>
          <button
            onClick={() => handleUnblock(block.id)}
            disabled={unblocking === block.id}
            className="text-xs px-3 py-1.5 rounded-lg font-medium text-red-600 bg-red-50 hover:bg-red-100 transition-colors disabled:opacity-50"
          >
            {unblocking === block.id ? <Loader2 className="w-3 h-3 animate-spin" /> : t('unblock')}
          </button>
        </div>
      ))}
    </div>
  )
}
