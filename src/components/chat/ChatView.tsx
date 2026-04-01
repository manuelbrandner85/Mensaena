'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import {
  Send, MessageCircle, Users, Plus, Search, X, ArrowLeft,
  Hash, Lock, CheckCheck, Check, Loader2, Mail
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { formatRelativeTime, cn } from '@/lib/utils'

// ─── Typen ────────────────────────────────────────────────────────────────────
interface Profile {
  id: string
  name: string | null
  email: string | null
  avatar_url: string | null
  nickname: string | null
}

interface ConvMember {
  user_id: string
  last_read_at?: string | null
  profiles: Profile | null
}

interface LastMsg {
  content: string
  created_at: string
  sender_id: string
}

interface Conversation {
  id: string
  type: 'direct' | 'group' | 'system'
  title: string | null
  post_id?: string | null
  updated_at?: string | null
  created_at: string
  conversation_members: ConvMember[]
  last_message?: LastMsg | null
  unread_count?: number
}

interface Message {
  id: string
  conversation_id: string
  sender_id: string
  content: string
  created_at: string
  profiles?: Profile | null
}

// ─── openDM: Findet oder erstellt eine DM-Konversation ───────────────────────
export async function openOrCreateDM(
  currentUserId: string,
  targetUserId: string,
  postId?: string | null
): Promise<string | null> {
  const supabase = createClient()

  // 1. Prüfe ob bereits eine DM existiert
  const { data: myMemberships } = await supabase
    .from('conversation_members').select('conversation_id').eq('user_id', currentUserId)

  if (myMemberships && myMemberships.length > 0) {
    const myConvIds = myMemberships.map((m: { conversation_id: string }) => m.conversation_id)
    const { data: shared } = await supabase
      .from('conversation_members').select('conversation_id, conversations(type)')
      .eq('user_id', targetUserId).in('conversation_id', myConvIds)

    if (shared) {
      const direct = (shared as any[]).find(s => s.conversations?.type === 'direct')
      if (direct) return direct.conversation_id
    }
  }

  // 2. Neue DM erstellen
  const { data: conv, error } = await supabase
    .from('conversations')
    .insert({ type: 'direct', title: null, post_id: postId ?? null })
    .select().single()

  if (error || !conv) return null

  await supabase.from('conversation_members').insert([
    { conversation_id: conv.id, user_id: currentUserId },
    { conversation_id: conv.id, user_id: targetUserId },
  ])

  return conv.id
}

// ─── Unread DM Count abrufen ──────────────────────────────────────────────────
export async function getUnreadDMCount(userId: string): Promise<number> {
  const supabase = createClient()
  const { data } = await supabase
    .from('conversation_members')
    .select(`
      conversation_id, last_read_at,
      conversations(id, type, messages(id, created_at, sender_id))
    `)
    .eq('user_id', userId)

  if (!data) return 0
  let total = 0
  for (const row of data as any[]) {
    const c = row.conversations
    if (!c || c.type === 'system') continue
    const lastRead = row.last_read_at ? new Date(row.last_read_at).getTime() : 0
    const msgs: any[] = c.messages ?? []
    const unread = msgs.filter(m =>
      m.sender_id !== userId && new Date(m.created_at).getTime() > lastRead
    ).length
    total += unread
  }
  return total
}

// ─── Haupt-Komponente ─────────────────────────────────────────────────────────
export default function ChatView({
  userId,
  initialConvId,
}: {
  userId: string
  initialConvId?: string | null
}) {
  const supabase = createClient()
  const [tab, setTab] = useState<'dm' | 'community'>(initialConvId ? 'dm' : 'community')
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [activeConvId, setActiveConvId] = useState<string | null>(initialConvId ?? null)
  const [messages, setMessages] = useState<Message[]>([])
  const [communityMessages, setCommunityMessages] = useState<Message[]>([])
  const [communityRoomId, setCommunityRoomId] = useState<string | null>(null)
  const [communityLoading, setCommunityLoading] = useState(true)
  const [newMessage, setNewMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [loadingConvs, setLoadingConvs] = useState(true)
  const [showNewChat, setShowNewChat] = useState(false)
  const [mobileShowChat, setMobileShowChat] = useState(!!initialConvId)
  const [totalUnread, setTotalUnread] = useState(0)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)
  const communityChannelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)

  // ── Community-Raum laden ──────────────────────────────────────────────────
  useEffect(() => {
    async function loadCommunityRoom() {
      setCommunityLoading(true)
      const { data } = await supabase
        .from('conversations').select('id').eq('type', 'system').eq('title', 'Community Chat').single()
      if (data) {
        setCommunityRoomId(data.id)
        await loadCommunityMessages(data.id)
      }
      setCommunityLoading(false)
    }
    loadCommunityRoom()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const loadCommunityMessages = useCallback(async (roomId: string) => {
    const { data } = await supabase
      .from('messages')
      .select('*, profiles(id, name, avatar_url, nickname)')
      .eq('conversation_id', roomId)
      .order('created_at', { ascending: true })
      .limit(200)
    setCommunityMessages((data as Message[]) ?? [])
  }, [supabase])

  // Realtime: Community-Raum
  useEffect(() => {
    if (!communityRoomId) return
    if (communityChannelRef.current) supabase.removeChannel(communityChannelRef.current)
    const ch = supabase
      .channel(`community:${communityRoomId}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'messages',
        filter: `conversation_id=eq.${communityRoomId}`,
      }, async (payload) => {
        const msg = payload.new as Message
        // Profil nachladen wenn nötig
        if (!msg.profiles) {
          const { data: profile } = await supabase
            .from('profiles').select('id, name, avatar_url, nickname').eq('id', msg.sender_id).single()
          msg.profiles = profile
        }
        setCommunityMessages(prev => {
          if (prev.some(m => m.id === msg.id)) return prev
          return [...prev, msg]
        })
      })
      .subscribe()
    communityChannelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [communityRoomId])

  // ── DM-Konversationen laden ──────────────────────────────────────────────
  const loadConversations = useCallback(async () => {
    setLoadingConvs(true)
    const { data } = await supabase
      .from('conversation_members')
      .select(`
        conversation_id, last_read_at,
        conversations(
          id, type, title, post_id, updated_at, created_at,
          conversation_members(user_id, last_read_at, profiles(id, name, email, avatar_url, nickname)),
          messages(id, content, created_at, sender_id)
        )
      `)
      .eq('user_id', userId)
      .order('created_at', { ascending: false })

    if (data) {
      const convs: Conversation[] = (data as any[])
        .map(row => {
          const c = row.conversations
          if (!c || c.type === 'system') return null
          const msgs: LastMsg[] = c.messages || []
          msgs.sort((a: LastMsg, b: LastMsg) =>
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          )
          const lastMsg = msgs[0] || null
          const myMember = c.conversation_members?.find((m: ConvMember) => m.user_id === userId)
          const lastRead = myMember?.last_read_at ? new Date(myMember.last_read_at).getTime() : 0
          const unread = msgs.filter(m =>
            m.sender_id !== userId && new Date(m.created_at).getTime() > lastRead
          ).length
          return { ...c, last_message: lastMsg, unread_count: unread }
        })
        .filter(Boolean) as Conversation[]

      // Sort by last activity
      convs.sort((a, b) => {
        const aTime = a.last_message?.created_at ?? a.updated_at ?? a.created_at
        const bTime = b.last_message?.created_at ?? b.updated_at ?? b.created_at
        return new Date(bTime).getTime() - new Date(aTime).getTime()
      })

      setConversations(convs)
      setTotalUnread(convs.reduce((sum, c) => sum + (c.unread_count ?? 0), 0))
    }
    setLoadingConvs(false)
  }, [userId, supabase])

  useEffect(() => { loadConversations() }, [loadConversations])

  // Wenn initialConvId gesetzt: direkt öffnen und auf DM-Tab wechseln
  useEffect(() => {
    if (initialConvId) {
      setTab('dm')
      setActiveConvId(initialConvId)
      setMobileShowChat(true)
    }
  }, [initialConvId])

  // ── DM-Nachrichten laden + Realtime ─────────────────────────────────────
  const loadDMMessages = useCallback(async (convId: string) => {
    const { data } = await supabase
      .from('messages')
      .select('*, profiles(id, name, avatar_url, nickname)')
      .eq('conversation_id', convId)
      .order('created_at', { ascending: true })
      .limit(100)
    setMessages((data as Message[]) ?? [])

    // Mark as read
    await supabase.from('conversation_members')
      .update({ last_read_at: new Date().toISOString() })
      .eq('conversation_id', convId).eq('user_id', userId)

    // Refresh unread in conv list
    setConversations(prev =>
      prev.map(c => c.id === convId ? { ...c, unread_count: 0 } : c)
    )
  }, [userId, supabase])

  useEffect(() => {
    if (!activeConvId) return
    loadDMMessages(activeConvId)

    if (channelRef.current) supabase.removeChannel(channelRef.current)
    const ch = supabase
      .channel(`dm:${activeConvId}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'messages',
        filter: `conversation_id=eq.${activeConvId}`,
      }, async (payload) => {
        const msg = payload.new as Message
        // Fetch profile for new message
        if (!msg.profiles) {
          const { data: profile } = await supabase
            .from('profiles').select('id, name, avatar_url, nickname').eq('id', msg.sender_id).single()
          msg.profiles = profile
        }
        setMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg])
        // Auto mark as read if this is the active conv
        await supabase.from('conversation_members')
          .update({ last_read_at: new Date().toISOString() })
          .eq('conversation_id', activeConvId).eq('user_id', userId)
        setConversations(prev =>
          prev.map(c => c.id === activeConvId ? { ...c, unread_count: 0 } : c)
        )
      })
      .subscribe()
    channelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeConvId, loadDMMessages, userId])

  // ── Auto-Scroll ───────────────────────────────────────────────────────────
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, communityMessages, tab])

  // ── Nachricht senden ──────────────────────────────────────────────────────
  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || sending) return

    const roomId = tab === 'community' ? communityRoomId : activeConvId
    if (!roomId) return

    setSending(true)
    const content = newMessage.trim()
    setNewMessage('')
    await supabase.from('messages').insert({ conversation_id: roomId, sender_id: userId, content })
    setSending(false)
    // Refocus input after sending
    setTimeout(() => inputRef.current?.focus(), 50)
  }

  // ── Konversation öffnen ───────────────────────────────────────────────────
  const openConv = (conv: Conversation) => {
    setActiveConvId(conv.id)
    setMobileShowChat(true)
    // Optimistic unread reset
    setConversations(prev =>
      prev.map(c => c.id === conv.id ? { ...c, unread_count: 0 } : c)
    )
  }

  // ── Gesprächspartner-Titel ────────────────────────────────────────────────
  const getConvTitle = (conv: Conversation) => {
    if (conv.title) return conv.title
    const other = conv.conversation_members?.find(m => m.user_id !== userId)
    return other?.profiles?.name ?? other?.profiles?.nickname ?? other?.profiles?.email?.split('@')[0] ?? 'Direktnachricht'
  }
  const getConvInitials = (conv: Conversation) =>
    getConvTitle(conv).split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)

  const getConvAvatar = (conv: Conversation): string | null => {
    if (conv.type === 'group') return null
    const other = conv.conversation_members?.find(m => m.user_id !== userId)
    return other?.profiles?.avatar_url ?? null
  }

  const activeConv = conversations.find(c => c.id === activeConvId) ?? null
  const displayMessages = tab === 'community' ? communityMessages : messages

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col">
      {/* Header */}
      <div className="mb-4 flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Nachrichten & Chat</h1>
          <p className="text-sm text-gray-500 mt-0.5">Community-Raum & private Direktnachrichten</p>
        </div>
        {tab === 'dm' && (
          <button onClick={() => setShowNewChat(true)} className="btn-primary gap-2 flex items-center">
            <Plus className="w-4 h-4" /> Neue Nachricht
          </button>
        )}
      </div>

      {/* Tab-Leiste */}
      <div className="flex gap-1 bg-warm-100 p-1 rounded-xl mb-4 flex-shrink-0">
        <button
          onClick={() => setTab('community')}
          className={cn('flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-sm font-semibold transition-all',
            tab === 'community' ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700')}
        >
          <Hash className="w-4 h-4" />
          <span className="hidden sm:inline">Community-Raum</span>
          <span className="sm:hidden">Community</span>
          <span className="text-xs text-gray-400 hidden sm:inline">(öffentlich)</span>
        </button>
        <button
          onClick={() => setTab('dm')}
          className={cn('flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-sm font-semibold transition-all',
            tab === 'dm' ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700')}
        >
          <Lock className="w-4 h-4" />
          <span className="hidden sm:inline">Direktnachrichten</span>
          <span className="sm:hidden">DMs</span>
          {totalUnread > 0 && (
            <span className="w-5 h-5 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
              {totalUnread > 9 ? '9+' : totalUnread}
            </span>
          )}
        </button>
      </div>

      {/* ══ Community-Raum Tab ══ */}
      {tab === 'community' && (
        <div className="flex-1 card flex flex-col min-h-0">
          {/* Room Header */}
          <div className="flex items-center gap-3 px-5 py-3.5 border-b border-warm-100 flex-shrink-0">
            <div className="w-8 h-8 rounded-xl bg-primary-100 flex items-center justify-center">
              <Hash className="w-4 h-4 text-primary-600" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-gray-900 text-sm">Community Chat</p>
              <p className="text-xs text-green-600 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-green-500 inline-block animate-pulse" />
                Live – alle Mitglieder können mitlesen & mitmachen
              </p>
            </div>
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-green-50 border border-green-200">
              <Users className="w-3.5 h-3.5 text-green-600" />
              <span className="text-xs font-medium text-green-700">Öffentlich</span>
            </div>
          </div>

          {/* Nachrichten */}
          <div className="flex-1 overflow-y-auto p-4 space-y-3 no-scrollbar">
            {communityLoading ? (
              <div className="flex flex-col items-center justify-center h-full text-center py-12">
                <Loader2 className="w-8 h-8 text-primary-300 animate-spin mb-3" />
                <p className="text-sm text-gray-400">Raum wird geladen…</p>
              </div>
            ) : communityRoomId === null ? (
              <div className="flex flex-col items-center justify-center h-full text-center py-12">
                <Hash className="w-12 h-12 text-gray-200 mb-3" />
                <p className="font-semibold text-gray-600 mb-1">Community-Raum nicht verfügbar</p>
                <p className="text-sm text-gray-400">Bitte kontaktiere den Administrator.</p>
              </div>
            ) : communityMessages.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-center py-12">
                <Hash className="w-12 h-12 text-gray-200 mb-3" />
                <p className="font-semibold text-gray-600 mb-1">Noch keine Nachrichten</p>
                <p className="text-sm text-gray-400">Sei der Erste und starte die Konversation! 👋</p>
              </div>
            ) : (
              <>
                <MessageGroup messages={communityMessages} userId={userId} />
                <div ref={messagesEndRef} />
              </>
            )}
          </div>

          {/* Eingabe */}
          <form onSubmit={sendMessage} className="px-4 py-3 border-t border-warm-100 flex-shrink-0 bg-white">
            <div className="flex gap-2 items-center">
              <input
                ref={inputRef}
                type="text" value={newMessage} onChange={e => setNewMessage(e.target.value)}
                placeholder="Nachricht an die Community schreiben…"
                disabled={!communityRoomId}
                className="input flex-1 text-sm"
              />
              <button type="submit" disabled={sending || !newMessage.trim() || !communityRoomId}
                className="p-2.5 bg-primary-600 hover:bg-primary-700 disabled:opacity-40 text-white rounded-xl transition-all flex-shrink-0">
                {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ══ DM Tab ══ */}
      {tab === 'dm' && (
        <div className="flex-1 flex gap-4 min-h-0">
          {/* Konversationsliste */}
          <div className={cn(
            'w-72 flex-shrink-0 flex flex-col bg-white rounded-2xl border border-warm-200 shadow-sm overflow-hidden',
            mobileShowChat ? 'hidden lg:flex' : 'flex'
          )}>
            {/* DM Header */}
            <div className="flex items-center justify-between px-4 py-3 border-b border-warm-100">
              <div className="flex items-center gap-2">
                <Mail className="w-4 h-4 text-primary-600" />
                <span className="font-semibold text-gray-900 text-sm">Nachrichten</span>
                {totalUnread > 0 && (
                  <span className="w-5 h-5 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                    {totalUnread > 9 ? '9+' : totalUnread}
                  </span>
                )}
              </div>
              <button onClick={() => setShowNewChat(true)}
                className="p-1.5 rounded-lg hover:bg-warm-100 text-gray-500 hover:text-primary-600 transition-all"
                title="Neue Nachricht">
                <Plus className="w-4 h-4" />
              </button>
            </div>

            {loadingConvs ? (
              <div className="flex flex-col items-center py-12 flex-1">
                <Loader2 className="w-6 h-6 text-primary-300 animate-spin mb-2" />
                <p className="text-xs text-gray-400">Lade Gespräche…</p>
              </div>
            ) : conversations.length === 0 ? (
              <div className="flex flex-col items-center py-10 px-4 text-center flex-1">
                <div className="w-14 h-14 rounded-full bg-primary-50 flex items-center justify-center mb-3">
                  <MessageCircle className="w-7 h-7 text-primary-300" />
                </div>
                <p className="text-sm text-gray-600 font-medium">Noch keine Gespräche</p>
                <p className="text-xs text-gray-400 mt-1 mb-4">Schreibe jemanden aus einem Inserat heraus oder starte hier</p>
                <button onClick={() => setShowNewChat(true)} className="btn-primary text-sm py-2 gap-1.5">
                  <Plus className="w-3.5 h-3.5" /> Neue Nachricht
                </button>
              </div>
            ) : (
              <div className="overflow-y-auto flex-1 no-scrollbar py-1">
                {conversations.map(conv => (
                  <ConversationItem
                    key={conv.id}
                    conv={conv}
                    active={activeConvId === conv.id}
                    title={getConvTitle(conv)}
                    initials={getConvInitials(conv)}
                    avatarUrl={getConvAvatar(conv)}
                    onClick={() => openConv(conv)}
                    userId={userId}
                  />
                ))}
              </div>
            )}
          </div>

          {/* Chat-Fenster */}
          <div className={cn('flex-1 card flex flex-col min-h-0',
            !mobileShowChat ? 'hidden lg:flex' : 'flex')}>
            {activeConv ? (
              <>
                {/* Header */}
                <div className="flex items-center gap-3 px-5 py-3.5 border-b border-warm-100 flex-shrink-0">
                  <button onClick={() => setMobileShowChat(false)}
                    className="lg:hidden p-1.5 rounded-lg hover:bg-warm-100 text-gray-500">
                    <ArrowLeft className="w-4 h-4" />
                  </button>
                  <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0 overflow-hidden">
                    {getConvAvatar(activeConv)
                      ? <img src={getConvAvatar(activeConv)!} alt="" className="w-full h-full object-cover" />
                      : activeConv.type === 'group'
                        ? <Users className="w-5 h-5" />
                        : getConvInitials(activeConv)
                    }
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-gray-900 text-sm truncate">{getConvTitle(activeConv)}</p>
                    {activeConv.post_id && (
                      <p className="text-xs text-primary-600 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-primary-400 inline-block" />
                        Bezüglich einem Inserat
                      </p>
                    )}
                    {!activeConv.post_id && (
                      <p className="text-xs text-gray-400 flex items-center gap-1">
                        <Lock className="w-2.5 h-2.5" />
                        Ende-zu-Ende privat
                      </p>
                    )}
                  </div>
                </div>

                {/* Nachrichten */}
                <div className="flex-1 overflow-y-auto p-4 space-y-3 no-scrollbar">
                  {messages.length === 0 ? (
                    <div className="flex flex-col items-center justify-center h-full text-center py-12">
                      <div className="w-14 h-14 rounded-full bg-primary-50 flex items-center justify-center mb-3">
                        <Lock className="w-7 h-7 text-primary-300" />
                      </div>
                      <p className="font-semibold text-gray-600 mb-1">Neue Konversation gestartet</p>
                      <p className="text-sm text-gray-400">
                        {activeConv.post_id
                          ? 'Schreib die erste Nachricht bezüglich des Inserats!'
                          : 'Schreib die erste Nachricht!'}
                      </p>
                    </div>
                  ) : (
                    <>
                      <MessageGroup messages={messages} userId={userId} />
                      <div ref={messagesEndRef} />
                    </>
                  )}
                </div>

                {/* Eingabe */}
                <form onSubmit={sendMessage} className="px-4 py-3 border-t border-warm-100 flex-shrink-0 bg-white">
                  <div className="flex gap-2 items-center">
                    <input
                      ref={tab === 'dm' ? inputRef : undefined}
                      type="text" value={newMessage} onChange={e => setNewMessage(e.target.value)}
                      placeholder={`Nachricht an ${getConvTitle(activeConv)}…`}
                      className="input flex-1 text-sm"
                    />
                    <button type="submit" disabled={sending || !newMessage.trim()}
                      className="p-2.5 bg-primary-600 hover:bg-primary-700 disabled:opacity-40 text-white rounded-xl transition-all flex-shrink-0">
                      {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                    </button>
                  </div>
                </form>
              </>
            ) : (
              <div className="flex-1 flex items-center justify-center text-center">
                <div>
                  <div className="w-20 h-20 rounded-full bg-primary-50 flex items-center justify-center mx-auto mb-4">
                    <MessageCircle className="w-10 h-10 text-primary-300" />
                  </div>
                  <h3 className="font-semibold text-gray-700 mb-2">Wähle ein Gespräch</h3>
                  <p className="text-sm text-gray-400 mb-5 max-w-xs">
                    Oder klicke auf „Direkte Nachricht" bei einem Inserat, um direkt zu schreiben
                  </p>
                  <button onClick={() => setShowNewChat(true)} className="btn-primary gap-2">
                    <Plus className="w-4 h-4" /> Neue Nachricht starten
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Neues Gespräch Modal ── */}
      {showNewChat && (
        <NewChatModal
          userId={userId}
          onClose={() => setShowNewChat(false)}
          onCreated={(convId) => {
            setShowNewChat(false)
            setTab('dm')
            loadConversations().then(() => {
              setActiveConvId(convId)
              setMobileShowChat(true)
            })
          }}
        />
      )}
    </div>
  )
}

// ─── MessageGroup – Nachrichten gruppiert nach Absender ──────────────────────
function MessageGroup({ messages, userId }: { messages: Message[]; userId: string }) {
  return (
    <>
      {messages.map((msg, i) => {
        const isMe = msg.sender_id === userId
        const prevMsg = messages[i - 1]
        const nextMsg = messages[i + 1]
        const sameAuthorPrev = prevMsg?.sender_id === msg.sender_id
        const sameAuthorNext = nextMsg?.sender_id === msg.sender_id
        const timeDiff = prevMsg
          ? new Date(msg.created_at).getTime() - new Date(prevMsg.created_at).getTime()
          : Infinity
        const showAvatar = !sameAuthorPrev || timeDiff > 5 * 60 * 1000
        const showName = showAvatar
        const isLast = !sameAuthorNext

        return (
          <div key={msg.id} className={cn(
            'flex gap-2',
            isMe ? 'justify-end' : 'justify-start',
            !showAvatar && !isMe && 'pl-9',
            'mb-0.5'
          )}>
            {!isMe && showAvatar && (
              <div className="w-7 h-7 rounded-full bg-warm-200 flex items-center justify-center text-xs font-bold text-gray-600 flex-shrink-0 mt-auto overflow-hidden">
                {msg.profiles?.avatar_url
                  ? <img src={msg.profiles.avatar_url} alt="" className="w-full h-full rounded-full object-cover" />
                  : (msg.profiles?.name ?? '?')[0].toUpperCase()}
              </div>
            )}
            {!isMe && !showAvatar && <div className="w-7 flex-shrink-0" />}
            <div className={cn('max-w-[72%] space-y-0.5')}>
              {!isMe && showName && (
                <p className="text-[10px] font-semibold text-primary-600 ml-1">
                  {msg.profiles?.name ?? msg.profiles?.nickname ?? 'Nutzer'}
                </p>
              )}
              <div className={cn(
                'px-3.5 py-2.5 text-sm shadow-sm',
                isMe
                  ? cn('bg-primary-600 text-white', isLast ? 'rounded-2xl rounded-br-sm' : 'rounded-2xl')
                  : cn('bg-warm-100 text-gray-800', isLast ? 'rounded-2xl rounded-bl-sm' : 'rounded-2xl')
              )}>
                <p className="leading-relaxed break-words whitespace-pre-wrap">{msg.content}</p>
                <div className={cn('flex items-center gap-1 mt-1', isMe ? 'justify-end' : 'justify-start')}>
                  <p className={cn('text-[10px]', isMe ? 'text-primary-200' : 'text-gray-400')}>
                    {formatRelativeTime(msg.created_at)}
                  </p>
                  {isMe && <CheckCheck className="w-3 h-3 text-primary-200" />}
                </div>
              </div>
            </div>
          </div>
        )
      })}
    </>
  )
}

// ─── ConversationItem ─────────────────────────────────────────────────────────
function ConversationItem({
  conv, active, title, initials, avatarUrl, onClick, userId
}: {
  conv: Conversation
  active: boolean
  title: string
  initials: string
  avatarUrl: string | null
  onClick: () => void
  userId: string
}) {
  const unread = conv.unread_count ?? 0

  return (
    <button onClick={onClick}
      className={cn(
        'w-full flex items-center gap-3 px-3 py-2.5 text-left transition-all duration-150',
        active ? 'bg-primary-50 border-l-2 border-primary-500' : 'hover:bg-warm-50 border-l-2 border-transparent',
        unread > 0 && !active && 'bg-blue-50/50'
      )}>
      <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0 relative overflow-hidden">
        {avatarUrl
          ? <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
          : conv.type === 'group' ? <Users className="w-5 h-5" /> : initials}
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <p className={cn('text-sm truncate', unread > 0 ? 'font-bold text-gray-900' : 'font-semibold text-gray-700')}>
          {title}
        </p>
        <p className={cn('text-xs truncate mt-0.5', unread > 0 ? 'text-gray-700 font-medium' : 'text-gray-400')}>
          {conv.last_message
            ? (conv.last_message.sender_id === userId ? '✓ Du: ' : '') + conv.last_message.content
            : conv.post_id ? '📋 Bezüglich einem Inserat' : 'Noch keine Nachrichten'}
        </p>
      </div>
      <div className="flex flex-col items-end gap-1 flex-shrink-0">
        {conv.last_message && (
          <span className="text-[10px] text-gray-400">{formatRelativeTime(conv.last_message.created_at)}</span>
        )}
        {unread > 0 ? (
          <span className="w-4 h-4 bg-primary-600 rounded-full" />
        ) : conv.last_message?.sender_id === userId ? (
          <Check className="w-3 h-3 text-gray-300" />
        ) : null}
      </div>
    </button>
  )
}

// ─── NewChatModal ─────────────────────────────────────────────────────────────
function NewChatModal({
  userId, onClose, onCreated,
}: {
  userId: string
  onClose: () => void
  onCreated: (convId: string) => void
}) {
  const supabase = createClient()
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Profile[]>([])
  const [selected, setSelected] = useState<Profile[]>([])
  const [groupTitle, setGroupTitle] = useState('')
  const [searching, setSearching] = useState(false)
  const [creating, setCreating] = useState(false)

  useEffect(() => {
    if (query.trim().length < 2) { setResults([]); return }
    const t = setTimeout(async () => {
      setSearching(true)
      const { data } = await supabase
        .from('profiles').select('id, name, email, avatar_url, nickname')
        .neq('id', userId)
        .or(`name.ilike.%${query}%,nickname.ilike.%${query}%,email.ilike.%${query}%`)
        .limit(8)
      setResults((data as Profile[]) ?? [])
      setSearching(false)
    }, 300)
    return () => clearTimeout(t)
  }, [query, userId, supabase])

  const toggle = (p: Profile) =>
    setSelected(prev => prev.find(s => s.id === p.id) ? prev.filter(s => s.id !== p.id) : [...prev, p])

  const start = async () => {
    if (selected.length === 0 || creating) return
    setCreating(true)

    if (selected.length === 1) {
      const convId = await openOrCreateDM(userId, selected[0].id)
      if (convId) { onCreated(convId); return }
    } else {
      const { data: conv } = await supabase
        .from('conversations').insert({
          type: 'group',
          title: groupTitle || selected.map(s => s.name ?? s.email).join(', '),
        }).select().single()
      if (conv) {
        await supabase.from('conversation_members').insert(
          [userId, ...selected.map(s => s.id)].map(uid => ({ conversation_id: conv.id, user_id: uid }))
        )
        onCreated(conv.id)
        return
      }
    }
    setCreating(false)
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between p-5 border-b border-warm-100">
          <div>
            <h3 className="font-bold text-gray-900 text-lg">Neue Unterhaltung</h3>
            <p className="text-xs text-gray-500 mt-0.5">Suche nach Name, Nickname oder E-Mail</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-warm-100 text-gray-500">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="p-5 space-y-4">
          {selected.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {selected.map(p => (
                <span key={p.id} className="flex items-center gap-1.5 px-3 py-1.5 bg-primary-100 text-primary-700 rounded-full text-sm font-medium">
                  {p.name ?? p.email?.split('@')[0]}
                  <button onClick={() => toggle(p)}><X className="w-3.5 h-3.5" /></button>
                </span>
              ))}
            </div>
          )}
          {selected.length > 1 && (
            <input value={groupTitle} onChange={e => setGroupTitle(e.target.value)}
              placeholder="Gruppenname (optional)" className="input" />
          )}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input value={query} onChange={e => setQuery(e.target.value)}
              placeholder="Name oder E-Mail suchen…" className="input pl-9" autoFocus />
          </div>
          <div className="space-y-1 max-h-60 overflow-y-auto no-scrollbar">
            {searching && <div className="flex justify-center py-4"><Loader2 className="w-5 h-5 text-primary-400 animate-spin" /></div>}
            {!searching && query.length >= 2 && results.length === 0 && (
              <p className="text-sm text-gray-400 text-center py-4">Keine Nutzer gefunden</p>
            )}
            {!searching && query.length < 2 && (
              <p className="text-sm text-gray-400 text-center py-4">Mindestens 2 Zeichen eingeben…</p>
            )}
            {results.map(p => {
              const isSel = selected.some(s => s.id === p.id)
              return (
                <button key={p.id} onClick={() => toggle(p)}
                  className={cn('w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all text-left',
                    isSel ? 'bg-primary-50 border border-primary-200' : 'hover:bg-warm-50 border border-transparent')}>
                  <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0 overflow-hidden">
                    {p.avatar_url
                      ? <img src={p.avatar_url} alt="" className="w-full h-full rounded-full object-cover" />
                      : (p.name ?? p.email ?? '?')[0].toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-900 truncate">{p.name ?? p.email?.split('@')[0] ?? 'Unbekannt'}</p>
                    <p className="text-xs text-gray-500 truncate">{p.nickname ? '@' + p.nickname : p.email}</p>
                  </div>
                  {isSel && (
                    <div className="w-5 h-5 rounded-full bg-primary-600 flex items-center justify-center flex-shrink-0">
                      <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                  )}
                </button>
              )
            })}
          </div>
        </div>
        <div className="p-5 border-t border-warm-100 flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1 justify-center">Abbrechen</button>
          <button onClick={start} disabled={selected.length === 0 || creating} className="btn-primary flex-1 justify-center">
            {creating
              ? <Loader2 className="w-4 h-4 animate-spin" />
              : selected.length > 1 ? `Gruppe (${selected.length})` : 'Gespräch starten'}
          </button>
        </div>
      </div>
    </div>
  )
}
