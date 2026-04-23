'use client'

import { useState } from 'react'
import { Download, Loader2, FileJson } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import type { DataExport } from '../types'

interface Props {
  userId: string
}

export default function DataExportButton({ userId }: Props) {
  const t = useTranslations('dataExportButton')
  const [exporting, setExporting] = useState(false)

  const handleExport = async () => {
    setExporting(true)
    try {
      const supabase = createClient()

      const [
        profileRes,
        postsRes,
        interactionsRes,
        messagesRes,
        savedRes,
        notificationsRes,
        ratingsRes,
      ] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', userId).single(),
        supabase.from('posts').select('*').eq('user_id', userId).order('created_at', { ascending: false }),
        supabase.from('interactions').select('*').eq('helper_id', userId).order('created_at', { ascending: false }),
        supabase.from('messages').select('id, content, created_at, conversation_id').eq('sender_id', userId).order('created_at', { ascending: false }),
        supabase.from('saved_posts').select('*').eq('user_id', userId),
        supabase.from('notifications').select('*').eq('user_id', userId).order('created_at', { ascending: false }).limit(100),
        supabase.from('trust_ratings').select('*').or(`rater_id.eq.${userId},rated_id.eq.${userId}`),
      ])

      const { data: { user } } = await supabase.auth.getUser()

      const exportData: DataExport = {
        exported_at: new Date().toISOString(),
        user: {
          id: userId,
          email: user?.email ?? '',
          created_at: user?.created_at ?? '',
        },
        profile: (profileRes.data ?? {}) as Record<string, unknown>,
        posts: (postsRes.data ?? []) as Record<string, unknown>[],
        messages: ((messagesRes.data ?? []).map(m => ({
          ...m,
          content: m.content,
        }))) as Record<string, unknown>[],
        interactions: (interactionsRes.data ?? []) as Record<string, unknown>[],
        saved_posts: (savedRes.data ?? []) as Record<string, unknown>[],
        trust_ratings_given: ((ratingsRes.data ?? []).filter((r: Record<string, unknown>) => r.rater_id === userId)) as Record<string, unknown>[],
        trust_ratings_received: ((ratingsRes.data ?? []).filter((r: Record<string, unknown>) => r.rated_id === userId)) as Record<string, unknown>[],
        notifications: (notificationsRes.data ?? []) as Record<string, unknown>[],
        conversations: [],
        reports: [],
        blocks: [],
      }

      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `mensaena-daten-export-${new Date().toISOString().slice(0, 10)}.json`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)

      toast.success(t('toastSuccess'))
    } catch (err) {
      console.error('Export error:', err)
      toast.error(t('toastError'))
    }
    setExporting(false)
  }

  return (
    <div className="flex items-center gap-4 p-4 rounded-xl bg-blue-50 border border-blue-200">
      <div className="w-10 h-10 rounded-xl bg-blue-100 flex items-center justify-center flex-shrink-0">
        <FileJson className="w-5 h-5 text-blue-600" />
      </div>
      <div className="flex-1">
        <p className="text-sm font-medium text-gray-900">{t('title')}</p>
        <p className="text-xs text-gray-500">{t('desc')}</p>
      </div>
      <button
        onClick={handleExport}
        disabled={exporting}
        className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-medium bg-blue-600 text-white hover:bg-blue-700 transition-all disabled:opacity-50"
      >
        {exporting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
        {exporting ? t('exporting') : t('export')}
      </button>
    </div>
  )
}
