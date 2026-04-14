'use client'

import { useEffect, useState, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { ShieldCheck, Lock, RefreshCw } from 'lucide-react'
import Link from 'next/link'
import type { AdminStats, AdminTab } from './components/AdminTypes'

// Tab components
import AdminSidebar from './components/AdminSidebar'
import DashboardHome from './components/DashboardHome'
import UsersTab from './components/UsersTab'
import PostsTab from './components/PostsTab'
import EventsTab from './components/EventsTab'
import BoardTab from './components/BoardTab'
import CrisisTab from './components/CrisisTab'
import OrgsTab from './components/OrgsTab'
import FarmsTab from './components/FarmsTab'
import ChatModTab from './components/ChatModTab'
import SystemTab from './components/SystemTab'
import ReportsTab from './components/ReportsTab'
import GroupsTab from './components/GroupsTab'
import ChallengesTab from './components/ChallengesTab'
import ZeitbankTab from './components/ZeitbankTab'

// Page titles per tab
const TAB_TITLES: Record<AdminTab, { title: string; subtitle: string }> = {
  overview:   { title: 'Dashboard',        subtitle: 'Übersicht über die Plattform' },
  users:      { title: 'Benutzer',         subtitle: 'Nutzer verwalten, sperren oder löschen' },
  posts:      { title: 'Beiträge',         subtitle: 'Beiträge moderieren und verwalten' },
  chat:       { title: 'Chat-Moderation',  subtitle: 'Gespräche und Nachrichten überprüfen' },
  events:     { title: 'Events',           subtitle: 'Veranstaltungen verwalten' },
  board:      { title: 'Brett',            subtitle: 'Brett-Beiträge verwalten' },
  crisis:     { title: 'Krisen',           subtitle: 'Krisenmeldungen verwalten' },
  orgs:       { title: 'Organisationen',   subtitle: 'Hilfsorganisationen verwalten' },
  farms:      { title: 'Betriebe',         subtitle: 'Regionale Betriebe verwalten' },
  reports:    { title: 'Meldungen',        subtitle: 'Gemeldete Inhalte prüfen und bearbeiten' },
  groups:     { title: 'Gruppen',          subtitle: 'Gruppen und Mitglieder verwalten' },
  challenges: { title: 'Challenges',       subtitle: 'Herausforderungen verwalten' },
  zeitbank:   { title: 'Zeitbank',         subtitle: 'Zeitbank-Einträge verwalten' },
  system:     { title: 'Einstellungen',    subtitle: 'System-Einstellungen & Audit-Log' },
}

export default function AdminDashboard() {
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null)
  const [userRole, setUserRole] = useState<string>('user')
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [tab, setTab] = useState<AdminTab>('overview')
  const [loading, setLoading] = useState(true)
  const [openReportsCount, setOpenReportsCount] = useState(0)

  // ── Admin Guard ─────────────────────────────────────────────
  useEffect(() => {
    const supabase = createClient()
    async function checkAdmin() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { setIsAdmin(false); return }
      const { data } = await supabase.from('profiles').select('role').eq('id', user.id).single()
      const role = data?.role ?? 'user'
      setUserRole(role)
      setIsAdmin(role === 'admin' || role === 'moderator')
    }
    checkAdmin()
  }, [])

  // ── Load Stats ──────────────────────────────────────────────
  const loadStats = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()

    // Load open reports count in parallel
    const reportsPromise = supabase
      .from('reports')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'pending')

    // Try RPC first
    const { data, error } = await supabase.rpc('get_admin_dashboard_stats')
    if (!error && data) {
      setStats(data as AdminStats)
    } else {
      // Fallback: build stats from direct queries
      const [
        { count: totalUsers },
        { count: totalPosts },
        { count: activePosts },
        { count: totalMessages },
        { count: totalEvents },
        { count: totalBoardPosts },
        { count: totalOrgs },
        { count: totalCrises },
        { count: totalFarms },
        { count: totalRatings },
        { count: totalGroups },
        { count: totalChallenges },
        { count: activeChallenges },
        { count: totalTimebankEntries },
      ] = await Promise.all([
        supabase.from('profiles').select('*', { count: 'exact', head: true }),
        supabase.from('posts').select('*', { count: 'exact', head: true }),
        supabase.from('posts').select('*', { count: 'exact', head: true }).eq('status', 'active'),
        supabase.from('messages').select('*', { count: 'exact', head: true }),
        supabase.from('events').select('*', { count: 'exact', head: true }),
        supabase.from('board_posts').select('*', { count: 'exact', head: true }),
        supabase.from('organizations').select('*', { count: 'exact', head: true }),
        supabase.from('crises').select('*', { count: 'exact', head: true }),
        supabase.from('farm_listings').select('*', { count: 'exact', head: true }),
        supabase.from('trust_ratings').select('*', { count: 'exact', head: true }),
        supabase.from('groups').select('*', { count: 'exact', head: true }),
        supabase.from('challenges').select('*', { count: 'exact', head: true }),
        supabase.from('challenges').select('*', { count: 'exact', head: true }).eq('status', 'active'),
        supabase.from('timebank_entries').select('*', { count: 'exact', head: true }),
      ])
      setStats({
        total_users: totalUsers ?? 0,
        active_users_30d: 0,
        total_posts: totalPosts ?? 0,
        active_posts: activePosts ?? 0,
        total_messages: totalMessages ?? 0,
        total_conversations: 0,
        total_interactions: 0,
        completed_interactions: 0,
        total_events: totalEvents ?? 0,
        upcoming_events: 0,
        total_board_posts: totalBoardPosts ?? 0,
        active_board_posts: 0,
        total_organizations: totalOrgs ?? 0,
        verified_organizations: 0,
        total_crises: totalCrises ?? 0,
        active_crises: 0,
        total_farm_listings: totalFarms ?? 0,
        verified_farms: 0,
        total_trust_ratings: totalRatings ?? 0,
        avg_trust_score: 0,
        total_notifications: 0,
        unread_notifications: 0,
        total_saved_posts: 0,
        total_regions: 0,
        new_users_7d: 0,
        new_posts_7d: 0,
        total_groups: totalGroups ?? 0,
        active_groups: 0,
        total_challenges: totalChallenges ?? 0,
        active_challenges: activeChallenges ?? 0,
        total_timebank_hours: 0,
        total_timebank_entries: totalTimebankEntries ?? 0,
      })
    }

    const { count: reportsCount } = await reportsPromise
    setOpenReportsCount(reportsCount ?? 0)
    setLoading(false)
  }, [])

  useEffect(() => { if (isAdmin) loadStats() }, [isAdmin, loadStats])

  // ── Loading / Guard ─────────────────────────────────────────
  if (isAdmin === null) {
    return (
      <div className="flex items-center justify-center min-h-64">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-primary-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-500">Prüfe Berechtigung...</p>
        </div>
      </div>
    )
  }

  if (isAdmin === false) {
    return (
      <div className="flex flex-col items-center justify-center min-h-64 text-center gap-4">
        <div className="w-16 h-16 bg-red-100 rounded-2xl flex items-center justify-center">
          <Lock className="w-8 h-8 text-red-500" />
        </div>
        <h2 className="text-xl font-bold text-gray-900">Kein Zugang</h2>
        <p className="text-gray-500 text-sm max-w-sm">
          Dieses Dashboard ist nur für Administratoren und Moderatoren zugänglich.
        </p>
        <Link href="/dashboard" className="px-4 py-2 bg-primary-600 text-white rounded-xl text-sm font-medium hover:bg-primary-700 transition-colors">
          Zurück zum Dashboard
        </Link>
      </div>
    )
  }

  const currentTitle = TAB_TITLES[tab]

  return (
    <div className="flex flex-col lg:flex-row gap-4 lg:gap-6">
      {/* Sidebar */}
      <AdminSidebar
        activeTab={tab}
        onTabChange={setTab}
        userRole={userRole}
        openReportsCount={openReportsCount}
      />

      {/* Main Content */}
      <main className="flex-1 min-w-0 space-y-5">
        {/* Page Header */}
        <div className="flex items-center justify-between flex-wrap gap-4 bg-white rounded-2xl border border-gray-100 shadow-sm px-5 py-4">
          <div className="min-w-0">
            <h1 className="text-xl font-bold text-gray-900 flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-primary-600 flex-shrink-0" />
              <span className="truncate">{currentTitle.title}</span>
            </h1>
            <p className="text-sm text-gray-500 mt-0.5 truncate">{currentTitle.subtitle}</p>
          </div>
          <button
            onClick={loadStats}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-primary-600 text-white rounded-xl text-sm font-medium hover:bg-primary-700 transition-colors disabled:opacity-50 flex-shrink-0"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            <span className="hidden sm:inline">Aktualisieren</span>
          </button>
        </div>

        {/* Tab Content */}
        {loading && tab === 'overview' ? (
          <div className="flex items-center justify-center min-h-48 bg-white rounded-2xl border border-gray-100">
            <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <>
            {tab === 'overview'   && <DashboardHome stats={stats} onNavigate={setTab} />}
            {tab === 'users'      && <UsersTab />}
            {tab === 'posts'      && <PostsTab />}
            {tab === 'chat'       && <ChatModTab />}
            {tab === 'events'     && <EventsTab />}
            {tab === 'board'      && <BoardTab />}
            {tab === 'crisis'     && <CrisisTab />}
            {tab === 'orgs'       && <OrgsTab />}
            {tab === 'farms'      && <FarmsTab />}
            {tab === 'reports'    && <ReportsTab />}
            {tab === 'groups'     && <GroupsTab />}
            {tab === 'challenges' && <ChallengesTab />}
            {tab === 'zeitbank'   && <ZeitbankTab />}
            {tab === 'system'     && <SystemTab />}
          </>
        )}
      </main>
    </div>
  )
}
