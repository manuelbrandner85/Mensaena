'use client'

import { useCallback, useEffect, useState } from 'react'
import {
  Mail, Share2, Users, Send, CheckCircle2, XCircle, Loader2,
  BarChart3, Megaphone, Link2,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import EmailsTab from './EmailsTab'
import SocialMediaSection from './SocialMediaSection'

type MarketingView = 'overview' | 'emails' | 'social'

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
    primary: 'bg-primary-50 text-primary-700 border-primary-100',
    green:   'bg-green-50 text-green-700 border-green-100',
    gray:    'bg-gray-50 text-gray-600 border-gray-200',
    blue:    'bg-blue-50 text-blue-700 border-blue-100',
    amber:   'bg-amber-50 text-amber-700 border-amber-100',
  }
  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
      <div className="flex items-start justify-between">
        <div className={`w-10 h-10 rounded-xl border flex items-center justify-center ${colors[color]}`}>
          {icon}
        </div>
        {loading && <Loader2 className="w-4 h-4 text-gray-300 animate-spin" />}
      </div>
      <p className="mt-3 text-2xl font-bold text-gray-900 tabular-nums">{value.toLocaleString('de-DE')}</p>
      <p className="text-xs text-gray-500 mt-0.5">{label}</p>
      {sub && <p className="text-xs text-gray-400 mt-0.5">{sub}</p>}
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
    { key: 'overview', label: 'Übersicht', icon: <BarChart3 className="w-4 h-4" /> },
    { key: 'emails',   label: 'E-Mails',   icon: <Mail className="w-4 h-4" /> },
    { key: 'social',   label: 'Social Media', icon: <Share2 className="w-4 h-4" /> },
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
                ? 'bg-primary-500 text-white shadow-sm'
                : 'text-gray-600 hover:bg-gray-100 bg-white border border-gray-100'
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
              <Mail className="w-4 h-4 text-primary-600" />
              <h3 className="text-sm font-bold text-gray-900">E-Mail-Marketing</h3>
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
              <Share2 className="w-4 h-4 text-primary-600" />
              <h3 className="text-sm font-bold text-gray-900">Social Media</h3>
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
              className="flex items-center gap-3 p-4 bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md hover:border-primary-200 transition-all text-left group"
            >
              <div className="w-10 h-10 rounded-xl bg-primary-50 border border-primary-100 flex items-center justify-center flex-shrink-0">
                <Mail className="w-5 h-5 text-primary-600" />
              </div>
              <div className="min-w-0">
                <p className="text-sm font-bold text-gray-900">E-Mail-Kampagnen</p>
                <p className="text-xs text-gray-500">Newsletter, Willkommensmail, Abonnenten</p>
              </div>
              <span className="ml-auto text-gray-300 group-hover:text-primary-500 transition-colors">→</span>
            </button>
            <button
              onClick={() => setView('social')}
              className="flex items-center gap-3 p-4 bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md hover:border-primary-200 transition-all text-left group"
            >
              <div className="w-10 h-10 rounded-xl bg-blue-50 border border-blue-100 flex items-center justify-center flex-shrink-0">
                <Share2 className="w-5 h-5 text-blue-600" />
              </div>
              <div className="min-w-0">
                <p className="text-sm font-bold text-gray-900">Social Media</p>
                <p className="text-xs text-gray-500">KI-Beiträge, Kanäle verwalten</p>
              </div>
              <span className="ml-auto text-gray-300 group-hover:text-blue-500 transition-colors">→</span>
            </button>
          </div>
        </div>
      )}

      {view === 'emails' && <EmailsTab />}
      {view === 'social' && <SocialMediaSection />}
    </div>
  )
}
