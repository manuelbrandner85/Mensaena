'use client'

import { useState, useEffect, useCallback, use, useRef } from 'react'
import {
  ArrowLeft, Users, Lock, Globe, Plus, Send, Loader2,
  Crown, Shield, MessageCircle, Trash2, UserPlus, UserMinus,
  Calendar, Tag, Camera, Pencil, X, Share2, Search,
} from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { cn, formatDate } from '@/lib/utils'
import toast from 'react-hot-toast'
import GroupPrivateThreads from '@/components/features/GroupPrivateThreads'
import ConfirmDialog from '@/app/dashboard/admin/components/ConfirmDialog'

// ── Category Config ─────────────────────────────────────────────
const CAT_CONFIG: Record<string, { emoji: string; label: string; color: string }> = {
  nachbarschaft: { emoji: '🏘️', label: 'Nachbarschaft',       color: 'from-blue-400 to-blue-600' },
  hobby:         { emoji: '🎨', label: 'Hobby & Freizeit',    color: 'from-pink-400 to-rose-500' },
  sport:         { emoji: '⚽', label: 'Sport & Fitness',     color: 'from-orange-400 to-orange-600' },
  eltern:        { emoji: '👶', label: 'Eltern & Familie',    color: 'from-yellow-400 to-amber-500' },
  senioren:      { emoji: '🧓', label: 'Senioren',            color: 'from-purple-400 to-purple-600' },
  umwelt:        { emoji: '🌿', label: 'Umwelt',              color: 'from-primary-400 to-primary-600' },
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
  avatar_url?: string | null
  banner_url?: string | null
}

type Reactions = Record<string, { count: number; userReacted: boolean }>

interface GroupPost {
  id: string
  content: string
  user_id: string
  created_at: string
  image_url?: string | null
  is_pinned: boolean
  profiles?: { name: string | null; avatar_url: string | null }
  reactions: Reactions
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
  const [bannerUploading, setBannerUploading] = useState(false)
  const [avatarUploading, setAvatarUploading] = useState(false)
  const [newPostImage, setNewPostImage] = useState<File | null>(null)
  const [newPostImagePreview, setNewPostImagePreview] = useState<string | null>(null)
  const [postImageUploading, setPostImageUploading] = useState(false)
  const [postSearch, setPostSearch] = useState('')
  const [confirmLeave, setConfirmLeave] = useState(false)
  const [confirmDeletePostId, setConfirmDeletePostId] = useState<string | null>(null)
  const [editingPostId, setEditingPostId] = useState<string | null>(null)
  const [editContent, setEditContent] = useState('')
  const [editSaving, setEditSaving] = useState(false)
  const bannerInputRef = useRef<HTMLInputElement>(null)
  const avatarInputRef = useRef<HTMLInputElement>(null)
  const postImageInputRef = useRef<HTMLInputElement>(null)

  const handleImageUpload = async (
    file: File,
    type: 'banner' | 'avatar',
    setUploading: (v: boolean) => void,
  ) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp']
    if (!allowed.includes(file.type)) { toast.error('Nur JPEG, PNG oder WebP erlaubt'); return }
    if (file.size > 8 * 1024 * 1024) { toast.error('Bild max. 8 MB'); return }
    setUploading(true)
    try {
      const supabase = createClient()
      const ext = file.name.split('.').pop() || 'jpg'
      const path = `groups/${groupId}/${type}.${ext}`
      const { error: upErr } = await supabase.storage
        .from('post-images')
        .upload(path, file, { cacheControl: '3600', upsert: true })
      if (upErr) throw upErr
      const { data } = supabase.storage.from('post-images').getPublicUrl(path)
      const col = type === 'banner' ? 'banner_url' : 'avatar_url'
      const { error: dbErr } = await supabase
        .from('groups')
        .update({ [col]: data.publicUrl })
        .eq('id', groupId)
      if (dbErr) throw dbErr
      setGroup((prev) => prev ? { ...prev, [col]: data.publicUrl } : prev)
      toast.success(type === 'banner' ? 'Banner aktualisiert' : 'Avatar aktualisiert')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Upload fehlgeschlagen')
    } finally {
      setUploading(false)
    }
  }

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)

    // BUG FIX: Embedded profile-Joins (`profiles:user_id(...)`) wurden durch
    // PostgREST/RLS gefiltert → group_members lieferte 0 Zeilen, obwohl der
    // User Mitglied war. Lösung: Queries splitten und Profile manuell mergen.
    const [groupRes, rawMembersRes] = await Promise.all([
      supabase.from('groups').select('*').eq('id', groupId).maybeSingle(),
      supabase
        .from('group_members')
        .select('user_id, role, joined_at')
        .eq('group_id', groupId)
        .order('joined_at', { ascending: true }),
    ])

    // Fetch posts with image_url; fall back if column doesn't exist yet
    let rawPostsRes = await supabase
      .from('group_posts')
      .select('id, content, user_id, created_at, image_url')
      .eq('group_id', groupId)
      .order('created_at', { ascending: false })
      .limit(50)
    if (rawPostsRes.error?.message?.includes('image_url')) {
      rawPostsRes = await supabase
        .from('group_posts')
        .select('id, content, user_id, created_at')
        .eq('group_id', groupId)
        .order('created_at', { ascending: false })
        .limit(50)
    }

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

    // Fetch reactions for all posts
    const postIds = (rawPostsRes.data ?? []).map(p => (p as Record<string, unknown>).id as string)
    const reactionsMap = new Map<string, Reactions>()
    if (postIds.length > 0) {
      const { data: reactionsData } = await supabase
        .from('group_post_reactions')
        .select('post_id, user_id, emoji')
        .in('post_id', postIds)
      for (const r of (reactionsData ?? [])) {
        if (!reactionsMap.has(r.post_id)) reactionsMap.set(r.post_id, {})
        const pr = reactionsMap.get(r.post_id)!
        if (!pr[r.emoji]) pr[r.emoji] = { count: 0, userReacted: false }
        pr[r.emoji].count++
        if (r.user_id === user?.id) pr[r.emoji].userReacted = true
      }
    }

    // Posts anreichern
    const enrichedPosts: GroupPost[] = (rawPostsRes.data ?? []).map(p => ({
      id: (p as Record<string, unknown>).id as string,
      content: (p as Record<string, unknown>).content as string,
      user_id: (p as Record<string, unknown>).user_id as string,
      created_at: (p as Record<string, unknown>).created_at as string,
      image_url: ((p as Record<string, unknown>).image_url as string | null) ?? null,
      is_pinned: ((p as Record<string, unknown>).is_pinned as boolean) ?? false,
      profiles: profileMap.get((p as Record<string, unknown>).user_id as string) ?? { name: null, avatar_url: null },
      reactions: reactionsMap.get((p as Record<string, unknown>).id as string) ?? {},
    }))
    // Pinned posts float to the top, preserve date order within each group
    enrichedPosts.sort((a, b) => Number(b.is_pinned) - Number(a.is_pinned))
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

  const handleLeave = () => {
    if (!userId || !group) return
    const creatorId = group.creator_id || group.created_by
    if (creatorId === userId) { toast.error('Als Ersteller kannst du die Gruppe nicht verlassen'); return }
    setConfirmLeave(true)
  }

  const handleConfirmLeave = async () => {
    setConfirmLeave(false)
    if (!userId || !group) return
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
    if (!newPost.trim() && !newPostImage) return
    if (!userId) return
    setPosting(true)

    let imageUrl: string | null = null
    if (newPostImage) {
      setPostImageUploading(true)
      try {
        const supabase = createClient()
        const ext = newPostImage.name.split('.').pop() || 'jpg'
        const path = `group-posts/${groupId}/${Date.now()}.${ext}`
        const { error: upErr } = await supabase.storage
          .from('post-images')
          .upload(path, newPostImage, { cacheControl: '3600', upsert: false })
        if (upErr) throw upErr
        const { data: urlData } = supabase.storage.from('post-images').getPublicUrl(path)
        imageUrl = urlData.publicUrl
      } catch {
        toast.error('Bild konnte nicht hochgeladen werden')
        setPosting(false)
        setPostImageUploading(false)
        return
      }
      setPostImageUploading(false)
    }

    const supabase = createClient()
    const insertPayload: Record<string, unknown> = {
      group_id: groupId,
      user_id: userId,
      content: newPost.trim(),
    }
    if (imageUrl) insertPayload.image_url = imageUrl

    const { error } = await supabase.from('group_posts').insert(insertPayload)
    if (error) {
      toast.error('Fehler beim Posten: ' + error.message)
    } else {
      toast.success('Beitrag veröffentlicht')
      setNewPost('')
      setNewPostImage(null)
      setNewPostImagePreview(null)
      loadData()
    }
    setPosting(false)
  }

  const handleDeletePost = (postId: string) => { setConfirmDeletePostId(postId) }

  const handleConfirmDeletePost = async () => {
    const postId = confirmDeletePostId
    setConfirmDeletePostId(null)
    if (!postId) return
    const post = posts.find(p => p.id === postId)
    const supabase = createClient()
    await supabase.from('group_posts').delete().eq('id', postId)
    if (post?.image_url) {
      try {
        const url = new URL(post.image_url)
        const match = url.pathname.match(/\/post-images\/(.+)$/)
        if (match?.[1]) await supabase.storage.from('post-images').remove([decodeURIComponent(match[1])])
      } catch { /* ignore storage cleanup errors */ }
    }
    toast.success('Beitrag gelöscht')
    setPosts(prev => prev.filter(p => p.id !== postId))
  }

  const handlePostImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 8 * 1024 * 1024) { toast.error('Bild max. 8 MB'); return }
    if (!file.type.startsWith('image/')) { toast.error('Nur Bilddateien erlaubt'); return }
    setNewPostImage(file)
    setNewPostImagePreview(URL.createObjectURL(file))
    e.target.value = ''
  }

  const handleStartEdit = (post: GroupPost) => {
    setEditingPostId(post.id)
    setEditContent(post.content)
  }

  const handleSaveEdit = async (postId: string) => {
    if (!editContent.trim()) return
    setEditSaving(true)
    const supabase = createClient()
    const { error } = await supabase.from('group_posts')
      .update({ content: editContent.trim() })
      .eq('id', postId)
    if (error) {
      toast.error('Fehler beim Speichern: ' + error.message)
    } else {
      setPosts(prev => prev.map(p => p.id === postId ? { ...p, content: editContent.trim() } : p))
      setEditingPostId(null)
      toast.success('Beitrag aktualisiert')
    }
    setEditSaving(false)
  }

  const handleCancelEdit = () => {
    setEditingPostId(null)
    setEditContent('')
  }

  const REACTION_EMOJIS = ['👍', '❤️', '😂', '👏']

  const handleReaction = async (postId: string, emoji: string) => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    const post = posts.find(p => p.id === postId)
    if (!post) return
    const hasReacted = post.reactions[emoji]?.userReacted ?? false

    // Optimistic update
    setPosts(prev => prev.map(p => {
      if (p.id !== postId) return p
      const cur = p.reactions[emoji] ?? { count: 0, userReacted: false }
      return {
        ...p,
        reactions: {
          ...p.reactions,
          [emoji]: { count: Math.max(0, cur.count + (hasReacted ? -1 : 1)), userReacted: !hasReacted },
        },
      }
    }))

    const supabase = createClient()
    if (hasReacted) {
      await supabase.from('group_post_reactions')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .eq('emoji', emoji)
    } else {
      await supabase.from('group_post_reactions')
        .insert({ post_id: postId, user_id: userId, emoji })
    }
  }

  const handleTogglePin = async (postId: string, currentPinned: boolean) => {
    setPosts(prev => prev
      .map(p => p.id === postId ? { ...p, is_pinned: !currentPinned } : p)
      .sort((a, b) => Number(b.is_pinned) - Number(a.is_pinned))
    )
    const supabase = createClient()
    await supabase.from('group_posts').update({ is_pinned: !currentPinned }).eq('id', postId)
    toast.success(!currentPinned ? 'Beitrag angepinnt' : 'Pin entfernt')
  }

  const handlePromoteMember = async (memberId: string, newRole: 'member' | 'moderator') => {
    setMembers(prev => prev.map(m => m.user_id === memberId ? { ...m, role: newRole } : m))
    const supabase = createClient()
    const { error } = await supabase
      .from('group_members')
      .update({ role: newRole })
      .eq('group_id', groupId)
      .eq('user_id', memberId)
    if (error) {
      setMembers(prev => prev.map(m => m.user_id === memberId
        ? { ...m, role: m.role === 'moderator' ? 'member' : 'moderator' } : m))
      toast.error('Fehler beim Aktualisieren der Rolle')
    } else {
      toast.success(newRole === 'moderator' ? 'Zum Moderator befördert' : 'Moderator-Rolle entfernt')
    }
  }

  const handleShareGroup = () => {
    const url = window.location.href
    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(url).then(() => toast.success('Link kopiert!'))
    } else {
      toast.success('Link: ' + url)
    }
  }

  const filteredPosts = postSearch.trim()
    ? posts.filter(p => {
        const q = postSearch.toLowerCase()
        const authorName = (p.profiles as { name?: string | null } | undefined)?.name ?? ''
        return p.content.toLowerCase().includes(q) || authorName.toLowerCase().includes(q)
      })
    : posts

  // ── Loading state ──────────────────────────────────────────────
  if (loading) {
    return (
      <div className="max-w-5xl mx-auto">
        {/* Hero skeleton */}
        <div className="h-52 bg-stone-200 rounded-2xl animate-pulse mb-6" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="md:col-span-2 space-y-4">
            {[1, 2, 3].map(i => <div key={i} className="h-32 bg-stone-100 rounded-2xl animate-pulse" />)}
          </div>
          <div className="space-y-4">
            <div className="h-48 bg-stone-100 rounded-2xl animate-pulse" />
            <div className="h-28 bg-stone-100 rounded-2xl animate-pulse" />
          </div>
        </div>
      </div>
    )
  }

  if (!group) {
    return (
      <div className="text-center py-24">
        <div className="text-5xl mb-4">🔍</div>
        <p className="text-ink-700 font-bold text-lg">Gruppe nicht gefunden</p>
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
      <Link href="/dashboard/groups" className="inline-flex items-center gap-1.5 text-sm text-ink-500 hover:text-primary-600 transition-colors mb-4 font-medium">
        <ArrowLeft className="w-4 h-4" /> Alle Gruppen
      </Link>

      {/* Hidden file inputs */}
      <input ref={bannerInputRef} type="file" accept="image/jpeg,image/png,image/webp" className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) handleImageUpload(f, 'banner', setBannerUploading); e.target.value = '' }} />
      <input ref={avatarInputRef} type="file" accept="image/jpeg,image/png,image/webp" className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) handleImageUpload(f, 'avatar', setAvatarUploading); e.target.value = '' }} />
      <input ref={postImageInputRef} type="file" accept="image/*" className="hidden" onChange={handlePostImageSelect} />

      {/* ── Hero Banner ──────────────────────────────────────────── */}
      <div className={cn('relative rounded-2xl overflow-hidden mb-6 shadow-card', group.banner_url ? 'bg-ink-900' : cn('bg-gradient-to-br', cat.color))}>
        {/* Banner image */}
        {group.banner_url && (
          <img src={group.banner_url} alt="" className="absolute inset-0 w-full h-full object-cover opacity-60"
            onError={(e) => { e.currentTarget.style.display = 'none' }} />
        )}
        {/* Noise grain */}
        {!group.banner_url && <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />}
        {/* Radial spotlight */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{ background: 'radial-gradient(circle at 15% 0%, rgba(255,255,255,0.22), transparent 55%)' }}
        />
        {/* Background decoration */}
        {!group.banner_url && (
          <div className="absolute inset-0 opacity-10">
            <div className="absolute top-4 right-8 text-[120px] leading-none select-none float-idle">{cat.emoji}</div>
          </div>
        )}
        {/* Admin upload buttons */}
        {isAdmin && (
          <div className="absolute top-3 right-3 flex gap-2 z-10">
            <button
              onClick={() => bannerInputRef.current?.click()}
              disabled={bannerUploading}
              className="flex items-center gap-1.5 px-2.5 py-1.5 bg-black/40 hover:bg-black/60 backdrop-blur-sm text-white rounded-lg text-xs font-medium transition"
              title="Banner ändern"
            >
              {bannerUploading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Camera className="w-3.5 h-3.5" />}
              Banner
            </button>
          </div>
        )}

        <div className="relative p-6 sm:p-8">
          <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div className="flex-1 min-w-0">
              {/* Group avatar */}
              <div className="flex items-center gap-3 mb-3">
                <div className="relative flex-shrink-0">
                  {group.avatar_url ? (
                    <img src={group.avatar_url} alt={group.name}
                      className="w-14 h-14 rounded-2xl object-cover border-2 border-white/40 shadow-lg"
                      onError={(e) => { e.currentTarget.style.display = 'none' }} />
                  ) : (
                    <div className="w-14 h-14 rounded-2xl bg-white/20 backdrop-blur-sm flex items-center justify-center text-3xl border-2 border-white/30">
                      {cat.emoji}
                    </div>
                  )}
                  {isAdmin && (
                    <button
                      onClick={() => avatarInputRef.current?.click()}
                      disabled={avatarUploading}
                      className="absolute -bottom-1 -right-1 p-1 bg-white rounded-full shadow border border-stone-200 hover:bg-stone-50 transition"
                      title="Avatar ändern"
                    >
                      {avatarUploading ? <Loader2 className="w-3 h-3 animate-spin text-ink-500" /> : <Camera className="w-3 h-3 text-ink-500" />}
                    </button>
                  )}
                </div>
              </div>
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

            {/* Join / Leave CTA + Share */}
            <div className="flex-shrink-0 flex items-center gap-2">
              <button
                onClick={handleShareGroup}
                className="p-2.5 bg-white/20 hover:bg-white/30 backdrop-blur-sm text-white rounded-xl transition-all border border-white/30"
                title="Link teilen"
              >
                <Share2 className="w-4 h-4" />
              </button>
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
                  className="shine flex items-center gap-2 px-5 py-2.5 bg-white text-primary-700 rounded-xl text-sm font-semibold hover:bg-primary-50 transition-all shadow-lg disabled:opacity-60 active:scale-95"
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
            <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4">
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
                    className="w-full px-0 py-1 text-sm text-ink-700 placeholder-ink-400 bg-transparent border-none resize-none outline-none focus:ring-2 focus:ring-primary-300 focus:border-primary-500 leading-relaxed"
                    maxLength={2000}
                    onKeyDown={e => {
                      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey) && (newPost.trim() || newPostImage)) {
                        handleCreatePost()
                      }
                    }}
                  />
                  {/* Image preview */}
                  {newPostImagePreview && (
                    <div className="relative inline-block mt-2">
                      <img src={newPostImagePreview} alt="" className="max-h-32 rounded-xl border border-stone-200 object-cover" />
                      <button
                        onClick={() => { setNewPostImage(null); setNewPostImagePreview(null) }}
                        className="absolute -top-1.5 -right-1.5 w-5 h-5 bg-ink-700 rounded-full flex items-center justify-center hover:bg-red-500 transition-colors"
                      >
                        <X className="w-3 h-3 text-white" />
                      </button>
                    </div>
                  )}
                  <div className="flex items-center justify-between mt-2 pt-2 border-t border-stone-100">
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => postImageInputRef.current?.click()}
                        disabled={posting}
                        className="p-1.5 rounded-lg text-ink-400 hover:text-primary-600 hover:bg-primary-50 transition-colors"
                        title="Bild hinzufügen"
                      >
                        {postImageUploading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Camera className="w-4 h-4" />}
                      </button>
                      <span className="text-xs text-ink-400">
                        {newPost.length > 0 ? `${newPost.length}/2000` : 'Ctrl+Enter zum Posten'}
                      </span>
                    </div>
                    <button
                      onClick={handleCreatePost}
                      disabled={posting || (!newPost.trim() && !newPostImage)}
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

          {/* Post search */}
          {posts.length > 0 && (
            <div className="relative">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-ink-400" />
              <input
                value={postSearch}
                onChange={e => setPostSearch(e.target.value)}
                placeholder="Beiträge durchsuchen..."
                className="input pl-9 py-2 text-sm w-full"
              />
              {postSearch && (
                <button onClick={() => setPostSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 p-0.5 hover:bg-stone-100 rounded">
                  <X className="w-3.5 h-3.5 text-ink-400" />
                </button>
              )}
            </div>
          )}

          {/* Posts List – grouped by day */}
          {filteredPosts.length === 0 ? (
            <div className="text-center py-14 bg-white rounded-2xl border border-stone-100 shadow-sm">
              <MessageCircle className="w-10 h-10 text-stone-300 mx-auto mb-3" />
              <p className="text-ink-500 font-medium text-sm">
                {postSearch ? `Keine Beiträge für „${postSearch}"` : 'Noch keine Beiträge'}
              </p>
              {isMember && !postSearch && (
                <p className="text-xs text-ink-400 mt-1">Sei der Erste und schreibe etwas!</p>
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
              const groups: { key: string; label: string; items: typeof filteredPosts }[] = []
              filteredPosts.forEach(p => {
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
                      <div key={post.id} className={cn('bg-white rounded-2xl border shadow-sm p-4 hover:border-primary-100 transition-colors', post.is_pinned ? 'border-amber-200 bg-amber-50/30' : 'border-stone-100')}>
                        {post.is_pinned && (
                          <div className="flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider text-amber-600 mb-2">
                            📌 Angepinnt
                          </div>
                        )}
                        <div className="flex items-start gap-3">
                          <Avatar name={poster?.name} avatarUrl={poster?.avatar_url} size="md" />
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between gap-2">
                              <div>
                                <span className="text-sm font-semibold text-ink-900">{poster?.name ?? 'Unbekannt'}</span>
                                {post.user_id === (group.creator_id || group.created_by) && (
                                  <span className="ml-1.5 inline-flex items-center gap-0.5 px-1.5 py-0.5 bg-amber-50 border border-amber-200 rounded-full text-[9px] font-bold text-amber-600">
                                    <Crown className="w-2.5 h-2.5" /> Admin
                                  </span>
                                )}
                                <p className="text-xs text-ink-400">{formatDate(post.created_at)}</p>
                              </div>
                              <div className="flex items-center gap-1 flex-shrink-0">
                                {isAdmin && editingPostId !== post.id && (
                                  <button
                                    onClick={() => handleTogglePin(post.id, post.is_pinned)}
                                    className={cn('p-1.5 rounded-lg transition-colors text-xs', post.is_pinned ? 'text-amber-500 hover:bg-amber-50' : 'text-stone-400 hover:bg-amber-50 hover:text-amber-500')}
                                    title={post.is_pinned ? 'Pin entfernen' : 'Anpinnen'}
                                  >
                                    📌
                                  </button>
                                )}
                                {post.user_id === userId && editingPostId !== post.id && (
                                  <button
                                    onClick={() => handleStartEdit(post)}
                                    className="p-1.5 hover:bg-primary-50 rounded-lg text-stone-400 hover:text-primary-500 transition-colors"
                                    title="Bearbeiten"
                                  >
                                    <Pencil className="w-3.5 h-3.5" />
                                  </button>
                                )}
                                {(post.user_id === userId || isAdmin) && (
                                  <button
                                    onClick={() => handleDeletePost(post.id)}
                                    className="p-1.5 hover:bg-red-50 rounded-lg text-stone-400 hover:text-red-400 transition-colors"
                                    title="Löschen"
                                  >
                                    <Trash2 className="w-3.5 h-3.5" />
                                  </button>
                                )}
                              </div>
                            </div>
                            {editingPostId === post.id ? (
                              <div className="mt-2">
                                <textarea
                                  value={editContent}
                                  onChange={e => setEditContent(e.target.value)}
                                  className="w-full text-sm text-ink-700 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 resize-none outline-none focus:border-primary-300 focus:ring-1 focus:ring-primary-100 leading-relaxed"
                                  rows={3}
                                  maxLength={2000}
                                  autoFocus
                                />
                                <div className="flex items-center justify-end gap-2 mt-2">
                                  <button
                                    onClick={handleCancelEdit}
                                    disabled={editSaving}
                                    className="px-3 py-1.5 rounded-lg text-xs font-medium text-ink-500 hover:bg-stone-100 transition-colors"
                                  >
                                    Abbrechen
                                  </button>
                                  <button
                                    onClick={() => handleSaveEdit(post.id)}
                                    disabled={editSaving || !editContent.trim()}
                                    className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-semibold bg-primary-600 text-white hover:bg-primary-700 disabled:opacity-50 transition-all"
                                  >
                                    {editSaving && <Loader2 className="w-3 h-3 animate-spin" />}
                                    Speichern
                                  </button>
                                </div>
                              </div>
                            ) : (
                              <>
                                <p className="text-sm text-ink-700 mt-2 whitespace-pre-wrap leading-relaxed">{post.content}</p>
                                {post.image_url && (
                                  // eslint-disable-next-line @next/next/no-img-element
                                  <img src={post.image_url} alt="" className="mt-2 max-w-full max-h-64 rounded-xl border border-stone-100 object-contain"
                                    onError={e => { e.currentTarget.style.display = 'none' }} />
                                )}
                                {/* Reactions */}
                                <div className="flex items-center gap-1 mt-2.5 flex-wrap">
                                  {REACTION_EMOJIS.map(emoji => {
                                    const r = post.reactions[emoji]
                                    const active = r?.userReacted ?? false
                                    return (
                                      <button
                                        key={emoji}
                                        onClick={() => handleReaction(post.id, emoji)}
                                        className={cn(
                                          'inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs transition-all border',
                                          active
                                            ? 'bg-primary-50 border-primary-200 text-primary-700 font-semibold'
                                            : 'bg-stone-50 border-stone-200 text-ink-500 hover:border-stone-300 hover:bg-stone-100',
                                        )}
                                      >
                                        {emoji}
                                        {r?.count ? <span className="font-medium">{r.count}</span> : null}
                                      </button>
                                    )
                                  })}
                                </div>
                              </>
                            )
                          }
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
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4">
            <h3 className="font-bold text-ink-900 text-sm mb-3 flex items-center gap-2">
              <Users className="w-4 h-4 text-primary-600" />
              Mitglieder
              <span className="ml-auto text-xs font-normal text-ink-400">{members.length}</span>
            </h3>
            <div className="space-y-2 max-h-72 overflow-y-auto pr-1">
              {members.map(m => {
                const profile = m.profiles as { name?: string | null; avatar_url?: string | null } | undefined
                const isCreator = m.user_id === (group.creator_id || group.created_by)
                return (
                  <div key={m.user_id} className="flex items-center gap-2">
                    <Avatar name={profile?.name} avatarUrl={profile?.avatar_url} size="sm" />
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-medium text-ink-800 truncate">{profile?.name ?? 'Unbekannt'}</p>
                      {m.role !== 'member' && (
                        <p className="text-[10px] text-ink-400 capitalize">{m.role === 'admin' ? 'Admin' : 'Moderator'}</p>
                      )}
                    </div>
                    {m.role === 'admin' && <Crown className="w-3.5 h-3.5 text-amber-500 flex-shrink-0" />}
                    {m.role === 'moderator' && <Shield className="w-3.5 h-3.5 text-blue-500 flex-shrink-0" />}
                    {isAdmin && !isCreator && m.user_id !== userId && (
                      <button
                        onClick={() => handlePromoteMember(m.user_id, m.role === 'moderator' ? 'member' : 'moderator')}
                        className={cn(
                          'flex-shrink-0 p-1 rounded-lg text-xs transition-colors',
                          m.role === 'moderator'
                            ? 'text-blue-500 hover:bg-blue-50'
                            : 'text-stone-400 hover:bg-stone-100 hover:text-blue-500',
                        )}
                        title={m.role === 'moderator' ? 'Moderator-Rolle entfernen' : 'Zum Moderator befördern'}
                      >
                        <Shield className="w-3 h-3" />
                      </button>
                    )}
                  </div>
                )
              })}
            </div>
          </div>

          {/* Private Threads */}
          <GroupPrivateThreads groupId={groupId} currentUserId={userId} isMember={isMember} />

          {/* Group Info Card */}
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4">
            <h3 className="font-bold text-ink-900 text-sm mb-3">Über diese Gruppe</h3>
            <div className="space-y-2.5">
              <div className="flex items-start gap-2.5 text-xs">
                <Tag className="w-3.5 h-3.5 text-ink-400 mt-0.5 flex-shrink-0" />
                <div>
                  <span className="text-ink-500">Kategorie</span>
                  <p className="font-medium text-ink-800 capitalize mt-0.5">{cat.emoji} {cat.label}</p>
                </div>
              </div>
              <div className="flex items-start gap-2.5 text-xs">
                <Globe className="w-3.5 h-3.5 text-ink-400 mt-0.5 flex-shrink-0" />
                <div>
                  <span className="text-ink-500">Sichtbarkeit</span>
                  <p className="font-medium text-ink-800 mt-0.5">
                    {isPrivate ? '🔒 Privat (Einladung)' : '🌍 Öffentlich'}
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-2.5 text-xs">
                <Calendar className="w-3.5 h-3.5 text-ink-400 mt-0.5 flex-shrink-0" />
                <div>
                  <span className="text-ink-500">Erstellt am</span>
                  <p className="font-medium text-ink-800 mt-0.5">{formatDate(group.created_at)}</p>
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
                className="w-full py-2 bg-white text-ink-800 rounded-xl text-xs font-semibold hover:bg-stone-50 transition-all disabled:opacity-60 flex items-center justify-center gap-1.5"
              >
                {joining ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <UserPlus className="w-3.5 h-3.5" />}
                {joining ? 'Beitreten...' : 'Jetzt beitreten'}
              </button>
            </div>
          )}
        </div>
      </div>

      <ConfirmDialog
        open={confirmLeave}
        title="Gruppe verlassen"
        message="Möchtest du diese Gruppe wirklich verlassen?"
        confirmLabel="Verlassen"
        variant="warning"
        onConfirm={handleConfirmLeave}
        onCancel={() => setConfirmLeave(false)}
      />
      <ConfirmDialog
        open={!!confirmDeletePostId}
        title="Beitrag löschen"
        message="Diesen Beitrag wirklich löschen?"
        confirmLabel="Löschen"
        variant="danger"
        onConfirm={handleConfirmDeletePost}
        onCancel={() => setConfirmDeletePostId(null)}
      />
    </div>
  )
}
