'use client'

import { useEffect, useState, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { CheckCircle, XCircle, User, X } from 'lucide-react'

interface ZeitbankEntry {
  id: string
  hours: number
  description: string
  help_date: string | null
  status: string
  giver: {
    id: string
    name: string | null
    nickname: string | null
    avatar_url: string | null
  } | null
}

interface ZeitbankNotif {
  id: string
  type: string
  message: string
  seen: boolean
  created_at: string
  entry: ZeitbankEntry | null
}

interface BannerItem extends ZeitbankNotif {
  visible: boolean
  loading: boolean
}

export default function ZeitbankConfirmationBanner() {
  const [banners, setBanners] = useState<BannerItem[]>([])

  const addNotif = useCallback((notif: ZeitbankNotif) => {
    if (notif.type !== 'confirmation_request') return
    if (!notif.entry || notif.entry.status !== 'pending') return

    setBanners(prev => {
      if (prev.some(b => b.id === notif.id)) return prev
      return [...prev, { ...notif, visible: true, loading: false }]
    })
  }, [])

  const removeBanner = useCallback((id: string) => {
    setBanners(prev => prev.map(b => b.id === id ? { ...b, visible: false } : b))
    setTimeout(() => setBanners(prev => prev.filter(b => b.id !== id)), 350)
  }, [])

  const handleAction = useCallback(async (banner: BannerItem, action: 'confirm' | 'reject') => {
    if (!banner.entry) return

    setBanners(prev => prev.map(b => b.id === banner.id ? { ...b, loading: true } : b))

    const endpoint = action === 'confirm'
      ? `/api/zeitbank/entries/${banner.entry.id}/confirm`
      : `/api/zeitbank/entries/${banner.entry.id}/reject`

    try {
      const res = await fetch(endpoint, { method: 'PATCH' })
      if (res.ok) {
        const supabase = createClient()
        await supabase
          .from('zeitbank_notifications')
          .update({ seen: true, clicked: true })
          .eq('id', banner.id)
        removeBanner(banner.id)
      }
    } catch {
      // ignore network errors
    } finally {
      setBanners(prev => prev.map(b => b.id === banner.id ? { ...b, loading: false } : b))
    }
  }, [removeBanner])

  const handleDismiss = useCallback(async (banner: BannerItem) => {
    removeBanner(banner.id)
    const supabase = createClient()
    await supabase
      .from('zeitbank_notifications')
      .update({ seen: true })
      .eq('id', banner.id)
  }, [removeBanner])

  useEffect(() => {
    let channelCleanup: (() => void) | null = null

    const init = async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      // Load existing unseen confirmation requests on mount
      try {
        const res = await fetch('/api/zeitbank/notifications?unseen=true')
        if (res.ok) {
          const { data } = await res.json() as { data: ZeitbankNotif[] }
          for (const n of data) addNotif(n)
        }
      } catch { /* ignore */ }

      // Subscribe to new zeitbank_notifications in realtime
      const channel = supabase
        .channel(`zeitbank-banner:${user.id}`)
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'zeitbank_notifications',
          filter: `user_id=eq.${user.id}`,
        }, async (payload) => {
          const row = payload.new as Record<string, unknown>
          if (row.type !== 'confirmation_request') return

          // Re-fetch to get the joined entry relation
          try {
            const res = await fetch('/api/zeitbank/notifications?unseen=true')
            if (res.ok) {
              const { data } = await res.json() as { data: ZeitbankNotif[] }
              const found = data.find(n => n.id === row.id)
              if (found) addNotif(found)
            }
          } catch { /* ignore */ }
        })
        .subscribe()

      channelCleanup = () => supabase.removeChannel(channel)
    }

    init()

    return () => { channelCleanup?.() }
  }, [addNotif])

  if (banners.length === 0) return null

  return (
    <div className="fixed top-14 md:top-16 left-0 right-0 z-30 flex flex-col items-center gap-2 py-2 px-4 pointer-events-none">
      {banners.map(banner => {
        const giver = banner.entry?.giver
        const giverName = giver?.name || giver?.nickname || 'Jemand'
        const giverAvatar = giver?.avatar_url
        const hours = banner.entry?.hours ?? 0
        const desc = banner.entry?.description ?? ''

        return (
          <div
            key={banner.id}
            className={`
              pointer-events-auto w-full max-w-lg
              bg-white border border-amber-100 rounded-2xl shadow-xl
              transition-all duration-300 ease-out
              ${banner.visible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-3'}
            `}
          >
            <div className="flex items-start gap-3 p-4">
              {/* Avatar */}
              <div className="flex-shrink-0 mt-0.5">
                {giverAvatar ? (
                  <img
                    src={giverAvatar}
                    alt={giverName}
                    className="w-10 h-10 rounded-full object-cover border border-stone-100"
                  />
                ) : (
                  <div className="w-10 h-10 rounded-full bg-amber-50 border border-amber-100 flex items-center justify-center">
                    <User className="w-5 h-5 text-amber-500" />
                  </div>
                )}
              </div>

              {/* Content */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5 mb-1">
                  <div className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" />
                  <span className="text-[10px] font-semibold text-amber-600 uppercase tracking-wider">
                    Zeitbank · Bestätigung erbeten
                  </span>
                </div>
                <p className="text-sm font-semibold text-ink-900 leading-snug">
                  <span className="text-primary-600">{giverName}</span>{' '}
                  hat{' '}
                  <span className="font-bold">{hours} Std.</span>{' '}
                  Hilfe eingetragen
                </p>
                {desc && (
                  <p className="text-xs text-ink-500 mt-0.5 line-clamp-1">{desc}</p>
                )}

                {/* Action buttons */}
                <div className="flex gap-2 mt-3">
                  <button
                    onClick={() => handleAction(banner, 'confirm')}
                    disabled={banner.loading}
                    className="flex-1 flex items-center justify-center gap-1.5 py-1.5 px-3 rounded-xl bg-primary-500 hover:bg-primary-600 active:bg-primary-700 text-white text-xs font-semibold transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    <CheckCircle className="w-3.5 h-3.5" />
                    Bestätigen
                  </button>
                  <button
                    onClick={() => handleAction(banner, 'reject')}
                    disabled={banner.loading}
                    className="flex-1 flex items-center justify-center gap-1.5 py-1.5 px-3 rounded-xl bg-red-50 hover:bg-red-100 active:bg-red-200 text-red-600 text-xs font-semibold transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    <XCircle className="w-3.5 h-3.5" />
                    Ablehnen
                  </button>
                </div>
              </div>

              {/* Dismiss */}
              <button
                onClick={() => handleDismiss(banner)}
                className="flex-shrink-0 p-1.5 -mr-1 -mt-1 rounded-lg text-ink-400 hover:text-ink-600 hover:bg-stone-100 transition-colors"
                aria-label="Schließen"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>
        )
      })}
    </div>
  )
}
