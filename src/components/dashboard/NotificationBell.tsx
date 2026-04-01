'use client'

import { useState, useEffect, useRef } from 'react'
import { Bell, BellOff, X, MessageCircle, Heart, AlertCircle, Check } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { usePushNotifications } from '@/hooks/usePushNotifications'
import { cn } from '@/lib/utils'
import Link from 'next/link'

interface NotificationItem {
  id: string
  type: 'message' | 'interaction' | 'post' | 'crisis' | 'system'
  title: string
  body: string
  url?: string
  read: boolean
  created_at: string
}

export default function NotificationBell({ userId }: { userId?: string }) {
  const [open, setOpen] = useState(false)
  const [notifications, setNotifications] = useState<NotificationItem[]>([])
  const [unread, setUnread] = useState(0)
  const ref = useRef<HTMLDivElement>(null)
  const { permission, subscribe } = usePushNotifications(userId)

  // Load recent notifications from Supabase
  useEffect(() => {
    if (!userId) return
    const supabase = createClient()

    async function loadNotifications() {
      const { data } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(20)
      if (data) {
        const items = data.map((n) => ({
          id: n.id,
          type: n.type || 'system',
          title: n.title || 'Benachrichtigung',
          body: n.message || n.body || '',
          url: n.url || '/dashboard',
          read: n.read ?? false,
          created_at: n.created_at,
        }))
        setNotifications(items)
        setUnread(items.filter((n) => !n.read).length)
      }
    }
    loadNotifications()

    // Realtime subscription for new notifications
    const channel = supabase
      .channel(`notifications:${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${userId}`,
      }, (payload) => {
        const n = payload.new as Record<string, unknown>
        const item: NotificationItem = {
          id: n.id as string,
          type: (n.type as NotificationItem['type']) || 'system',
          title: (n.title as string) || 'Benachrichtigung',
          body: (n.message as string) || (n.body as string) || '',
          url: (n.url as string) || '/dashboard',
          read: false,
          created_at: n.created_at as string,
        }
        setNotifications((prev) => [item, ...prev.slice(0, 19)])
        setUnread((prev) => prev + 1)
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [userId])

  // Close on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  const markAllRead = async () => {
    if (!userId) return
    const supabase = createClient()
    await supabase
      .from('notifications')
      .update({ read: true })
      .eq('user_id', userId)
      .eq('read', false)
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
    setUnread(0)
  }

  const markRead = async (id: string) => {
    const supabase = createClient()
    await supabase.from('notifications').update({ read: true }).eq('id', id)
    setNotifications((prev) => prev.map((n) => n.id === id ? { ...n, read: true } : n))
    setUnread((prev) => Math.max(0, prev - 1))
  }

  const getIcon = (type: NotificationItem['type']) => {
    switch (type) {
      case 'message': return <MessageCircle className="w-4 h-4 text-violet-500" />
      case 'interaction': return <Heart className="w-4 h-4 text-pink-500" />
      case 'crisis': return <AlertCircle className="w-4 h-4 text-red-500" />
      default: return <Bell className="w-4 h-4 text-primary-500" />
    }
  }

  const timeAgo = (dateStr: string) => {
    const diff = Date.now() - new Date(dateStr).getTime()
    const m = Math.floor(diff / 60000)
    if (m < 1) return 'gerade'
    if (m < 60) return `${m} Min.`
    const h = Math.floor(m / 60)
    if (h < 24) return `${h} Std.`
    return `${Math.floor(h / 24)} Tage`
  }

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="relative p-2 rounded-xl text-gray-500 hover:bg-warm-100 hover:text-gray-700 transition-colors"
        title="Benachrichtigungen"
      >
        <Bell className="w-5 h-5" />
        {unread > 0 && (
          <span className="absolute top-1 right-1 w-4 h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 top-full mt-2 w-80 bg-white rounded-2xl shadow-2xl border border-warm-200 z-50 overflow-hidden">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 border-b border-warm-100">
            <h3 className="font-semibold text-gray-900 text-sm">Benachrichtigungen</h3>
            <div className="flex items-center gap-2">
              {unread > 0 && (
                <button onClick={markAllRead} className="text-xs text-primary-600 hover:underline">
                  Alle gelesen
                </button>
              )}
              {/* Push Toggle */}
              <button
                onClick={() => permission !== 'granted' ? subscribe() : undefined}
                title={permission === 'granted' ? 'Push aktiv' : 'Push aktivieren'}
                className={cn('p-1.5 rounded-lg transition-colors',
                  permission === 'granted' ? 'text-primary-600 bg-primary-50' : 'text-gray-400 hover:bg-gray-100'
                )}
              >
                {permission === 'granted'
                  ? <Bell className="w-3.5 h-3.5" />
                  : <BellOff className="w-3.5 h-3.5" />}
              </button>
              <button onClick={() => setOpen(false)} className="text-gray-400 hover:text-gray-600">
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Push activation banner */}
          {permission === 'default' && (
            <div className="mx-3 mt-3 p-3 bg-primary-50 rounded-xl border border-primary-200">
              <p className="text-xs text-primary-700 font-medium mb-1.5">🔔 Push-Benachrichtigungen aktivieren?</p>
              <p className="text-xs text-gray-500 mb-2">Erhalte sofortige Benachrichtigungen bei neuen Nachrichten und Notfällen.</p>
              <button onClick={subscribe} className="w-full py-1.5 bg-primary-600 text-white text-xs font-medium rounded-lg hover:bg-primary-700 transition-colors">
                Jetzt aktivieren
              </button>
            </div>
          )}

          {/* Notification list */}
          <div className="max-h-80 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="py-10 text-center">
                <Bell className="w-8 h-8 text-gray-200 mx-auto mb-2" />
                <p className="text-sm text-gray-400">Keine Benachrichtigungen</p>
              </div>
            ) : (
              notifications.map((n) => (
                <Link
                  key={n.id}
                  href={n.url || '/dashboard'}
                  onClick={() => { markRead(n.id); setOpen(false) }}
                  className={cn(
                    'flex items-start gap-3 px-4 py-3 hover:bg-gray-50 transition-colors border-b border-warm-50 last:border-0',
                    !n.read && 'bg-primary-50/50'
                  )}
                >
                  <div className="mt-0.5 flex-shrink-0">{getIcon(n.type)}</div>
                  <div className="flex-1 min-w-0">
                    <p className={cn('text-sm font-medium text-gray-900 truncate', !n.read && 'text-primary-900')}>
                      {n.title}
                    </p>
                    {n.body && (
                      <p className="text-xs text-gray-500 truncate mt-0.5">{n.body}</p>
                    )}
                    <p className="text-xs text-gray-400 mt-0.5">{timeAgo(n.created_at)}</p>
                  </div>
                  {!n.read && <div className="w-2 h-2 bg-primary-500 rounded-full mt-1.5 flex-shrink-0" />}
                </Link>
              ))
            )}
          </div>

          {notifications.length > 0 && (
            <div className="px-4 py-2.5 border-t border-warm-100">
              <Link href="/dashboard" onClick={() => setOpen(false)} className="text-xs text-primary-600 hover:underline">
                Alle ansehen →
              </Link>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
