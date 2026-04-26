'use client'

import { useState, useRef } from 'react'
import Link from 'next/link'
import {
  ArrowLeft, MapPin, Clock, Users, Eye, Phone, Share2,
  ShieldCheck, XCircle, CheckCircle2, AlertTriangle, Flag, Loader2, Camera, X,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import toast from 'react-hot-toast'
import CrisisStatusBadge from './CrisisStatusBadge'
import CrisisCategoryBadge from './CrisisCategoryBadge'
import CrisisUrgencyIndicator from './CrisisUrgencyIndicator'
import CrisisContactBar from './CrisisContactBar'
import CrisisResourceCard from './CrisisResourceCard'
import CrisisTimeline from './CrisisTimeline'
import CrisisHelperList from './CrisisHelperList'
import CrisisMap from './CrisisMap'
import type { Crisis, CrisisUpdate, CrisisHelper, CrisisStatus, HelperStatus, UpdateType } from '../types'

interface Props {
  crisis: Crisis
  updates: CrisisUpdate[]
  helpers: CrisisHelper[]
  userId: string
  loading: boolean
  loadingUpdates: boolean
  loadingHelpers: boolean
  onUpdateStatus: (crisisId: string, status: CrisisStatus, userId: string) => Promise<void>
  onVerify: (crisisId: string, userId: string) => Promise<void>
  onFalseAlarm: (crisisId: string, userId: string) => Promise<void>
  onAddUpdate: (crisisId: string, userId: string, content: string, updateType?: UpdateType, imageUrl?: string) => Promise<void>
  onOfferHelp: (crisisId: string, userId: string, message?: string, skills?: string[]) => Promise<void>
  onWithdrawHelp: (crisisId: string, userId: string) => Promise<void>
  onUpdateHelperStatus: (helperId: string, status: HelperStatus) => Promise<void>
}

export default function CrisisDetail({
  crisis, updates, helpers, userId, loading,
  loadingUpdates, loadingHelpers,
  onUpdateStatus, onVerify, onFalseAlarm,
  onAddUpdate, onOfferHelp, onWithdrawHelp, onUpdateHelperStatus,
}: Props) {
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [showResolveModal, setShowResolveModal] = useState(false)
  const [resolveNote, setResolveNote] = useState('')
  const [resolveImageUrl, setResolveImageUrl] = useState<string | null>(null)
  const [resolveImageUploading, setResolveImageUploading] = useState(false)
  const resolveImageRef = useRef<HTMLInputElement>(null)
  const isCreator = crisis.creator_id === userId
  const isActive = crisis.status === 'active' || crisis.status === 'in_progress'
  const isCritical = crisis.urgency === 'critical'

  const handleResolveImageUpload = async (file: File) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp']
    if (!allowed.includes(file.type)) { toast.error('Nur JPEG, PNG oder WebP erlaubt'); return }
    if (file.size > 8 * 1024 * 1024) { toast.error('Bild max. 8 MB'); return }
    setResolveImageUploading(true)
    try {
      const supabase = createClient()
      const ext = file.name.split('.').pop() || 'jpg'
      const path = `crisis/${crisis.id}/resolved_${Date.now()}.${ext}`
      const { error: upErr } = await supabase.storage
        .from('post-images')
        .upload(path, file, { cacheControl: '3600', upsert: false })
      if (upErr) throw upErr
      const { data } = supabase.storage.from('post-images').getPublicUrl(path)
      setResolveImageUrl(data.publicUrl)
      toast.success('Foto hochgeladen')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Upload fehlgeschlagen')
    } finally {
      setResolveImageUploading(false)
    }
  }

  const handleConfirmResolve = async () => {
    setActionLoading('resolve')
    try {
      if (resolveImageUrl) {
        const supabase = createClient()
        await supabase.from('crises')
          .update({ resolved_image_url: resolveImageUrl })
          .eq('id', crisis.id)
      }
      if (resolveNote.trim()) {
        await onAddUpdate(crisis.id, userId, resolveNote.trim(), 'resolved')
      }
      await onUpdateStatus(crisis.id, 'resolved', userId)
      toast.success('Krise als gelöst markiert!')
      setShowResolveModal(false)
    } catch (e: any) {
      toast.error(e?.message || 'Fehler beim Abschließen.')
    } finally {
      setActionLoading(null)
    }
  }

  const handleAction = async (action: string, fn: () => Promise<void>) => {
    setActionLoading(action)
    try {
      await fn()
      toast.success(
        action === 'resolve' ? 'Krise als gelöst markiert!' :
        action === 'verify' ? 'Krise verifiziert!' :
        action === 'false_alarm' ? 'Als Fehlalarm markiert.' :
        action === 'in_progress' ? 'Status aktualisiert.' :
        'Aktion ausgeführt.'
      )
    } catch (e: any) {
      toast.error(e?.message || 'Fehler bei der Aktion.')
    } finally {
      setActionLoading(null)
    }
  }

  const handleShare = () => {
    if (navigator.share) {
      navigator.share({ title: crisis.title, url: window.location.href }).catch(() => {})
    } else {
      navigator.clipboard.writeText(window.location.href)
      toast.success('Link kopiert!')
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="mb-4">
        <Link
          href="/dashboard/crisis"
          className="inline-flex items-center gap-1 text-sm text-ink-500 hover:text-ink-700 mb-3"
        >
          <ArrowLeft className="w-4 h-4" />
          Zurück zur Übersicht
        </Link>

        {/* Badges */}
        <div className="flex flex-wrap items-center gap-2 mb-3">
          <CrisisUrgencyIndicator urgency={crisis.urgency} size="md" />
          <CrisisCategoryBadge category={crisis.category} size="md" />
          <CrisisStatusBadge status={crisis.status} size="md" />
          {crisis.is_verified && (
            <span className="inline-flex items-center gap-1 px-3 py-1 bg-primary-50 border border-primary-200 rounded-full text-sm text-primary-700 font-semibold">
              <ShieldCheck className="w-4 h-4" /> Verifiziert
            </span>
          )}
        </div>

        {/* Title */}
        <h1 className="text-xl sm:text-2xl font-black text-ink-900 mb-2">{crisis.title}</h1>

        {/* Meta */}
        <div className="flex flex-wrap items-center gap-3 text-sm text-ink-500 mb-3">
          <span className="flex items-center gap-1">
            <Clock className="w-4 h-4" />
            {formatRelativeTime(crisis.created_at)}
          </span>
          {crisis.location_text && (
            <span className="flex items-center gap-1">
              <MapPin className="w-4 h-4" />
              {crisis.location_text}
            </span>
          )}
          <span className="flex items-center gap-1">
            <Users className="w-4 h-4" />
            {crisis.helper_count}/{crisis.needed_helpers} Helfer
          </span>
          {crisis.affected_count > 0 && (
            <span className="flex items-center gap-1">
              <Eye className="w-4 h-4" />
              ~{crisis.affected_count} Betroffene
            </span>
          )}
        </div>

        {/* Creator info */}
        {!crisis.is_anonymous && crisis.profiles && (
          <div className="flex items-center gap-2 text-sm text-ink-600 mb-3">
            {crisis.profiles.avatar_url ? (
              <img src={crisis.profiles.avatar_url} alt="" className="w-6 h-6 rounded-full object-cover" />
            ) : (
              <div className="w-6 h-6 rounded-full bg-stone-200 flex items-center justify-center">
                <Users className="w-3 h-3 text-ink-400" />
              </div>
            )}
            <span>Gemeldet von <strong>{crisis.profiles.name || 'Nutzer'}</strong></span>
          </div>
        )}
      </div>

      {/* Images */}
      {crisis.image_urls && crisis.image_urls.length > 0 && (
        <div className="mb-4 grid grid-cols-2 sm:grid-cols-4 gap-2">
          {crisis.image_urls.map((url, i) => (
            <div key={i} className="rounded-xl overflow-hidden border border-stone-200 aspect-video">
              <img src={url} alt={`Krisenfoto ${i + 1}`} className="w-full h-full object-cover" loading="lazy" onError={(e) => { e.currentTarget.style.display = 'none' }} />
            </div>
          ))}
        </div>
      )}

      {/* Description */}
      <div className="bg-white border border-stone-100 rounded-2xl p-4 shadow-sm mb-4">
        <h3 className="text-sm font-bold text-ink-800 mb-2">Beschreibung</h3>
        <p className="text-sm text-ink-700 whitespace-pre-wrap leading-relaxed">{crisis.description}</p>
      </div>

      {/* Contact bar */}
      <CrisisContactBar crisis={crisis} className="mb-4" />

      {/* Action buttons */}
      {isActive && (
        <div className="flex flex-wrap gap-2 mb-4">
          {isCreator && (
            <>
              {crisis.status === 'active' && (
                <button
                  onClick={() => handleAction('in_progress', () => onUpdateStatus(crisis.id, 'in_progress', userId))}
                  disabled={actionLoading === 'in_progress'}
                  className="flex items-center gap-1.5 px-4 py-2 bg-orange-100 text-orange-700 border border-orange-200 rounded-xl text-xs font-semibold hover:bg-orange-200 transition-colors"
                >
                  {actionLoading === 'in_progress' ? <Loader2 className="w-3 h-3 animate-spin" /> : <AlertTriangle className="w-3 h-3" />}
                  In Bearbeitung
                </button>
              )}
              <button
                onClick={() => setShowResolveModal(true)}
                disabled={actionLoading === 'resolve'}
                className="flex items-center gap-1.5 px-4 py-2 bg-green-100 text-green-700 border border-green-200 rounded-xl text-xs font-semibold hover:bg-green-200 transition-colors"
              >
                {actionLoading === 'resolve' ? <Loader2 className="w-3 h-3 animate-spin" /> : <CheckCircle2 className="w-3 h-3" />}
                Als gelöst markieren
              </button>
              <button
                onClick={() => handleAction('cancel', () => onUpdateStatus(crisis.id, 'cancelled', userId))}
                disabled={actionLoading === 'cancel'}
                className="flex items-center gap-1.5 px-4 py-2 bg-stone-100 text-ink-600 border border-stone-200 rounded-xl text-xs font-semibold hover:bg-stone-200 transition-colors"
              >
                Abbrechen
              </button>
            </>
          )}

          {!crisis.is_verified && (
            <button
              onClick={() => handleAction('verify', () => onVerify(crisis.id, userId))}
              disabled={actionLoading === 'verify'}
              className="flex items-center gap-1.5 px-4 py-2 bg-primary-100 text-primary-700 border border-primary-200 rounded-xl text-xs font-semibold hover:bg-primary-200 transition-colors"
            >
              {actionLoading === 'verify' ? <Loader2 className="w-3 h-3 animate-spin" /> : <ShieldCheck className="w-3 h-3" />}
              Verifizieren
            </button>
          )}

          <button
            onClick={() => handleAction('false_alarm', () => onFalseAlarm(crisis.id, userId))}
            disabled={actionLoading === 'false_alarm'}
            className="flex items-center gap-1.5 px-4 py-2 bg-red-50 text-red-600 border border-red-200 rounded-xl text-xs font-semibold hover:bg-red-100 transition-colors"
          >
            {actionLoading === 'false_alarm' ? <Loader2 className="w-3 h-3 animate-spin" /> : <XCircle className="w-3 h-3" />}
            Fehlalarm
          </button>

          <button
            onClick={handleShare}
            className="flex items-center gap-1.5 px-4 py-2 bg-stone-100 text-ink-600 border border-stone-200 rounded-xl text-xs font-semibold hover:bg-stone-200 transition-colors ml-auto"
          >
            <Share2 className="w-3 h-3" />
            Teilen
          </button>
        </div>
      )}

      {/* Map */}
      {crisis.latitude && crisis.longitude && (
        <div className="mb-4">
          <CrisisMap crises={[crisis]} height="h-[250px]" />
        </div>
      )}

      {/* Resources & Skills */}
      <CrisisResourceCard crisis={crisis} className="mb-4" />

      {/* Grid: Helpers + Timeline */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <CrisisHelperList
          helpers={helpers}
          loading={loadingHelpers}
          userId={userId}
          isCreator={isCreator}
          onOfferHelp={async (msg, skills) => {
            try {
              await onOfferHelp(crisis.id, userId, msg, skills)
              toast.success('Danke! Du hilfst jetzt bei dieser Krise.')
            } catch (e: any) {
              toast.error(e?.message || 'Fehler beim Anbieten der Hilfe.')
            }
          }}
          onWithdrawHelp={async () => {
            try {
              await onWithdrawHelp(crisis.id, userId)
              toast.success('Hilfe zurückgezogen.')
            } catch (e: any) {
              toast.error(e?.message || 'Fehler.')
            }
          }}
          onUpdateStatus={onUpdateHelperStatus}
        />

        <CrisisTimeline
          updates={updates}
          loading={loadingUpdates}
          canPost={isActive}
          onAddUpdate={async (content, type) => {
            try {
              await onAddUpdate(crisis.id, userId, content, type)
              toast.success('Update hinzugefügt.')
            } catch (e: any) {
              toast.error(e?.message || 'Fehler.')
            }
          }}
        />
      </div>

      {/* Resolved image display */}
      {crisis.status === 'resolved' && crisis.resolved_image_url && (
        <div className="mt-4 bg-green-50 border border-green-200 rounded-2xl p-4">
          <p className="text-xs font-semibold text-green-700 mb-2 flex items-center gap-1.5">
            <CheckCircle2 className="w-3.5 h-3.5" /> Abschlussfoto
          </p>
          <img
            src={crisis.resolved_image_url}
            alt="Abschlussfoto"
            className="w-full max-h-64 object-cover rounded-xl"
            onError={(e) => { e.currentTarget.style.display = 'none' }}
          />
        </div>
      )}

      {/* Resolve modal */}
      {showResolveModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <input
              ref={resolveImageRef}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; if (f) handleResolveImageUpload(f); e.target.value = '' }}
            />
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-ink-900 flex items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-green-600" /> Krise abschließen
              </h3>
              <button onClick={() => setShowResolveModal(false)} aria-label="Schließen" className="p-1.5 rounded-lg hover:bg-stone-100 text-ink-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <p className="text-sm text-ink-600">Möchtest du diese Krise als gelöst markieren? Du kannst optional ein Abschlussfoto und eine Notiz hinzufügen.</p>
            <div>
              <label className="block text-xs font-semibold text-ink-500 mb-1">Abschlussnotiz (optional)</label>
              <textarea
                value={resolveNote}
                onChange={(e) => setResolveNote(e.target.value)}
                rows={2}
                maxLength={500}
                placeholder="Kurze Zusammenfassung wie die Krise gelöst wurde…"
                className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300 resize-none"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-ink-500 mb-2">Abschlussfoto (optional)</label>
              {resolveImageUrl ? (
                <div className="relative">
                  <img src={resolveImageUrl} alt="" className="w-full h-32 object-cover rounded-xl"
                    onError={(e) => { e.currentTarget.style.display = 'none' }} />
                  <button
                    onClick={() => setResolveImageUrl(null)}
                    className="absolute top-1.5 right-1.5 p-1 bg-white rounded-full shadow border border-stone-200"
                  >
                    <X className="w-3 h-3 text-ink-500" />
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => resolveImageRef.current?.click()}
                  disabled={resolveImageUploading}
                  className="w-full h-20 flex flex-col items-center justify-center gap-1.5 border border-dashed border-stone-300 rounded-xl hover:bg-stone-50 transition text-xs text-ink-500 disabled:opacity-50"
                >
                  {resolveImageUploading ? <Loader2 className="w-5 h-5 animate-spin" /> : <Camera className="w-5 h-5" />}
                  {resolveImageUploading ? 'Wird hochgeladen…' : 'Foto hinzufügen'}
                </button>
              )}
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowResolveModal(false)}
                className="flex-1 px-4 py-2.5 bg-stone-100 text-ink-700 rounded-xl text-sm font-semibold hover:bg-stone-200 transition-colors"
              >
                Abbrechen
              </button>
              <button
                onClick={handleConfirmResolve}
                disabled={actionLoading === 'resolve' || resolveImageUploading}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-green-600 text-white rounded-xl text-sm font-semibold hover:bg-green-700 transition-colors disabled:opacity-50"
              >
                {actionLoading === 'resolve' ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
                Als gelöst markieren
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
