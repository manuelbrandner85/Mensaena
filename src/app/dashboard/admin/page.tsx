'use client'

import { useEffect, useState, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  CheckCircle2, XCircle, Eye, RefreshCw,
  MapPin, Globe, Mail, Phone, Leaf, AlertTriangle, Search,
  TrendingUp, Database, Users, ShieldCheck, Lock,
  MessageCircle, ShieldOff, Volume2, VolumeX, Trash2, Ban
} from 'lucide-react'
import Link from 'next/link'
import type { FarmListing } from '@/types/farm'
import { CATEGORY_ICONS, COUNTRY_LABELS } from '@/types/farm'

interface Stats {
  total: number
  withCoords: number
  bio: number
  verified: number
  noEmail: number
  noPhone: number
  byCountry: Record<string, number>
  byCategory: Record<string, number>
  duplicates: { name: string; city: string; count: number }[]
}

export default function AdminDashboard() {
  const [farms,     setFarms]     = useState<FarmListing[]>([])
  const [stats,     setStats]     = useState<Stats | null>(null)
  const [loading,   setLoading]   = useState(true)
  const [isAdmin,   setIsAdmin]   = useState<boolean | null>(null)
  const [search,    setSearch]    = useState('')
  const [tab,       setTab]       = useState<'overview' | 'list' | 'duplicates' | 'missing' | 'chat'>('overview')
  const [saving,    setSaving]    = useState<string | null>(null)

  // Chat Moderation State
  const [communityRoom, setCommunityRoom]   = useState<{id:string;is_locked:boolean;locked_reason:string|null}|null>(null)
  const [chatMessages,  setChatMessages]    = useState<{id:string;content:string;created_at:string;deleted_at:string|null;sender_id:string;profiles:{name:string|null;email:string|null}|null}[]>([])
  const [chatUsers,     setChatUsers]       = useState<{id:string;name:string|null;email:string|null;banned:boolean}[]>([])
  const [lockReason,    setLockReason]      = useState('')
  const [chatLoading,   setChatLoading]     = useState(false)

  // ── Admin-Guard ─────────────────────────────────────────────
  useEffect(() => {
    const supabase = createClient()
    async function checkAdmin() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { setIsAdmin(false); return }
      // Check role – falls Spalte noch nicht existiert, erlaube ersten User als Admin
      const { data } = await supabase.from('profiles').select('role, email').eq('id', user.id).single()
      const adminEmails = ['brandy13062@gmail.com', 'uwevetter@gmx.at']
      const isAdminUser = data?.role === 'admin' || adminEmails.includes(data?.email ?? '') || adminEmails.includes(user.email ?? '')
      setIsAdmin(isAdminUser)
    }
    checkAdmin()
  }, [])

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data } = await supabase
      .from('farm_listings')
      .select('*')
      .order('created_at', { ascending: false })
    const all = (data || []) as FarmListing[]
    setFarms(all)

    // Compute stats
    const byCountry: Record<string, number> = {}
    const byCategory: Record<string, number> = {}
    all.forEach((f) => {
      byCountry[f.country] = (byCountry[f.country] || 0) + 1
      byCategory[f.category] = (byCategory[f.category] || 0) + 1
    })

    // Duplicate detection: same name + city (case-insensitive)
    const seen: Record<string, number> = {}
    all.forEach((f) => {
      const key = `${f.name.toLowerCase().trim()}|||${f.city.toLowerCase().trim()}`
      seen[key] = (seen[key] || 0) + 1
    })
    const duplicates = Object.entries(seen)
      .filter(([, count]) => count > 1)
      .map(([key, count]) => {
        const [name, city] = key.split('|||')
        return { name, city, count }
      })

    setStats({
      total: all.length,
      withCoords: all.filter((f) => f.latitude && f.longitude).length,
      bio: all.filter((f) => f.is_bio).length,
      verified: all.filter((f) => f.is_verified).length,
      noEmail: all.filter((f) => !f.email).length,
      noPhone: all.filter((f) => !f.phone).length,
      byCountry,
      byCategory,
      duplicates,
    })
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const loadChatData = useCallback(async () => {
    setChatLoading(true)
    const supabase = createClient()

    // Community Room
    const { data: room } = await supabase
      .from('conversations').select('id, is_locked, locked_reason')
      .eq('type', 'system').eq('title', 'Community Chat').single()
    if (room) setCommunityRoom(room as any)

    // Recent messages
    if (room) {
      const { data: msgs } = await supabase
        .from('messages')
        .select('id, content, created_at, deleted_at, sender_id, profiles(name, email)')
        .eq('conversation_id', room.id)
        .order('created_at', { ascending: false })
        .limit(50)
      setChatMessages((msgs as any[]) ?? [])
    }

    // Banned users
    const { data: bans } = await supabase
      .from('chat_banned_users')
      .select('user_id, profiles(id, name, email)')
    const bannedIds = new Set((bans ?? []).map((b: any) => b.user_id))

    // Active chat users (last 20 who sent messages)
    const { data: chatUserData } = await supabase
      .from('messages').select('sender_id, profiles(id, name, email)')
      .eq('conversation_id', room?.id ?? '')
      .not('sender_id', 'is', null)
      .limit(100)
    const seen = new Set<string>()
    const users: any[] = []
    for (const m of (chatUserData ?? []) as any[]) {
      if (!seen.has(m.sender_id) && m.profiles) {
        seen.add(m.sender_id)
        users.push({ ...m.profiles, banned: bannedIds.has(m.sender_id) })
      }
    }
    setChatUsers(users)
    setChatLoading(false)
  }, [])

  useEffect(() => { if (tab === 'chat') loadChatData() }, [tab, loadChatData])

  const handleToggleLock = async () => {
    if (!communityRoom) return
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    const newLocked = !communityRoom.is_locked
    await supabase.from('conversations').update({
      is_locked: newLocked,
      locked_by: newLocked ? user?.id : null,
      locked_at: newLocked ? new Date().toISOString() : null,
      locked_reason: newLocked ? (lockReason || null) : null,
    }).eq('id', communityRoom.id)
    setCommunityRoom(prev => prev ? { ...prev, is_locked: newLocked, locked_reason: lockReason || null } : prev)
    setLockReason('')
  }

  const handleDeleteChatMsg = async (msgId: string) => {
    const supabase = createClient()
    await supabase.from('messages').update({ deleted_at: new Date().toISOString() }).eq('id', msgId)
    setChatMessages(prev => prev.map(m => m.id === msgId ? { ...m, deleted_at: new Date().toISOString() } : m))
  }

  const handleToggleBan = async (targetUserId: string, isBanned: boolean) => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (isBanned) {
      await supabase.from('chat_banned_users').delete().eq('user_id', targetUserId)
    } else {
      await supabase.from('chat_banned_users').insert({ user_id: targetUserId, banned_by: user?.id, reason: 'Admin-Entscheidung' })
    }
    setChatUsers(prev => prev.map(u => u.id === targetUserId ? { ...u, banned: !isBanned } : u))
  }

  const toggleVerified = async (farm: FarmListing) => {
    setSaving(farm.id)
    const supabase = createClient()
    await supabase.from('farm_listings').update({ is_verified: !farm.is_verified }).eq('id', farm.id)
    setFarms((prev) => prev.map((f) => f.id === farm.id ? { ...f, is_verified: !f.is_verified } : f))
    setSaving(null)
  }

  const togglePublic = async (farm: FarmListing) => {
    setSaving(farm.id)
    const supabase = createClient()
    await supabase.from('farm_listings').update({ is_public: !farm.is_public }).eq('id', farm.id)
    setFarms((prev) => prev.map((f) => f.id === farm.id ? { ...f, is_public: !f.is_public } : f))
    setSaving(null)
  }

  const filtered = farms.filter((f) =>
    !search || f.name.toLowerCase().includes(search.toLowerCase()) ||
    f.city.toLowerCase().includes(search.toLowerCase())
  )
  const missing = farms.filter((f) => !f.latitude || !f.longitude || !f.email || !f.phone)

  if (loading && isAdmin === null) {
    return (
      <div className="flex items-center justify-center min-h-64">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-green-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-500">Prüfe Berechtigung…</p>
        </div>
      </div>
    )
  }

  // ── Kein Admin-Zugang ──────────────────────────────────────────
  if (isAdmin === false) {
    return (
      <div className="flex flex-col items-center justify-center min-h-64 text-center gap-4">
        <div className="w-16 h-16 bg-red-100 rounded-2xl flex items-center justify-center">
          <Lock className="w-8 h-8 text-red-500" />
        </div>
        <h2 className="text-xl font-bold text-gray-900">Kein Zugang</h2>
        <p className="text-gray-500 text-sm max-w-sm">
          Dieses Dashboard ist nur für Administratoren zugänglich.
          Wende dich an den Support, wenn du Zugang benötigst.
        </p>
        <Link href="/dashboard" className="btn-primary text-sm">
          Zurück zum Dashboard
        </Link>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-64">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-green-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-500">Admin-Daten werden geladen…</p>
        </div>
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
          <p className="text-sm text-gray-500 mt-1">Betriebe verwalten, verifizieren und Datenqualität verbessern</p>
        </div>
        <button
          onClick={load}
          className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-xl text-sm font-medium hover:bg-green-700 transition-colors"
        >
          <RefreshCw className="w-4 h-4" /> Aktualisieren
        </button>
      </div>

      {/* Tab Navigation */}
      <div className="flex gap-1 bg-gray-100 rounded-xl p-1 w-fit flex-wrap">
        {([
          { key: 'overview',   label: '📊 Übersicht' },
          { key: 'list',       label: '📋 Alle Betriebe' },
          { key: 'duplicates', label: `⚠️ Duplikate (${stats?.duplicates.length || 0})` },
          { key: 'missing',    label: `❌ Lückenhaft (${missing.length})` },
          { key: 'chat',       label: '💬 Chat-Moderation' },
        ] as const).map(({ key, label }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              tab === key ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* ── Overview Tab ── */}
      {tab === 'overview' && stats && (
        <div className="space-y-6">
          {/* Stats Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[
              { icon: <Database className="w-5 h-5 text-green-600" />, label: 'Gesamt', value: stats.total, bg: 'bg-green-50' },
              { icon: <MapPin className="w-5 h-5 text-blue-600" />, label: 'Mit GPS', value: `${stats.withCoords} / ${stats.total}`, bg: 'bg-blue-50' },
              { icon: <Leaf className="w-5 h-5 text-lime-600" />, label: 'Bio', value: stats.bio, bg: 'bg-lime-50' },
              { icon: <ShieldCheck className="w-5 h-5 text-indigo-600" />, label: 'Verifiziert', value: stats.verified, bg: 'bg-indigo-50' },
              { icon: <Mail className="w-5 h-5 text-amber-600" />, label: 'Ohne E-Mail', value: stats.noEmail, bg: 'bg-amber-50' },
              { icon: <Phone className="w-5 h-5 text-orange-600" />, label: 'Ohne Telefon', value: stats.noPhone, bg: 'bg-orange-50' },
              { icon: <AlertTriangle className="w-5 h-5 text-red-500" />, label: 'Duplikate', value: stats.duplicates.length, bg: 'bg-red-50' },
              { icon: <TrendingUp className="w-5 h-5 text-purple-600" />, label: 'GPS-Abdeckung', value: `${Math.round(stats.withCoords / stats.total * 100)}%`, bg: 'bg-purple-50' },
            ].map(({ icon, label, value, bg }) => (
              <div key={label} className={`${bg} rounded-2xl p-4 border border-white/50`}>
                <div className="flex items-center gap-2 mb-2">{icon}<span className="text-xs text-gray-500 font-medium">{label}</span></div>
                <p className="text-2xl font-bold text-gray-900">{value}</p>
              </div>
            ))}
          </div>

          {/* By Country */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Globe className="w-4 h-4 text-gray-400" /> Nach Land
              </h3>
              <div className="space-y-3">
                {Object.entries(stats.byCountry).sort((a, b) => b[1] - a[1]).map(([country, count]) => (
                  <div key={country} className="flex items-center gap-3">
                    <span className="text-sm font-medium w-24 shrink-0">{COUNTRY_LABELS[country] ?? country}</span>
                    <div className="flex-1 bg-gray-100 rounded-full h-2 overflow-hidden">
                      <div className="bg-green-500 h-2 rounded-full" style={{ width: `${(count / stats.total) * 100}%` }} />
                    </div>
                    <span className="text-sm text-gray-600 w-10 text-right">{count}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Users className="w-4 h-4 text-gray-400" /> Nach Kategorie
              </h3>
              <div className="space-y-3">
                {Object.entries(stats.byCategory).sort((a, b) => b[1] - a[1]).map(([cat, count]) => (
                  <div key={cat} className="flex items-center gap-3">
                    <span className="text-sm w-40 shrink-0 truncate">{CATEGORY_ICONS[cat as keyof typeof CATEGORY_ICONS]} {cat}</span>
                    <div className="flex-1 bg-gray-100 rounded-full h-2 overflow-hidden">
                      <div className="bg-amber-400 h-2 rounded-full" style={{ width: `${(count / stats.total) * 100}%` }} />
                    </div>
                    <span className="text-sm text-gray-600 w-10 text-right">{count}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── List Tab ── */}
      {tab === 'list' && (
        <div className="space-y-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Betrieb oder Stadt suchen…"
              className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
            />
          </div>
          <p className="text-sm text-gray-500">{filtered.length} Einträge</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Name</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Stadt</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Land</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">GPS</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Öffentlich</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Verifiziert</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {filtered.slice(0, 100).map((f) => (
                    <tr key={f.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <span>{CATEGORY_ICONS[f.category] || '🏡'}</span>
                          <span className="font-medium text-gray-900 truncate max-w-48">{f.name}</span>
                          {f.is_bio && <Leaf className="w-3.5 h-3.5 text-lime-600 shrink-0" />}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-gray-600">{f.city}</td>
                      <td className="px-4 py-3 text-gray-500">{COUNTRY_LABELS[f.country] ?? f.country}</td>
                      <td className="px-4 py-3 text-center">
                        {f.latitude && f.longitude
                          ? <CheckCircle2 className="w-4 h-4 text-green-500 mx-auto" />
                          : <XCircle className="w-4 h-4 text-red-400 mx-auto" />}
                      </td>
                      <td className="px-4 py-3 text-center">
                        <button
                          onClick={() => togglePublic(f)}
                          disabled={saving === f.id}
                          className={`w-10 h-5 rounded-full transition-all relative ${f.is_public ? 'bg-green-500' : 'bg-gray-300'}`}
                        >
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${f.is_public ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <button
                          onClick={() => toggleVerified(f)}
                          disabled={saving === f.id}
                          className={`w-10 h-5 rounded-full transition-all relative ${f.is_verified ? 'bg-blue-500' : 'bg-gray-300'}`}
                        >
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${f.is_verified ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-2 justify-end">
                          <Link href={`/dashboard/supply/farm/${f.slug}`}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-green-600 hover:bg-green-50 transition-colors">
                            <Eye className="w-4 h-4" />
                          </Link>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {filtered.length > 100 && (
              <p className="text-xs text-center text-gray-400 p-3">Zeige erste 100 von {filtered.length}</p>
            )}
          </div>
        </div>
      )}

      {/* ── Duplicates Tab ── */}
      {tab === 'duplicates' && (
        <div className="space-y-4">
          <p className="text-sm text-gray-500">Betriebe mit identischem Namen und Stadt (potenzielle Duplikate):</p>
          {stats?.duplicates.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-2xl border border-gray-100">
              <span className="text-4xl mb-2 block">✅</span>
              <p className="text-gray-600 font-medium">Keine Duplikate gefunden!</p>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Name</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Stadt</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Anzahl</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {stats?.duplicates.map((d, i) => (
                    <tr key={i} className="hover:bg-red-50 transition-colors">
                      <td className="px-4 py-3 font-medium text-gray-900 capitalize">{d.name}</td>
                      <td className="px-4 py-3 text-gray-600 capitalize">{d.city}</td>
                      <td className="px-4 py-3 text-center">
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-700">
                          {d.count}×
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ── Missing Data Tab ── */}
      {tab === 'missing' && (
        <div className="space-y-4">
          <p className="text-sm text-gray-500">Betriebe mit fehlenden Daten (GPS, E-Mail oder Telefon):</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Name</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Stadt</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">GPS</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">E-Mail</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Telefon</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Link</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {missing.map((f) => (
                    <tr key={f.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3">
                        <span className="font-medium text-gray-900 truncate max-w-48 block">{f.name}</span>
                      </td>
                      <td className="px-4 py-3 text-gray-600">{f.city}</td>
                      <td className="px-4 py-3 text-center">
                        {f.latitude && f.longitude
                          ? <CheckCircle2 className="w-4 h-4 text-green-500 mx-auto" />
                          : <XCircle className="w-4 h-4 text-red-400 mx-auto" />}
                      </td>
                      <td className="px-4 py-3 text-center">
                        {f.email
                          ? <CheckCircle2 className="w-4 h-4 text-green-500 mx-auto" />
                          : <XCircle className="w-4 h-4 text-red-400 mx-auto" />}
                      </td>
                      <td className="px-4 py-3 text-center">
                        {f.phone
                          ? <CheckCircle2 className="w-4 h-4 text-green-500 mx-auto" />
                          : <XCircle className="w-4 h-4 text-red-400 mx-auto" />}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <Link href={`/dashboard/supply/farm/${f.slug}`}
                          className="text-green-600 hover:text-green-800 text-xs font-medium">
                          Ansehen →
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
      {/* ── Chat Moderation Tab ── */}
      {tab === 'chat' && (
        <div className="space-y-6">
          {chatLoading ? (
            <div className="flex justify-center py-12">
              <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
            </div>
          ) : (
            <>
              {/* Lock/Unlock Panel */}
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h3 className="font-bold text-gray-900 flex items-center gap-2">
                      <MessageCircle className="w-4 h-4 text-primary-600" /> Community Chat
                    </h3>
                    <p className="text-sm text-gray-500 mt-0.5">Öffentlichen Chat sperren oder entsperren</p>
                  </div>
                  <div className={`px-3 py-1.5 rounded-full text-xs font-bold ${
                    communityRoom?.is_locked ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'
                  }`}>
                    {communityRoom?.is_locked ? '🔒 Gesperrt' : '✅ Offen'}
                  </div>
                </div>
                {communityRoom?.is_locked && communityRoom.locked_reason && (
                  <p className="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2 mb-3">
                    Sperrgrund: {communityRoom.locked_reason}
                  </p>
                )}
                <div className="flex gap-3 items-center">
                  <input
                    value={lockReason}
                    onChange={e => setLockReason(e.target.value)}
                    placeholder="Grund für Sperrung (optional)…"
                    className="flex-1 px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
                  />
                  <button onClick={handleToggleLock}
                    className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition-all whitespace-nowrap ${
                      communityRoom?.is_locked
                        ? 'bg-green-600 text-white hover:bg-green-700'
                        : 'bg-red-500 text-white hover:bg-red-600'
                    }`}>
                    {communityRoom?.is_locked
                      ? <><Volume2 className="w-4 h-4" /> Entsperren</>
                      : <><VolumeX className="w-4 h-4" /> Sperren</>}
                  </button>
                </div>
              </div>

              {/* User Management */}
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
                <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <Users className="w-4 h-4 text-gray-400" /> Nutzer ({chatUsers.length})
                </h3>
                <div className="space-y-2">
                  {chatUsers.length === 0 && <p className="text-sm text-gray-400 text-center py-4">Noch keine Chat-Nutzer</p>}
                  {chatUsers.map(u => (
                    <div key={u.id} className={`flex items-center justify-between px-4 py-3 rounded-xl ${
                      u.banned ? 'bg-red-50 border border-red-100' : 'bg-gray-50'
                    }`}>
                      <div>
                        <p className="text-sm font-semibold text-gray-900">{u.name ?? 'Unbekannt'}</p>
                        <p className="text-xs text-gray-500">{u.email}</p>
                      </div>
                      <div className="flex items-center gap-2">
                        {u.banned && <span className="text-xs font-bold text-red-600 bg-red-100 px-2 py-0.5 rounded-full">Gesperrt</span>}
                        <button
                          onClick={() => handleToggleBan(u.id, u.banned)}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                            u.banned
                              ? 'bg-green-100 text-green-700 hover:bg-green-200'
                              : 'bg-red-100 text-red-700 hover:bg-red-200'
                          }`}>
                          {u.banned ? <><ShieldOff className="w-3 h-3" /> Entsperren</> : <><Ban className="w-3 h-3" /> Sperren</>}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Recent Messages */}
              <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
                <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <MessageCircle className="w-4 h-4 text-gray-400" /> Letzte Nachrichten
                </h3>
                <div className="space-y-2 max-h-96 overflow-y-auto">
                  {chatMessages.length === 0 && <p className="text-sm text-gray-400 text-center py-4">Keine Nachrichten</p>}
                  {chatMessages.map(msg => (
                    <div key={msg.id} className={`flex items-start justify-between gap-3 px-3 py-2.5 rounded-xl ${
                      msg.deleted_at ? 'bg-gray-50 opacity-50' : 'hover:bg-gray-50'
                    }`}>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-0.5">
                          <span className="text-xs font-semibold text-gray-700">{(msg.profiles as any)?.name ?? 'Unbekannt'}</span>
                          <span className="text-[10px] text-gray-400">{new Date(msg.created_at).toLocaleString('de-AT')}</span>
                          {msg.deleted_at && <span className="text-[10px] text-red-500 font-bold">GELÖSCHT</span>}
                        </div>
                        <p className={`text-sm ${
                          msg.deleted_at ? 'italic text-gray-400' : 'text-gray-700'
                        }`}>
                          {msg.deleted_at ? 'Nachricht gelöscht' : msg.content}
                        </p>
                      </div>
                      {!msg.deleted_at && (
                        <button onClick={() => handleDeleteChatMsg(msg.id)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-all flex-shrink-0">
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  )
}
