'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  Mail, Send, Edit3, Trash2, Eye, Loader2, Users,
  CheckCircle2, XCircle, Sparkles, FileText, RefreshCw, Search,
  ShieldCheck, GitBranch, MousePointerClick, TrendingUp, Bell,
  AlertTriangle, Monitor, Smartphone, Share2, FlaskConical,
  UserCheck, Zap,
} from 'lucide-react'
import toast from 'react-hot-toast'
import type { AdminEmailCampaign, AdminEmailSubscription } from './AdminTypes'

// Auth-Header Helper: Liest den Supabase-Session-Token und sendet ihn als Bearer
async function authFetch(url: string, init?: RequestInit): Promise<Response> {
  const supabase = createClient()
  const { data: { session } } = await supabase.auth.getSession()
  const headers: Record<string, string> = {
    ...(init?.headers as Record<string, string> || {}),
  }
  if (session?.access_token) {
    headers['Authorization'] = `Bearer ${session.access_token}`
  }
  return fetch(url, { ...init, headers })
}

import EmailBlockEditor from './EmailBlockEditor'

type ViewMode = 'campaigns' | 'welcome' | 'subscribers' | 'editor' | 'drip' | 'compliance'

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
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
        <div className="border-b border-stone-100 px-4 py-3 flex items-center gap-2 overflow-x-auto">
          <ViewTab active={view === 'campaigns'}   onClick={() => setView('campaigns')}   icon={<Mail className="w-4 h-4" />}  label="Kampagnen" />
          <ViewTab active={view === 'drip'}        onClick={() => setView('drip')}        icon={<GitBranch className="w-4 h-4" />} label="Drip-Funnels" />
          <ViewTab active={view === 'welcome'}     onClick={() => setView('welcome')}     icon={<Sparkles className="w-4 h-4" />} label="Willkommensmail" />
          <ViewTab active={view === 'subscribers'} onClick={() => setView('subscribers')} icon={<Users className="w-4 h-4" />} label="Abonnenten" />
          <ViewTab active={view === 'compliance'}  onClick={() => setView('compliance')}  icon={<ShieldCheck className="w-4 h-4" />} label="Compliance" />
          <ViewTab active={view === 'editor'} onClick={() => setView('editor')} icon={<Edit3 className="w-4 h-4" />} label="Editor" />
        </div>

        <div className="p-4 lg:p-5">
          {view === 'campaigns'   && <CampaignsView onChange={loadStats} />}
          {view === 'drip'        && <DripView />}
          {view === 'welcome'     && <WelcomeView />}
          {view === 'subscribers' && <SubscribersView />}
          {view === 'compliance'  && <ComplianceView />}
          {view === 'editor' && (
            <EmailBlockEditor onSave={(html) => {
              setView('campaigns')
              // Kampagne als Entwurf erstellen
              authFetch('/api/emails/campaigns', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ type: 'custom', subject: 'Neue Kampagne (Block-Editor)', html_content: html }),
              }).then(res => {
                if (res.ok) toast.success('Kampagne aus Editor erstellt')
                else toast.error('Fehler beim Erstellen')
              })
            }} />
          )}
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
    gray:    'bg-stone-50 text-ink-600 border-stone-200',
  }
  return (
    <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4">
      <div className="flex items-start justify-between">
        <div className={`w-10 h-10 rounded-xl border flex items-center justify-center ${colorMap[color]}`}>
          {icon}
        </div>
        {loading && <Loader2 className="w-4 h-4 text-stone-400 animate-spin" />}
      </div>
      <p className="mt-3 text-2xl font-bold text-ink-900 tabular-nums">{value.toLocaleString('de-DE')}</p>
      <p className="text-xs text-ink-500 mt-0.5">{label}</p>
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
          : 'text-ink-600 hover:bg-stone-100'
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
  const [generatingFree, setGeneratingFree] = useState(false)
  const [freeTopic, setFreeTopic] = useState('')
  const [editCampaign, setEditCampaign] = useState<AdminEmailCampaign | null>(null)
  const [previewCampaign, setPreviewCampaign] = useState<AdminEmailCampaign | null>(null)
  const [sendCampaignId, setSendCampaignId] = useState<string | null>(null)
  const [sendMode, setSendMode] = useState<'all' | 'specific' | 'segment'>('all')
  const [sendEmails, setSendEmails] = useState('')
  const [sendSegment, setSendSegment] = useState('new_7d')
  const [sending, setSending] = useState(false)
  const [scheduledAt, setScheduledAt] = useState('')
  const [channels, setChannels] = useState<string[]>(['email'])
  const [aiScore, setAiScore] = useState<{ score: number; feedback: string; alternatives: string[] } | null>(null)
  const [aiScoring, setAiScoring] = useState(false)
  const [abEnabled, setAbEnabled] = useState(false)
  const [abSubjectA, setAbSubjectA] = useState('')
  const [abSubjectB, setAbSubjectB] = useState('')
  const [abSplitPct, setAbSplitPct] = useState(10)
  const [socialGenerating, setSocialGenerating] = useState<string | null>(null)
  const [socialResult, setSocialResult] = useState<{ facebook: string; instagram: string; hashtags: string[] } | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const supabase = createClient()
      const { data, error } = await supabase
        .from('email_campaigns')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100)
      if (error) throw error
      setCampaigns((data ?? []) as AdminEmailCampaign[])
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
      const res = await authFetch('/api/emails/generate-draft', {
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

  // Sende-Modal öffnen statt direkt senden
  const openSendModal = (id: string) => {
    setSendCampaignId(id)
    setSendMode('all')
    setSendEmails('')
    setScheduledAt('')
    setChannels(['email'])
    setAiScore(null)
    setAbEnabled(false)
    const c = campaigns.find(x => x.id === id)
    setAbSubjectA(c?.subject ?? '')
    setAbSubjectB('')
    setAbSplitPct(10)
  }

  const generateSocialPost = async (campaignId: string) => {
    setSocialGenerating(campaignId)
    setSocialResult(null)
    try {
      const res = await authFetch('/api/social/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ campaign_id: campaignId }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Fehler')
      setSocialResult({ facebook: data.facebook, instagram: data.instagram, hashtags: data.hashtags })
      toast.success('Social Posts generiert und als Entwurf gespeichert!')
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setSocialGenerating(null)
    }
  }

  const runAiOptimizer = async () => {
    const campaign = campaigns.find(c => c.id === sendCampaignId)
    if (!campaign) return
    setAiScoring(true)
    try {
      const res = await authFetch('/api/emails/optimize-subject', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject: campaign.subject, preview_text: campaign.preview_text }),
      })
      const data = await res.json()
      if (res.ok) setAiScore(data)
      else toast.error('AI-Analyse fehlgeschlagen')
    } catch {
      toast.error('AI-Analyse fehlgeschlagen')
    } finally {
      setAiScoring(false)
    }
  }

  const toggleChannel = (ch: string) =>
    setChannels(prev => prev.includes(ch) ? prev.filter(c => c !== ch) : [...prev, ch])

  const doSend = async () => {
    if (!sendCampaignId) return
    setSending(true)
    const loadingToast = toast.loading('Kampagne wird versendet…')
    try {
      const body: Record<string, unknown> = { channels }
      if (sendMode === 'specific' && sendEmails.trim()) {
        body.emails = sendEmails.split(/[,;\n]+/).map(e => e.trim()).filter(Boolean)
      }
      if (sendMode === 'segment') {
        body.segment = sendSegment
      }
      if (scheduledAt) {
        body.scheduled_at = new Date(scheduledAt).toISOString()
      }
      // A/B Test anlegen falls aktiv
      if (abEnabled && abSubjectA.trim() && abSubjectB.trim()) {
        await authFetch('/api/emails/ab-test', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ campaign_id: sendCampaignId, subject_a: abSubjectA, subject_b: abSubjectB, split_pct: abSplitPct }),
        })
      }

      const res = await authFetch(`/api/emails/campaigns/${sendCampaignId}/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Versand fehlgeschlagen')
      }
      const result = await res.json()
      toast.dismiss(loadingToast)
      if (scheduledAt) {
        toast.success(`Versand geplant für ${new Date(scheduledAt).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}`)
      } else {
        toast.success(`${result.sent_count} von ${result.recipient_count} Mails versendet`)
      }
      setSendCampaignId(null)
      load()
      onChange()
    } catch (e) {
      toast.dismiss(loadingToast)
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setSending(false)
    }
  }

  // Freies Thema generieren via AI
  const generateFreeTopic = async () => {
    if (!freeTopic.trim()) { toast.error('Bitte ein Thema eingeben'); return }
    setGeneratingFree(true)
    try {
      const res = await authFetch('/api/emails/generate-draft', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-cron-secret': 'manual' },
        body: JSON.stringify({ topic: freeTopic.trim() }),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Fehler beim Generieren')
      }
      toast.success('Entwurf generiert')
      setFreeTopic('')
      load()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setGeneratingFree(false)
    }
  }

  const deleteCampaign = async (id: string) => {
    if (!confirm('Entwurf wirklich löschen?')) return
    try {
      const res = await authFetch(`/api/emails/campaigns/${id}`, { method: 'DELETE' })
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
    <div className="space-y-5">
      {/* Bereich 1: Wochenrückblick (letzte 7 Tage) */}
      <div className="bg-primary-50 border border-primary-100 rounded-2xl p-4">
        <div className="flex items-center gap-2 mb-2">
          <span className="text-lg">📊</span>
          <h3 className="text-sm font-bold text-ink-900">Wochenrückblick generieren</h3>
        </div>
        <p className="text-xs text-ink-600 mb-3">Erstellt automatisch einen Newsletter aus der Plattform-Aktivität der letzten 7 Tage (neue Beiträge, Events, Gruppen, Mitglieder).</p>
        <button
          onClick={generateDraft}
          disabled={generating}
          className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-xs font-medium shadow-sm disabled:opacity-50 transition-colors"
        >
          {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
          Wochenrückblick generieren
        </button>
      </div>

      {/* Bereich 2: Freies Thema (KI generiert beliebigen Newsletter) */}
      <div className="bg-white border border-stone-100 rounded-2xl p-4 shadow-sm">
        <div className="flex items-center gap-2 mb-2">
          <span className="text-lg">🤖</span>
          <h3 className="text-sm font-bold text-ink-900">Newsletter zu beliebigem Thema</h3>
        </div>
        <p className="text-xs text-ink-600 mb-3">KI generiert einen professionellen Newsletter zu jedem gewünschten Thema — Sommer-Aktionen, Sicherheitstipps, Feiertage, uvm.</p>
        <div className="flex gap-2">
          <input
            type="text"
            value={freeTopic}
            onChange={e => setFreeTopic(e.target.value)}
            placeholder="z.B. 'Sommerfest 2026', 'Tipps für Nachbarschaftshilfe', 'Weihnachtsaktion'"
            className="flex-1 px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
            onKeyDown={e => e.key === 'Enter' && generateFreeTopic()}
          />
          <button
            onClick={generateFreeTopic}
            disabled={generatingFree}
            className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-xs font-medium shadow-sm disabled:opacity-50 transition-colors whitespace-nowrap"
          >
            {generatingFree ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
            Generieren
          </button>
        </div>
      </div>

      {/* Aktions-Buttons */}
      <div className="flex flex-wrap items-center gap-2">
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
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-stone-200 hover:bg-stone-50 text-ink-700 rounded-xl text-sm font-medium transition-colors"
        >
          <FileText className="w-4 h-4" />
          Neue Kampagne
        </button>
        <button
          onClick={load}
          className="inline-flex items-center gap-2 px-3 py-2 text-ink-500 hover:bg-stone-100 rounded-xl text-sm transition-colors"
        >
          <RefreshCw className="w-4 h-4" />
        </button>
      </div>

      {/* Standard-Templates */}
      <div className="bg-white border border-stone-100 rounded-2xl p-4">
        <p className="text-xs font-bold text-ink-700 mb-3">Standard-Vorlagen (klicken zum Erstellen):</p>
        <div className="flex flex-wrap gap-2">
          {([
            { key: 'new_features',        label: 'Neue Features',           icon: '🚀', type: 'update' },
            { key: 'community_highlight', label: 'Community-Highlight',     icon: '🤝', type: 'update' },
            { key: 'event_invite',        label: 'Event-Einladung',         icon: '📅', type: 'update' },
            { key: 'inactivity_reminder', label: 'Inaktivitäts-Erinnerung', icon: '💚', type: 'update' },
            { key: 'security_update',     label: 'Sicherheits-Update',      icon: '🔒', type: 'update' },
          ] as const).map(tpl => (
            <button
              key={tpl.key}
              onClick={async () => {
                try {
                  const res = await authFetch(`/api/emails/standard-template?template=${tpl.key}`)
                  const data = await res.json()
                  if (!res.ok) throw new Error(data.error)
                  setEditCampaign({
                    id: '',
                    type: tpl.type,
                    status: 'draft',
                    subject: data.subject,
                    preview_text: null,
                    html_content: data.html,
                    recipient_count: 0,
                    sent_count: 0,
                    auto_generated: false,
                    sent_at: null,
                    created_by: null,
                    created_at: new Date().toISOString(),
                    updated_at: new Date().toISOString(),
                  })
                } catch (e) {
                  toast.error(e instanceof Error ? e.message : 'Template laden fehlgeschlagen')
                }
              }}
              className="px-3 py-2 bg-stone-50 hover:bg-primary-50 border border-stone-200 hover:border-primary-200 rounded-xl text-xs font-medium text-ink-700 hover:text-primary-700 transition-all"
            >
              {tpl.icon} {tpl.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-5 h-5 text-stone-400 animate-spin" />
        </div>
      ) : (
        <>
          {/* Entwürfe */}
          <section>
            <h3 className="text-sm font-bold text-ink-900 mb-3 flex items-center gap-2">
              <Edit3 className="w-4 h-4" />
              Entwürfe ({drafts.length})
            </h3>
            {drafts.length === 0 ? (
              <div className="text-sm text-ink-400 italic bg-stone-50 rounded-xl p-6 text-center">
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
                    onSend={() => openSendModal(c.id)}
                    onDelete={() => deleteCampaign(c.id)}
                    onGenerateSocial={() => generateSocialPost(c.id)}
                  />
                ))}
              </div>
            )}
          </section>

          {/* Versendet */}
          <section>
            <h3 className="text-sm font-bold text-ink-900 mb-3 flex items-center gap-2">
              <Send className="w-4 h-4" />
              Versendet ({sent.length})
            </h3>
            {sent.length === 0 ? (
              <div className="text-sm text-ink-400 italic bg-stone-50 rounded-xl p-6 text-center">
                Noch keine Kampagnen versendet.
              </div>
            ) : (
              <div className="space-y-2">
                {sent.map(c => (
                  <CampaignRow
                    key={c.id}
                    campaign={c}
                    onPreview={() => setPreviewCampaign(c)}
                    onGenerateSocial={() => generateSocialPost(c.id)}
                  />
                ))}
              </div>
            )}
          </section>
        </>
      )}

      {/* Social Post Ergebnis-Modal */}
      {(socialGenerating || socialResult) && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg">
            <div className="flex items-center justify-between p-5 border-b border-stone-100">
              <div className="flex items-center gap-2">
                <Share2 className="w-5 h-5 text-blue-600" />
                <h3 className="text-sm font-bold text-ink-900">Social Post generiert</h3>
              </div>
              <button onClick={() => { setSocialResult(null); setSocialGenerating(null) }} className="text-ink-400 hover:text-ink-900 text-2xl">×</button>
            </div>
            {socialGenerating ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="w-6 h-6 animate-spin text-primary-500" />
                <span className="ml-3 text-sm text-ink-500">KI generiert Posts…</span>
              </div>
            ) : socialResult && (
              <div className="p-5 space-y-4">
                <div className="bg-blue-50 border border-blue-100 rounded-xl p-4">
                  <p className="text-[10px] font-bold text-blue-700 uppercase tracking-wide mb-2">📘 Facebook</p>
                  <p className="text-sm text-ink-700 whitespace-pre-wrap">{socialResult.facebook}</p>
                </div>
                <div className="bg-pink-50 border border-pink-100 rounded-xl p-4">
                  <p className="text-[10px] font-bold text-pink-700 uppercase tracking-wide mb-2">📸 Instagram</p>
                  <p className="text-sm text-ink-700 whitespace-pre-wrap">{socialResult.instagram}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  {socialResult.hashtags.map((tag, i) => (
                    <span key={i} className="px-2 py-1 bg-stone-100 text-ink-600 rounded-lg text-xs font-medium">{tag}</span>
                  ))}
                </div>
                <p className="text-xs text-ink-500">Posts wurden als Entwurf in Social Media gespeichert. Bearbeiten & veröffentlichen unter Marketing → Social Media.</p>
              </div>
            )}
          </div>
        </div>
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

      {/* Sende-Modal: Empfänger wählen */}
      {sendCampaignId && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-5 border-b border-stone-100">
              <h3 className="text-sm font-bold text-ink-900">Kampagne versenden</h3>
              <button onClick={() => setSendCampaignId(null)} className="text-ink-400 hover:text-ink-900 text-xl">×</button>
            </div>
            <div className="p-5 space-y-4">

              {/* AI-Optimizer */}
              <div className="bg-gradient-to-r from-primary-50 to-blue-50 border border-primary-100 rounded-xl p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <TrendingUp className="w-4 h-4 text-primary-600" />
                    <span className="text-xs font-bold text-ink-800">KI-Betreffzeilen-Analyse</span>
                  </div>
                  <button
                    onClick={runAiOptimizer}
                    disabled={aiScoring}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-primary-500 hover:bg-primary-600 text-white rounded-lg text-xs font-medium disabled:opacity-50"
                  >
                    {aiScoring ? <Loader2 className="w-3 h-3 animate-spin" /> : <Sparkles className="w-3 h-3" />}
                    Analysieren
                  </button>
                </div>
                {aiScore && (
                  <div className="space-y-2">
                    <div className="flex items-center gap-3">
                      <div className="flex-1 h-2 bg-stone-200 rounded-full overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all ${aiScore.score >= 60 ? 'bg-green-500' : aiScore.score >= 40 ? 'bg-yellow-500' : 'bg-red-500'}`}
                          style={{ width: `${aiScore.score}%` }}
                        />
                      </div>
                      <span className="text-sm font-bold text-ink-900 tabular-nums">{aiScore.score}%</span>
                    </div>
                    <p className="text-xs text-ink-600">{aiScore.feedback}</p>
                    {aiScore.alternatives.length > 0 && (
                      <div className="space-y-1">
                        <p className="text-[10px] font-bold text-ink-500 uppercase tracking-wide">Bessere Alternativen:</p>
                        {aiScore.alternatives.map((alt, i) => (
                          <button
                            key={i}
                            onClick={() => {
                              const c = campaigns.find(x => x.id === sendCampaignId)
                              if (c) { c.subject = alt; toast.success('Betreff übernommen – bitte Kampagne speichern') }
                            }}
                            className="block w-full text-left text-xs text-primary-700 hover:text-primary-900 bg-white hover:bg-primary-50 border border-primary-100 rounded-lg px-3 py-2 transition-colors"
                          >
                            {alt}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                )}
                {!aiScore && !aiScoring && (
                  <p className="text-xs text-ink-500">Analysiert Betreffzeile + gibt Verbesserungsvorschläge basierend auf bisherigen Öffnungsraten.</p>
                )}
              </div>

              {/* Multi-Channel */}
              <div className="border border-stone-100 rounded-xl p-4">
                <p className="text-xs font-bold text-ink-700 mb-3">Kanäle wählen</p>
                <div className="flex flex-wrap gap-2">
                  {[
                    { id: 'email', label: 'E-Mail', icon: <Mail className="w-3.5 h-3.5" /> },
                    { id: 'push',  label: 'Push-Benachrichtigung', icon: <Bell className="w-3.5 h-3.5" /> },
                  ].map(ch => (
                    <button
                      key={ch.id}
                      onClick={() => toggleChannel(ch.id)}
                      className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium border transition-all ${
                        channels.includes(ch.id)
                          ? 'bg-primary-500 text-white border-primary-500'
                          : 'bg-white text-ink-600 border-stone-200 hover:border-primary-300'
                      }`}
                    >
                      {ch.icon} {ch.label}
                      {channels.includes(ch.id) && <CheckCircle2 className="w-3 h-3" />}
                    </button>
                  ))}
                </div>
              </div>
              <div className="space-y-2">
                <label className="flex items-center gap-3 p-3 border rounded-xl cursor-pointer hover:bg-stone-50 transition-colors">
                  <input type="radio" name="sendMode" checked={sendMode === 'all'} onChange={() => setSendMode('all')} className="accent-primary-500" />
                  <div>
                    <p className="text-sm font-medium text-ink-900">An alle Abonnenten</p>
                    <p className="text-xs text-ink-500">Alle aktiven Subscriber</p>
                  </div>
                </label>
                <label className="flex items-center gap-3 p-3 border rounded-xl cursor-pointer hover:bg-stone-50 transition-colors">
                  <input type="radio" name="sendMode" checked={sendMode === 'segment'} onChange={() => setSendMode('segment')} className="accent-primary-500" />
                  <div>
                    <p className="text-sm font-medium text-ink-900">An eine Gruppe</p>
                    <p className="text-xs text-ink-500">Neue User, Inaktive oder nach Region</p>
                  </div>
                </label>
                <label className="flex items-center gap-3 p-3 border rounded-xl cursor-pointer hover:bg-stone-50 transition-colors">
                  <input type="radio" name="sendMode" checked={sendMode === 'specific'} onChange={() => setSendMode('specific')} className="accent-primary-500" />
                  <div>
                    <p className="text-sm font-medium text-ink-900">An bestimmte Personen</p>
                    <p className="text-xs text-ink-500">Manuelle E-Mail-Adressen eingeben</p>
                  </div>
                </label>
              </div>
              {sendMode === 'segment' && (
                <div className="space-y-2">
                  <label className="block text-xs font-bold text-ink-700 mb-1">Empfänger-Gruppe wählen</label>
                  <select
                    value={sendSegment}
                    onChange={e => setSendSegment(e.target.value)}
                    className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                  >
                    <option value="new_7d">Neue User (letzte 7 Tage)</option>
                    <option value="new_30d">Neue User (letzte 30 Tage)</option>
                    <option value="inactive_30d">Inaktive User (30+ Tage)</option>
                    <option value="inactive_90d">Inaktive User (90+ Tage)</option>
                  </select>
                </div>
              )}
              {sendMode === 'specific' && (
                <div>
                  <label className="block text-xs font-bold text-ink-700 mb-1">E-Mail-Adressen (je Zeile eine oder kommagetrennt)</label>
                  <textarea
                    value={sendEmails}
                    onChange={e => setSendEmails(e.target.value)}
                    className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                    rows={4}
                    placeholder={"max@beispiel.de\nanna@beispiel.de"}
                  />
                </div>
              )}
              {/* A/B Testing */}
              <div className="border border-stone-100 rounded-xl p-4">
                <label className="flex items-center gap-3 cursor-pointer">
                  <div className={`w-10 h-6 rounded-full transition-colors relative ${abEnabled ? 'bg-primary-500' : 'bg-stone-200'}`}>
                    <div className={`absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-all ${abEnabled ? 'left-5' : 'left-1'}`} />
                    <input type="checkbox" className="sr-only" checked={abEnabled} onChange={e => setAbEnabled(e.target.checked)} />
                  </div>
                  <div className="flex items-center gap-2">
                    <FlaskConical className="w-4 h-4 text-purple-600" />
                    <span className="text-xs font-bold text-ink-800">A/B-Test aktivieren</span>
                  </div>
                </label>
                {abEnabled && (
                  <div className="mt-3 space-y-2">
                    <p className="text-[10px] text-ink-500">Jede Variante wird an {abSplitPct}% der Empfänger gesendet. Nach 4h gewinnt die Version mit mehr Öffnungen.</p>
                    <div>
                      <label className="block text-[10px] font-bold text-ink-600 mb-1">Betreff A</label>
                      <input value={abSubjectA} onChange={e => setAbSubjectA(e.target.value)} className="w-full px-3 py-2 border border-purple-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-400" placeholder="Variante A" />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-ink-600 mb-1">Betreff B</label>
                      <input value={abSubjectB} onChange={e => setAbSubjectB(e.target.value)} className="w-full px-3 py-2 border border-purple-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-400" placeholder="Variante B" />
                    </div>
                    <div className="flex items-center gap-3">
                      <label className="text-[10px] text-ink-600 whitespace-nowrap">Split: {abSplitPct}% / {abSplitPct}%</label>
                      <input type="range" min={5} max={30} value={abSplitPct} onChange={e => setAbSplitPct(Number(e.target.value))} className="flex-1 accent-purple-500" />
                    </div>
                  </div>
                )}
              </div>

              {/* Geplanter Versand */}
              <div className="border-t border-stone-100 pt-3">
                <label className="flex items-center gap-2 text-xs text-ink-700">
                  <input
                    type="checkbox"
                    checked={!!scheduledAt}
                    onChange={e => setScheduledAt(e.target.checked ? new Date(Date.now() + 3600000).toISOString().slice(0, 16) : '')}
                    className="accent-primary-500"
                  />
                  <span className="font-medium">Versand planen</span>
                </label>
                {scheduledAt && (
                  <input
                    type="datetime-local"
                    value={scheduledAt}
                    onChange={e => setScheduledAt(e.target.value)}
                    min={new Date().toISOString().slice(0, 16)}
                    className="mt-2 w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
                  />
                )}
              </div>
            </div>
            <div className="p-5 border-t border-stone-100 flex justify-end gap-2">
              <button onClick={() => setSendCampaignId(null)} className="px-4 py-2 text-ink-600 hover:bg-stone-100 rounded-xl text-sm">Abbrechen</button>
              <button
                onClick={doSend}
                disabled={sending || (sendMode === 'specific' && !sendEmails.trim())}
                className="inline-flex items-center gap-2 px-5 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium shadow-sm disabled:opacity-50"
              >
                {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                {scheduledAt ? 'Versand planen' : 'Jetzt senden'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ============================================================
// Kampagnen-Zeile
// ============================================================
function CampaignRow({
  campaign, onEdit, onPreview, onSend, onDelete, onGenerateSocial,
}: {
  campaign: AdminEmailCampaign
  onEdit?: () => void
  onPreview: () => void
  onSend?: () => void
  onDelete?: () => void
  onGenerateSocial?: () => void
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
    <div className="flex items-center gap-3 p-3 bg-white border border-stone-100 hover:border-primary-200 rounded-xl transition-colors">
      <div className="flex-shrink-0 w-10 h-10 bg-primary-50 rounded-xl flex items-center justify-center">
        <Mail className="w-4 h-4 text-primary-600" />
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <p className="text-sm font-semibold text-ink-900 truncate">{campaign.subject}</p>
          {campaign.auto_generated && (
            <span className="flex-shrink-0 text-[10px] font-bold uppercase tracking-wide bg-primary-50 text-primary-700 px-1.5 py-0.5 rounded">
              Auto
            </span>
          )}
        </div>
        <p className="text-xs text-ink-500 mt-0.5">
          {typeLabel} · {dateLabel}
          {campaign.status === 'sent' && (
            <>
              {` · ${campaign.sent_count}/${campaign.recipient_count} versendet`}
              {(campaign as { open_count?: number }).open_count !== undefined && (campaign as { open_count?: number }).open_count! > 0 && (
                <span className="ml-1.5 text-green-600">· {(campaign as { open_count?: number }).open_count} Öffnungen</span>
              )}
              {(campaign as { click_count?: number }).click_count !== undefined && (campaign as { click_count?: number }).click_count! > 0 && (
                <span className="ml-1.5 text-blue-600">· {(campaign as { click_count?: number }).click_count} Klicks</span>
              )}
            </>
          )}
        </p>
      </div>
      <div className="flex items-center gap-1 flex-shrink-0">
        <IconButton onClick={onPreview} title="Vorschau"><Eye className="w-4 h-4" /></IconButton>
        {onEdit && <IconButton onClick={onEdit} title="Bearbeiten"><Edit3 className="w-4 h-4" /></IconButton>}
        {onGenerateSocial && (
          <IconButton onClick={onGenerateSocial} title="Social Post generieren">
            <Share2 className="w-4 h-4" />
          </IconButton>
        )}
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
      aria-label={title}
      className={`w-10 h-10 rounded-lg flex items-center justify-center transition-colors ${
        danger
          ? 'text-red-500 hover:bg-red-50'
          : 'text-ink-500 hover:bg-stone-100 hover:text-ink-900'
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
      const res = await authFetch(url, {
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
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg sm:max-w-2xl lg:max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-5 border-b border-stone-100">
          <h3 className="text-lg font-bold text-ink-900">
            {isNew ? 'Neue Kampagne' : 'Kampagne bearbeiten'}
          </h3>
          <button onClick={onClose} className="text-ink-400 hover:text-ink-900 text-2xl leading-none" aria-label="Schließen">×</button>
        </div>

        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          <div>
            <label className="block text-xs font-bold text-ink-700 mb-1.5">Betreff</label>
            <input
              type="text"
              value={subject}
              onChange={e => setSubject(e.target.value)}
              className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
              placeholder="z.B. Hallo {{vorname}}, diese Woche in Mensaena…"
            />
          </div>

          {/* Personalisierungs-Hinweis */}
          <div className="bg-blue-50 border border-blue-100 rounded-xl p-3">
            <p className="text-xs font-bold text-blue-800 mb-1.5">🎯 Personalisierung (erhöht Öffnungsrate um bis zu 26%)</p>
            <div className="flex flex-wrap gap-1.5">
              {[
                { var: '{{vorname}}', desc: 'Vorname des Nutzers' },
                { var: '{{name}}',    desc: 'Voller Name' },
                { var: '{{stadt}}',   desc: 'Wohnort / Stadtteil' },
                { var: '{{letzte_hilfe}}', desc: 'Letzte Hilfsaktion' },
              ].map(p => (
                <button
                  key={p.var}
                  onClick={() => setSubject(s => s + p.var)}
                  title={p.desc}
                  className="px-2 py-1 bg-white border border-blue-200 rounded-lg text-[11px] font-mono text-blue-700 hover:bg-blue-100 transition-colors"
                >
                  {p.var}
                </button>
              ))}
            </div>
            <p className="text-[10px] text-blue-600 mt-1.5">Klicken zum Einfügen in Betreff. Im HTML-Inhalt ebenfalls nutzbar.</p>
          </div>
          <div>
            <label className="block text-xs font-bold text-ink-700 mb-1.5">Preview-Text (optional)</label>
            <input
              type="text"
              value={previewText}
              onChange={e => setPreviewText(e.target.value)}
              className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
              placeholder="Kurzer Anreißer-Text, der in der Mailbox erscheint"
            />
          </div>
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-bold text-ink-700">HTML-Inhalt</label>
              <button
                onClick={() => setShowPreview(p => !p)}
                className="text-xs text-primary-600 hover:underline"
              >
                {showPreview ? 'HTML anzeigen' : 'Vorschau anzeigen'}
              </button>
            </div>
            {showPreview ? (
              <div className="border border-stone-200 rounded-xl overflow-hidden bg-stone-50">
                <iframe srcDoc={html} className="w-full h-[500px]" />
              </div>
            ) : (
              <textarea
                value={html}
                onChange={e => setHtml(e.target.value)}
                className="w-full px-3 py-2 border border-stone-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-primary-400"
                rows={18}
                placeholder="<html>...</html>"
              />
            )}
          </div>
        </div>

        <div className="p-5 border-t border-stone-100 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-ink-600 hover:bg-stone-100 rounded-xl text-sm font-medium"
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
// Preview Modal – Desktop / Mobile Toggle
// ============================================================
function PreviewModal({ campaign, onClose }: { campaign: AdminEmailCampaign; onClose: () => void }) {
  const [device, setDevice] = useState<'desktop' | 'mobile'>('desktop')
  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-5 border-b border-stone-100">
          <div className="min-w-0">
            <h3 className="text-lg font-bold text-ink-900 truncate">{campaign.subject}</h3>
            <p className="text-xs text-ink-500 mt-0.5">Vorschau</p>
          </div>
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1 bg-stone-100 rounded-xl p-1">
              <button
                onClick={() => setDevice('desktop')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${device === 'desktop' ? 'bg-white shadow-sm text-ink-900' : 'text-ink-500 hover:text-ink-700'}`}
              >
                <Monitor className="w-3.5 h-3.5" /> Desktop
              </button>
              <button
                onClick={() => setDevice('mobile')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${device === 'mobile' ? 'bg-white shadow-sm text-ink-900' : 'text-ink-500 hover:text-ink-700'}`}
              >
                <Smartphone className="w-3.5 h-3.5" /> Mobile
              </button>
            </div>
            <button onClick={onClose} className="text-ink-400 hover:text-ink-900 text-2xl leading-none">×</button>
          </div>
        </div>
        <div className="flex-1 overflow-y-auto bg-stone-100 flex justify-center p-4">
          <div style={{ width: device === 'mobile' ? '375px' : '100%' }} className="transition-all duration-300">
            <iframe srcDoc={campaign.html_content} className="w-full bg-white rounded-xl shadow-sm" style={{ minHeight: '600px', border: 'none' }} />
          </div>
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Willkommensmail View
// ============================================================
function WelcomeView() {
  const [logs, setLogs] = useState<Array<{ id: string; email: string; status: string; sent_at: string }>>([])
  const [loadingLogs, setLoadingLogs] = useState(true)

  const loadLogs = useCallback(async () => {
    setLoadingLogs(true)
    const supabase = createClient()
    const { data } = await supabase
      .from('email_logs')
      .select('id, email, status, sent_at')
      .is('campaign_id', null)
      .order('sent_at', { ascending: false })
      .limit(50)
    setLogs((data ?? []) as typeof logs)
    setLoadingLogs(false)
  }, [])

  useEffect(() => { loadLogs() }, [loadLogs])

  return (
    <div className="space-y-4">
      <div className="bg-primary-50 border border-primary-100 rounded-2xl p-5">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center flex-shrink-0">
            <Sparkles className="w-5 h-5 text-primary-600" />
          </div>
          <div className="min-w-0">
            <h3 className="text-sm font-bold text-ink-900">Automatische Willkommensmail</h3>
            <p className="text-xs text-ink-600 mt-1 leading-relaxed">
              Jeder neu registrierte User erhält automatisch eine Willkommensmail
              mit Mensaena-Logo, Feature-Übersicht und direktem Login-Link.
              Der Name wird automatisch aus dem Nutzerprofil gelesen.
            </p>
          </div>
        </div>
      </div>

      {/* Versand-Log */}
      <div className="bg-white border border-stone-100 rounded-2xl p-5">
        <div className="flex items-center justify-between mb-3">
          <h4 className="text-sm font-bold text-ink-900">Versand-Protokoll</h4>
          <button onClick={loadLogs} className="text-xs text-primary-600 hover:underline">
            <RefreshCw className="w-3 h-3 inline mr-1" />Aktualisieren
          </button>
        </div>
        {loadingLogs ? (
          <div className="flex justify-center py-6"><Loader2 className="w-5 h-5 text-stone-400 animate-spin" /></div>
        ) : logs.length === 0 ? (
          <p className="text-xs text-ink-400 italic text-center py-4">Noch keine Willkommensmails versendet.</p>
        ) : (
          <div className="divide-y divide-stone-100 max-h-64 overflow-y-auto">
            {logs.map(log => (
              <div key={log.id} className="flex items-center justify-between py-2">
                <div className="flex items-center gap-2 min-w-0">
                  {log.status === 'sent' ? (
                    <CheckCircle2 className="w-3.5 h-3.5 text-green-500 flex-shrink-0" />
                  ) : (
                    <XCircle className="w-3.5 h-3.5 text-red-400 flex-shrink-0" />
                  )}
                  <span className="text-xs text-ink-700 truncate">{log.email}</span>
                </div>
                <span className="text-xs text-ink-400 flex-shrink-0 ml-2">
                  {new Date(log.sent_at).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Vorschau */}
      <div className="bg-white border border-stone-100 rounded-2xl p-5">
        <h4 className="text-sm font-bold text-ink-900 mb-3">Vorschau</h4>
        <div className="border border-stone-200 rounded-xl overflow-hidden bg-stone-50">
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
      .select('*')
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
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-ink-400" />
          <input
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="E-Mail suchen..."
            className="w-full pl-9 pr-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
          />
        </div>
        <select
          value={filter}
          onChange={e => setFilter(e.target.value as typeof filter)}
          aria-label="Abonnenten nach Status filtern"
          className="px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
        >
          <option value="all">Alle ({subscribers.length})</option>
          <option value="active">Aktiv ({subscribers.filter(s => s.subscribed).length})</option>
          <option value="unsubscribed">Abgemeldet ({subscribers.filter(s => !s.subscribed).length})</option>
        </select>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-5 h-5 text-stone-400 animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-sm text-ink-400 italic bg-stone-50 rounded-xl p-6 text-center">
          Keine Einträge
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs font-bold text-ink-500 uppercase tracking-wider border-b border-stone-100">
                <th className="px-3 py-2">E-Mail</th>
                <th className="px-3 py-2">Name</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Angemeldet</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-stone-100">
              {filtered.map(s => (
                <tr key={s.id} className="hover:bg-stone-50">
                  <td className="px-3 py-2.5 text-ink-900">{s.email}</td>
                  <td className="px-3 py-2.5 text-ink-600">{s.profiles?.name ?? '–'}</td>
                  <td className="px-3 py-2.5">
                    {s.subscribed ? (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-green-50 text-green-700 rounded-full text-xs font-medium">
                        <CheckCircle2 className="w-3 h-3" /> Aktiv
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-stone-100 text-ink-600 rounded-full text-xs font-medium">
                        <XCircle className="w-3 h-3" /> Abgemeldet
                      </span>
                    )}
                  </td>
                  <td className="px-3 py-2.5 text-ink-500 text-xs">
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

// ============================================================
// Compliance-Dashboard (Feature 10)
// ============================================================
function ComplianceView() {
  const [data, setData] = useState<{
    total: number; active: number; unsubscribed: number
    totalSent: number; totalOpen: number; totalClick: number; totalBounce: number
  } | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    Promise.all([
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }),
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }).eq('subscribed', true),
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }).eq('subscribed', false),
      supabase.from('email_campaigns').select('sent_count, open_count, click_count, bounce_count').eq('status', 'sent'),
    ]).then(([totalRes, activeRes, unsubRes, campsRes]) => {
      const camps = campsRes.data ?? []
      const totalSent   = camps.reduce((s: number, c: { sent_count: number }) => s + (c.sent_count ?? 0), 0)
      const totalOpen   = camps.reduce((s: number, c: { open_count?: number }) => s + (c.open_count ?? 0), 0)
      const totalClick  = camps.reduce((s: number, c: { click_count?: number }) => s + (c.click_count ?? 0), 0)
      const totalBounce = camps.reduce((s: number, c: { bounce_count?: number }) => s + (c.bounce_count ?? 0), 0)
      setData({
        total: totalRes.count ?? 0,
        active: activeRes.count ?? 0,
        unsubscribed: unsubRes.count ?? 0,
        totalSent, totalOpen, totalClick, totalBounce,
      })
      setLoading(false)
    })
  }, [])

  if (loading) return <div className="flex items-center justify-center py-16"><Loader2 className="w-5 h-5 animate-spin text-stone-400" /></div>
  if (!data) return null

  const optInRate   = data.total > 0 ? Math.round((data.active / data.total) * 100) : 0
  const unsubRate   = data.total > 0 ? Math.round((data.unsubscribed / data.total) * 100) : 0
  const openRate    = data.totalSent > 0 ? Math.round((data.totalOpen / data.totalSent) * 100) : 0
  const clickRate   = data.totalSent > 0 ? Math.round((data.totalClick / data.totalSent) * 100) : 0
  const bounceRate  = data.totalSent > 0 ? Math.round((data.totalBounce / data.totalSent) * 100) : 0

  const metrics = [
    { label: 'Opt-In-Rate', value: `${optInRate}%`, sub: `${data.active} von ${data.total} Nutzern`, status: optInRate >= 70 ? 'ok' : 'warn', icon: <CheckCircle2 className="w-5 h-5" /> },
    { label: 'Abmelde-Rate', value: `${unsubRate}%`, sub: `${data.unsubscribed} abgemeldet`, status: unsubRate <= 5 ? 'ok' : 'warn', icon: <XCircle className="w-5 h-5" /> },
    { label: 'Ø Öffnungsrate', value: `${openRate}%`, sub: `${data.totalOpen} Öffnungen gesamt`, status: openRate >= 20 ? 'ok' : 'warn', icon: <Mail className="w-5 h-5" /> },
    { label: 'Ø Klickrate', value: `${clickRate}%`, sub: `${data.totalClick} Klicks gesamt`, status: clickRate >= 2 ? 'ok' : 'warn', icon: <MousePointerClick className="w-5 h-5" /> },
    { label: 'Bounce-Rate', value: `${bounceRate}%`, sub: `${data.totalBounce} Bounces`, status: bounceRate <= 2 ? 'ok' : 'warn', icon: <AlertTriangle className="w-5 h-5" /> },
    { label: 'Versendete Mails', value: data.totalSent.toLocaleString('de-DE'), sub: 'über alle Kampagnen', status: 'ok', icon: <Send className="w-5 h-5" /> },
  ] as const

  return (
    <div className="space-y-6">
      <div className="bg-primary-50 border border-primary-100 rounded-2xl p-5">
        <div className="flex items-center gap-3 mb-1">
          <ShieldCheck className="w-5 h-5 text-primary-600" />
          <h3 className="text-sm font-bold text-ink-900">DSGVO & Email-Compliance</h3>
        </div>
        <p className="text-xs text-ink-600">Alle Nutzer haben beim Registrieren aktiv zugestimmt (Double-Opt-In via Supabase Auth). Jede Mail enthält einen Abmeldelink.</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-3 gap-3">
        {metrics.map(m => (
          <div key={m.label} className="bg-white border border-stone-100 rounded-2xl p-4 shadow-sm">
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center mb-3 ${m.status === 'ok' ? 'bg-green-50 text-green-600' : 'bg-amber-50 text-amber-600'}`}>
              {m.icon}
            </div>
            <p className="text-2xl font-bold text-ink-900 tabular-nums">{m.value}</p>
            <p className="text-xs font-semibold text-ink-700 mt-0.5">{m.label}</p>
            <p className="text-[10px] text-ink-400 mt-0.5">{m.sub}</p>
            {m.status === 'warn' && (
              <p className="text-[10px] text-amber-600 mt-1 font-medium">⚠ Optimierungspotential</p>
            )}
          </div>
        ))}
      </div>

      <div className="bg-white border border-stone-100 rounded-2xl p-5">
        <h4 className="text-sm font-bold text-ink-900 mb-3">DSGVO-Checkliste</h4>
        <div className="space-y-2">
          {[
            { ok: true,  label: 'Explizite Zustimmung beim Registrieren (Supabase Auth)' },
            { ok: true,  label: 'Abmeldelink in jeder Kampagnen-Mail' },
            { ok: true,  label: 'IP-Hashing beim Öffnungs-/Klick-Tracking' },
            { ok: true,  label: 'Daten bleiben in der EU (Supabase Frankfurt)' },
            { ok: unsubRate <= 5, label: 'Abmelderate unter 5% (Branchenstandard)' },
            { ok: bounceRate <= 2, label: 'Bounce-Rate unter 2%' },
          ].map((item, i) => (
            <div key={i} className="flex items-center gap-3">
              <div className={`flex-shrink-0 w-5 h-5 rounded-full flex items-center justify-center ${item.ok ? 'bg-green-100 text-green-600' : 'bg-amber-100 text-amber-600'}`}>
                {item.ok ? <CheckCircle2 className="w-3 h-3" /> : <AlertTriangle className="w-3 h-3" />}
              </div>
              <p className="text-xs text-ink-700">{item.label}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Drip-Kampagnen (Feature 7)
// ============================================================
type DripCampaign = {
  id: string; name: string; description: string | null
  trigger_type: string; active: boolean; created_at: string
  step_count?: number
}

function DripView() {
  const [campaigns, setCampaigns] = useState<DripCampaign[]>([])
  const [loading, setLoading] = useState(true)
  const [creating, setCreating] = useState(false)
  const [editDrip, setEditDrip] = useState<DripCampaign | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data } = await supabase
      .from('drip_campaigns')
      .select('*, drip_steps(id)')
      .order('created_at', { ascending: false })
    setCampaigns((data ?? []).map((d: { id: string; name: string; description: string | null; trigger_type: string; active: boolean; created_at: string; drip_steps: { id: string }[] }) => ({
      ...d,
      step_count: d.drip_steps?.length ?? 0,
    })))
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const toggleActive = async (drip: DripCampaign) => {
    const supabase = createClient()
    await supabase.from('drip_campaigns').update({ active: !drip.active }).eq('id', drip.id)
    load()
  }

  const triggerLabel: Record<string, string> = {
    on_register: '🚀 Bei Registrierung',
    on_inactive: '💤 Bei Inaktivität',
    manual: '✋ Manuell',
  }

  return (
    <div className="space-y-5">
      <div className="bg-primary-50 border border-primary-100 rounded-2xl p-5">
        <div className="flex items-center gap-2 mb-1">
          <GitBranch className="w-4 h-4 text-primary-600" />
          <h3 className="text-sm font-bold text-ink-900">Drip-Kampagnen & Auto-Funnels</h3>
        </div>
        <p className="text-xs text-ink-600">Automatische E-Mail-Sequenzen: z.B. Willkommen → Tag 3: Tipps → Tag 7: Erste Hilfe anbieten → Tag 14: Feedback.</p>
      </div>

      <div className="flex items-center justify-between">
        <p className="text-sm font-bold text-ink-900">Funnels ({campaigns.length})</p>
        <button
          onClick={() => setEditDrip({ id: '', name: '', description: null, trigger_type: 'on_register', active: false, created_at: new Date().toISOString() })}
          className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium"
        >
          <FileText className="w-4 h-4" /> Neuer Funnel
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12"><Loader2 className="w-5 h-5 animate-spin text-stone-400" /></div>
      ) : campaigns.length === 0 ? (
        <div className="bg-stone-50 rounded-2xl p-8 text-center text-sm text-ink-400">
          Noch keine Drip-Kampagnen. Erstelle deinen ersten Funnel.
        </div>
      ) : (
        <div className="space-y-2">
          {campaigns.map(drip => (
            <div key={drip.id} className="flex items-center gap-3 p-4 bg-white border border-stone-100 hover:border-primary-200 rounded-xl transition-colors">
              <div className="flex-shrink-0 w-10 h-10 bg-primary-50 rounded-xl flex items-center justify-center">
                <GitBranch className="w-4 h-4 text-primary-600" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-ink-900">{drip.name}</p>
                <p className="text-xs text-ink-500 mt-0.5">
                  {triggerLabel[drip.trigger_type] ?? drip.trigger_type}
                  {' · '}{drip.step_count ?? 0} Schritte
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => toggleActive(drip)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${drip.active ? 'bg-green-100 text-green-700 hover:bg-green-200' : 'bg-stone-100 text-ink-600 hover:bg-stone-200'}`}
                >
                  {drip.active ? '✓ Aktiv' : 'Inaktiv'}
                </button>
                <button
                  onClick={() => setEditDrip(drip)}
                  className="w-9 h-9 flex items-center justify-center rounded-lg text-ink-500 hover:bg-stone-100"
                >
                  <Edit3 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Re-Engagement Automation */}
      <ReEngagementPanel />

      {editDrip && <DripEditModal drip={editDrip} onClose={() => setEditDrip(null)} onSaved={() => { setEditDrip(null); load() }} />}
    </div>
  )
}

function ReEngagementPanel() {
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<{ enrolled: number; message?: string } | null>(null)
  const [inactiveDays, setInactiveDays] = useState(30)

  const trigger = async () => {
    setRunning(true)
    setResult(null)
    try {
      const res = await authFetch(`/api/emails/re-engagement?inactive_days=${inactiveDays}`, {
        method: 'POST',
        headers: { 'x-cron-secret': 'manual' },
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Fehler')
      setResult({ enrolled: data.enrolled, message: data.message })
      toast.success(`Re-Engagement: ${data.enrolled} User eingeschrieben`)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setRunning(false)
    }
  }

  return (
    <div className="bg-amber-50 border border-amber-100 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-1">
        <UserCheck className="w-4 h-4 text-amber-600" />
        <h3 className="text-sm font-bold text-ink-900">Re-Engagement Automation</h3>
      </div>
      <p className="text-xs text-ink-600 mb-4">
        Meldet inaktive User automatisch in der ersten aktiven "Bei Inaktivität"-Drip-Kampagne an.
        Läuft auch automatisch via Cron (Mo. 22:00 UTC).
      </p>
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2">
          <label className="text-xs text-ink-700 whitespace-nowrap">Inaktiv seit:</label>
          <select
            value={inactiveDays}
            onChange={e => setInactiveDays(Number(e.target.value))}
            className="px-2 py-1.5 border border-amber-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-amber-400 bg-white"
          >
            <option value={14}>14 Tagen</option>
            <option value={30}>30 Tagen</option>
            <option value={60}>60 Tagen</option>
            <option value={90}>90 Tagen</option>
          </select>
        </div>
        <button
          onClick={trigger}
          disabled={running}
          className="inline-flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-600 text-white rounded-xl text-xs font-medium disabled:opacity-50"
        >
          {running ? <Loader2 className="w-3 h-3 animate-spin" /> : <Zap className="w-3 h-3" />}
          Jetzt ausführen
        </button>
      </div>
      {result && (
        <div className="mt-3 text-xs text-ink-700 bg-white rounded-lg px-3 py-2 border border-amber-100">
          {result.enrolled > 0
            ? `✓ ${result.enrolled} User in Re-Engagement-Funnel eingeschrieben`
            : result.message ?? 'Keine neuen User zum Einschreiben gefunden'}
        </div>
      )}
    </div>
  )
}

function DripEditModal({ drip, onClose, onSaved }: { drip: DripCampaign; onClose: () => void; onSaved: () => void }) {
  const isNew = !drip.id
  const [name, setName] = useState(drip.name)
  const [description, setDescription] = useState(drip.description ?? '')
  const [triggerType, setTriggerType] = useState(drip.trigger_type)
  const [steps, setSteps] = useState<Array<{ delay_days: number; subject: string; html_content: string }>>([
    { delay_days: 0, subject: '', html_content: '' },
  ])
  const [saving, setSaving] = useState(false)
  const [generating, setGenerating] = useState(false)

  const generateWithAi = async () => {
    if (!name.trim() && !triggerType) { toast.error('Bitte zuerst einen Namen und Trigger wählen'); return }
    setGenerating(true)
    try {
      const res = await authFetch('/api/emails/drip/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, trigger_type: triggerType, description, num_steps: 5 }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Fehler')
      setSteps(data.steps)
      toast.success(`${data.steps.length} Schritte generiert`)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'KI-Fehler')
    } finally {
      setGenerating(false)
    }
  }

  const save = async () => {
    if (!name.trim()) { toast.error('Name erforderlich'); return }
    if (steps.some(s => !s.subject.trim() || !s.html_content.trim())) {
      toast.error('Alle Schritte brauchen Betreff und Inhalt')
      return
    }
    setSaving(true)
    try {
      const supabase = createClient()
      if (isNew) {
        const { data: dc, error } = await supabase.from('drip_campaigns').insert({
          name, description: description || null, trigger_type: triggerType, active: false,
        }).select('id').single()
        if (error || !dc) throw new Error(error?.message ?? 'Fehler')
        const stepRows = steps.map((s, i) => ({ drip_campaign_id: dc.id, step_order: i, ...s }))
        await supabase.from('drip_steps').insert(stepRows)
      } else {
        await supabase.from('drip_campaigns').update({ name, description: description || null, trigger_type: triggerType }).eq('id', drip.id)
        await supabase.from('drip_steps').delete().eq('drip_campaign_id', drip.id)
        const stepRows = steps.map((s, i) => ({ drip_campaign_id: drip.id, step_order: i, ...s }))
        if (stepRows.length > 0) await supabase.from('drip_steps').insert(stepRows)
      }
      toast.success('Funnel gespeichert')
      onSaved()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-5 border-b border-stone-100">
          <h3 className="text-sm font-bold text-ink-900">{isNew ? 'Neuer Drip-Funnel' : 'Funnel bearbeiten'}</h3>
          <button onClick={onClose} className="text-ink-400 hover:text-ink-900 text-2xl">×</button>
        </div>
        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-ink-700 mb-1.5">Name</label>
              <input value={name} onChange={e => setName(e.target.value)} className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400" placeholder="Willkommens-Funnel" />
            </div>
            <div>
              <label className="block text-xs font-bold text-ink-700 mb-1.5">Trigger</label>
              <select value={triggerType} onChange={e => setTriggerType(e.target.value)} className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400">
                <option value="on_register">Bei Registrierung</option>
                <option value="on_inactive">Bei Inaktivität</option>
                <option value="manual">Manuell</option>
              </select>
            </div>
          </div>
          <div>
            <label className="block text-xs font-bold text-ink-700 mb-1.5">Beschreibung (optional)</label>
            <input value={description} onChange={e => setDescription(e.target.value)} className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400" placeholder="Kurze Beschreibung" />
          </div>

          {/* KI-Generator */}
          <div className="bg-gradient-to-r from-purple-50 to-blue-50 border border-purple-100 rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Zap className="w-4 h-4 text-purple-600" />
                <span className="text-xs font-bold text-ink-800">KI-Funnel-Generator</span>
              </div>
              <button
                onClick={generateWithAi}
                disabled={generating}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-xs font-medium disabled:opacity-50"
              >
                {generating ? <Loader2 className="w-3 h-3 animate-spin" /> : <Sparkles className="w-3 h-3" />}
                {generating ? 'Generiert…' : 'Automatisch generieren'}
              </button>
            </div>
            <p className="text-xs text-ink-500 mt-1.5">KI erstellt 5 professionelle E-Mails passend zum gewählten Trigger. Danach manuell editierbar.</p>
          </div>

          <div>
            <div className="flex items-center justify-between mb-3">
              <label className="text-xs font-bold text-ink-700">Schritte ({steps.length})</label>
              <button
                onClick={() => setSteps(s => [...s, { delay_days: 7, subject: '', html_content: '' }])}
                className="text-xs text-primary-600 hover:underline"
              >+ Schritt hinzufügen</button>
            </div>
            <div className="space-y-3">
              {steps.map((step, i) => (
                <div key={i} className="border border-stone-100 rounded-xl p-4 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-ink-800">Schritt {i + 1}</span>
                    {steps.length > 1 && (
                      <button onClick={() => setSteps(s => s.filter((_, j) => j !== i))} className="text-xs text-red-500 hover:underline">Entfernen</button>
                    )}
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="w-24">
                      <label className="block text-[10px] text-ink-500 mb-1">Verzögerung (Tage)</label>
                      <input type="number" min={0} value={step.delay_days} onChange={e => setSteps(s => s.map((x, j) => j === i ? { ...x, delay_days: parseInt(e.target.value) || 0 } : x))} className="w-full px-2 py-1.5 border border-stone-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-400" />
                    </div>
                    <div className="flex-1">
                      <label className="block text-[10px] text-ink-500 mb-1">Betreff</label>
                      <input value={step.subject} onChange={e => setSteps(s => s.map((x, j) => j === i ? { ...x, subject: e.target.value } : x))} className="w-full px-2 py-1.5 border border-stone-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-400" placeholder="Hallo {{vorname}}, …" />
                    </div>
                  </div>
                  <div>
                    <label className="block text-[10px] text-ink-500 mb-1">HTML-Inhalt</label>
                    <textarea value={step.html_content} onChange={e => setSteps(s => s.map((x, j) => j === i ? { ...x, html_content: e.target.value } : x))} className="w-full px-2 py-1.5 border border-stone-200 rounded-lg text-xs font-mono focus:outline-none focus:ring-2 focus:ring-primary-400" rows={4} placeholder="<p>Hallo {{vorname}}, …</p>" />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
        <div className="p-5 border-t border-stone-100 flex justify-end gap-2">
          <button onClick={onClose} className="px-4 py-2 text-ink-600 hover:bg-stone-100 rounded-xl text-sm">Abbrechen</button>
          <button onClick={save} disabled={saving} className="inline-flex items-center gap-2 px-5 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium disabled:opacity-50">
            {saving && <Loader2 className="w-4 h-4 animate-spin" />} Speichern
          </button>
        </div>
      </div>
    </div>
  )
}
