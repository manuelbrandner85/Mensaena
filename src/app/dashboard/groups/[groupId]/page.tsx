'use client'

import { useState, useEffect, useCallback, use } from 'react'
import {
  ArrowLeft, Users, Lock, Globe, Plus, Send, Loader2,
  Crown, Shield, MessageCircle, Settings, Trash2,
} from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { cn, formatDate } from '@/lib/utils'
import toast from 'react-hot-toast'

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

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)

    // Load group
    const { data: groupData } = await supabase
      .from('groups')
      .select('*')
      .eq('id', groupId)
      .single()
    if (groupData) setGroup(groupData as Group)

    // Load posts
    const { data: postsData } = await supabase
      .from('group_posts')
      .select('id, content, user_id, created_at, profiles:user_id(name, avatar_url)')
      .eq('group_id', groupId)
      .order('created_at', { ascending: false })
      .limit(50)
    setPosts((postsData ?? []) as GroupPost[])

    // Load members
    const { data: membersData } = await supabase
      .from('group_members')
      .select('user_id, role, joined_at, profiles:user_id(name, avatar_url)')
      .eq('group_id', groupId)
      .order('joined_at', { ascending: true })
    setMembers((membersData ?? []) as Member[])

    // Check membership
    if (user) {
      const member = (membersData ?? []).find((m: any) => m.user_id === user.id)
      setIsMember(!!member)
      if (member) setMyRole((member as any).role)
    }

    setLoading(false)
  }, [groupId])

  useEffect(() => { loadData() }, [loadData])

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
      toast.success('Beitrag erstellt')
      setNewPost('')
      loadData()
    }
    setPosting(false)
  }

  const handleJoin = async () => {
    if (!userId) return
    const supabase = createClient()
    const { error } = await supabase.from('group_members').insert({
      group_id: groupId,
      user_id: userId,
      role: 'member',
    })
    if (error) {
      if (error.code === '23505') toast.error('Du bist bereits Mitglied dieser Gruppe')
      else toast.error('Fehler beim Beitreten: ' + error.message)
    } else {
      toast.success('Gruppe beigetreten!')
      loadData()
    }
  }

  const handleDeletePost = async (postId: string) => {
    if (!confirm('Beitrag löschen?')) return
    const supabase = createClient()
    await supabase.from('group_posts').delete().eq('id', postId)
    toast.success('Beitrag gelöscht')
    setPosts(prev => prev.filter(p => p.id !== postId))
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!group) {
    return (
      <div className="text-center py-16">
        <Users className="w-12 h-12 text-gray-300 mx-auto mb-3" />
        <p className="text-gray-500 font-medium">Gruppe nicht gefunden</p>
        <Link href="/dashboard/groups" className="mt-3 text-sm text-primary-600 hover:text-primary-700 font-medium">
          Zurück zu allen Gruppen
        </Link>
      </div>
    )
  }

  const isAdmin = myRole === 'admin' || (group.creator_id || group.created_by) === userId

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <Link href="/dashboard/groups" className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4">
        <ArrowLeft className="w-4 h-4" /> Zurück zu Gruppen
      </Link>

      <div className="bg-gradient-to-r from-primary-500 to-teal-600 rounded-2xl p-6 text-white mb-6">
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <h1 className="text-2xl font-bold">{group.name}</h1>
              {(group.is_private || group.is_public === false) ? <Lock className="w-5 h-5 opacity-80" /> : <Globe className="w-5 h-5 opacity-80" />}
            </div>
            {group.description && <p className="text-primary-100 text-sm mt-1">{group.description}</p>}
            <div className="flex items-center gap-4 mt-3 text-sm text-primary-100">
              <span className="flex items-center gap-1"><Users className="w-4 h-4" /> {members.length} Mitglieder</span>
              <span className="flex items-center gap-1"><MessageCircle className="w-4 h-4" /> {posts.length} Beiträge</span>
            </div>
          </div>
          {!isMember && (
            <button onClick={handleJoin}
              className="px-4 py-2 bg-white text-primary-700 rounded-xl text-sm font-medium hover:bg-primary-50 transition-all">
              Beitreten
            </button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Posts */}
        <div className="md:col-span-2 space-y-4">
          {/* New Post */}
          {isMember && (
            <div className="bg-white rounded-2xl border border-gray-100 p-4">
              <textarea
                value={newPost}
                onChange={e => setNewPost(e.target.value)}
                placeholder="Schreibe einen Beitrag..."
                rows={3}
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm resize-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                maxLength={2000}
              />
              <div className="flex justify-end mt-2">
                <button onClick={handleCreatePost} disabled={posting || !newPost.trim()}
                  className="flex items-center gap-2 px-4 py-2 bg-primary-600 text-white rounded-xl text-sm font-medium hover:bg-primary-700 disabled:opacity-50 transition-all">
                  {posting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                  Posten
                </button>
              </div>
            </div>
          )}

          {/* Posts list */}
          {posts.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-2xl border border-gray-100">
              <MessageCircle className="w-8 h-8 text-gray-300 mx-auto mb-2" />
              <p className="text-gray-500 text-sm">Noch keine Beiträge</p>
            </div>
          ) : (
            posts.map(post => (
              <div key={post.id} className="bg-white rounded-2xl border border-gray-100 p-4">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-2 mb-2">
                    <div className="w-8 h-8 rounded-full bg-primary-100 flex items-center justify-center text-xs font-bold text-primary-700">
                      {((post.profiles as any)?.name ?? 'U').charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-900">{(post.profiles as any)?.name ?? 'Unbekannt'}</p>
                      <p className="text-xs text-gray-400">{formatDate(post.created_at)}</p>
                    </div>
                  </div>
                  {(post.user_id === userId || isAdmin) && (
                    <button onClick={() => handleDeletePost(post.id)}
                      className="p-1 hover:bg-red-50 rounded-lg text-gray-400 hover:text-red-500 transition-colors">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
                <p className="text-sm text-gray-700 whitespace-pre-wrap">{post.content}</p>
              </div>
            ))
          )}
        </div>

        {/* Members sidebar */}
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-gray-100 p-4">
            <h3 className="font-bold text-gray-900 text-sm mb-3 flex items-center gap-2">
              <Users className="w-4 h-4 text-primary-600" /> Mitglieder ({members.length})
            </h3>
            <div className="space-y-2 max-h-80 overflow-y-auto">
              {members.map(m => (
                <div key={m.user_id} className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-full bg-gray-100 flex items-center justify-center text-xs font-bold text-gray-600">
                    {((m.profiles as any)?.name ?? 'U').charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium text-gray-800 truncate">{(m.profiles as any)?.name ?? 'Unbekannt'}</p>
                  </div>
                  {m.role === 'admin' && <Crown className="w-3.5 h-3.5 text-amber-500" title="Admin" />}
                  {m.role === 'moderator' && <Shield className="w-3.5 h-3.5 text-blue-500" title="Moderator" />}
                </div>
              ))}
            </div>
          </div>

          {/* Group Info */}
          <div className="bg-white rounded-2xl border border-gray-100 p-4">
            <h3 className="font-bold text-gray-900 text-sm mb-2">Info</h3>
            <div className="space-y-1 text-xs text-gray-500">
              <p>Kategorie: <span className="text-gray-700 capitalize">{group.category}</span></p>
              <p>Erstellt: <span className="text-gray-700">{formatDate(group.created_at)}</span></p>
              <p>Typ: <span className="text-gray-700">{(group.is_private || group.is_public === false) ? 'Privat' : 'Öffentlich'}</span></p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
