'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import {
  Map, FilePlus, MessageCircle, ShieldAlert, PawPrint, Home,
  Wheat, Bell, TrendingUp, Heart, Flame, Plus, ArrowRight,
  BookmarkCheck, Users, Siren, Clock, Star, Sprout, HandCoins,
  AlertTriangle, X, BookOpen, Wrench, Shuffle, Brain, Car
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'

const quickActions = [
  { href: '/dashboard/map',            icon: Map,          label: 'Karte',         color: 'bg-trust-100 text-trust-600'   },
  { href: '/dashboard/rescuer',        icon: ShieldAlert,  label: 'Retter',        color: 'bg-orange-100 text-orange-700' },
  { href: '/dashboard/animals',        icon: PawPrint,     label: 'Tiere',         color: 'bg-pink-100 text-pink-700'    },
  { href: '/dashboard/housing',        icon: Home,         label: 'Wohnen',        color: 'bg-blue-100 text-blue-700'    },
  { href: '/dashboard/supply',         icon: Wheat,        label: 'Versorgung',    color: 'bg-yellow-100 text-yellow-700'},
  { href: '/dashboard/chat',           icon: MessageCircle,label: 'Chat',          color: 'bg-purple-100 text-purple-700'},
  { href: '/dashboard/community',      icon: Users,        label: 'Community',     color: 'bg-violet-100 text-violet-700'},
  { href: '/dashboard/crisis',         icon: Siren,        label: 'Notfall',       color: 'bg-red-100 text-red-700'      },
  { href: '/dashboard/timebank',       icon: Clock,        label: 'Zeitbank',      color: 'bg-amber-100 text-amber-700'  },
  { href: '/dashboard/harvest',        icon: Sprout,       label: 'Erntehilfe',    color: 'bg-lime-100 text-lime-700'    },
  { href: '/dashboard/skills',         icon: Wrench,       label: 'Skills',        color: 'bg-purple-100 text-purple-600'},
  { href: '/dashboard/knowledge',      icon: BookOpen,     label: 'Wissen',        color: 'bg-teal-100 text-teal-700'    },
  { href: '/dashboard/sharing',        icon: Shuffle,      label: 'Teilen',        color: 'bg-teal-100 text-emerald-700' },
  { href: '/dashboard/mobility',       icon: Car,          label: 'Mobilität',     color: 'bg-indigo-100 text-indigo-700'},
  { href: '/dashboard/mental-support', icon: Brain,        label: 'Mental',        color: 'bg-cyan-100 text-cyan-700'    },
]

export default function DashboardPage() {
  const [profile, setProfile]           = useState<Record<string,unknown> | null>(null)
  const [urgentPosts, setUrgentPosts]   = useState<PostCardPost[]>([])
  const [helpRequests, setHelpRequests] = useState<PostCardPost[]>([])
  const [helpOffers, setHelpOffers]     = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds]         = useState<string[]>([])
  const [userId, setUserId]             = useState<string>()
  const [stats, setStats]               = useState({ active: 0, mine: 0, saved: 0, notifications: 0 })
  const [crisisPosts, setCrisisPosts]   = useState<PostCardPost[]>([])
  const [showCrisisBanner, setShowCrisisBanner] = useState(true)
  const [loading, setLoading]           = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      setUserId(user.id)

      const [profileRes, urgentRes, requestRes, offerRes, savedRes, myCount, activeCount, savedCount, crisisRes] =
        await Promise.all([
          supabase.from('profiles').select('*').eq('id', user.id).single(),
          supabase.from('posts').select('*, profiles(name,avatar_url)')
            .eq('status','active').eq('urgency','high')
            .order('created_at',{ascending:false}).limit(3),
          supabase.from('posts').select('*, profiles(name,avatar_url)')
            .eq('status','active').eq('type','help_request')
            .order('created_at',{ascending:false}).limit(4),
          supabase.from('posts').select('*, profiles(name,avatar_url)')
            .eq('status','active').eq('type','help_offer')
            .order('created_at',{ascending:false}).limit(4),
          supabase.from('saved_posts').select('post_id').eq('user_id', user.id),
          supabase.from('posts').select('*',{count:'exact',head:true}).eq('user_id',user.id),
          supabase.from('posts').select('*',{count:'exact',head:true}).eq('status','active'),
          supabase.from('saved_posts').select('*',{count:'exact',head:true}).eq('user_id',user.id),
          supabase.from('posts').select('*, profiles(name,avatar_url)')
            .eq('status','active').eq('type','crisis')
            .order('created_at',{ascending:false}).limit(3),
        ])

      setProfile(profileRes.data)
      setCrisisPosts(crisisRes.data ?? [])
      setUrgentPosts(urgentRes.data ?? [])
      setHelpRequests(requestRes.data ?? [])
      setHelpOffers(offerRes.data ?? [])
      setSavedIds((savedRes.data ?? []).map((s:{post_id:string}) => s.post_id))
      setStats({
        active: activeCount.count ?? 0,
        mine: myCount.count ?? 0,
        saved: savedCount.count ?? 0,
        notifications: (crisisRes.data ?? []).length,  // echte Zahl: aktive Krisen
      })
      setLoading(false)
    }
    load()
  }, [])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
      </div>
    )
  }

  const name = (profile?.name as string) ?? 'Nutzer'
  const hour = new Date().getHours()
  const greeting = hour < 12 ? 'Guten Morgen' : hour < 18 ? 'Guten Tag' : 'Guten Abend'
  const trust = (profile?.trust_score as number) ?? 0
  const impact = (profile?.impact_score as number) ?? 0

  return (
    <div className="max-w-6xl space-y-8">

      {/* ── Notfall-Banner ── */}
      {crisisPosts.length > 0 && showCrisisBanner && (
        <div className="bg-red-600 text-white rounded-2xl p-4 flex items-start gap-3 animate-fade-in">
          <AlertTriangle className="w-5 h-5 flex-shrink-0 mt-0.5 text-red-200" />
          <div className="flex-1">
            <p className="font-bold text-sm">
              🚨 {crisisPosts.length} aktive{crisisPosts.length > 1 ? ' Notfälle' : 'r Notfall'} in der Community
            </p>
            <p className="text-xs text-red-100 mt-0.5">
              {crisisPosts[0]?.title} – sofortige Hilfe gesucht
            </p>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0">
            <Link href="/dashboard/crisis"
              className="text-xs font-bold bg-white/20 hover:bg-white/30 px-3 py-1.5 rounded-lg transition-all">
              Ansehen →
            </Link>
            <button onClick={() => setShowCrisisBanner(false)} className="p-1.5 hover:bg-white/20 rounded-lg">
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* ── Begrüßung ── */}
      <div className="bg-gradient-to-r from-primary-600 to-primary-800 rounded-2xl p-6 text-white">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <p className="text-primary-200 text-sm mb-1">{greeting},</p>
            <h1 className="text-2xl font-bold">{name} 👋</h1>
            <p className="text-primary-100 text-sm mt-1">
              Was möchtest du heute tun? Du machst die Welt ein Stück besser. 🌿
            </p>
            <div className="flex items-center gap-4 mt-3">
              <div className="flex items-center gap-1.5 text-sm text-primary-100">
                <Star className="w-4 h-4 text-yellow-300 fill-yellow-300" />
                Vertrauen: <span className="font-bold text-white">{trust}</span>
              </div>
              <div className="flex items-center gap-1.5 text-sm text-primary-100">
                <Heart className="w-4 h-4 text-pink-300 fill-pink-300" />
                Impact: <span className="font-bold text-white">{impact}</span>
              </div>
            </div>
          </div>
          {/* Primäraktionen */}
          <div className="flex flex-col gap-2 flex-shrink-0">
            <Link href="/dashboard/create?type=help_request"
              className="flex items-center gap-2 px-5 py-2.5 bg-red-500 hover:bg-red-600 rounded-xl text-sm font-bold transition-all shadow-md">
              <Heart className="w-4 h-4" /> Ich brauche Hilfe
            </Link>
            <Link href="/dashboard/create?type=help_offer"
              className="flex items-center gap-2 px-5 py-2.5 bg-green-500 hover:bg-green-600 rounded-xl text-sm font-bold transition-all shadow-md">
              <Plus className="w-4 h-4" /> Ich helfe
            </Link>
          </div>
        </div>
      </div>

      {/* ── Stats ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { icon: TrendingUp,     label: 'Aktive Beiträge',  value: stats.active,        color: 'text-primary-600 bg-primary-50' },
          { icon: FilePlus,       label: 'Meine Beiträge',   value: stats.mine,          color: 'text-trust-600 bg-trust-50'    },
          { icon: BookmarkCheck,  label: 'Gespeichert',      value: stats.saved,         color: 'text-violet-600 bg-violet-50'  },
          { icon: Bell,           label: 'Benachrichtigungen',value: stats.notifications, color: 'text-orange-600 bg-orange-50'  },
        ].map(s => (
          <div key={s.label} className="bg-white rounded-2xl border border-warm-200 p-4 flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${s.color}`}>
              <s.icon className="w-5 h-5" />
            </div>
            <div>
              <p className="text-2xl font-bold text-gray-900">{s.value}</p>
              <p className="text-xs text-gray-500">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* ── Schnellzugriffe ── */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-bold text-gray-900">Schnellzugriff</h2>
        </div>
        <div className="grid grid-cols-5 sm:grid-cols-8 lg:grid-cols-[repeat(15,minmax(0,1fr))] gap-2">
          {quickActions.map(a => (
            <Link key={a.href} href={a.href}
              className="flex flex-col items-center gap-2 p-3 bg-white rounded-2xl border border-warm-200 hover:border-primary-300 hover:shadow-md transition-all group">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${a.color} group-hover:scale-110 transition-transform`}>
                <a.icon className="w-5 h-5" />
              </div>
              <span className="text-xs font-medium text-gray-700 text-center leading-tight">{a.label}</span>
            </Link>
          ))}
        </div>
      </div>

      {/* ── Dringende Beiträge ── */}
      {urgentPosts.length > 0 && (
        <div>
          <div className="flex items-center gap-2 mb-3">
            <Flame className="w-5 h-5 text-red-500" />
            <h2 className="text-lg font-bold text-gray-900">Dringende Hilfe gesucht</h2>
            <span className="ml-auto text-xs text-red-600 bg-red-50 px-2 py-0.5 rounded-full font-medium">
              {urgentPosts.length} aktiv
            </span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {urgentPosts.map(p => (
              <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds}
                onSaveToggle={(id,s) => setSavedIds(prev => s ? [...prev,id] : prev.filter(x=>x!==id))} />
            ))}
          </div>
        </div>
      )}

      {/* ── Feed: Hilfe gesucht & angeboten ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Hilfe gesucht */}
        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="flex items-center gap-2 text-base font-bold text-gray-900">
              <span className="w-3 h-3 rounded-full bg-red-500 inline-block" />
              Neue Hilfe-Anfragen
            </h2>
            <Link href="/dashboard/posts" className="text-xs text-primary-600 flex items-center gap-1 hover:underline">
              Alle <ArrowRight className="w-3 h-3" />
            </Link>
          </div>
          {helpRequests.length === 0 ? (
            <div className="text-center py-8 bg-white rounded-2xl border border-warm-200">
              <p className="text-sm text-gray-400">Keine Anfragen – das ist gut! 🌿</p>
            </div>
          ) : (
            <div className="space-y-3">
              {helpRequests.map(p => (
                <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds} compact
                  onSaveToggle={(id,s) => setSavedIds(prev => s ? [...prev,id] : prev.filter(x=>x!==id))} />
              ))}
            </div>
          )}
        </div>

        {/* Hilfe angeboten */}
        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="flex items-center gap-2 text-base font-bold text-gray-900">
              <span className="w-3 h-3 rounded-full bg-green-500 inline-block" />
              Neue Angebote
            </h2>
            <Link href="/dashboard/posts" className="text-xs text-primary-600 flex items-center gap-1 hover:underline">
              Alle <ArrowRight className="w-3 h-3" />
            </Link>
          </div>
          {helpOffers.length === 0 ? (
            <div className="text-center py-8 bg-white rounded-2xl border border-warm-200">
              <p className="text-sm text-gray-400">Noch keine Angebote. Sei der Erste! 🌿</p>
              <Link href="/dashboard/create?type=help_offer" className="mt-3 btn-primary inline-flex text-sm">
                <Plus className="w-4 h-4" /> Angebot erstellen
              </Link>
            </div>
          ) : (
            <div className="space-y-3">
              {helpOffers.map(p => (
                <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds} compact
                  onSaveToggle={(id,s) => setSavedIds(prev => s ? [...prev,id] : prev.filter(x=>x!==id))} />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Neue Module: Zeitbank & Erntehilfe ── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Link href="/dashboard/timebank"
          className="relative flex items-center gap-4 p-5 bg-gradient-to-r from-amber-50 to-yellow-50 border border-amber-200 rounded-2xl hover:shadow-md transition-all group overflow-hidden">
          <div className="w-12 h-12 rounded-xl bg-amber-200 flex items-center justify-center group-hover:scale-110 transition-transform flex-shrink-0">
            <HandCoins className="w-6 h-6 text-amber-700" />
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <p className="font-bold text-amber-900">Zeitbank</p>
              <span className="text-[10px] font-bold bg-green-100 text-green-700 px-1.5 py-0.5 rounded-full">NEU</span>
            </div>
            <p className="text-xs text-amber-700 mt-0.5">Tausche Zeit statt Geld – Stunden anbieten &amp; verdienen</p>
          </div>
          <ArrowRight className="w-4 h-4 text-amber-500 flex-shrink-0" />
        </Link>
        <Link href="/dashboard/harvest"
          className="relative flex items-center gap-4 p-5 bg-gradient-to-r from-lime-50 to-green-50 border border-lime-200 rounded-2xl hover:shadow-md transition-all group overflow-hidden">
          <div className="w-12 h-12 rounded-xl bg-lime-200 flex items-center justify-center group-hover:scale-110 transition-transform flex-shrink-0">
            <Sprout className="w-6 h-6 text-lime-700" />
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <p className="font-bold text-lime-900">Erntehilfe</p>
              <span className="text-[10px] font-bold bg-green-100 text-green-700 px-1.5 py-0.5 rounded-full">NEU</span>
            </div>
            <p className="text-xs text-lime-700 mt-0.5">Helfe beim Ernten – bekomme frisches Gemüse &amp; Obst</p>
          </div>
          <ArrowRight className="w-4 h-4 text-lime-500 flex-shrink-0" />
        </Link>
      </div>

      {/* ── Aktions-Banner ── */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <Link href="/dashboard/map"
          className="flex items-center gap-3 p-4 bg-trust-50 border border-trust-200 rounded-2xl hover:bg-trust-100 transition-all group">
          <div className="w-10 h-10 rounded-xl bg-trust-200 flex items-center justify-center group-hover:scale-110 transition-transform">
            <Map className="w-5 h-5 text-trust-600" />
          </div>
          <div>
            <p className="font-semibold text-trust-800 text-sm">Karte öffnen</p>
            <p className="text-xs text-trust-600">Hilfe in deiner Nähe finden</p>
          </div>
        </Link>
        <Link href="/dashboard/posts"
          className="flex items-center gap-3 p-4 bg-primary-50 border border-primary-200 rounded-2xl hover:bg-primary-100 transition-all group">
          <div className="w-10 h-10 rounded-xl bg-primary-200 flex items-center justify-center group-hover:scale-110 transition-transform">
            <TrendingUp className="w-5 h-5 text-primary-700" />
          </div>
          <div>
            <p className="font-semibold text-primary-800 text-sm">Alle Beiträge</p>
            <p className="text-xs text-primary-600">{stats.active} aktive Einträge</p>
          </div>
        </Link>
        <Link href="/dashboard/chat"
          className="flex items-center gap-3 p-4 bg-purple-50 border border-purple-200 rounded-2xl hover:bg-purple-100 transition-all group">
          <div className="w-10 h-10 rounded-xl bg-purple-200 flex items-center justify-center group-hover:scale-110 transition-transform">
            <MessageCircle className="w-5 h-5 text-purple-700" />
          </div>
          <div>
            <p className="font-semibold text-purple-800 text-sm">Community-Chat</p>
            <p className="text-xs text-purple-600">In Echtzeit austauschen</p>
          </div>
        </Link>
      </div>

    </div>
  )
}
