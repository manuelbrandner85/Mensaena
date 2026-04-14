'use client'

import { useEffect, useState, useCallback } from 'react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import {
  ShieldCheck, Lock, RefreshCw,
  BarChart3, Users, FileText, MessageCircle, Calendar,
  LayoutGrid, AlertTriangle, Building2, Wheat, Settings, Flag,
  UsersRound, Target, Clock
} from 'lucide-react'
import Link from 'next/link'
import type { AdminStats, AdminTab } from './components/AdminTypes'

// Lazy-loaded tab components
import OverviewTab from './components/OverviewTab'
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

const TABS: { key: AdminTab; label: string; icon: React.ReactNode }[] = [
  { key: 'overview', label: 'Übersicht',     icon: <BarChart3 className="w-4 h-4" /> },
  { key: 'users',    label: 'Nutzer',          icon: <Users className="w-4 h-4" /> },
  { key: 'posts',    label: 'Beiträge',       icon: <FileText className="w-4 h-4" /> },
  { key: 'chat',     label: 'Chat',            icon: <MessageCircle className="w-4 h-4" /> },
  { key: 'events',   label: 'Events',          icon: <Calendar className="w-4 h-4" /> },
  { key: 'board',    label: 'Brett',           icon: <LayoutGrid className="w-4 h-4" /> },
  { key: 'crisis',   label: 'Krisen',          icon: <AlertTriangle className="w-4 h-4" /> },
  { key: 'orgs',     label: 'Organisationen',  icon: <Building2 className="w-4 h-4" /> },
  { key: 'farms',    label: 'Betriebe',        icon: <Wheat className="w-4 h-4" /> },
  { key: 'reports',    label: 'Meldungen',       icon: <Flag className="w-4 h-4" /> },
  { key: 'groups',     label: 'Gruppen',         icon: <UsersRound className="w-4 h-4" /> },
  { key: 'challenges', label: 'Challenges',      icon: <Target className="w-4 h-4" /> },
  { key: 'zeitbank',   label: 'Zeitbank',        icon: <Clock className="w-4 h-4" /> },
  { key: 'system',     label: 'System',          icon: <Settings className="w-4 h-4" /> },
]

// Tabs restricted to admin-only (moderators can't see these)
const ADMIN_ONLY_TABS: AdminTab[] = ['users', 'system']

export default function AdminDashboard() {
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null)
  const [userRole, setUserRole] = useState<string>('user')
  const [stats, setStats]     = useState<AdminStats | null>(null)
  const [tab, setTab]         = useState<AdminTab>('overview')
  const [loading, setLoading] = useState(true)

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
    // Try RPC first
    const { data, error } = await supabase.rpc('get_admin_dashboard_stats')
    if (!error && data) {
      // RPC returns JSON object with 26+ fields
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
    setLoading(false)
  }, [])

  useEffect(() => { if (isAdmin) loadStats() }, [isAdmin, loadStats])

  // ── Loading / Guard ─────────────────────────────────────────
  if (isAdmin === null) {
    return (
      <div className="flex items-center justify-center min-h-64">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-green-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
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
        <Link href="/dashboard" className="px-4 py-2 bg-green-600 text-white rounded-xl text-sm font-medium hover:bg-green-700 transition-colors">
          Zurück zum Dashboard
        </Link>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <ShieldCheck className="w-6 h-6 text-green-600" /> Admin-Dashboard
          </h1>
          <p className="text-sm text-gray-500 mt-1">Plattform verwalten und moderieren</p>
        </div>
        <button onClick={loadStats} disabled={loading}
          className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-xl text-sm font-medium hover:bg-green-700 transition-colors disabled:opacity-50">
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} /> Aktualisieren
        </button>
      </div>

      {/* Tab Navigation */}
      <div className="flex gap-1 bg-gray-100 rounded-xl p-1 overflow-x-auto">
        {TABS
          .filter(({ key }) => userRole === 'admin' || !ADMIN_ONLY_TABS.includes(key))
          .map(({ key, label, icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex items-center gap-1.5 px-3 py-2 rounded-lg text-sm font-medium transition-all whitespace-nowrap ${
              tab === key
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {icon}
            <span className="hidden sm:inline">{label}</span>
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {loading && tab === 'overview' ? (
        <div className="flex items-center justify-center min-h-48">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          {tab === 'overview' && <OverviewTab stats={stats} />}
          {tab === 'users' && <UsersTab />}
          {tab === 'posts' && <PostsTab />}
          {tab === 'chat' && <ChatModTab />}
          {tab === 'events' && <EventsTab />}
          {tab === 'board' && <BoardTab />}
          {tab === 'crisis' && <CrisisTab />}
          {tab === 'orgs' && <OrgsTab />}
          {tab === 'farms' && <FarmsTab />}
          {tab === 'reports'    && <ReportsTab />}
          {tab === 'groups'     && <GroupsTab />}
          {tab === 'challenges' && <ChallengesTab />}
          {tab === 'zeitbank'   && <ZeitbankTab />}
          {tab === 'system'     && <SystemTab />}
        </>
      )}
    </div>
  )
}
