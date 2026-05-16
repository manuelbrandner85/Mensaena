'use client'

import { useCallback, useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import {
  Mail, Share2, Users, Send, CheckCircle2, XCircle, Loader2,
  BarChart3, Megaphone, Link2, Calendar, TrendingUp, Trash2,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import EmailsTab from './EmailsTab'
import SocialMediaSection from './SocialMediaSection'

type MarketingView = 'overview' | 'emails' | 'social' | 'calendar' | 'analytics'

// ── Stat Card ────────────────────────────────────────────────
function StatCard({
  icon, label, value, loading, color, sub,
}: {
  icon: React.ReactNode
  label: string
  value: number
  loading: boolean
  color: 'primary' | 'green' | 'gray' | 'blue' | 'amber'
  sub?: string
}) {
  const colors = {
    primary: 'bg-mn-bronze/5 text-mn-bronze border-white/8',
    green:   'bg-mn-surface text-mn-leben border-white/5',
    gray:    'bg-mn-surface text-mn-ink-soft border-white/5',
    blue:    'bg-mn-surface text-mn-teal-soft border-white/5',
    amber:   'bg-amber-50 text-amber-700 border-amber-100',
  }
  return (
    <div className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-4">
      <div className="flex items-start justify-between">
        <div className={`w-10 h-10 rounded-xl border flex items-center justify-center ${colors[color]}`}>
          {icon}
        </div>
        {loading && <Loader2 className="w-4 h-4 text-mn-ghost animate-spin" />}
      </div>
      <p className="mt-3 text-2xl font-bold text-mn-ink tabular-nums">{value.toLocaleString('de-DE')}</p>
      <p className="text-xs text-mn-mute mt-0.5">{label}</p>
      {sub && <p className="text-xs text-mn-mute mt-0.5">{sub}</p>}
    </div>
  )
}

// ── Haupt-Komponente ─────────────────────────────────────────
export default function MarketingTab() {
  const [view, setView] = useState<MarketingView>('overview')
  const [stats, setStats] = useState({
    emailTotal: 0, emailActive: 0, emailUnsubscribed: 0, emailCampaignsSent: 0,
    smChannels: 0, smConnected: 0, smDrafts: 0, smPublished: 0,
  })
  const [loadingStats, setLoadingStats] = useState(true)

  const loadStats = useCallback(async () => {
    setLoadingStats(true)
    const supabase = createClient()
    const [
      totalRes, activeRes, unsubRes, sentRes,
      chRes, connRes, draftRes, pubRes,
    ] = await Promise.all([
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }),
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }).eq('subscribed', true),
      supabase.from('email_subscriptions').select('id', { count: 'exact', head: true }).eq('subscribed', false),
      supabase.from('email_campaigns').select('id', { count: 'exact', head: true }).eq('status', 'sent'),
      supabase.from('social_media_channels').select('id', { count: 'exact', head: true }),
      supabase.from('social_media_channels').select('id', { count: 'exact', head: true }).eq('is_connected', true),
      supabase.from('social_media_posts').select('id', { count: 'exact', head: true }).eq('status', 'draft'),
      supabase.from('social_media_posts').select('id', { count: 'exact', head: true }).eq('status', 'published'),
    ])
    setStats({
      emailTotal: totalRes.count ?? 0,
      emailActive: activeRes.count ?? 0,
      emailUnsubscribed: unsubRes.count ?? 0,
      emailCampaignsSent: sentRes.count ?? 0,
      smChannels: chRes.count ?? 0,
      smConnected: connRes.count ?? 0,
      smDrafts: draftRes.count ?? 0,
      smPublished: pubRes.count ?? 0,
    })
    setLoadingStats(false)
  }, [])

  useEffect(() => { loadStats() }, [loadStats])

  const tabs: { key: MarketingView; label: string; icon: React.ReactNode }[] = [
    { key: 'overview',   label: 'Übersicht',     icon: <BarChart3 className="w-4 h-4" /> },
    { key: 'emails',     label: 'E-Mails',       icon: <Mail className="w-4 h-4" /> },
    { key: 'social',     label: 'Social Media',   icon: <Share2 className="w-4 h-4" /> },
    { key: 'calendar',   label: 'Kalender',       icon: <Calendar className="w-4 h-4" /> },
    { key: 'analytics',  label: 'Analytics',      icon: <TrendingUp className="w-4 h-4" /> },
  ]

  return (
    <div className="space-y-5">
      {/* Navigation */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1">
        {tabs.map(t => (
          <button
            key={t.key}
            onClick={() => setView(t.key)}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-medium transition-all whitespace-nowrap ${
              view === t.key
                ? 'bg-mn-bronze text-white shadow-sm'
                : 'text-mn-ink-soft hover:bg-mn-elevated bg-mn-elevated border border-white/5'
            }`}
          >
            {t.icon}
            {t.label}
          </button>
        ))}
      </div>

      {/* Views */}
      {view === 'overview' && (
        <div className="space-y-5">
          {/* E-Mail Stats */}
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Mail className="w-4 h-4 text-mn-bronze" />
              <h3 className="text-sm font-bold text-mn-ink">E-Mail-Marketing</h3>
            </div>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
              <StatCard icon={<Users className="w-5 h-5" />} label="Abonnenten" value={stats.emailTotal} loading={loadingStats} color="primary" />
              <StatCard icon={<CheckCircle2 className="w-5 h-5" />} label="Aktive" value={stats.emailActive} loading={loadingStats} color="green" />
              <StatCard icon={<XCircle className="w-5 h-5" />} label="Abgemeldet" value={stats.emailUnsubscribed} loading={loadingStats} color="gray" />
              <StatCard icon={<Send className="w-5 h-5" />} label="Kampagnen gesendet" value={stats.emailCampaignsSent} loading={loadingStats} color="primary" />
            </div>
          </div>

          {/* Social Media Stats */}
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Share2 className="w-4 h-4 text-mn-bronze" />
              <h3 className="text-sm font-bold text-mn-ink">Social Media</h3>
            </div>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
              <StatCard icon={<Link2 className="w-5 h-5" />} label="Kanäle konfiguriert" value={stats.smChannels} loading={loadingStats} color="blue" />
              <StatCard icon={<CheckCircle2 className="w-5 h-5" />} label="Kanäle verbunden" value={stats.smConnected} loading={loadingStats} color="green" />
              <StatCard icon={<Megaphone className="w-5 h-5" />} label="Entwürfe" value={stats.smDrafts} loading={loadingStats} color="amber" />
              <StatCard icon={<Send className="w-5 h-5" />} label="Veröffentlicht" value={stats.smPublished} loading={loadingStats} color="primary" />
            </div>
          </div>

          {/* Quick Actions */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <button
              onClick={() => setView('emails')}
              className="flex items-center gap-3 p-4 bg-mn-elevated rounded-2xl border border-white/5 shadow-sm hover:shadow-md hover:border-mn-bronze/20 transition-all text-left group"
            >
              <div className="w-10 h-10 rounded-xl bg-mn-bronze/5 border border-white/8 flex items-center justify-center flex-shrink-0">
                <Mail className="w-5 h-5 text-mn-bronze" />
              </div>
              <div className="min-w-0">
                <p className="text-sm font-bold text-mn-ink">E-Mail-Kampagnen</p>
                <p className="text-xs text-mn-mute">Newsletter, Willkommensmail, Abonnenten</p>
              </div>
              <span className="ml-auto text-mn-ghost group-hover:text-mn-bronze transition-colors">→</span>
            </button>
            <button
              onClick={() => setView('social')}
              className="flex items-center gap-3 p-4 bg-mn-elevated rounded-2xl border border-white/5 shadow-sm hover:shadow-md hover:border-mn-bronze/20 transition-all text-left group"
            >
              <div className="w-10 h-10 rounded-xl bg-mn-surface border border-white/5 flex items-center justify-center flex-shrink-0">
                <Share2 className="w-5 h-5 text-mn-teal-soft" />
              </div>
              <div className="min-w-0">
                <p className="text-sm font-bold text-mn-ink">Social Media</p>
                <p className="text-xs text-mn-mute">KI-Beiträge, Kanäle verwalten</p>
              </div>
              <span className="ml-auto text-mn-ghost group-hover:text-mn-teal-soft transition-colors">→</span>
            </button>
          </div>
        </div>
      )}

      {view === 'emails' && <EmailsTab />}
      {view === 'social' && <SocialMediaSection />}
      {view === 'calendar' && <CalendarView />}
      {view === 'analytics' && <AnalyticsView />}
    </div>
  )
}

// ── Content-Kalender ─────────────────────────────────────────
function CalendarView() {
  const [items, setItems] = useState<Array<{ id: string; channel: string; title: string; status: string; scheduled_at: string }>>([])
  const [loading, setLoading] = useState(true)
  const [deleting, setDeleting] = useState<string | null>(null)
  const [month, setMonth] = useState(() => {
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  })

  const loadItems = useCallback(() => {
    setLoading(true)
    const supabase = createClient()
    const [y, m] = month.split('-').map(Number)
    const start = new Date(y, m - 1, 1).toISOString()
    const end = new Date(y, m, 0, 23, 59, 59).toISOString()

    Promise.all([
      supabase.from('email_campaigns').select('id, subject, status, scheduled_at, created_at')
        .not('scheduled_at', 'is', null).gte('scheduled_at', start).lte('scheduled_at', end),
      supabase.from('social_media_posts').select('id, content, status, scheduled_at, created_at')
        .not('scheduled_at', 'is', null).gte('scheduled_at', start).lte('scheduled_at', end),
    ]).then(([emailRes, smRes]) => {
      const emails = (emailRes.data ?? []).map(e => ({
        id: e.id, channel: 'email' as const, title: e.subject, status: e.status, scheduled_at: e.scheduled_at!,
      }))
      const social = (smRes.data ?? []).map(s => ({
        id: s.id, channel: 'social' as const, title: s.content?.slice(0, 60) || 'Post', status: s.status, scheduled_at: s.scheduled_at!,
      }))
      setItems([...emails, ...social].sort((a, b) => a.scheduled_at.localeCompare(b.scheduled_at)))
      setLoading(false)
    })
  }, [month])

  useEffect(() => { loadItems() }, [loadItems])

  const deleteItem = async (item: { id: string; channel: string }) => {
    if (!confirm('Geplanten Eintrag wirklich löschen?')) return
    setDeleting(item.id)
    const supabase = createClient()
    const table = item.channel === 'email' ? 'email_campaigns' : 'social_media_posts'
    await supabase.from(table).delete().eq('id', item.id)
    setItems(prev => prev.filter(i => i.id !== item.id))
    setDeleting(null)
    toast.success('Gelöscht')
  }

  // Tage im Monat generieren
  const [year, mon] = month.split('-').map(Number)
  const daysInMonth = new Date(year, mon, 0).getDate()
  const firstDay = (new Date(year, mon - 1, 1).getDay() + 6) % 7 // Montag = 0

  const getItemsForDay = (day: number) => {
    const dateStr = `${year}-${String(mon).padStart(2, '0')}-${String(day).padStart(2, '0')}`
    return items.filter(i => i.scheduled_at.startsWith(dateStr))
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-bold text-mn-ink flex items-center gap-2">
          <Calendar className="w-4 h-4 text-mn-bronze" /> Content-Kalender
        </h3>
        <input
          type="month"
          value={month}
          onChange={e => setMonth(e.target.value)}
          className="px-3 py-1.5 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400"
        />
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader2 className="w-5 h-5 text-mn-ghost animate-spin" /></div>
      ) : (
        <div className="bg-mn-elevated border border-white/5 rounded-2xl overflow-hidden shadow-sm">
          {/* Wochentage */}
          <div className="hidden sm:grid grid-cols-7 bg-mn-surface border-b border-white/5">
            {['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'].map(d => (
              <div key={d} className="px-1 py-2 text-center text-xs font-bold text-mn-mute">{d}</div>
            ))}
          </div>
          {/* Kalender-Grid */}
          <div className="grid grid-cols-4 sm:grid-cols-7">
            {Array.from({ length: firstDay }, (_, i) => (
              <div key={`e-${i}`} className="hidden sm:block min-h-[60px] border-b border-r border-white/5" />
            ))}
            {Array.from({ length: daysInMonth }, (_, i) => {
              const day = i + 1
              const dayItems = getItemsForDay(day)
              const isToday = new Date().getDate() === day && new Date().getMonth() + 1 === mon && new Date().getFullYear() === year
              return (
                <div key={day} className={`min-h-[60px] border-b border-r border-white/5 p-1 ${isToday ? 'bg-mn-bronze/5' : ''}`}>
                  <p className={`text-xs font-medium mb-0.5 ${isToday ? 'text-mn-bronze font-bold' : 'text-mn-mute'}`}>{day}</p>
                  {dayItems.map(item => (
                    <div
                      key={item.id}
                      className={`text-xs leading-tight px-1 py-0.5 rounded mb-0.5 flex items-center gap-0.5 group ${
                        item.channel === 'email'
                          ? 'bg-mn-bronze/10 text-mn-bronze'
                          : 'bg-mn-elevated text-mn-teal-soft'
                      }`}
                      title={`${item.title}\nKlicke ✕ zum Löschen`}
                    >
                      <span className="truncate flex-1">{item.channel === 'email' ? '✉' : '📱'} {item.title}</span>
                      <button
                        onClick={e => { e.stopPropagation(); deleteItem(item) }}
                        disabled={deleting === item.id}
                        className="hidden group-hover:block flex-shrink-0 text-mn-herzrot hover:text-mn-herzrot"
                      >
                        {deleting === item.id ? '…' : '✕'}
                      </button>
                    </div>
                  ))}
                </div>
              )
            })}
          </div>
          <div className="p-3 flex items-center gap-4 text-xs text-mn-mute">
            <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-mn-bronze/10" /> E-Mail</span>
            <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-mn-elevated" /> Social Media</span>
          </div>
        </div>
      )}
    </div>
  )
}

// ── Analytics ────────────────────────────────────────────────
function AnalyticsView() {
  const [emailStats, setEmailStats] = useState({ sent: 0, opened: 0, campaigns: 0 })
  const [smStats, setSmStats] = useState({ posts: 0, published: 0, failed: 0, channels: 0 })
  const [recentCampaigns, setRecentCampaigns] = useState<Array<{ id: string; subject: string; recipient_count: number; open_count: number; sent_at: string }>>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const supabase = createClient()
    Promise.all([
      // E-Mail stats
      supabase.from('email_logs').select('id', { count: 'exact', head: true }).eq('status', 'sent'),
      supabase.from('email_opens').select('id', { count: 'exact', head: true }),
      supabase.from('email_campaigns').select('id', { count: 'exact', head: true }).eq('status', 'sent'),
      // SM stats
      supabase.from('social_media_posts').select('id', { count: 'exact', head: true }),
      supabase.from('social_media_posts').select('id', { count: 'exact', head: true }).eq('status', 'published'),
      supabase.from('social_media_posts').select('id', { count: 'exact', head: true }).eq('status', 'failed'),
      supabase.from('social_media_channels').select('id', { count: 'exact', head: true }).eq('is_connected', true),
      // Letzte Kampagnen
      supabase.from('email_campaigns').select('id, subject, recipient_count, open_count, sent_at').eq('status', 'sent').order('sent_at', { ascending: false }).limit(5),
    ]).then(([sentRes, openRes, campRes, postRes, pubRes, failRes, chRes, recentRes]) => {
      setEmailStats({
        sent: sentRes.count ?? 0,
        opened: openRes.count ?? 0,
        campaigns: campRes.count ?? 0,
      })
      setSmStats({
        posts: postRes.count ?? 0,
        published: pubRes.count ?? 0,
        failed: failRes.count ?? 0,
        channels: chRes.count ?? 0,
      })
      setRecentCampaigns((recentRes.data ?? []) as typeof recentCampaigns)
      setLoading(false)
    })
  }, [])

  const openRate = emailStats.sent > 0 ? Math.round((emailStats.opened / emailStats.sent) * 100) : 0

  if (loading) return <div className="flex justify-center py-12"><Loader2 className="w-5 h-5 text-mn-ghost animate-spin" /></div>

  return (
    <div className="space-y-5">
      <h3 className="text-sm font-bold text-mn-ink flex items-center gap-2">
        <TrendingUp className="w-4 h-4 text-mn-bronze" /> Marketing Analytics
      </h3>

      {/* E-Mail Analytics */}
      <div>
        <p className="text-xs font-bold text-mn-ink-soft mb-2 flex items-center gap-1"><Mail className="w-3.5 h-3.5" /> E-Mail Performance</p>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-ink">{emailStats.campaigns}</p>
            <p className="text-xs text-mn-mute">Kampagnen gesendet</p>
          </div>
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-ink">{emailStats.sent}</p>
            <p className="text-xs text-mn-mute">E-Mails gesendet</p>
          </div>
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-ink">{emailStats.opened}</p>
            <p className="text-xs text-mn-mute">Öffnungen</p>
          </div>
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-bronze">{openRate}%</p>
            <p className="text-xs text-mn-mute">Öffnungsrate</p>
          </div>
        </div>
      </div>

      {/* Social Media Analytics */}
      <div>
        <p className="text-xs font-bold text-mn-ink-soft mb-2 flex items-center gap-1"><Share2 className="w-3.5 h-3.5" /> Social Media Performance</p>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-ink">{smStats.channels}</p>
            <p className="text-xs text-mn-mute">Kanäle verbunden</p>
          </div>
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-ink">{smStats.posts}</p>
            <p className="text-xs text-mn-mute">Posts gesamt</p>
          </div>
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-leben">{smStats.published}</p>
            <p className="text-xs text-mn-mute">Veröffentlicht</p>
          </div>
          <div className="bg-mn-elevated rounded-xl border border-white/5 p-3">
            <p className="text-2xl font-bold text-mn-herzrot">{smStats.failed}</p>
            <p className="text-xs text-mn-mute">Fehlgeschlagen</p>
          </div>
        </div>
      </div>

      {/* Letzte Kampagnen mit Öffnungsrate */}
      {recentCampaigns.length > 0 && (
        <div className="bg-mn-elevated border border-white/5 rounded-2xl p-4 shadow-sm">
          <p className="text-xs font-bold text-mn-ink-soft mb-3">Letzte Kampagnen</p>
          <div className="divide-y divide-stone-100">
            {recentCampaigns.map(c => {
              const rate = c.recipient_count > 0 ? Math.round((c.open_count / c.recipient_count) * 100) : 0
              return (
                <div key={c.id} className="flex items-center justify-between py-2">
                  <div className="min-w-0">
                    <p className="text-sm text-mn-ink truncate">{c.subject}</p>
                    <p className="text-xs text-mn-mute">{c.sent_at ? new Date(c.sent_at).toLocaleDateString('de-DE') : ''} · {c.recipient_count} Empfänger</p>
                  </div>
                  <div className="text-right flex-shrink-0 ml-3">
                    <p className="text-sm font-bold text-mn-bronze">{rate}%</p>
                    <p className="text-xs text-mn-mute">geöffnet</p>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
