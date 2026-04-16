'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Mail, Send, Edit3, Trash2, Eye, Loader2, Users,
  CheckCircle2, XCircle, Sparkles, FileText, RefreshCw, Search,
} from 'lucide-react'
import toast from 'react-hot-toast'
import type { AdminEmailCampaign, AdminEmailSubscription } from './AdminTypes'

type ViewMode = 'campaigns' | 'welcome' | 'subscribers'

// ============================================================
// Haupt-Komponente
// ============================================================
export default function EmailsTab() {
  const [view, setView] = useState<ViewMode>('campaigns')
  const [stats, setStats] = useState({
    total: 0, active: 0, unsubscribed: 0, sent_campaigns: 0,
  })
  const [loadingStats, setLoadingStats] = useState(true)

  // Stats laden
  const loadStats = useCallback(async () => {
    setLoadingStats(true)
    const supabase = createClient()
    const [subsRes, activeRes, unsubRes, sentRes] = await Promise.all([
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }),
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }).eq('subscribed', true),
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }).eq('subscribed', false),
      supabase.from('email_campaigns').select('id', { count: 'exact', head: true }).eq('status', 'sent'),
    ])
    setStats({
      total: subsRes.count ?? 0,
      active: activeRes.count ?? 0,
      unsubscribed: unsubRes.count ?? 0,
      sent_campaigns: sentRes.count ?? 0,
    })
    setLoadingStats(false)
  }, [])

  useEffect(() => { loadStats() }, [loadStats])

  return (
    <div className="space-y-5">
      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          icon={<Users className="w-5 h-5" />}
          label="Abonnenten gesamt"
          value={stats.total}
          loading={loadingStats}
          color="primary"
        />
        <StatCard
          icon={<CheckCircle2 className="w-5 h-5" />}
          label="Aktiv"
          value={stats.active}
          loading={loadingStats}
          color="green"
        />
        <StatCard
          icon={<XCircle className="w-5 h-5" />}
          label="Abgemeldet"
          value={stats.unsubscribed}
          loading={loadingStats}
          color="gray"
        />
        <StatCard
          icon={<Send className="w-5 h-5" />}
          label="Versendete Kampagnen"
          value={stats.sent_campaigns}
          loading={loadingStats}
          color="primary"
        />
      </div>

      {/* View-Tabs */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="border-b border-gray-100 px-4 py-3 flex items-center gap-2 overflow-x-auto">
          <ViewTab active={view === 'campaigns'}   onClick={() => setView('campaigns')}   icon={<Mail className="w-4 h-4" />}  label="Kampagnen & Entwürfe" />
          <ViewTab active={view === 'welcome'}     onClick={() => setView('welcome')}     icon={<Sparkles className="w-4 h-4" />} label="Willkommensmail" />
          <ViewTab active={view === 'subscribers'} onClick={() => setView('subscribers')} icon={<Users className="w-4 h-4" />} label="Abonnenten" />
        </div>

        <div className="p-4 lg:p-5">
          {view === 'campaigns'   && <CampaignsView onChange={loadStats} />}
          {view === 'welcome'     && <WelcomeView />}
          {view === 'subscribers' && <SubscribersView />}
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Stats Card
// ============================================================
function StatCard({
  icon, label, value, loading, color,
}: {
  icon: React.ReactNode
  label: string
  value: number
  loading: boolean
  color: 'primary' | 'green' | 'gray'
}) {
  const colorMap = {
    primary: 'bg-primary-50 text-primary-700 border-primary-100',
    green:   'bg-green-50 text-green-700 border-green-100',
    gray:    'bg-gray-50 text-gray-600 border-gray-200',
  }
  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
      <div className="flex items-start justify-between">
        <div className={`w-10 h-10 rounded-xl border flex items-center justify-center ${colorMap[color]}`}>
          {icon}
        </div>
        {loading && <Loader2 className="w-4 h-4 text-gray-300 animate-spin" />}
      </div>
      <p className="mt-3 text-2xl font-bold text-gray-900 tabular-nums">{value.toLocaleString('de-DE')}</p>
      <p className="text-xs text-gray-500 mt-0.5">{label}</p>
    </div>
  )
}

// ============================================================
// View-Tab Button
// ============================================================
function ViewTab({
  active, onClick, icon, label,
}: {
  active: boolean
  onClick: () => void
  icon: React.ReactNode
  label: string
}) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all whitespace-nowrap ${
        active
          ? 'bg-primary-500 text-white shadow-sm'
          : 'text-gray-600 hover:bg-gray-100'
      }`}
    >
      {icon}
      <span>{label}</span>
    </button>
  )
}

// ============================================================
// Kampagnen-View
// ============================================================
function CampaignsView({ onChange }: { onChange: () => void }) {
  const [campaigns, setCampaigns] = useState<AdminEmailCampaign[]>([])
  const [loading, setLoading] = useState(true)
  const [generating, setGenerating] = useState(false)
  const [editCampaign, setEditCampaign] = useState<AdminEmailCampaign | null>(null)
  const [previewCampaign, setPreviewCampaign] = useState<AdminEmailCampaign | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/emails/campaigns')
      if (!res.ok) throw new Error('Laden fehlgeschlagen')
      const data = await res.json()
      setCampaigns(data as AdminEmailCampaign[])
    } catch (e) {
      toast.error('Kampagnen konnten nicht geladen werden')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const generateDraft = async () => {
    setGenerating(true)
    try {
      const res = await fetch('/api/emails/generate-draft', {
        method: 'POST',
        headers: { 'x-cron-secret': 'manual' },
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Fehler beim Generieren')
      }
      toast.success('Entwurf generiert')
      load()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setGenerating(false)
    }
  }

  const sendCampaign = async (id: string) => {
    if (!confirm('Kampagne wirklich an alle aktiven Abonnenten senden?')) return
    const loadingToast = toast.loading('Kampagne wird versendet…')
    try {
      const res = await fetch(`/api/emails/campaigns/${id}/send`, { method: 'POST' })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Versand fehlgeschlagen')
      }
      const result = await res.json()
      toast.dismiss(loadingToast)
      toast.success(`${result.sent_count} von ${result.recipient_count} Mails versendet`)
      load()
      onChange()
    } catch (e) {
      toast.dismiss(loadingToast)
      toast.error(e instanceof Error ? e.message : 'Fehler')
    }
  }

  const deleteCampaign = async (id: string) => {
    if (!confirm('Entwurf wirklich löschen?')) return
    try {
      const res = await fetch(`/api/emails/campaigns/${id}`, { method: 'DELETE' })
      if (!res.ok) throw new Error('Löschen fehlgeschlagen')
      toast.success('Entwurf gelöscht')
      load()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    }
  }

  const drafts = campaigns.filter(c => c.status === 'draft')
  const sent = campaigns.filter(c => c.status === 'sent')

  return (
    <div className="space-y-6">
      {/* Aktions-Buttons */}
      <div className="flex flex-wrap items-center gap-2">
        <button
          onClick={generateDraft}
          disabled={generating}
          className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium shadow-sm disabled:opacity-50 transition-colors"
        >
          {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
          Newsletter-Entwurf generieren
        </button>
        <button
          onClick={() => setEditCampaign({
            id: '',
            type: 'update',
            status: 'draft',
            subject: '',
            preview_text: null,
            html_content: '',
            recipient_count: 0,
            sent_count: 0,
            auto_generated: false,
            sent_at: null,
            created_by: null,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-200 hover:bg-gray-50 text-gray-700 rounded-xl text-sm font-medium transition-colors"
        >
          <FileText className="w-4 h-4" />
          Neue Kampagne
        </button>
        <button
          onClick={load}
          className="inline-flex items-center gap-2 px-3 py-2 text-gray-500 hover:bg-gray-100 rounded-xl text-sm transition-colors"
        >
          <RefreshCw className="w-4 h-4" />
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-6 h-6 text-gray-300 animate-spin" />
        </div>
      ) : (
        <>
          {/* Entwürfe */}
          <section>
            <h3 className="text-sm font-bold text-gray-900 mb-3 flex items-center gap-2">
              <Edit3 className="w-4 h-4" />
              Entwürfe ({drafts.length})
            </h3>
            {drafts.length === 0 ? (
              <div className="text-sm text-gray-400 italic bg-gray-50 rounded-xl p-6 text-center">
                Keine Entwürfe vorhanden. Klicke oben auf „Newsletter-Entwurf generieren".
              </div>
            ) : (
              <div className="space-y-2">
                {drafts.map(c => (
                  <CampaignRow
                    key={c.id}
                    campaign={c}
                    onEdit={() => setEditCampaign(c)}
                    onPreview={() => setPreviewCampaign(c)}
                    onSend={() => sendCampaign(c.id)}
                    onDelete={() => deleteCampaign(c.id)}
                  />
                ))}
              </div>
            )}
          </section>

          {/* Versendet */}
          <section>
            <h3 className="text-sm font-bold text-gray-900 mb-3 flex items-center gap-2">
              <Send className="w-4 h-4" />
              Versendet ({sent.length})
            </h3>
            {sent.length === 0 ? (
              <div className="text-sm text-gray-400 italic bg-gray-50 rounded-xl p-6 text-center">
                Noch keine Kampagnen versendet.
              </div>
            ) : (
              <div className="space-y-2">
                {sent.map(c => (
                  <CampaignRow
                    key={c.id}
                    campaign={c}
                    onPreview={() => setPreviewCampaign(c)}
                  />
                ))}
              </div>
            )}
          </section>
        </>
      )}

      {/* Edit Modal */}
      {editCampaign && (
        <CampaignEditModal
          campaign={editCampaign}
          onClose={() => setEditCampaign(null)}
          onSaved={() => { setEditCampaign(null); load() }}
        />
      )}

      {/* Preview Modal */}
      {previewCampaign && (
        <PreviewModal
          campaign={previewCampaign}
          onClose={() => setPreviewCampaign(null)}
        />
      )}
    </div>
  )
}

// ============================================================
// Kampagnen-Zeile
// ============================================================
function CampaignRow({
  campaign, onEdit, onPreview, onSend, onDelete,
}: {
  campaign: AdminEmailCampaign
  onEdit?: () => void
  onPreview: () => void
  onSend?: () => void
  onDelete?: () => void
}) {
  const typeLabel = {
    welcome: 'Willkommen',
    newsletter: 'Newsletter',
    update: 'Update',
    custom: 'Kampagne',
  }[campaign.type]

  const dateLabel = campaign.sent_at
    ? new Date(campaign.sent_at).toLocaleString('de-DE', {
        day: '2-digit', month: '2-digit', year: 'numeric',
      })
    : new Date(campaign.created_at).toLocaleString('de-DE', {
        day: '2-digit', month: '2-digit', year: 'numeric',
      })

  return (
    <div className="flex items-center gap-3 p-3 bg-white border border-gray-100 hover:border-primary-200 rounded-xl transition-colors">
      <div className="flex-shrink-0 w-10 h-10 bg-primary-50 rounded-xl flex items-center justify-center">
        <Mail className="w-4 h-4 text-primary-600" />
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <p className="text-sm font-semibold text-gray-900 truncate">{campaign.subject}</p>
          {campaign.auto_generated && (
            <span className="flex-shrink-0 text-[10px] font-bold uppercase tracking-wide bg-primary-50 text-primary-700 px-1.5 py-0.5 rounded">
              Auto
            </span>
          )}
        </div>
        <p className="text-xs text-gray-500 mt-0.5">
          {typeLabel} · {dateLabel}
          {campaign.status === 'sent' && ` · ${campaign.sent_count}/${campaign.recipient_count} gesendet`}
        </p>
      </div>
      <div className="flex items-center gap-1 flex-shrink-0">
        <IconButton onClick={onPreview} title="Vorschau"><Eye className="w-4 h-4" /></IconButton>
        {onEdit && <IconButton onClick={onEdit} title="Bearbeiten"><Edit3 className="w-4 h-4" /></IconButton>}
        {onSend && (
          <button
            onClick={onSend}
            className="inline-flex items-center gap-1 px-3 py-1.5 bg-primary-500 hover:bg-primary-600 text-white rounded-lg text-xs font-medium"
          >
            <Send className="w-3 h-3" /> Senden
          </button>
        )}
        {onDelete && <IconButton onClick={onDelete} title="Löschen" danger><Trash2 className="w-4 h-4" /></IconButton>}
      </div>
    </div>
  )
}

function IconButton({
  onClick, title, children, danger,
}: { onClick: () => void; title: string; children: React.ReactNode; danger?: boolean }) {
  return (
    <button
      onClick={onClick}
      title={title}
      className={`w-8 h-8 rounded-lg flex items-center justify-center transition-colors ${
        danger
          ? 'text-red-500 hover:bg-red-50'
          : 'text-gray-500 hover:bg-gray-100 hover:text-gray-900'
      }`}
    >
      {children}
    </button>
  )
}

// ============================================================
// Edit Modal
// ============================================================
function CampaignEditModal({
  campaign, onClose, onSaved,
}: {
  campaign: AdminEmailCampaign
  onClose: () => void
  onSaved: () => void
}) {
  const isNew = !campaign.id
  const [subject, setSubject] = useState(campaign.subject)
  const [previewText, setPreviewText] = useState(campaign.preview_text ?? '')
  const [html, setHtml] = useState(campaign.html_content)
  const [saving, setSaving] = useState(false)
  const [showPreview, setShowPreview] = useState(false)

  const save = async () => {
    if (!subject.trim() || !html.trim()) {
      toast.error('Betreff und Inhalt sind erforderlich')
      return
    }
    setSaving(true)
    try {
      const url = isNew ? '/api/emails/campaigns' : `/api/emails/campaigns/${campaign.id}`
      const method = isNew ? 'POST' : 'PUT'
      const body = isNew
        ? { type: 'update', subject, preview_text: previewText, html_content: html }
        : { subject, preview_text: previewText, html_content: html }
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (!res.ok) throw new Error('Speichern fehlgeschlagen')
      toast.success('Gespeichert')
      onSaved()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <h3 className="text-lg font-bold text-gray-900">
            {isNew ? 'Neue Kampagne' : 'Kampagne bearbeiten'}
          </h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-900 text-2xl leading-none">×</button>
        </div>

        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          <div>
            <label className="block text-xs font-bold text-gray-700 mb-1.5">Betreff</label>
            <input
              type="text"
              value={subject}
              onChange={e => setSubject(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
              placeholder="z.B. Mensaena Wochennews · KW 17"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-gray-700 mb-1.5">Preview-Text (optional)</label>
            <input
              type="text"
              value={previewText}
              onChange={e => setPreviewText(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
              placeholder="Kurzer Anreißer-Text, der in der Mailbox erscheint"
            />
          </div>
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-bold text-gray-700">HTML-Inhalt</label>
              <button
                onClick={() => setShowPreview(p => !p)}
                className="text-xs text-primary-600 hover:underline"
              >
                {showPreview ? 'HTML anzeigen' : 'Vorschau anzeigen'}
              </button>
            </div>
            {showPreview ? (
              <div className="border border-gray-200 rounded-xl overflow-hidden bg-gray-50">
                <iframe srcDoc={html} className="w-full h-[500px]" />
              </div>
            ) : (
              <textarea
                value={html}
                onChange={e => setHtml(e.target.value)}
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-primary-400"
                rows={18}
                placeholder="<html>...</html>"
              />
            )}
          </div>
        </div>

        <div className="p-5 border-t border-gray-100 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-xl text-sm font-medium"
          >
            Abbrechen
          </button>
          <button
            onClick={save}
            disabled={saving}
            className="inline-flex items-center gap-2 px-5 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium shadow-sm disabled:opacity-50"
          >
            {saving && <Loader2 className="w-4 h-4 animate-spin" />}
            Speichern
          </button>
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Preview Modal
// ============================================================
function PreviewModal({ campaign, onClose }: { campaign: AdminEmailCampaign; onClose: () => void }) {
  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <div className="min-w-0">
            <h3 className="text-lg font-bold text-gray-900 truncate">{campaign.subject}</h3>
            <p className="text-xs text-gray-500 mt-0.5">Vorschau</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-900 text-2xl leading-none flex-shrink-0">×</button>
        </div>
        <div className="flex-1 overflow-y-auto bg-gray-50">
          <iframe srcDoc={campaign.html_content} className="w-full h-full min-h-[600px]" />
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Willkommensmail View
// ============================================================
function WelcomeView() {
  const [sending, setSending] = useState(false)
  const [result, setResult] = useState<{ sent: number; failed: number } | null>(null)

  const sendToAll = async () => {
    if (!confirm('Willkommensmail an alle aktiven Abonnenten senden? (Name wird automatisch aus dem Profil geladen)')) return
    setSending(true)
    setResult(null)
    try {
      const res = await fetch('/api/emails/welcome-all', { method: 'POST' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Fehler')
      setResult({ sent: data.sent, failed: data.failed })
      toast.success(`Willkommensmail versendet: ${data.sent} erfolgreich, ${data.failed} fehlgeschlagen`)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler beim Senden')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="bg-primary-50 border border-primary-100 rounded-2xl p-5">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center flex-shrink-0">
            <Sparkles className="w-5 h-5 text-primary-600" />
          </div>
          <div className="min-w-0 flex-1">
            <h3 className="text-sm font-bold text-gray-900">Automatische Willkommensmail</h3>
            <p className="text-xs text-gray-600 mt-1 leading-relaxed">
              Jeder neu registrierte User erhält automatisch eine Willkommensmail
              mit Mensaena-Logo, Feature-Übersicht und direktem Login-Link.
              Der Name wird automatisch aus dem Nutzerprofil gelesen.
            </p>
            <div className="mt-3 flex items-center gap-2 flex-wrap">
              <button
                onClick={sendToAll}
                disabled={sending}
                className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-xs font-medium shadow-sm disabled:opacity-50 transition-colors"
              >
                {sending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
                An alle Subscriber senden
              </button>
              {result && (
                <span className="text-xs text-gray-600">
                  {result.sent} gesendet · {result.failed} fehlgeschlagen
                </span>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white border border-gray-100 rounded-2xl p-5">
        <h4 className="text-sm font-bold text-gray-900 mb-3">Vorschau</h4>
        <div className="border border-gray-200 rounded-xl overflow-hidden bg-gray-50">
          <iframe
            src="/api/emails/welcome-preview"
            className="w-full h-[600px] bg-white"
            title="Welcome Email Preview"
          />
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Abonnenten View
// ============================================================
function SubscribersView() {
  const [subscribers, setSubscribers] = useState<AdminEmailSubscription[]>([])
  const [loading, setLoading] = useState(true)
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<'all' | 'active' | 'unsubscribed'>('all')

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data, error } = await supabase
      .from('email_subscriptions')
      .select('*, profiles(name)')
      .order('created_at', { ascending: false })
      .limit(500)
    if (error) {
      toast.error('Laden fehlgeschlagen')
    } else {
      setSubscribers((data ?? []) as AdminEmailSubscription[])
    }
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const filtered = useMemo(() => {
    return subscribers.filter(s => {
      if (filter === 'active' && !s.subscribed) return false
      if (filter === 'unsubscribed' && s.subscribed) return false
      if (query && !s.email.toLowerCase().includes(query.toLowerCase())) return false
      return true
    })
  }, [subscribers, query, filter])

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="E-Mail suchen..."
            className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
          />
        </div>
        <select
          value={filter}
          onChange={e => setFilter(e.target.value as typeof filter)}
          className="px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
        >
          <option value="all">Alle ({subscribers.length})</option>
          <option value="active">Aktiv ({subscribers.filter(s => s.subscribed).length})</option>
          <option value="unsubscribed">Abgemeldet ({subscribers.filter(s => !s.subscribed).length})</option>
        </select>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-6 h-6 text-gray-300 animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-sm text-gray-400 italic bg-gray-50 rounded-xl p-6 text-center">
          Keine Einträge
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs font-bold text-gray-500 uppercase tracking-wider border-b border-gray-100">
                <th className="px-3 py-2">E-Mail</th>
                <th className="px-3 py-2">Name</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Angemeldet</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filtered.map(s => (
                <tr key={s.id} className="hover:bg-gray-50">
                  <td className="px-3 py-2.5 text-gray-900">{s.email}</td>
                  <td className="px-3 py-2.5 text-gray-600">{s.profiles?.name ?? '–'}</td>
                  <td className="px-3 py-2.5">
                    {s.subscribed ? (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-green-50 text-green-700 rounded-full text-xs font-medium">
                        <CheckCircle2 className="w-3 h-3" /> Aktiv
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-600 rounded-full text-xs font-medium">
                        <XCircle className="w-3 h-3" /> Abgemeldet
                      </span>
                    )}
                  </td>
                  <td className="px-3 py-2.5 text-gray-500 text-xs">
                    {new Date(s.created_at).toLocaleDateString('de-DE')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
