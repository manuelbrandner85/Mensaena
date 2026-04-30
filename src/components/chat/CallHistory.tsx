'use client'

// FEATURE: Anrufhistorie

import { useState, useEffect } from 'react'
import { Phone, PhoneIncoming, PhoneOutgoing, PhoneMissed, X, Clock } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import Image from 'next/image'

interface CallRecord {
  id: string
  caller_id: string
  callee_id: string
  call_type: 'audio' | 'video'
  status: string
  created_at: string
  answered_at: string | null
  ended_at: string | null
  partner_name: string
  partner_avatar: string | null
}

export interface CallHistoryProps {
  userId: string
  onClose: () => void
  onCall: (partnerId: string, type: 'audio' | 'video') => void
}

export default function CallHistory({ userId, onClose, onCall }: CallHistoryProps) {
  const [calls, setCalls] = useState<CallRecord[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      const supabase = createClient()
      const { data } = await supabase
        .from('dm_calls')
        .select('id, caller_id, callee_id, call_type, status, created_at, answered_at, ended_at')
        .or(`caller_id.eq.${userId},callee_id.eq.${userId}`)
        .order('created_at', { ascending: false })
        .limit(30)

      if (!data?.length) { setLoading(false); return }

      const partnerIds = [...new Set(data.map(c =>
        c.caller_id === userId ? c.callee_id : c.caller_id
      ))]
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, name, avatar_url')
        .in('id', partnerIds)

      const profileMap = new Map(
        (profiles ?? []).map(p => [p.id, p])
      )

      setCalls(data.map(c => {
        const partnerId = c.caller_id === userId ? c.callee_id : c.caller_id
        const profile = profileMap.get(partnerId)
        return {
          ...c,
          partner_name: (profile as { name?: string | null } | undefined)?.name ?? 'Unbekannt',
          partner_avatar: (profile as { avatar_url?: string | null } | undefined)?.avatar_url ?? null,
        }
      }))
      setLoading(false)
    }
    void load()
  }, [userId])

  const formatDuration = (start: string | null, end: string | null): string => {
    if (!start || !end) return ''
    const diff = Math.floor((new Date(end).getTime() - new Date(start).getTime()) / 1000)
    const m = Math.floor(diff / 60)
    const s = diff % 60
    return `${m}:${String(s).padStart(2, '0')}`
  }

  const formatTime = (iso: string): string => {
    const d = new Date(iso)
    const now = new Date()
    const diff = now.getTime() - d.getTime()
    if (diff < 86400000) return d.toLocaleTimeString('de', { hour: '2-digit', minute: '2-digit' })
    if (diff < 604800000) return d.toLocaleDateString('de', { weekday: 'short', hour: '2-digit', minute: '2-digit' })
    return d.toLocaleDateString('de', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
  }

  return (
    <div
      className="fixed inset-0 z-[100] bg-black/50 backdrop-blur-sm flex items-end sm:items-center justify-center"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
      role="dialog"
      aria-modal="true"
      aria-label="Anrufhistorie"
    >
      <div className="bg-white rounded-t-2xl sm:rounded-2xl w-full sm:max-w-md max-h-[80vh] flex flex-col shadow-xl">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <Clock className="w-5 h-5 text-primary-500" />
            Letzte Anrufe
          </h2>
          <button
            onClick={onClose}
            className="p-2 rounded-full hover:bg-gray-100 min-w-[44px] min-h-[44px] flex items-center justify-center"
            aria-label="Schließen"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Liste */}
        <div className="flex-1 overflow-y-auto divide-y divide-gray-100">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin" />
            </div>
          ) : calls.length === 0 ? (
            <p className="text-center text-gray-400 py-12 text-sm">Noch keine Anrufe</p>
          ) : (
            calls.map(call => {
              const isOutgoing = call.caller_id === userId
              const isMissed = call.status === 'missed'
              const isDeclined = call.status === 'declined'
              const isEnded = call.status === 'ended'
              const duration = formatDuration(call.answered_at, call.ended_at)
              const partnerId = isOutgoing ? call.callee_id : call.caller_id

              return (
                <div key={call.id} className="flex items-center gap-3 px-5 py-3 hover:bg-gray-50">
                  {/* Avatar */}
                  <div className="relative w-10 h-10 rounded-full overflow-hidden bg-primary-100 flex-shrink-0">
                    {call.partner_avatar ? (
                      <Image src={call.partner_avatar} alt="" fill className="object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-primary-600 font-semibold text-sm">
                        {call.partner_name.charAt(0).toUpperCase()}
                      </div>
                    )}
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">{call.partner_name}</p>
                    <div className="flex items-center gap-1.5 text-xs text-gray-500">
                      {isOutgoing ? (
                        <PhoneOutgoing className="w-3 h-3 text-gray-400" />
                      ) : isMissed ? (
                        <PhoneMissed className="w-3 h-3 text-red-500" />
                      ) : (
                        <PhoneIncoming className="w-3 h-3 text-green-500" />
                      )}
                      <span>
                        {isMissed ? 'Verpasst' :
                         isDeclined ? 'Abgelehnt' :
                         isEnded && duration ? duration :
                         call.status === 'cancelled' ? 'Abgebrochen' :
                         call.status}
                      </span>
                      <span className="text-gray-300">·</span>
                      <span>{formatTime(call.created_at)}</span>
                    </div>
                  </div>

                  {/* Anrufen-Button */}
                  <button
                    onClick={() => onCall(partnerId, call.call_type)}
                    className="p-2.5 rounded-full text-primary-500 hover:bg-primary-50 min-w-[44px] min-h-[44px] flex items-center justify-center"
                    aria-label={`${call.partner_name} anrufen`}
                  >
                    <Phone className="w-5 h-5" />
                  </button>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}
