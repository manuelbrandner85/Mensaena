'use client'

import Link from 'next/link'
import {
  ArrowLeft, User, Sparkles, MapPin, Calendar,
  Clock, CheckCircle2, ExternalLink,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import InteractionStatusBadge from './InteractionStatusBadge'
import InteractionActions from './InteractionActions'
import InteractionTimeline from './InteractionTimeline'
import { InteractionDetailSkeleton } from './InteractionSkeleton'
import { STATUS_CONFIG, type Interaction, type InteractionUpdate } from '../types'

interface Props {
  interaction: Interaction | null
  updates: InteractionUpdate[]
  detailLoading: boolean
  updatesLoading: boolean
  myRole: 'helper' | 'helped'
  canAccept: boolean
  canDecline: boolean
  canStart: boolean
  canComplete: boolean
  canCancel: boolean
  canDispute: boolean
  canRate: boolean
  onAccept: (id: string, accept: boolean, msg?: string) => Promise<void>
  onStart: (id: string) => Promise<void>
  onComplete: (id: string, notes?: string) => Promise<void>
  onCancel: (id: string, reason?: string) => Promise<void>
  onDispute: (id: string, reason: string) => Promise<void>
  onAddUpdate: (id: string, content: string) => Promise<void>
}

export default function InteractionDetailView({
  interaction: i, updates, detailLoading, updatesLoading,
  myRole, canAccept, canDecline, canStart, canComplete, canCancel, canDispute, canRate,
  onAccept, onStart, onComplete, onCancel, onDispute, onAddUpdate,
}: Props) {
  if (detailLoading || !i) return <InteractionDetailSkeleton />

  const cfg = STATUS_CONFIG[i.status] ?? STATUS_CONFIG.requested
  const Icon = cfg.icon

  return (
    <div className="space-y-6">
      {/* Back link */}
      <Link
        href="/dashboard/interactions"
        className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" /> Zurueck zu Interaktionen
      </Link>

      {/* Status Banner */}
      <div className={cn(
        'rounded-xl p-4 flex items-center gap-3',
        cfg.color,
      )}>
        <Icon className="w-6 h-6 flex-shrink-0" />
        <div>
          <p className="font-semibold">{cfg.label}</p>
          <p className="text-sm opacity-80">{cfg.description}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* ── Left column (3/5) ── */}
        <div className="lg:col-span-3 space-y-4">
          {/* Post info */}
          {i.post && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-sm font-semibold text-gray-800">Beitrag</h3>
                <Link
                  href={`/dashboard/posts/${i.post.id}`}
                  className="text-xs text-emerald-600 hover:text-emerald-700 flex items-center gap-1"
                >
                  Zum Beitrag <ExternalLink className="w-3 h-3" />
                </Link>
              </div>
              <h4 className="font-medium text-gray-900 mb-1">{i.post.title}</h4>
              <div className="flex items-center gap-2 text-xs text-gray-500">
                {i.post.category && (
                  <span className="bg-gray-100 px-2 py-0.5 rounded-full">{i.post.category}</span>
                )}
                {i.post.type && (
                  <span className="bg-gray-100 px-2 py-0.5 rounded-full">{i.post.type}</span>
                )}
              </div>
            </div>
          )}

          {/* Partner profile */}
          <div className="bg-white rounded-xl border border-gray-100 p-5">
            <h3 className="text-sm font-semibold text-gray-800 mb-3">
              {myRole === 'helper' ? 'Hilfesuchender' : 'Helfer'}
            </h3>
            <div className="flex items-center gap-3">
              <div className="w-14 h-14 rounded-full bg-gray-100 flex items-center justify-center overflow-hidden flex-shrink-0">
                {i.partner.avatar_url
                  ? <img src={i.partner.avatar_url} alt="" className="w-full h-full object-cover" />
                  : <User className="w-6 h-6 text-gray-400" />
                }
              </div>
              <div>
                <p className="font-medium text-gray-900">{i.partner.name ?? 'Nutzer'}</p>
                {i.partner.trust_score != null && i.partner.trust_score > 0 && (
                  <div className="flex items-center gap-1 text-xs text-gray-500 mt-0.5">
                    <CheckCircle2 className="w-3 h-3 text-emerald-500" />
                    Vertrauenswert: {i.partner.trust_score}
                    {i.partner.trust_count != null && i.partner.trust_count > 0 && (
                      <span>({i.partner.trust_count} Bewertungen)</span>
                    )}
                  </div>
                )}
                <p className="text-xs text-gray-400 mt-0.5">
                  {myRole === 'helper' ? 'Du hilfst dieser Person' : 'Diese Person hilft dir'}
                </p>
              </div>
            </div>
          </div>

          {/* Match info */}
          {i.match_id && (
            <div className="bg-amber-50 rounded-xl border border-amber-100 p-4">
              <div className="flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-amber-600" />
                <p className="text-sm font-medium text-amber-800">Aus Matching entstanden</p>
              </div>
              {i.match_score != null && (
                <p className="text-xs text-amber-600 mt-1">Match-Score: {i.match_score}%</p>
              )}
            </div>
          )}

          {/* Messages */}
          {i.message && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-800 mb-2">Nachricht</h3>
              <p className="text-sm text-gray-700 whitespace-pre-wrap">{i.message}</p>
            </div>
          )}

          {i.response_message && (
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="text-sm font-semibold text-gray-800 mb-2">Antwort</h3>
              <p className="text-sm text-gray-700 whitespace-pre-wrap">{i.response_message}</p>
            </div>
          )}

          {i.cancel_reason && (
            <div className="bg-red-50 rounded-xl border border-red-100 p-5">
              <h3 className="text-sm font-semibold text-red-800 mb-2">Absagegrund</h3>
              <p className="text-sm text-red-700 whitespace-pre-wrap">{i.cancel_reason}</p>
            </div>
          )}

          {i.completion_notes && (
            <div className="bg-green-50 rounded-xl border border-green-100 p-5">
              <h3 className="text-sm font-semibold text-green-800 mb-2">Abschlussnotiz</h3>
              <p className="text-sm text-green-700 whitespace-pre-wrap">{i.completion_notes}</p>
            </div>
          )}

          {/* Metadata */}
          <div className="bg-white rounded-xl border border-gray-100 p-5">
            <h3 className="text-sm font-semibold text-gray-800 mb-3">Details</h3>
            <div className="grid grid-cols-2 gap-3 text-xs">
              <div>
                <p className="text-gray-500">Erstellt</p>
                <p className="text-gray-700 font-medium">{new Date(i.created_at).toLocaleDateString('de-DE', { day: '2-digit', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</p>
              </div>
              <div>
                <p className="text-gray-500">Letzte Aktualisierung</p>
                <p className="text-gray-700 font-medium">{formatRelativeTime(i.updated_at)}</p>
              </div>
              {i.completed_at && (
                <div>
                  <p className="text-gray-500">Abgeschlossen am</p>
                  <p className="text-gray-700 font-medium">{new Date(i.completed_at).toLocaleDateString('de-DE', { day: '2-digit', month: 'long', year: 'numeric' })}</p>
                </div>
              )}
              <div>
                <p className="text-gray-500">Meine Rolle</p>
                <p className="text-gray-700 font-medium">{myRole === 'helper' ? 'Helfer' : 'Hilfesuchender'}</p>
              </div>
              {i.helper_rated !== undefined && (
                <div>
                  <p className="text-gray-500">Helfer hat bewertet</p>
                  <p className="text-gray-700 font-medium">{i.helper_rated ? 'Ja' : 'Nein'}</p>
                </div>
              )}
              {i.helped_rated !== undefined && (
                <div>
                  <p className="text-gray-500">Hilfesuchender hat bewertet</p>
                  <p className="text-gray-700 font-medium">{i.helped_rated ? 'Ja' : 'Nein'}</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* ── Right column (2/5) ── */}
        <div className="lg:col-span-2 space-y-4">
          {/* Actions */}
          <InteractionActions
            interaction={i}
            canAccept={canAccept}
            canDecline={canDecline}
            canStart={canStart}
            canComplete={canComplete}
            canCancel={canCancel}
            canDispute={canDispute}
            canRate={canRate}
            onAccept={onAccept}
            onStart={onStart}
            onComplete={onComplete}
            onCancel={onCancel}
            onDispute={onDispute}
          />

          {/* Timeline */}
          <InteractionTimeline
            updates={updates}
            loading={updatesLoading}
            canAddNote={['requested', 'accepted', 'in_progress'].includes(i.status)}
            onAddNote={(content) => onAddUpdate(i.id, content)}
          />
        </div>
      </div>
    </div>
  )
}
