'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, MessageCircle, Users, Volume2, VolumeX,
  Trash2, Ban, ShieldOff, RefreshCw
} from 'lucide-react'
import type { AdminMessage } from './AdminTypes'

interface ChatUser {
  id: string
  name: string | null
  email: string | null
  banned: boolean
}

interface CommunityRoom {
  id: string
  is_locked: boolean
  locked_reason: string | null
}

export default function ChatModTab({ userRole = 'moderator' }: { userRole?: string }) {
  const isAdmin = userRole === 'admin'
  const [communityRoom, setCommunityRoom] = useState<CommunityRoom | null>(null)
  const [chatMessages, setChatMessages]   = useState<AdminMessage[]>([])
  const [chatUsers, setChatUsers]         = useState<ChatUser[]>([])
  const [lockReason, setLockReason]       = useState('')
  const [msgSearch, setMsgSearch]         = useState('')
  const [loading, setLoading]             = useState(true)

  const loadChatData = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()

    // Community Room – try exact title first, fall back to any system conversation
    let room: CommunityRoom | null = null
    const { data: r1 } = await supabase
      .from('conversations').select('id, is_locked, locked_reason')
      .eq('type', 'system').eq('title', 'Community Chat').maybeSingle()
    if (r1) { room = r1 as CommunityRoom }
    else {
      const { data: r2 } = await supabase
        .from('conversations').select('id, is_locked, locked_reason')
        .eq('type', 'system').or('title.eq.Allgemein,title.ilike.%community%').maybeSingle()
      if (r2) room = r2 as CommunityRoom
    }
    if (room) setCommunityRoom(room)

    // Recent messages
    if (room) {
      let query = supabase
        .from('messages')
        .select('id, content, created_at, deleted_at, sender_id, conversation_id, profiles(name, email)')
        .eq('conversation_id', room.id)
        .order('created_at', { ascending: false })
        .limit(100)
      const { data: msgs } = await query
      setChatMessages((msgs as AdminMessage[]) ?? [])
    }

    // Banned users
    const { data: bans } = await supabase
      .from('chat_banned_users')
      .select('user_id, profiles(id, name, email)')
    const bannedIds = new Set((bans ?? []).map((b: any) => b.user_id))

    // Active chat users
    const { data: chatUserData } = await supabase
      .from('messages').select('sender_id, profiles(id, name, email)')
      .eq('conversation_id', room?.id ?? '')
      .not('sender_id', 'is', null)
      .limit(200)
    const seen = new Set<string>()
    const users: ChatUser[] = []
    for (const m of (chatUserData ?? []) as any[]) {
      if (!seen.has(m.sender_id) && m.profiles) {
        seen.add(m.sender_id)
        users.push({ ...m.profiles, banned: bannedIds.has(m.sender_id) })
      }
    }
    setChatUsers(users)
    setLoading(false)
  }, [])

  useEffect(() => { loadChatData() }, [loadChatData])

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
    toast.success(newLocked ? 'Chat gesperrt' : 'Chat entsperrt')
  }

  const handleDeleteMsg = async (msgId: string) => {
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_hard_delete_message', { p_message_id: msgId })
    if (error) {
      await supabase.from('messages').update({ deleted_at: new Date().toISOString() }).eq('id', msgId)
      setChatMessages(prev => prev.map(m => m.id === msgId ? { ...m, deleted_at: new Date().toISOString() } : m))
      return
    }
    setChatMessages(prev => prev.filter(m => m.id !== msgId))
    toast.success('Nachricht gelöscht')
  }

  const handleToggleBan = async (userId: string, isBanned: boolean) => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (isBanned) {
      await supabase.from('chat_banned_users').delete().eq('user_id', userId)
      toast.success('Nutzer entsperrt')
    } else {
      await supabase.from('chat_banned_users').insert({ user_id: userId, banned_by: user?.id, reason: 'Admin-Entscheidung' })
      toast.success('Nutzer gesperrt')
    }
    setChatUsers(prev => prev.map(u => u.id === userId ? { ...u, banned: !isBanned } : u))
  }

  const filteredMessages = msgSearch
    ? chatMessages.filter(m => m.content?.toLowerCase().includes(msgSearch.toLowerCase()))
    : chatMessages

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Lock/Unlock Panel */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-5">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="font-bold text-ink-900 flex items-center gap-2">
              <MessageCircle className="w-4 h-4 text-green-600" /> Community Chat
            </h3>
            <p className="text-sm text-ink-500 mt-0.5">Öffentlichen Chat sperren oder entsperren</p>
          </div>
          <div className="flex items-center gap-2">
            <div className={`px-3 py-1.5 rounded-full text-xs font-bold ${
              communityRoom?.is_locked ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'
            }`}>
              {communityRoom?.is_locked ? 'Gesperrt' : 'Offen'}
            </div>
            <button onClick={loadChatData}
              className="p-1.5 rounded-xl text-ink-400 hover:text-green-600 hover:bg-green-50 transition-colors" aria-label="Aktualisieren">
              <RefreshCw className="w-4 h-4" />
            </button>
          </div>
        </div>
        {communityRoom?.is_locked && communityRoom.locked_reason && (
          <p className="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2 mb-3">
            Sperrgrund: {communityRoom.locked_reason}
          </p>
        )}
        <div className="flex gap-3 items-center">
          <input
            value={lockReason} onChange={e => setLockReason(e.target.value)}
            placeholder="Grund für Sperrung (optional)..."
            className="flex-1 px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
          <button onClick={isAdmin ? handleToggleLock : undefined}
            disabled={!isAdmin}
            title={!isAdmin ? 'Nur Admins können den Chat sperren' : undefined}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition-all whitespace-nowrap ${
              !isAdmin ? 'bg-stone-200 text-ink-400 cursor-not-allowed' :
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
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-5">
        <h3 className="font-bold text-ink-900 mb-4 flex items-center gap-2">
          <Users className="w-4 h-4 text-ink-400" /> Nutzer ({chatUsers.length})
        </h3>
        <div className="space-y-2 max-h-80 overflow-y-auto">
          {chatUsers.length === 0 && <p className="text-sm text-ink-400 text-center py-4">Noch keine Chat-Nutzer</p>}
          {chatUsers.map(u => (
            <div key={u.id} className={`flex items-center justify-between px-4 py-3 rounded-xl ${
              u.banned ? 'bg-red-50 border border-red-100' : 'bg-stone-50'
            }`}>
              <div>
                <p className="text-sm font-semibold text-ink-900">{u.name ?? 'Unbekannt'}</p>
                <p className="text-xs text-ink-500">{u.email}</p>
              </div>
              <div className="flex items-center gap-2">
                {u.banned && <span className="text-xs font-bold text-red-600 bg-red-100 px-2 py-0.5 rounded-full">Gesperrt</span>}
                <button onClick={() => handleToggleBan(u.id, u.banned)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                    u.banned ? 'bg-green-100 text-green-700 hover:bg-green-200' : 'bg-red-100 text-red-700 hover:bg-red-200'
                  }`}>
                  {u.banned ? <><ShieldOff className="w-3 h-3" /> Entsperren</> : <><Ban className="w-3 h-3" /> Sperren</>}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Recent Messages */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-5">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-bold text-ink-900 flex items-center gap-2">
            <MessageCircle className="w-4 h-4 text-ink-400" /> Nachrichten ({chatMessages.length})
          </h3>
          <div className="relative w-48">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-ink-400" />
            <input type="text" value={msgSearch} onChange={e => setMsgSearch(e.target.value)}
              placeholder="Suchen..."
              className="w-full pl-8 pr-3 py-1.5 border border-stone-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-green-300"
            />
          </div>
        </div>
        <div className="space-y-2 max-h-96 overflow-y-auto">
          {filteredMessages.length === 0 && <p className="text-sm text-ink-400 text-center py-4">Keine Nachrichten</p>}
          {filteredMessages.map(msg => (
            <div key={msg.id} className={`flex items-start justify-between gap-3 px-3 py-2.5 rounded-xl ${
              msg.deleted_at ? 'bg-stone-50 opacity-50' : 'hover:bg-stone-50'
            }`}>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-0.5">
                  <span className="text-xs font-semibold text-ink-700">{(msg.profiles as any)?.name ?? 'Unbekannt'}</span>
                  <span className="text-[10px] text-ink-400">{new Date(msg.created_at).toLocaleString('de-AT')}</span>
                  {msg.deleted_at && <span className="text-[10px] text-red-500 font-bold">GELOESCHT</span>}
                </div>
                <p className={`text-sm ${msg.deleted_at ? 'italic text-ink-400' : 'text-ink-700'}`}>
                  {msg.deleted_at ? 'Nachricht gelöscht' : msg.content}
                </p>
              </div>
              {!msg.deleted_at && (
                <button onClick={() => handleDeleteMsg(msg.id)}
                  className="p-1.5 rounded-xl text-ink-400 hover:text-red-600 hover:bg-red-50 transition-all flex-shrink-0" aria-label="Nachricht löschen">
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
