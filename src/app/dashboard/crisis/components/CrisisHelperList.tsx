'use client'

import { useState } from 'react'
import { Users, Clock, MapPin, ShieldCheck, Star, ChevronDown, HandHelping, Loader2, LogOut } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import { HELPER_STATUS_CONFIG, type CrisisHelper, type HelperStatus } from '../types'

interface Props {
  helpers: CrisisHelper[]
  loading: boolean
  userId?: string
  isCreator?: boolean
  onOfferHelp?: (message?: string, skills?: string[]) => Promise<void>
  onWithdrawHelp?: () => Promise<void>
  onUpdateStatus?: (helperId: string, status: HelperStatus) => Promise<void>
}

export default function CrisisHelperList({
  helpers, loading, userId, isCreator,
  onOfferHelp, onWithdrawHelp, onUpdateStatus,
}: Props) {
  const [showForm, setShowForm] = useState(false)
  const [message, setMessage] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const myHelper = helpers.find(h => h.user_id === userId && h.status !== 'withdrawn')
  const activeHelpers = helpers.filter(h => !['withdrawn', 'completed'].includes(h.status))

  const handleOffer = async () => {
    if (!onOfferHelp) return
    setSubmitting(true)
    try {
      await onOfferHelp(message || undefined)
      setShowForm(false)
      setMessage('')
    } catch {
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="bg-white border border-gray-100 rounded-2xl shadow-sm overflow-hidden">
      <div className="px-4 pt-4 pb-3 border-b border-gray-100 flex items-center justify-between">
        <h4 className="text-sm font-bold text-gray-800 flex items-center gap-2">
          <Users className="w-4 h-4 text-primary-600" />
          Helfer ({activeHelpers.length})
        </h4>
        {!myHelper && onOfferHelp && (
          <button
            onClick={() => setShowForm(true)}
            className="px-3 py-1.5 bg-primary-600 text-white rounded-lg text-xs font-semibold hover:bg-primary-700 transition-colors flex items-center gap-1"
          >
            <HandHelping className="w-3 h-3" />
            Ich helfe!
          </button>
        )}
        {myHelper && onWithdrawHelp && (
          <button
            onClick={async () => { setSubmitting(true); await onWithdrawHelp().catch(() => {}); setSubmitting(false) }}
            disabled={submitting}
            className="px-3 py-1.5 bg-gray-100 text-gray-600 rounded-lg text-xs font-semibold hover:bg-gray-200 transition-colors flex items-center gap-1"
          >
            {submitting ? <Loader2 className="w-3 h-3 animate-spin" /> : <LogOut className="w-3 h-3" />}
            Zurückziehen
          </button>
        )}
      </div>

      {/* Offer form */}
      {showForm && (
        <div className="px-4 py-3 border-b border-gray-100 bg-primary-50/50">
          <p className="text-xs font-semibold text-primary-800 mb-2">Hilfe anbieten:</p>
          <input
            type="text"
            value={message}
            onChange={e => setMessage(e.target.value)}
            placeholder="Nachricht (optional): z.B. Bin in 10 Min. da"
            className="w-full px-3 py-2 bg-white border border-primary-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-200 mb-2"
            aria-label="Nachricht an Hilfesuchende"
          />
          <div className="flex gap-2">
            <button
              onClick={handleOffer}
              disabled={submitting}
              className="px-4 py-2 bg-primary-600 text-white rounded-xl text-xs font-semibold hover:bg-primary-700 disabled:opacity-50 flex items-center gap-1"
            >
              {submitting ? <Loader2 className="w-3 h-3 animate-spin" /> : <HandHelping className="w-3 h-3" />}
              Hilfe bestätigen
            </button>
            <button
              onClick={() => setShowForm(false)}
              className="px-4 py-2 bg-white border border-gray-200 text-gray-600 rounded-xl text-xs hover:bg-gray-50"
            >
              Abbrechen
            </button>
          </div>
        </div>
      )}

      {/* Helper list */}
      <div className="px-4 py-3">
        {loading ? (
          <div className="space-y-3">
            {[0, 1].map(i => (
              <div key={i} className="flex gap-3 animate-pulse">
                <div className="w-8 h-8 rounded-full bg-gray-200" />
                <div className="flex-1 space-y-1">
                  <div className="h-4 w-24 bg-gray-200 rounded" />
                  <div className="h-3 w-40 bg-gray-100 rounded" />
                </div>
              </div>
            ))}
          </div>
        ) : helpers.length === 0 ? (
          <p className="text-xs text-gray-400 text-center py-4">
            Noch keine Helfer - sei der Erste!
          </p>
        ) : (
          <div className="space-y-3">
            {helpers.filter(h => h.status !== 'withdrawn').map(h => {
              const statusCfg = HELPER_STATUS_CONFIG[h.status]
              return (
                <div key={h.id} className="flex items-start gap-3">
                  <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center flex-shrink-0">
                    {h.profiles?.avatar_url ? (
                      <img src={h.profiles.avatar_url} alt="" className="w-8 h-8 rounded-full object-cover" />
                    ) : (
                      <Users className="w-4 h-4 text-gray-400" />
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-xs font-semibold text-gray-800">
                        {h.profiles?.name || h.profiles?.display_name || 'Helfer'}
                      </span>
                      <span className={cn('px-1.5 py-0.5 rounded-full text-xs font-medium', statusCfg.bgColor, statusCfg.color)}>
                        {statusCfg.label}
                      </span>
                      {h.profiles?.is_crisis_volunteer && (
                        <span className="flex items-center gap-0.5 px-1.5 py-0.5 bg-amber-50 border border-amber-200 rounded-full text-xs text-amber-700">
                          <Star className="w-3 h-3" /> Freiwillig
                        </span>
                      )}
                    </div>
                    {h.message && <p className="text-xs text-gray-600 mt-0.5">{h.message}</p>}
                    <div className="flex items-center gap-3 mt-1 text-xs text-gray-400">
                      {h.eta_minutes && (
                        <span className="flex items-center gap-1">
                          <Clock className="w-3 h-3" /> ~{h.eta_minutes} Min.
                        </span>
                      )}
                      <span>{formatRelativeTime(h.created_at)}</span>
                    </div>
                    {/* Creator can update helper status */}
                    {isCreator && onUpdateStatus && !['completed', 'withdrawn'].includes(h.status) && (
                      <div className="flex gap-1 mt-2">
                        {h.status === 'offered' && (
                          <button
                            onClick={() => onUpdateStatus(h.id, 'accepted')}
                            className="px-2 py-0.5 bg-primary-100 text-primary-700 rounded text-xs hover:bg-primary-200"
                          >
                            Akzeptieren
                          </button>
                        )}
                        {h.status === 'accepted' && (
                          <button
                            onClick={() => onUpdateStatus(h.id, 'on_way')}
                            className="px-2 py-0.5 bg-blue-100 text-blue-700 rounded text-xs hover:bg-blue-200"
                          >
                            Unterwegs
                          </button>
                        )}
                        {(h.status === 'on_way' || h.status === 'arrived') && (
                          <button
                            onClick={() => onUpdateStatus(h.id, 'completed')}
                            className="px-2 py-0.5 bg-green-100 text-green-700 rounded text-xs hover:bg-green-200"
                          >
                            Fertig
                          </button>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
