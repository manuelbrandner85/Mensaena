'use client'

import { useState, useEffect, useCallback, use } from 'react'
import {
  ArrowLeft, Users, Lock, Globe, Plus, Send, Loader2,
  Crown, Shield, MessageCircle, Trash2, UserPlus, UserMinus,
  Calendar, Tag,
} from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { cn, formatDate } from '@/lib/utils'
import toast from 'react-hot-toast'
import GroupPrivateThreads from '@/components/features/GroupPrivateThreads'

// ── Category Config ─────────────────────────────────────────────
const CAT_CONFIG: Record<string, { emoji: string; label: string; color: string }> = {
  nachbarschaft: { emoji: '🏘️', label: 'Nachbarschaft',       color: 'from-blue-400 to-blue-600' },
  hobby:         { emoji: '🎨', label: 'Hobby & Freizeit',    color: 'from-pink-400 to-rose-500' },
  sport:         { emoji: '⚽', label: 'Sport & Fitness',     color: 'from-orange-400 to-orange-600' },
  eltern:        { emoji: '👶', label: 'Eltern & Familie',    color: 'from-yellow-400 to-amber-500' },
  senioren:      { emoji: '🧓', label: 'Senioren',            color: 'from-purple-400 to-purple-600' },
  umwelt:        { emoji: '🌿', label: 'Umwelt',              color: 'from-green-400 to-green-600' },
  bildung:       { emoji: '📚', label: 'Bildung & Lernen',    color: 'from-indigo-400 to-indigo-600' },
  tiere:         { emoji: '🐾', label: 'Tiere',               color: 'from-amber-400 to-yellow-600' },
  handwerk:      { emoji: '🔧', label: 'Handwerk & DIY',      color: 'from-slate-400 to-slate-600' },
  sonstiges:     { emoji: '💬', label: 'Sonstiges',           color: 'from-primary-400 to-teal-600' },
}

function getCat(category: string) {
  return CAT_CONFIG[category] ?? CAT_CONFIG['sonstiges']
}

// ── Types ──────────────────────────────────────────────────────
interface Group {
  id: string
  name: string
  slug: string
  description: string | null
  category: string
  is_private?: boolean
  is_public?: boolean
  member_count: number
  post_count?: number
  created_at: string
  creator_id?: string
  created_by?: string
}

interface GroupPost {
  id: string
  content: string
  user_id: string
  created_at: string
  profiles?: { name: string | null; avatar_url: string | null }
}

interface Member {
  user_id: string
  role: string
  joined_at: string
  profiles?: { name: string | null; avatar_url: string | null }
}

// ── Avatar ─────────────────────────────────────────────────────
function Avatar({ name, avatarUrl, size = 'md' }: { name?: string | null; avatarUrl?: string | null; size?: 'sm' | 'md' | 'lg' }) {
  const initials = (name ?? 'U').charAt(0).toUpperCase()
  const sizeClass = size === 'sm' ? 'w-7 h-7 text-xs' : size === 'lg' ? 'w-10 h-10 text-sm' : 'w-8 h-8 text-xs'

  if (avatarUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img src={avatarUrl} alt={name ?? ''} className={cn(sizeClass, 'rounded-full object-cover border-2 border-white')} />
    )
  }
  return (
    <div className={cn(sizeClass, 'rounded-full bg-gradient-to-br from-primary-400 to-teal-500 flex items-center justify-center font-bold text-white border-2 border-white')}>
      {initials}
    </div>
  )
}

export default function GroupDetailPage({ params }: { params: Promise<{ groupId: string }> }) {
  const { groupId } = use(params)
  const [group, setGroup] = useState<Group | null>(null)
  const [posts, setPosts] = useState<GroupPost[]>([])
  const [members, setMembers] = useState<Member[]>([])
  const [userId, setUserId] = useState<string>()
  const [isMember, setIsMember] = useState(false)
  const [myRole, setMyRole] = useState<string>('member')
  const [loading, setLoading] = useState(true)
  const [newPost, setNewPost] = useState('')
  const [posting, setPosting] = useState(false)
  const [joining, setJoining] = useState(false)
  const [leaving, setLeaving] = useState(false)

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)

    // BUG FIX: Embedded profile-Joins (`profiles:user_id(...)`) wurden durch
    // PostgREST/RLS gefiltert → group_members lieferte 0 Zeilen, obwohl der
    // User Mitglied war. Lösung: Queries splitten und Profile manuell mergen.
    const [groupRes, rawPostsRes, rawMembersRes] = await Promise.all([
      supabase.from('groups').select('*').eq('id', groupId).maybeSingle(),
      supabase
        .from('group_posts')
        .select('id, content, user_id, created_at')
        .eq('group_id', groupId)
        .order('created_at', { ascending: false })
        .limit(50),
      supabase
        .from('group_members')
        .select('user_id, role, joined_at')
        .eq('group_id', groupId)
        .order('joined_at', { ascending: true }),
    ])

    if (groupRes.error) {
      console.error('load group failed:', groupRes.error.message)
    }
    if (groupRes.data) setGroup(groupRes.data as Group)

    // Profile separat laden für alle beteiligten User-IDs (Mitglieder + Post-Autoren)
    const userIds = Array.from(new Set([
      ...(rawMembersRes.data ?? []).map(m => m.user_id),
      ...(rawPostsRes.data ?? []).map(p => p.user_id),
    ]))

    let profileMap = new Map<string, { name: string | null; avatar_url: string | null }>()
    if (userIds.length > 0) {
      const { data: profilesData } = await supabase
        .from('profiles')
        .select('id, name, avatar_url')
        .in('id', userIds)
      profileMap = new Map(
        (profilesData ?? []).map(p => [p.id, { name: p.name, avatar_url: p.avatar_url }])
      )
    }

    // Members anreichern
    const enrichedMembers: Member[] = (rawMembersRes.data ?? []).map(m => ({
      user_id: m.user_id,
      role: m.role,
      joined_at: m.joined_at,
      profiles: profileMap.get(m.user_id) ?? { name: null, avatar_url: null },
    }))
    setMembers(enrichedMembers)

    // Posts anreichern
    const enrichedPosts: GroupPost[] = (rawPostsRes.data ?? []).map(p => ({
      id: p.id,
      content: p.content,
      user_id: p.user_id,
      created_at: p.created_at,
      profiles: profileMap.get(p.user_id) ?? { name: null, avatar_url: null },
    }))
    setPosts(enrichedPosts)

    // Membership-Check: nutzt die rohen group_members-Daten (kein Profil-Join → keine Filterung)
    if (user) {
      const member = (rawMembersRes.data ?? []).find(m => m.user_id === user.id)
      setIsMember(!!member)
      if (member) setMyRole(member.role)
    }

    setLoading(false)
  }, [groupId])

  useEffect(() => { loadData() }, [loadData])

  const handleJoin = async () => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    setJoining(true)
    // Optimistic update
    setIsMember(true)
    const supabase = createClient()
    const { error } = await supabase.from('group_members').insert({
      group_id: groupId,
      user_id: userId,
      role: 'member',
    })
    setJoining(false)
    if (error) {
      setIsMember(false) // revert
      if (error.code === '23505') toast.error('Du bist bereits Mitglied dieser Gruppe')
      else toast.error('Fehler beim Beitreten: ' + error.message)
      return
    }
    toast.success('Gruppe beigetreten!')
    loadData()
  }

  const handleLeave = async () => {
    if (!userId || !group) return
    const creatorId = group.creator_id || group.created_by
    if (creatorId === userId) { toast.error('Als Ersteller kannst du die Gruppe nicht verlassen'); return }
    if (!confirm('Gruppe wirklich verlassen?')) return
    setLeaving(true)
    // Optimistic update
    setIsMember(false)
    const supabase = createClient()
    const { error } = await supabase.from('group_members').delete()
      .eq('group_id', groupId).eq('user_id', userId)
    setLeaving(false)
    if (error) {
      setIsMember(true) // revert
      toast.error('Fehler beim Verlassen')
      return
    }
    toast.success('Gruppe verlassen')
    loadData()
  }

  const handleCreatePost = async () => {
    if (!newPost.trim() || !userId) return
    setPosting(true)
    const supabase = createClient()
    const { error } = await supabase.from('group_posts').insert({
      group_id: groupId,
      user_id: userId,
      content: newPost.trim(),
    })
    if (error) {
      toast.error('Fehler beim Posten: ' + error.message)
    } else {
      toast.success('Beitrag veröffentlicht')
      setNewPost('')
      loadData()
    }
    setPosting(false)
  }

  const handleDeletePost = async (postId: string) => {
    if (!confirm('Beitrag löschen?')) return
    const supabase = createClient()
    await supabase.from('group_posts').delete().eq('id', postId)
    toast.success('Beitrag gelöscht')
    setPosts(prev => prev.filter(p => p.id !== postId))
  }

  // ── Loading state ──────────────────────────────────────────────
  if (loading) {
    return (
      <div className="max-w-5xl mx-auto">
        {/* Hero skeleton */}
        <div className="h-52 bg-gray-200 rounded-2xl animate-pulse mb-6" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="md:col-span-2 space-y-4">
            {[1, 2, 3].map(i => <div key={i} className="h-32 bg-gray-100 rounded-2xl animate-pulse" />)}
          </div>
          <div className="space-y-4">
            <div className="h-48 bg-gray-100 rounded-2xl animate-pulse" />
            <div className="h-28 bg-gray-100 rounded-2xl animate-pulse" />
          </div>
        </div>
      </div>
    )
  }

  if (!group) {
    return (
      <div className="text-center py-24">
        <div className="text-5xl mb-4">🔍</div>
        <p className="text-gray-700 font-bold text-lg">Gruppe nicht gefunden</p>
        <Link href="/dashboard/groups" className="mt-3 inline-block text-sm text-primary-600 hover:text-primary-700 font-medium">
          ← Zurück zu allen Gruppen
        </Link>
      </div>
    )
  }

  const cat = getCat(group.category)
  const isPrivate = group.is_private || group.is_public === false
  const isAdmin = myRole === 'admin' || (group.creator_id || group.created_by) === userId
  const visibleMembers = members.slice(0, 12)

  return (
    <div className="max-w-5xl mx-auto">
      {/* Back link */}
      <Link href="/dashboard/groups" className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-primary-600 transition-colors mb-4 font-medium">
        <ArrowLeft className="w-4 h-4" /> Alle Gruppen
      </Link>

      {/* ── Hero Banner ──────────────────────────────────────────── */}
      <div className={cn('relative rounded-2xl overflow-hidden mb-6 bg-gradient-to-br', cat.color)}>
        {/* Background decoration */}
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-4 right-8 text-[120px] leading-none select-none">{cat.emoji}</div>
        </div>

        <div className="relative p-6 sm:p-8">
          <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div className="flex-1 min-w-0">
              {/* Badges row */}
              <div className="flex flex-wrap items-center gap-2 mb-3">
                <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-white/20 backdrop-blur-sm rounded-full text-xs font-medium text-white">
                  {cat.emoji} {cat.label}
                </span>
                {isPrivate ? (
                  <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-black/20 backdrop-blur-sm rounded-full text-xs font-medium text-white">
                    <Lock className="w-3 h-3" /> Privat
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-white/10 backdrop-blur-sm rounded-full text-xs font-medium text-white">
                    <Globe className="w-3 h-3" /> Öffentlich
                  </span>
                )}
                {isMember && (
                  <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-white/25 backdrop-blur-sm rounded-full text-xs font-semibold text-white">
                    ✓ Mitglied
                  </span>
                )}
              </div>

              <h1 className="text-2xl sm:text-3xl font-bold text-white mb-2 leading-tight">{group.name}</h1>
              {group.description && (
                <p className="text-white/80 text-sm leading-relaxed max-w-lg">{group.description}</p>
              )}

              {/* Stats */}
              <div className="flex flex-wrap items-center gap-4 mt-4 text-sm text-white/80">
                <span className="flex items-center gap-1.5">
                  <Users className="w-4 h-4" />
                  <strong className="text-white">{members.length}</strong> Mitglieder
                </span>
                <span className="flex items-center gap-1.5">
                  <MessageCircle className="w-4 h-4" />
                  <strong className="text-white">{posts.length}</strong> Beiträge
                </span>
                <span className="flex items-center gap-1.5">
                  <Calendar className="w-4 h-4" />
                  Seit {formatDate(group.created_at)}
                </span>
              </div>
            </div>

            {/* Join / Leave CTA */}
            <div className="flex-shrink-0">
              {isMember ? (
                <button
                  onClick={handleLeave}
                  disabled={leaving}
                  className="flex items-center gap-2 px-5 py-2.5 bg-white/20 hover:bg-white/30 backdrop-blur-sm text-white rounded-xl text-sm font-semibold transition-all disabled:opacity-60 border border-white/30"
                >
                  {leaving ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserMinus className="w-4 h-4" />}
                  {leaving ? 'Wird verlassen...' : 'Verlassen'}
                </button>
              ) : (
                <button
                  onClick={handleJoin}
                  disabled={joining}
                  className="flex items-center gap-2 px-5 py-2.5 bg-white text-primary-700 rounded-xl text-sm font-semibold hover:bg-primary-50 transition-all shadow-lg disabled:opacity-60 active:scale-95"
                >
                  {joining ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserPlus className="w-4 h-4" />}
                  {joining ? 'Beitreten...' : 'Gruppe beitreten'}
                </button>
              )}
            </div>
          </div>

          {/* Member avatars strip */}
          {members.length > 0 && (
            <div className="flex items-center gap-2 mt-5 pt-5 border-t border-white/20">
              <div className="flex -space-x-2">
                {visibleMembers.slice(0, 8).map(m => (
                  <Avatar
                    key={m.user_id}
                    name={(m.profiles as { name?: string | null })?.name}
                    avatarUrl={(m.profiles as { avatar_url?: string | null })?.avatar_url}
                    size="sm"
                  />
                ))}
              </div>
              {members.length > 8 && (
                <span className="text-xs text-white/70 font-medium ml-1">
                  +{members.length - 8} weitere
                </span>
              )}
              {members.length <= 8 && (
                <span className="text-xs text-white/70 ml-1">
                  {members.length === 1 ? '1 Mitglied' : `${members.length} Mitglieder`}
                </span>
              )}
            </div>
          )}
        </div>
      </div>

      {/* ── Content ──────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* ── Posts Column ─────────────────────────────────────── */}
        <div className="md:col-span-2 space-y-4">
          {/* New Post Input */}
          {isMember ? (
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
              <div className="flex gap-3">
                <div className="flex-shrink-0 mt-0.5">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-400 to-teal-500 flex items-center justify-center text-white text-xs font-bold">
                    Du
                  </div>
                </div>
                <div className="flex-1">
                  <textarea
                    value={newPost}
                    onChange={e => setNewPost(e.target.value)}
                    placeholder="Schreibe einen Beitrag für die Gruppe..."
                    rows={3}
                    className="w-full px-0 py-1 text-sm text-gray-700 placeholder-gray-400 bg-transparent border-none resize-none outline-none leading-relaxed"
                    maxLength={2000}
                    onKeyDown={e => {
                      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey) && newPost.trim()) {
                        handleCreatePost()
                      }
                    }}
                  />
                  <div className="flex items-center justify-between mt-2 pt-2 border-t border-gray-100">
                    <span className="text-xs text-gray-400">
                      {newPost.length > 0 ? `${newPost.length}/2000` : 'Ctrl+Enter zum Posten'}
                    </span>
                    <button
                      onClick={handleCreatePost}
                      disabled={posting || !newPost.trim()}
                      className="flex items-center gap-1.5 px-4 py-1.5 bg-primary-600 text-white rounded-xl text-xs font-semibold hover:bg-primary-700 disabled:opacity-50 transition-all active:scale-95"
                    >
                      {posting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
                      Posten
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="bg-primary-50 border border-primary-100 rounded-2xl p-4 text-center">
              <p className="text-sm text-primary-700 font-medium mb-2">
                Tritt der Gruppe bei, um Beiträge zu schreiben
              </p>
              <button
                onClick={handleJoin}
                disabled={joining}
                className="inline-flex items-center gap-1.5 px-4 py-2 bg-primary-600 text-white rounded-xl text-xs font-semibold hover:bg-primary-700 transition-all disabled:opacity-60"
              >
                {joining ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <UserPlus className="w-3.5 h-3.5" />}
                Jetzt beitreten
              </button>
            </div>
          )}

          {/* Posts List – grouped by day */}
          {posts.length === 0 ? (
            <div className="text-center py-14 bg-white rounded-2xl border border-gray-100 shadow-sm">
              <MessageCircle className="w-10 h-10 text-gray-200 mx-auto mb-3" />
              <p className="text-gray-500 font-medium text-sm">Noch keine Beiträge</p>
              {isMember && (
                <p className="text-xs text-gray-400 mt-1">Sei der Erste und schreibe etwas!</p>
              )}
            </div>
          ) : (
            (() => {
              const today = new Date(); today.setHours(0, 0, 0, 0)
              const yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1)
              const weekAgo = new Date(today); weekAgo.setDate(weekAgo.getDate() - 7)
              const labelFor = (d: Date) => {
                const norm = new Date(d); norm.setHours(0, 0, 0, 0)
                if (norm.getTime() === today.getTime()) return 'Heute'
                if (norm.getTime() === yesterday.getTime()) return 'Gestern'
                if (norm.getTime() >= weekAgo.getTime()) return 'Diese Woche'
                return d.toLocaleDateString('de-AT', { month: 'long', year: 'numeric' })
              }
              const groups: { key: string; label: string; items: typeof posts }[] = []
              posts.forEach(p => {
                const label = labelFor(new Date(p.created_at))
                const existing = groups.find(g => g.key === label)
                if (existing) existing.items.push(p)
                else groups.push({ key: label, label, items: [p] })
              })
              return groups.map(g => (
                <div key={g.key} className="space-y-4">
                  <div className="flex items-center gap-3 pt-2">
                    <div className="h-px flex-1 bg-gradient-to-r from-transparent via-stone-200 to-stone-200" />
                    <span className="text-[11px] font-bold uppercase tracking-wider text-ink-400">
                      {g.label}
                    </span>
                    <div className="h-px flex-1 bg-gradient-to-l from-transparent via-stone-200 to-stone-200" />
                  </div>
                  {g.items.map(post => {
                    const poster = post.profiles as { name?: string | null; avatar_url?: string | null } | undefined
                    return (
                      <div key={post.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 hover:border-primary-100 transition-colors">
                        <div className="flex items-start gap-3">
                          <Avatar name={poster?.name} avatarUrl={poster?.avatar_url} size="md" />
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between gap-2">
                              <div>
                                <span className="text-sm font-semibold text-gray-900">{poster?.name ?? 'Unbekannt'}</span>
                                {post.user_id === (group.creator_id || group.created_by) && (
                                  <span className="ml-1.5 inline-flex items-center gap-0.5 px-1.5 py-0.5 bg-amber-50 border border-amber-200 rounded-full text-[9px] font-bold text-amber-600">
                                    <Crown className="w-2.5 h-2.5" /> Admin
                                  </span>
                                )}
                                <p className="text-xs text-gray-400">{formatDate(post.created_at)}</p>
                              </div>
                              {(post.user_id === userId || isAdmin) && (
                                <button
                                  onClick={() => handleDeletePost(post.id)}
                                  className="flex-shrink-0 p-1.5 hover:bg-red-50 rounded-lg text-gray-300 hover:text-red-400 transition-colors"
                                >
                                  <Trash2 className="w-3.5 h-3.5" />
                                </button>
                              )}
                            </div>
                            <p className="text-sm text-gray-700 mt-2 whitespace-pre-wrap leading-relaxed">{post.content}</p>
                          </div>
                        </div>
                      </div>
                    )
                  })}
                </div>
              ))
            })()
          )}
        </div>

        {/* ── Sidebar ──────────────────────────────────────────── */}
        <div className="space-y-4">
          {/* Members Card */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
            <h3 className="font-bold text-gray-900 text-sm mb-3 flex items-center gap-2">
              <Users className="w-4 h-4 text-primary-600" />
              Mitglieder
              <span className="ml-auto text-xs font-normal text-gray-400">{members.length}</span>
            </h3>
            <div className="space-y-2.5 max-h-72 overflow-y-auto pr-1">
              {members.map(m => {
                const profile = m.profiles as { name?: string | null; avatar_url?: string | null } | undefined
                return (
                  <div key={m.user_id} className="flex items-center gap-2.5">
                    <Avatar name={profile?.name} avatarUrl={profile?.avatar_url} size="sm" />
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-medium text-gray-800 truncate">{profile?.name ?? 'Unbekannt'}</p>
                    </div>
                    {m.role === 'admin' && <Crown className="w-3.5 h-3.5 text-amber-500 flex-shrink-0" title="Admin" />}
                    {m.role === 'moderator' && <Shield className="w-3.5 h-3.5 text-blue-500 flex-shrink-0" title="Moderator" />}
                  </div>
                )
              })}
            </div>
          </div>

          {/* Private Threads */}
          <GroupPrivateThreads groupId={groupId} currentUserId={userId} isMember={isMember} />

          {/* Group Info Card */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
            <h3 className="font-bold text-gray-900 text-sm mb-3">Über diese Gruppe</h3>
            <div className="space-y-2.5">
              <div className="flex items-start gap-2.5 text-xs">
                <Tag className="w-3.5 h-3.5 text-gray-400 mt-0.5 flex-shrink-0" />
                <div>
                  <span className="text-gray-500">Kategorie</span>
                  <p className="font-medium text-gray-800 capitalize mt-0.5">{cat.emoji} {cat.label}</p>
                </div>
              </div>
              <div className="flex items-start gap-2.5 text-xs">
                <Globe className="w-3.5 h-3.5 text-gray-400 mt-0.5 flex-shrink-0" />
                <div>
                  <span className="text-gray-500">Sichtbarkeit</span>
                  <p className="font-medium text-gray-800 mt-0.5">
                    {isPrivate ? '🔒 Privat (Einladung)' : '🌍 Öffentlich'}
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-2.5 text-xs">
                <Calendar className="w-3.5 h-3.5 text-gray-400 mt-0.5 flex-shrink-0" />
                <div>
                  <span className="text-gray-500">Erstellt am</span>
                  <p className="font-medium text-gray-800 mt-0.5">{formatDate(group.created_at)}</p>
                </div>
              </div>
            </div>
          </div>

          {/* Not a member CTA (sidebar) */}
          {!isMember && (
            <div className={cn('rounded-2xl p-4 bg-gradient-to-br text-white text-center', cat.color)}>
              <p className="text-2xl mb-2">{cat.emoji}</p>
              <p className="font-bold text-sm mb-1">Noch kein Mitglied?</p>
              <p className="text-xs text-white/80 mb-3">Tritt der Gruppe bei und nimm am Austausch teil</p>
              <button
                onClick={handleJoin}
                disabled={joining}
                className="w-full py-2 bg-white text-gray-800 rounded-xl text-xs font-semibold hover:bg-gray-50 transition-all disabled:opacity-60 flex items-center justify-center gap-1.5"
              >
                {joining ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <UserPlus className="w-3.5 h-3.5" />}
                {joining ? 'Beitreten...' : 'Jetzt beitreten'}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
