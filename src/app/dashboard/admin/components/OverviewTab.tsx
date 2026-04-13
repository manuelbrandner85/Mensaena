'use client'

import {
  Users, FileText, MessageCircle, Calendar, LayoutGrid,
  Building2, AlertTriangle, Wheat, Star, Bell,
  TrendingUp, Activity, Shield, MapPin
} from 'lucide-react'
import type { AdminStats } from './AdminTypes'

interface Props { stats: AdminStats | null }

export default function OverviewTab({ stats }: Props) {
  if (!stats) return null

  const cards: { icon: React.ReactNode; label: string; value: number | string; bg: string; sub?: string }[] = [
    { icon: <Users className="w-5 h-5 text-blue-600" />, label: 'Nutzer gesamt', value: stats.total_users ?? 0, bg: 'bg-blue-50', sub: `${stats.active_users_30d ?? 0} aktiv (30d)` },
    { icon: <TrendingUp className="w-5 h-5 text-green-600" />, label: 'Neue Nutzer (7d)', value: stats.new_users_7d ?? 0, bg: 'bg-green-50' },
    { icon: <FileText className="w-5 h-5 text-primary-600" />, label: 'Beiträge gesamt', value: stats.total_posts ?? 0, bg: 'bg-primary-50', sub: `${stats.active_posts ?? 0} aktiv` },
    { icon: <Activity className="w-5 h-5 text-amber-600" />, label: 'Neue Beiträge (7d)', value: stats.new_posts_7d ?? 0, bg: 'bg-amber-50' },
    { icon: <MessageCircle className="w-5 h-5 text-purple-600" />, label: 'Nachrichten', value: stats.total_messages ?? 0, bg: 'bg-purple-50', sub: `${stats.total_conversations ?? 0} Gespraeche` },
    { icon: <Shield className="w-5 h-5 text-indigo-600" />, label: 'Interaktionen', value: stats.total_interactions ?? 0, bg: 'bg-indigo-50', sub: `${stats.completed_interactions ?? 0} abgeschlossen` },
    { icon: <Calendar className="w-5 h-5 text-sky-600" />, label: 'Events', value: stats.total_events ?? 0, bg: 'bg-sky-50', sub: `${stats.upcoming_events ?? 0} geplant` },
    { icon: <LayoutGrid className="w-5 h-5 text-orange-600" />, label: 'Brett-Beiträge', value: stats.total_board_posts ?? 0, bg: 'bg-orange-50', sub: `${stats.active_board_posts ?? 0} aktiv` },
    { icon: <Building2 className="w-5 h-5 text-teal-600" />, label: 'Organisationen', value: stats.total_organizations ?? 0, bg: 'bg-teal-50', sub: `${stats.verified_organizations ?? 0} verifiziert` },
    { icon: <AlertTriangle className="w-5 h-5 text-red-600" />, label: 'Krisen', value: stats.total_crises ?? 0, bg: 'bg-red-50', sub: `${stats.active_crises ?? 0} aktiv` },
    { icon: <Wheat className="w-5 h-5 text-lime-600" />, label: 'Betriebe', value: stats.total_farm_listings ?? 0, bg: 'bg-lime-50', sub: `${stats.verified_farms ?? 0} verifiziert` },
    { icon: <Star className="w-5 h-5 text-yellow-600" />, label: 'Bewertungen', value: stats.total_trust_ratings ?? 0, bg: 'bg-yellow-50', sub: `${typeof stats.avg_trust_score === 'number' ? stats.avg_trust_score.toFixed(1) : '0'} Avg` },
    { icon: <Bell className="w-5 h-5 text-pink-600" />, label: 'Benachrichtigungen', value: stats.total_notifications ?? 0, bg: 'bg-pink-50', sub: `${stats.unread_notifications ?? 0} ungelesen` },
    { icon: <MapPin className="w-5 h-5 text-cyan-600" />, label: 'Regionen', value: stats.total_regions ?? 0, bg: 'bg-cyan-50' },
  ]

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
        {cards.map(({ icon, label, value, bg, sub }) => (
          <div key={label} className={`${bg} rounded-2xl p-4 border border-white/50`}>
            <div className="flex items-center gap-2 mb-2">
              {icon}
              <span className="text-xs text-gray-500 font-medium truncate">{label}</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            {sub && <p className="text-xs text-gray-500 mt-1">{sub}</p>}
          </div>
        ))}
      </div>
    </div>
  )
}
