'use client'

import Link from 'next/link'
import {
  Map, FilePlus, MessageCircle, ShieldAlert, PawPrint,
  Home, Wheat, Users, Siren, TrendingUp, Heart, Star, ArrowRight,
  Clock, MapPin
} from 'lucide-react'
import { formatRelativeTime, getPostTypeColor, getPostTypeLabel } from '@/lib/utils'
import type { Post, UserProfile } from '@/types'

const quickActions = [
  { href: '/dashboard/map', icon: Map, label: 'Karte öffnen', color: 'bg-trust-100 text-trust-400' },
  { href: '/dashboard/create', icon: FilePlus, label: 'Beitrag erstellen', color: 'bg-primary-100 text-primary-700', highlight: true },
  { href: '/dashboard/chat', icon: MessageCircle, label: 'Nachrichten', color: 'bg-purple-100 text-purple-700' },
  { href: '/dashboard/rescuer', icon: ShieldAlert, label: 'Retter-System', color: 'bg-orange-100 text-orange-700' },
  { href: '/dashboard/animals', icon: PawPrint, label: 'Tiere', color: 'bg-pink-100 text-pink-700' },
  { href: '/dashboard/housing', icon: Home, label: 'Wohnen', color: 'bg-blue-100 text-blue-700' },
  { href: '/dashboard/supply', icon: Wheat, label: 'Versorgung', color: 'bg-yellow-100 text-yellow-700' },
  { href: '/dashboard/community', icon: Users, label: 'Community', color: 'bg-indigo-100 text-indigo-700' },
  { href: '/dashboard/crisis', icon: Siren, label: 'Notfall', color: 'bg-red-100 text-red-700' },
]

export default function DashboardOverview({
  displayName,
  profile,
  recentPosts,
  myPostsCount,
  activePostsCount,
}: {
  displayName: string
  profile: UserProfile | null
  recentPosts: Post[]
  myPostsCount: number
  activePostsCount: number
}) {
  const hour = new Date().getHours()
  const greeting =
    hour < 12 ? 'Guten Morgen' :
    hour < 18 ? 'Guten Tag' : 'Guten Abend'

  return (
    <div className="space-y-8 max-w-7xl">
      {/* Greeting Header */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <p className="text-sm text-gray-500 mb-1">{greeting},</p>
          <h1 className="text-3xl font-bold text-gray-900">{displayName} 👋</h1>
          <p className="text-gray-600 mt-1.5 text-sm">
            Hier ist deine persönliche Übersicht. Was möchtest du heute tun?
          </p>
        </div>
        <Link href="/dashboard/create" className="btn-primary self-start sm:self-auto flex-shrink-0">
          <FilePlus className="w-4 h-4" />
          Neuer Beitrag
        </Link>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          icon={<TrendingUp className="w-5 h-5" />}
          label="Aktive Beiträge"
          value={activePostsCount.toString()}
          sub="in der Community"
          color="bg-primary-100 text-primary-700"
        />
        <StatCard
          icon={<FilePlus className="w-5 h-5" />}
          label="Meine Beiträge"
          value={myPostsCount.toString()}
          sub="erstellt"
          color="bg-trust-100 text-trust-400"
        />
        <StatCard
          icon={<Heart className="w-5 h-5" />}
          label="Vertrauensscore"
          value={(profile?.trust_score ?? 0).toString()}
          sub="Punkte"
          color="bg-pink-100 text-pink-700"
        />
        <StatCard
          icon={<Star className="w-5 h-5" />}
          label="Impact Score"
          value={(profile?.impact_score ?? 0).toString()}
          sub="Wirkungspunkte"
          color="bg-amber-100 text-amber-700"
        />
      </div>

      {/* Quick Actions */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Schnellzugriff</h2>
        <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-9 gap-3">
          {quickActions.map((action) => {
            const Icon = action.icon
            return (
              <Link
                key={action.href}
                href={action.href}
                className={`group flex flex-col items-center gap-2 p-3 rounded-2xl border transition-all duration-200 hover:-translate-y-0.5 hover:shadow-card
                  ${action.highlight
                    ? 'bg-primary-600 border-primary-700 text-white hover:bg-primary-700'
                    : 'bg-white border-warm-100 hover:border-primary-200 hover:bg-primary-50'
                  }`}
              >
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${action.highlight ? 'bg-white/20' : action.color}`}>
                  <Icon className="w-5 h-5" />
                </div>
                <span className={`text-[10px] font-medium text-center leading-tight ${action.highlight ? 'text-white' : 'text-gray-700'}`}>
                  {action.label}
                </span>
              </Link>
            )
          })}
        </div>
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Feed */}
        <div className="lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Aktuelle Beiträge</h2>
            <Link href="/dashboard/posts" className="text-sm text-primary-600 hover:text-primary-700 font-medium flex items-center gap-1">
              Alle anzeigen <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
          <div className="space-y-3">
            {recentPosts.length > 0 ? (
              recentPosts.map((post) => <PostCard key={post.id} post={post} />)
            ) : (
              <EmptyFeed />
            )}
          </div>
        </div>

        {/* Sidebar Widgets */}
        <div className="space-y-4">
          {/* Map CTA */}
          <div className="card p-5 bg-gradient-to-br from-trust-50 to-trust-100/50 border-trust-200">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-trust-400 flex items-center justify-center flex-shrink-0">
                <Map className="w-5 h-5 text-white" />
              </div>
              <div className="flex-1">
                <h3 className="font-semibold text-gray-900 text-sm mb-1">Interaktive Karte</h3>
                <p className="text-xs text-gray-600 mb-3">Alle Angebote und Anfragen in deiner Umgebung auf einen Blick.</p>
                <Link href="/dashboard/map" className="inline-flex items-center gap-1 text-xs font-medium text-trust-500 hover:text-trust-600">
                  Karte öffnen <ArrowRight className="w-3.5 h-3.5" />
                </Link>
              </div>
            </div>
          </div>

          {/* Profile Completion */}
          <div className="card p-5">
            <h3 className="font-semibold text-gray-900 text-sm mb-3">Profil vervollständigen</h3>
            <div className="space-y-2">
              {[
                { label: 'Profilbild hinzufügen', done: !!profile?.avatar_url },
                { label: 'Standort eintragen', done: !!profile?.location },
                { label: 'Fähigkeiten ergänzen', done: !!(profile?.skills && profile.skills.length > 0) },
                { label: 'Über mich schreiben', done: !!profile?.bio },
              ].map((item, i) => (
                <div key={i} className="flex items-center gap-2.5">
                  <div className={`w-4 h-4 rounded-full flex-shrink-0 flex items-center justify-center text-[10px] font-bold
                    ${item.done ? 'bg-primary-500 text-white' : 'border-2 border-gray-200'}`}>
                    {item.done && '✓'}
                  </div>
                  <span className={`text-xs ${item.done ? 'text-gray-400 line-through' : 'text-gray-700'}`}>
                    {item.label}
                  </span>
                </div>
              ))}
            </div>
            <Link href="/dashboard/profile" className="btn-outline w-full justify-center mt-4 text-xs py-2">
              Profil bearbeiten
            </Link>
          </div>

          {/* Emergency */}
          <div className="card p-5 bg-red-50 border-red-100">
            <div className="flex items-start gap-3">
              <Siren className="w-5 h-5 text-emergency-500 flex-shrink-0 mt-0.5" />
              <div>
                <h3 className="font-semibold text-gray-900 text-sm mb-1">Krisensystem</h3>
                <p className="text-xs text-gray-600 mb-3">Bei dringenden Notfällen schnell Hilfe koordinieren.</p>
                <Link href="/dashboard/crisis" className="text-xs font-semibold text-emergency-500 hover:text-emergency-600">
                  Zum Krisensystem →
                </Link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function StatCard({ icon, label, value, sub, color }: {
  icon: React.ReactNode
  label: string
  value: string
  sub: string
  color: string
}) {
  return (
    <div className="card p-5">
      <div className={`w-10 h-10 rounded-xl ${color} flex items-center justify-center mb-3`}>
        {icon}
      </div>
      <div className="text-2xl font-bold text-gray-900">{value}</div>
      <div className="text-sm font-medium text-gray-700 mt-0.5">{label}</div>
      <div className="text-xs text-gray-400 mt-0.5">{sub}</div>
    </div>
  )
}

function PostCard({ post }: { post: Post }) {
  const dotColor = getPostTypeColor(post.type)
  return (
    <Link href={`/dashboard/posts`}>
      <div className="card p-4 hover:shadow-hover hover:-translate-y-0.5 transition-all duration-200 cursor-pointer">
        <div className="flex items-start gap-3">
          <div
            className="w-2.5 h-2.5 rounded-full mt-1.5 flex-shrink-0"
            style={{ backgroundColor: dotColor }}
          />
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-xs font-medium text-gray-500">
                {getPostTypeLabel(post.type)}
              </span>
              <span className="text-gray-300">·</span>
              <span className="text-xs text-gray-400 flex items-center gap-1">
                <Clock className="w-3 h-3" />
                {formatRelativeTime(post.created_at)}
              </span>
            </div>
            <h4 className="text-sm font-semibold text-gray-900 truncate">{post.title}</h4>
            <p className="text-xs text-gray-600 mt-0.5 line-clamp-2">{post.description}</p>
            {post.latitude && post.longitude && (
              <div className="flex items-center gap-1 mt-1.5">
                <MapPin className="w-3 h-3 text-gray-400" />
                <span className="text-xs text-gray-400">Standort verfügbar</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </Link>
  )
}

function EmptyFeed() {
  return (
    <div className="card p-12 text-center">
      <div className="text-4xl mb-3">🌱</div>
      <h3 className="font-semibold text-gray-900 mb-2">Noch keine Beiträge</h3>
      <p className="text-sm text-gray-600 mb-4">Sei der Erste und erstelle einen Beitrag!</p>
      <Link href="/dashboard/create" className="btn-primary justify-center">
        Ersten Beitrag erstellen
      </Link>
    </div>
  )
}
