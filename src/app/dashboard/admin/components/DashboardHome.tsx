'use client'

import { useEffect, useState } from 'react'
import {
  Users, UsersRound, Target, Clock, TrendingUp,
  Flag, UserPlus, PlusCircle, Activity, ArrowRight,
  FileText, ShieldCheck, AlertCircle, CheckCircle2
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import type { AdminStats, AdminTab } from './AdminTypes'

interface Props {
  stats: AdminStats | null
  onNavigate: (tab: AdminTab) => void
}

interface RecentActivity {
  id: string
  action: string
  target_type: string | null
  created_at: string
  actor_name: string | null
}

const ACTION_LABELS: Record<string, { label: string; icon: React.ComponentType<{ className?: string }>; color: string }> = {
  delete_user:    { label: 'Benutzer gelöscht',     icon: Users,       color: 'text-red-600 bg-red-50' },
  change_role:    { label: 'Rolle geändert',        icon: ShieldCheck, color: 'text-purple-600 bg-purple-50' },
  ban_user:       { label: 'Benutzer gesperrt',     icon: AlertCircle, color: 'text-orange-600 bg-orange-50' },
  unban_user:     { label: 'Sperre aufgehoben',     icon: CheckCircle2,color: 'text-green-600 bg-green-50' },
  delete_post:    { label: 'Beitrag gelöscht',      icon: FileText,    color: 'text-red-600 bg-red-50' },
  delete_group:   { label: 'Gruppe gelöscht',       icon: UsersRound,  color: 'text-red-600 bg-red-50' },
  delete_challenge: { label: 'Challenge gelöscht',  icon: Target,      color: 'text-red-600 bg-red-50' },
  resolve_report: { label: 'Meldung bearbeitet',    icon: Flag,        color: 'text-blue-600 bg-blue-50' },
}

function formatRelativeTime(iso: string): string {
  const date = new Date(iso)
  const diff = Date.now() - date.getTime()
  const minutes = Math.floor(diff / 60000)
  if (minutes < 1) return 'gerade eben'
  if (minutes < 60) return `vor ${minutes} Min.`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `vor ${hours} Std.`
  const days = Math.floor(hours / 24)
  if (days < 7) return `vor ${days} T.`
  return date.toLocaleDateString('de-DE')
}

export default function DashboardHome({ stats, onNavigate }: Props) {
  const [activities, setActivities] = useState<RecentActivity[]>([])
  const [openReports, setOpenReports] = useState(0)
  const [loadingActivities, setLoadingActivities] = useState(true)

  useEffect(() => {
    const load = async () => {
      const supabase = createClient()
      const [{ data: logs }, { count }] = await Promise.all([
        supabase
          .from('audit_logs')
          .select('id, action, target_type, created_at, profiles!audit_logs_actor_id_fkey(name)')
          .order('created_at', { ascending: false })
          .limit(8),
        supabase
          .from('content_reports')
          .select('*', { count: 'exact', head: true })
          .eq('status', 'pending'),
      ])
      if (logs) {
        setActivities(
          (logs as unknown as Array<{
            id: string
            action: string
            target_type: string | null
            created_at: string
            profiles?: { name: string | null } | null
          }>).map(l => ({
            id: l.id,
            action: l.action,
            target_type: l.target_type,
            created_at: l.created_at,
            actor_name: l.profiles?.name ?? null,
          }))
        )
      }
      setOpenReports(count ?? 0)
      setLoadingActivities(false)
    }
    load()
  }, [])

  const statCards = [
    {
      label: 'Benutzer gesamt',
      value: stats?.total_users ?? 0,
      sub: `${stats?.active_users_30d ?? 0} aktiv (30d)`,
      icon: Users,
      gradient: 'from-blue-500 to-cyan-500',
      bg: 'from-blue-50 to-cyan-50',
    },
    {
      label: 'Neue Nutzer (7d)',
      value: stats?.new_users_7d ?? 0,
      sub: 'in den letzten 7 Tagen',
      icon: TrendingUp,
      gradient: 'from-green-500 to-primary-500',
      bg: 'from-green-50 to-primary-50',
    },
    {
      label: 'Aktive Gruppen',
      value: stats?.active_groups ?? 0,
      sub: `von ${stats?.total_groups ?? 0} gesamt`,
      icon: UsersRound,
      gradient: 'from-primary-500 to-teal-500',
      bg: 'from-primary-50 to-teal-50',
    },
    {
      label: 'Aktive Challenges',
      value: stats?.active_challenges ?? 0,
      sub: `von ${stats?.total_challenges ?? 0} gesamt`,
      icon: Target,
      gradient: 'from-violet-500 to-purple-500',
      bg: 'from-violet-50 to-purple-50',
    },
    {
      label: 'Zeitbank-Stunden',
      value: `${Number(stats?.total_timebank_hours ?? 0).toFixed(0)}h`,
      sub: `${stats?.total_timebank_entries ?? 0} Einträge`,
      icon: Clock,
      gradient: 'from-amber-500 to-orange-500',
      bg: 'from-amber-50 to-orange-50',
    },
  ]

  const quickActions: { label: string; icon: React.ComponentType<{ className?: string }>; color: string; tab: AdminTab }[] = [
    { label: 'Benutzer verwalten',    icon: UserPlus,    color: 'bg-blue-500 hover:bg-blue-600',       tab: 'users' },
    { label: 'Challenge erstellen',   icon: Target,      color: 'bg-violet-500 hover:bg-violet-600',   tab: 'challenges' },
    { label: 'Gruppe verwalten',      icon: UsersRound,  color: 'bg-primary-500 hover:bg-primary-600', tab: 'groups' },
    { label: 'Zeitbank prüfen',       icon: Clock,       color: 'bg-amber-500 hover:bg-amber-600',     tab: 'zeitbank' },
  ]

  return (
    <div className="space-y-6">
      {/* Welcome + Open Reports Alert */}
      {openReports > 0 && (
        <button
          onClick={() => onNavigate('reports')}
          className="w-full flex items-center gap-4 p-4 bg-gradient-to-r from-red-50 to-orange-50 border border-red-200 rounded-2xl hover:shadow-md transition-all group"
        >
          <div className="flex-shrink-0 w-12 h-12 bg-red-500 rounded-xl flex items-center justify-center shadow-sm">
            <Flag className="w-5 h-5 text-white" />
          </div>
          <div className="flex-1 text-left min-w-0">
            <p className="text-sm font-semibold text-red-900">
              {openReports} offene Meldung{openReports === 1 ? '' : 'en'}
            </p>
            <p className="text-xs text-red-700 mt-0.5">Prüfe die gemeldeten Inhalte und reagiere zeitnah.</p>
          </div>
          <ArrowRight className="w-5 h-5 text-red-600 group-hover:translate-x-1 transition-transform" />
        </button>
      )}

      {/* Stat Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3">
        {statCards.map(({ label, value, sub, icon: Icon, gradient, bg }) => (
          <div
            key={label}
            className={`relative overflow-hidden bg-gradient-to-br ${bg} rounded-2xl p-4 border border-white/50 hover:shadow-md transition-all`}
          >
            <div className="flex items-start justify-between mb-3">
              <div className={`w-9 h-9 rounded-xl bg-gradient-to-br ${gradient} flex items-center justify-center shadow-sm`}>
                <Icon className="w-4 h-4 text-white" />
              </div>
            </div>
            <p className="text-2xl font-bold text-ink-900 leading-tight">{value}</p>
            <p className="text-[11px] font-semibold text-ink-600 mt-1 truncate">{label}</p>
            <p className="text-[10px] text-ink-500 mt-0.5 truncate">{sub}</p>
          </div>
        ))}
      </div>

      {/* Grid: Activity Feed + Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Activity Feed */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between px-5 py-4 border-b border-stone-100">
            <div className="flex items-center gap-2">
              <Activity className="w-4 h-4 text-primary-600" />
              <h3 className="text-sm font-semibold text-ink-900">Letzte Aktivitäten</h3>
            </div>
            <button
              onClick={() => onNavigate('system')}
              className="text-xs text-primary-600 hover:text-primary-700 font-medium flex items-center gap-1"
            >
              Alle anzeigen <ArrowRight className="w-3 h-3" />
            </button>
          </div>
          <div className="divide-y divide-stone-100">
            {loadingActivities ? (
              <div className="p-8 text-center">
                <div className="w-6 h-6 border-2 border-primary-400 border-t-transparent rounded-full animate-spin mx-auto" />
              </div>
            ) : activities.length === 0 ? (
              <div className="p-8 text-center text-sm text-ink-400">
                Keine Aktivitäten vorhanden
              </div>
            ) : (
              activities.map(act => {
                const meta = ACTION_LABELS[act.action] ?? {
                  label: act.action,
                  icon: Activity,
                  color: 'text-ink-600 bg-stone-50',
                }
                const Icon = meta.icon
                return (
                  <div key={act.id} className="flex items-center gap-3 px-5 py-3 hover:bg-stone-50/50 transition-colors">
                    <div className={`flex-shrink-0 w-9 h-9 rounded-xl flex items-center justify-center ${meta.color}`}>
                      <Icon className="w-4 h-4" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-ink-900 truncate">{meta.label}</p>
                      <p className="text-xs text-ink-500 truncate">
                        {act.actor_name ?? 'System'}
                        {act.target_type && <> · {act.target_type}</>}
                      </p>
                    </div>
                    <span className="flex-shrink-0 text-[11px] text-ink-400 whitespace-nowrap">
                      {formatRelativeTime(act.created_at)}
                    </span>
                  </div>
                )
              })
            )}
          </div>
        </div>

        {/* Quick Actions */}
        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-stone-100 flex items-center gap-2">
            <PlusCircle className="w-4 h-4 text-primary-600" />
            <h3 className="text-sm font-semibold text-ink-900">Schnellaktionen</h3>
          </div>
          <div className="p-3 space-y-2">
            {quickActions.map(({ label, icon: Icon, color, tab }) => (
              <button
                key={tab}
                onClick={() => onNavigate(tab)}
                className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-stone-50 border border-stone-100 hover:border-stone-200 transition-all group"
              >
                <div className={`w-9 h-9 rounded-xl ${color} flex items-center justify-center shadow-sm transition-colors`}>
                  <Icon className="w-4 h-4 text-white" />
                </div>
                <span className="flex-1 text-left text-sm font-medium text-ink-700 group-hover:text-ink-900">{label}</span>
                <ArrowRight className="w-4 h-4 text-stone-400 group-hover:text-ink-500 group-hover:translate-x-0.5 transition-all" />
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Secondary Stats Grid */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-5">
        <h3 className="text-sm font-semibold text-ink-900 mb-4 flex items-center gap-2">
          <FileText className="w-4 h-4 text-primary-600" />
          Plattform-Übersicht
        </h3>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
          {[
            { label: 'Beiträge',      value: stats?.total_posts ?? 0,         sub: `${stats?.active_posts ?? 0} aktiv` },
            { label: 'Nachrichten',   value: stats?.total_messages ?? 0,      sub: `${stats?.total_conversations ?? 0} Chats` },
            { label: 'Events',        value: stats?.total_events ?? 0,        sub: `${stats?.upcoming_events ?? 0} geplant` },
            { label: 'Brett-Posts',   value: stats?.total_board_posts ?? 0,   sub: `${stats?.active_board_posts ?? 0} aktiv` },
            { label: 'Krisen',        value: stats?.total_crises ?? 0,        sub: `${stats?.active_crises ?? 0} aktiv` },
            { label: 'Betriebe',      value: stats?.total_farm_listings ?? 0, sub: `${stats?.verified_farms ?? 0} verifiziert` },
          ].map(({ label, value, sub }) => (
            <div key={label} className="bg-stone-50 rounded-xl p-3 border border-stone-100">
              <p className="text-lg font-bold text-ink-900">{value}</p>
              <p className="text-[11px] font-semibold text-ink-700 truncate">{label}</p>
              <p className="text-[10px] text-ink-500 truncate">{sub}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
