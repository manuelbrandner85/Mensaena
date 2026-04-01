'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import {
  Send, MessageCircle, Users, Plus, Search, X, ArrowLeft,
  Hash, Lock, CheckCheck, Check, Loader2, Mail, Smile,
  Trash2, Reply, MoreVertical, ShieldOff, AlertCircle,
  Volume2, VolumeX, Crown, Info, Pin, UserX, ChevronDown,
  RefreshCw
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
  role?: string | null
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
  is_locked?: boolean
  locked_reason?: string | null
  conversation_members: ConvMember[]
  last_message?: LastMsg | null
  unread_count?: number
}

interface Reaction {
  emoji: string
  user_id: string
  message_id: string
}

interface Message {
  id: string
  conversation_id: string
  sender_id: string
  content: string
  created_at: string
  deleted_at?: string | null
  reply_to_id?: string | null
  pinned?: boolean | null
  profiles?: Profile | null
  reactions?: Reaction[]
  reply_to?: { content: string; profiles?: { name?: string | null } | null } | null
}

// Quick emoji options
const QUICK_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '✅', '👏', '💪']

// Admin-Emails
const ADMIN_EMAILS = ['manuelbrandner85@gmail.com', 'admin@mensaena.at', 'brandy13062@gmail.com', 'uwevetter@gmx.at']

// Chat rules
const CHAT_RULES = [
  'Sei respektvoll und freundlich',
  'Keine Beleidigungen oder Diskriminierung',
  'Kein Spam oder Werbung',
  'Teile nur verlässliche Informationen',
  'Schütze die Privatsphäre anderer',
]

// ─── openDM ──────────────────────────────────────────────────────────────────
export async function openOrCreateDM(
  currentUserId: string,
  targetUserId: string,
  postId?: string | null
): Promise<string | null> {
  const supabase = createClient()
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

// ─── getUnreadDMCount ─────────────────────────────────────────────────────────
export async function getUnreadDMCount(userId: string): Promise<number> {
  const supabase = createClient()
  const { data } = await supabase
    .from('conversation_members')
    .select('conversation_id, last_read_at, conversations(id, type, messages(id, created_at, sender_id))')
    .eq('user_id', userId)
  if (!data) return 0
  let total = 0
  for (const row of data as any[]) {
    const c = row.conversations
    if (!c || c.type === 'system') continue
    const lastRead = row.last_read_at ? new Date(row.last_read_at).getTime() : 0
    const msgs: any[] = c.messages ?? []
    total += msgs.filter(m => m.sender_id !== userId && new Date(m.created_at).getTime() > lastRead).length
  }
  return total
}

// ─── Haupt-Komponente ─────────────────────────────────────────────────────────
export default function ChatView({ userId, initialConvId }: { userId: string; initialConvId?: string | null }) {
  const supabase = createClient()
  const [tab, setTab] = useState<'dm' | 'community'>(initialConvId ? 'dm' : 'community')
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [activeConvId, setActiveConvId] = useState<string | null>(initialConvId ?? null)
  const [messages, setMessages] = useState<Message[]>([])
  const [communityMessages, setCommunityMessages] = useState<Message[]>([])
  const [communityRoom, setCommunityRoom] = useState<Conversation | null>(null)
  const [communityLoading, setCommunityLoading] = useState(true)
  const [newMessage, setNewMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [loadingConvs, setLoadingConvs] = useState(true)
  const [showNewChat, setShowNewChat] = useState(false)
  const [mobileShowChat, setMobileShowChat] = useState(!!initialConvId)
  const [totalUnread, setTotalUnread] = useState(0)
  const [isAdmin, setIsAdmin] = useState(false)
  const [isBanned, setIsBanned] = useState(false)
  const [replyTo, setReplyTo] = useState<Message | null>(null)
  const [showEmojiFor, setShowEmojiFor] = useState<string | null>(null)
  const [msgMenuFor, setMsgMenuFor] = useState<string | null>(null)
  const [onlineCount, setOnlineCount] = useState(1)
  const [typingUsers, setTypingUsers] = useState<string[]>([])
  const [isTyping, setIsTyping] = useState(false)
  const [showRules, setShowRules] = useState(false)
  const [showLockForm, setShowLockForm] = useState(false)
  const [lockReason, setLockReason] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [showSearch, setShowSearch] = useState(false)
  const [pinnedMessage, setPinnedMessage] = useState<Message | null>(null)
  const [myName, setMyName] = useState('Jemand')
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)
  const communityChannelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)
  const presenceChannelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)
  const typingTimeout = useRef<NodeJS.Timeout | null>(null)

  // ── Admin & Ban Check ─────────────────────────────────────────────────────
  useEffect(() => {
    async function checkUser() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data: profile } = await supabase.from('profiles').select('role, email, name, nickname').eq('id', user.id).single()
      const adminCheck = profile?.role === 'admin' || ADMIN_EMAILS.includes(profile?.email ?? '') || ADMIN_EMAILS.includes(user.email ?? '')
      setIsAdmin(adminCheck)
      const displayName = profile?.name ?? profile?.nickname ?? user.email?.split('@')[0] ?? 'Jemand'
      setMyName(displayName)

      const { data: ban } = await supabase.from('chat_banned_users').select('id, expires_at').eq('user_id', userId).single()
      if (ban) {
        if (!ban.expires_at || new Date(ban.expires_at) > new Date()) {
          setIsBanned(true)
        }
      }
    }
    checkUser()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  // ── Community-Raum laden ──────────────────────────────────────────────────
  useEffect(() => {
    async function loadCommunityRoom() {
      setCommunityLoading(true)
      const { data } = await supabase
        .from('conversations')
        .select('id, type, title, is_locked, locked_reason')
        .eq('type', 'system').eq('title', 'Community Chat').single()
      if (data) {
        setCommunityRoom(data as any)
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
      .select('*, profiles(id, name, avatar_url, nickname, role), reply_to:reply_to_id(content, profiles(name))')
      .eq('conversation_id', roomId)
      .order('created_at', { ascending: true })
      .limit(200)

    if (!data) return
    const msgIds = (data as Message[]).map(m => m.id)

    // Load reactions
    let reactionsMap: Record<string, Reaction[]> = {}
    if (msgIds.length > 0) {
      const { data: reactions } = await supabase
        .from('message_reactions').select('*').in('message_id', msgIds)
      if (reactions) {
        for (const r of reactions as Reaction[]) {
          if (!reactionsMap[r.message_id]) reactionsMap[r.message_id] = []
          reactionsMap[r.message_id].push(r)
        }
      }
    }
    const msgs = (data as Message[]).map(m => ({ ...m, reactions: reactionsMap[m.id] ?? [] }))
    setCommunityMessages(msgs)

    // Set pinned message
    const pinned = msgs.filter(m => m.pinned && !m.deleted_at).pop() ?? null
    setPinnedMessage(pinned)
  }, [supabase])

  // ── Presence: Online-Zähler + Typing ─────────────────────────────────────
  useEffect(() => {
    if (!communityRoom?.id) return
    if (presenceChannelRef.current) supabase.removeChannel(presenceChannelRef.current)

    const ch = supabase.channel(`presence:${communityRoom.id}`, { config: { presence: { key: userId } } })
      .on('presence', { event: 'sync' }, () => {
        const state = ch.presenceState()
        setOnlineCount(Object.keys(state).length)
      })
      .on('broadcast', { event: 'typing' }, ({ payload }) => {
        if (payload.userId !== userId) {
          setTypingUsers(prev => {
            if (!prev.includes(payload.name)) return [...prev, payload.name]
            return prev
          })
          setTimeout(() => {
            setTypingUsers(prev => prev.filter(u => u !== payload.name))
          }, 3000)
        }
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await ch.track({ userId, online_at: new Date().toISOString() })
        }
      })

    presenceChannelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [communityRoom?.id, userId])

  // Typing broadcast
  const broadcastTyping = useCallback(() => {
    if (!presenceChannelRef.current || !communityRoom?.id) return
    presenceChannelRef.current.send({ type: 'broadcast', event: 'typing', payload: { userId, name: myName } })
  }, [communityRoom?.id, userId, myName])

  // ── Realtime: Community ───────────────────────────────────────────────────
  useEffect(() => {
    if (!communityRoom?.id) return
    if (communityChannelRef.current) supabase.removeChannel(communityChannelRef.current)
    const ch = supabase
      .channel(`community_msg:${communityRoom.id}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${communityRoom.id}` },
        async (payload) => {
          const msg = payload.new as Message
          if (!msg.profiles) {
            const { data: p } = await supabase.from('profiles').select('id, name, avatar_url, nickname, role').eq('id', msg.sender_id).single()
            msg.profiles = p
          }
          if (msg.reply_to_id) {
            const { data: rt } = await supabase.from('messages').select('content, profiles(name)').eq('id', msg.reply_to_id).single()
            msg.reply_to = rt as any
          }
          msg.reactions = []
          setCommunityMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg])
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages', filter: `conversation_id=eq.${communityRoom.id}` },
        (payload) => {
          const updated = payload.new as Message
          setCommunityMessages(prev => prev.map(m => m.id === updated.id ? { ...m, ...updated } : m))
          if (updated.pinned) setPinnedMessage(prev => prev?.id === updated.id ? { ...prev, ...updated } : prev)
          if (updated.pinned) {
            setCommunityMessages(prev => {
              const p = prev.find(m => m.id === updated.id)
              if (p) setPinnedMessage({ ...p, ...updated })
              return prev
            })
          }
          if (updated.pinned === false && pinnedMessage?.id === updated.id) setPinnedMessage(null)
        })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'message_reactions' },
        (payload) => {
          const r = payload.new as Reaction
          setCommunityMessages(prev => prev.map(m =>
            m.id === r.message_id ? { ...m, reactions: [...(m.reactions ?? []), r] } : m
          ))
        })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'message_reactions' },
        (payload) => {
          const old = payload.old as Reaction
          setCommunityMessages(prev => prev.map(m =>
            m.id === old.message_id
              ? { ...m, reactions: (m.reactions ?? []).filter(r => !(r.user_id === old.user_id && r.emoji === old.emoji)) }
              : m
          ))
        })
      // Realtime lock/unlock of community room
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'conversations', filter: `id=eq.${communityRoom.id}` },
        (payload) => {
          setCommunityRoom(prev => prev ? { ...prev, ...(payload.new as any) } : prev)
        })
      .subscribe()
    communityChannelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [communityRoom?.id])

  // ── DM-Konversationen ─────────────────────────────────────────────────────
  const loadConversations = useCallback(async () => {
    setLoadingConvs(true)
    const { data } = await supabase
      .from('conversation_members')
      .select(`conversation_id, last_read_at,
        conversations(id, type, title, post_id, updated_at, created_at,
          conversation_members(user_id, last_read_at, profiles(id, name, email, avatar_url, nickname)),
          messages(id, content, created_at, sender_id))`)
      .eq('user_id', userId).order('created_at', { ascending: false })

    if (data) {
      const convs: Conversation[] = (data as any[]).map(row => {
        const c = row.conversations
        if (!c || c.type === 'system') return null
        const msgs: LastMsg[] = c.messages || []
        msgs.sort((a: LastMsg, b: LastMsg) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        const lastMsg = msgs[0] || null
        const myMember = c.conversation_members?.find((m: ConvMember) => m.user_id === userId)
        const lastRead = myMember?.last_read_at ? new Date(myMember.last_read_at).getTime() : 0
        const unread = msgs.filter(m => m.sender_id !== userId && new Date(m.created_at).getTime() > lastRead).length
        return { ...c, last_message: lastMsg, unread_count: unread }
      }).filter(Boolean) as Conversation[]

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

  useEffect(() => {
    if (initialConvId) { setTab('dm'); setActiveConvId(initialConvId); setMobileShowChat(true) }
  }, [initialConvId])

  // ── DM-Nachrichten ────────────────────────────────────────────────────────
  const loadDMMessages = useCallback(async (convId: string) => {
    const { data } = await supabase
      .from('messages')
      .select('*, profiles(id, name, avatar_url, nickname, role), reply_to:reply_to_id(content, profiles(name))')
      .eq('conversation_id', convId)
      .order('created_at', { ascending: true }).limit(100)
    setMessages((data as Message[]) ?? [])
    await supabase.from('conversation_members')
      .update({ last_read_at: new Date().toISOString() })
      .eq('conversation_id', convId).eq('user_id', userId)
    setConversations(prev => prev.map(c => c.id === convId ? { ...c, unread_count: 0 } : c))
  }, [userId, supabase])

  useEffect(() => {
    if (!activeConvId) return
    loadDMMessages(activeConvId)
    if (channelRef.current) supabase.removeChannel(channelRef.current)
    const ch = supabase
      .channel(`dm:${activeConvId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${activeConvId}` },
        async (payload) => {
          const msg = payload.new as Message
          if (!msg.profiles) {
            const { data: p } = await supabase.from('profiles').select('id, name, avatar_url, nickname, role').eq('id', msg.sender_id).single()
            msg.profiles = p
          }
          msg.reactions = []
          setMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg])
          await supabase.from('conversation_members')
            .update({ last_read_at: new Date().toISOString() })
            .eq('conversation_id', activeConvId).eq('user_id', userId)
          setConversations(prev => prev.map(c => c.id === activeConvId ? { ...c, unread_count: 0 } : c))
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages', filter: `conversation_id=eq.${activeConvId}` },
        (payload) => {
          setMessages(prev => prev.map(m => m.id === (payload.new as Message).id ? { ...m, ...(payload.new as Message) } : m))
        })
      .subscribe()
    channelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeConvId, loadDMMessages, userId])

  // Auto-Scroll
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, communityMessages, tab])

  // ── Nachricht senden ──────────────────────────────────────────────────────
  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || sending) return
    const roomId = tab === 'community' ? communityRoom?.id : activeConvId
    if (!roomId) return
    if (tab === 'community' && communityRoom?.is_locked && !isAdmin) return
    if (isBanned) return

    setSending(true)
    const content = newMessage.trim()
    setNewMessage('')
    setReplyTo(null)
    await supabase.from('messages').insert({
      conversation_id: roomId,
      sender_id: userId,
      content,
      reply_to_id: replyTo?.id ?? null
    })
    setSending(false)
    setTimeout(() => inputRef.current?.focus(), 50)
  }

  // ── Typing Indicator ──────────────────────────────────────────────────────
  const handleInputChange = (val: string) => {
    setNewMessage(val)
    if (tab === 'community' && val.length > 0) {
      if (!isTyping) {
        setIsTyping(true)
        broadcastTyping()
      }
      if (typingTimeout.current) clearTimeout(typingTimeout.current)
      typingTimeout.current = setTimeout(() => setIsTyping(false), 2000)
    }
  }

  // ── Reaktion hinzufügen/entfernen ─────────────────────────────────────────
  const handleReaction = async (msgId: string, emoji: string) => {
    setShowEmojiFor(null)
    const currentMsgs = tab === 'community' ? communityMessages : messages
    const msg = currentMsgs.find(m => m.id === msgId)
    const existing = msg?.reactions?.find(r => r.user_id === userId && r.emoji === emoji)

    if (existing) {
      await supabase.from('message_reactions').delete().eq('message_id', msgId).eq('user_id', userId).eq('emoji', emoji)
    } else {
      await supabase.from('message_reactions').insert({ message_id: msgId, user_id: userId, emoji })
    }

    // Optimistic update for DMs (community is realtime)
    if (tab === 'dm') {
      setMessages(prev => prev.map(m => {
        if (m.id !== msgId) return m
        if (existing) {
          return { ...m, reactions: (m.reactions ?? []).filter(r => !(r.user_id === userId && r.emoji === emoji)) }
        } else {
          return { ...m, reactions: [...(m.reactions ?? []), { message_id: msgId, user_id: userId, emoji }] }
        }
      }))
    }
  }

  // ── Nachricht löschen (Soft-Delete) ────────────────────────────────────────
  const handleDeleteMessage = async (msgId: string, senderId: string) => {
    setMsgMenuFor(null)
    if (!isAdmin && senderId !== userId) return
    await supabase.from('messages').update({ deleted_at: new Date().toISOString() }).eq('id', msgId)

    const update = (msgs: Message[]) => msgs.map(m => m.id === msgId ? { ...m, deleted_at: new Date().toISOString() } : m)
    if (tab === 'community') setCommunityMessages(update)
    else setMessages(update)
  }

  // ── Nachricht anpinnen (Admin) ─────────────────────────────────────────────
  const handlePinMessage = async (msgId: string, currentPinned: boolean) => {
    setMsgMenuFor(null)
    if (!isAdmin) return
    // Unpin all first
    if (!currentPinned && communityRoom?.id) {
      await supabase.from('messages').update({ pinned: false }).eq('conversation_id', communityRoom.id)
    }
    await supabase.from('messages').update({ pinned: !currentPinned }).eq('id', msgId)
    if (currentPinned) {
      setPinnedMessage(null)
    } else {
      const msg = communityMessages.find(m => m.id === msgId)
      if (msg) setPinnedMessage({ ...msg, pinned: true })
    }
    setCommunityMessages(prev => prev.map(m => {
      if (!currentPinned) return { ...m, pinned: m.id === msgId }
      return { ...m, pinned: m.id === msgId ? false : m.pinned }
    }))
  }

  // ── Admin: Nutzer vom Chat bannen ──────────────────────────────────────────
  const handleBanUser = async (targetUserId: string, targetName: string) => {
    setMsgMenuFor(null)
    if (!isAdmin || targetUserId === userId) return
    const { data: { user } } = await supabase.auth.getUser()
    const exists = await supabase.from('chat_banned_users').select('id').eq('user_id', targetUserId).single()
    if (exists.data) {
      // Already banned – unban
      await supabase.from('chat_banned_users').delete().eq('user_id', targetUserId)
      alert(`${targetName} wurde entsperrt.`)
    } else {
      await supabase.from('chat_banned_users').insert({ user_id: targetUserId, banned_by: user?.id, reason: 'Admin-Aktion aus Chat' })
      alert(`${targetName} wurde vom Chat gesperrt.`)
    }
  }

  // ── Admin: Community-Raum sperren/entsperren ──────────────────────────────
  const handleToggleLock = async () => {
    if (!isAdmin || !communityRoom) return
    const newLocked = !communityRoom.is_locked
    await supabase.from('conversations').update({
      is_locked: newLocked,
      locked_by: newLocked ? userId : null,
      locked_at: newLocked ? new Date().toISOString() : null,
      locked_reason: newLocked ? (lockReason.trim() || null) : null,
    }).eq('id', communityRoom.id)
    setCommunityRoom(prev => prev ? { ...prev, is_locked: newLocked, locked_reason: lockReason.trim() || null } : prev)
    setLockReason('')
    setShowLockForm(false)
  }

  // ── Konversation öffnen ───────────────────────────────────────────────────
  const openConv = (conv: Conversation) => {
    setActiveConvId(conv.id)
    setMobileShowChat(true)
    setConversations(prev => prev.map(c => c.id === conv.id ? { ...c, unread_count: 0 } : c))
  }

  const getConvTitle = (conv: Conversation) => {
    if (conv.title) return conv.title
    const other = conv.conversation_members?.find(m => m.user_id !== userId)
    return other?.profiles?.name ?? other?.profiles?.nickname ?? other?.profiles?.email?.split('@')[0] ?? 'Direktnachricht'
  }
  const getConvInitials = (conv: Conversation) => getConvTitle(conv).split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  const getConvAvatar = (conv: Conversation): string | null => {
    if (conv.type === 'group') return null
    return conv.conversation_members?.find(m => m.user_id !== userId)?.profiles?.avatar_url ?? null
  }

  const activeConv = conversations.find(c => c.id === activeConvId) ?? null
  const isLocked = tab === 'community' && communityRoom?.is_locked && !isAdmin

  // Search filter
  const filteredCommunityMessages = showSearch && searchQuery.trim()
    ? communityMessages.filter(m => !m.deleted_at && m.content.toLowerCase().includes(searchQuery.toLowerCase()))
    : communityMessages

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col">
      {/* Header */}
      <div className="mb-4 flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Nachrichten & Chat</h1>
          <p className="text-sm text-gray-500 mt-0.5">Community-Raum & private Direktnachrichten</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          {tab === 'dm' && (
            <button onClick={() => setShowNewChat(true)} className="btn-primary gap-2 flex items-center">
              <Plus className="w-4 h-4" /> Neue Nachricht
            </button>
          )}
          {tab === 'community' && isAdmin && (
            <button
              onClick={() => { setShowLockForm(!showLockForm); setShowRules(false) }}
              className={cn('flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition-all',
                communityRoom?.is_locked
                  ? 'bg-green-600 text-white hover:bg-green-700'
                  : 'bg-red-500 text-white hover:bg-red-600'
              )}
            >
              {communityRoom?.is_locked
                ? <><Volume2 className="w-4 h-4" /> Entsperren</>
                : <><VolumeX className="w-4 h-4" /> Sperren</>}
            </button>
          )}
        </div>
      </div>

      {/* Admin Lock Form */}
      {showLockForm && isAdmin && tab === 'community' && (
        <div className="mb-3 p-4 bg-amber-50 border border-amber-200 rounded-xl flex flex-col sm:flex-row gap-3 items-start sm:items-center">
          {!communityRoom?.is_locked ? (
            <>
              <input
                value={lockReason}
                onChange={e => setLockReason(e.target.value)}
                placeholder="Grund für Sperrung (optional)…"
                className="input flex-1 text-sm"
              />
              <div className="flex gap-2">
                <button onClick={() => setShowLockForm(false)} className="btn-secondary text-sm py-2 px-3">Abbrechen</button>
                <button onClick={handleToggleLock} className="bg-red-500 text-white rounded-xl px-4 py-2 text-sm font-semibold hover:bg-red-600 transition-all">
                  Chat sperren
                </button>
              </div>
            </>
          ) : (
            <>
              <p className="text-sm text-amber-800 flex-1">Chat ist derzeit gesperrt. Entsperren?</p>
              <div className="flex gap-2">
                <button onClick={() => setShowLockForm(false)} className="btn-secondary text-sm py-2 px-3">Abbrechen</button>
                <button onClick={handleToggleLock} className="bg-green-600 text-white rounded-xl px-4 py-2 text-sm font-semibold hover:bg-green-700 transition-all">
                  Jetzt entsperren
                </button>
              </div>
            </>
          )}
        </div>
      )}

      {/* Ban Banner */}
      {isBanned && (
        <div className="flex items-center gap-3 px-4 py-3 bg-red-50 border border-red-200 rounded-xl mb-4">
          <ShieldOff className="w-5 h-5 text-red-500 flex-shrink-0" />
          <p className="text-sm text-red-700 font-medium">Du wurdest vom Chat gesperrt und kannst keine Nachrichten senden.</p>
        </div>
      )}

      {/* Tab-Leiste */}
      <div className="flex gap-1 bg-warm-100 p-1 rounded-xl mb-4 flex-shrink-0">
        <button onClick={() => setTab('community')}
          className={cn('flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-sm font-semibold transition-all',
            tab === 'community' ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700')}>
          <Hash className="w-4 h-4" />
          <span className="hidden sm:inline">Community-Raum</span>
          <span className="sm:hidden">Community</span>
          {communityRoom?.is_locked && <Lock className="w-3 h-3 text-red-500" />}
        </button>
        <button onClick={() => setTab('dm')}
          className={cn('flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-sm font-semibold transition-all',
            tab === 'dm' ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700')}>
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

      {/* ══ Community-Raum ══ */}
      {tab === 'community' && (
        <div className="flex-1 card flex flex-col min-h-0">
          {/* Room Header */}
          <div className="flex items-center gap-3 px-5 py-3.5 border-b border-warm-100 flex-shrink-0">
            <div className={cn('w-8 h-8 rounded-xl flex items-center justify-center',
              communityRoom?.is_locked ? 'bg-red-100' : 'bg-primary-100')}>
              {communityRoom?.is_locked
                ? <Lock className="w-4 h-4 text-red-600" />
                : <Hash className="w-4 h-4 text-primary-600" />}
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-gray-900 text-sm">Community Chat</p>
              {communityRoom?.is_locked ? (
                <p className="text-xs text-red-600 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-red-500 inline-block" />
                  Gesperrt{communityRoom.locked_reason ? ` – ${communityRoom.locked_reason}` : ' – nur Admins können schreiben'}
                </p>
              ) : (
                <p className="text-xs text-green-600 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-green-500 inline-block animate-pulse" />
                  Live – {communityMessages.filter(m => !m.deleted_at).length} Nachrichten
                </p>
              )}
            </div>
            <div className="flex items-center gap-2">
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-green-50 border border-green-200">
                <Users className="w-3.5 h-3.5 text-green-600" />
                <span className="text-xs font-medium text-green-700">{onlineCount} online</span>
              </div>
              {/* Search toggle */}
              <button
                onClick={() => { setShowSearch(!showSearch); setSearchQuery('') }}
                className={cn('p-1.5 rounded-lg transition-all', showSearch ? 'bg-primary-100 text-primary-600' : 'hover:bg-warm-100 text-gray-400')}
                title="Suche">
                <Search className="w-4 h-4" />
              </button>
              {/* Rules toggle */}
              <button
                onClick={() => setShowRules(!showRules)}
                className={cn('p-1.5 rounded-lg transition-all', showRules ? 'bg-primary-100 text-primary-600' : 'hover:bg-warm-100 text-gray-400')}
                title="Regeln">
                <Info className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Search Bar */}
          {showSearch && (
            <div className="px-4 py-2 border-b border-warm-100 flex-shrink-0">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
                <input
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  placeholder="Nachrichten durchsuchen…"
                  className="input pl-8 py-1.5 text-sm w-full"
                  autoFocus
                />
                {searchQuery && (
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">
                    {filteredCommunityMessages.length} Treffer
                  </span>
                )}
              </div>
            </div>
          )}

          {/* Rules Panel */}
          {showRules && (
            <div className="px-5 py-4 bg-blue-50 border-b border-blue-100 flex-shrink-0">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm font-bold text-blue-900 flex items-center gap-1.5">
                  <Info className="w-4 h-4" /> Chat-Regeln
                </p>
                <button onClick={() => setShowRules(false)} className="text-blue-400 hover:text-blue-600">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <ul className="space-y-1">
                {CHAT_RULES.map((rule, i) => (
                  <li key={i} className="text-xs text-blue-800 flex items-start gap-1.5">
                    <span className="text-blue-400 font-bold mt-0.5">{i + 1}.</span>
                    {rule}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Lock Banner für nicht-Admins */}
          {communityRoom?.is_locked && !isAdmin && (
            <div className="flex items-center gap-3 px-5 py-3 bg-red-50 border-b border-red-100">
              <AlertCircle className="w-4 h-4 text-red-500 flex-shrink-0" />
              <p className="text-sm text-red-700">
                Der Community-Chat wurde vom Administrator gesperrt.
                {communityRoom.locked_reason && ` Grund: ${communityRoom.locked_reason}`}
              </p>
            </div>
          )}

          {/* Pinned Message */}
          {pinnedMessage && !pinnedMessage.deleted_at && (
            <div className="flex items-center gap-2 px-5 py-2 bg-amber-50 border-b border-amber-100 flex-shrink-0">
              <Pin className="w-3.5 h-3.5 text-amber-600 flex-shrink-0" />
              <p className="text-xs text-amber-800 flex-1 truncate">
                <span className="font-semibold">{pinnedMessage.profiles?.name ?? 'Nutzer'}: </span>
                {pinnedMessage.content}
              </p>
              {isAdmin && (
                <button onClick={() => handlePinMessage(pinnedMessage.id, true)}
                  className="text-amber-500 hover:text-amber-700">
                  <X className="w-3.5 h-3.5" />
                </button>
              )}
            </div>
          )}

          {/* Nachrichten */}
          <div className="flex-1 overflow-y-auto p-4 space-y-1 no-scrollbar"
            onClick={() => { setShowEmojiFor(null); setMsgMenuFor(null) }}>
            {communityLoading ? (
              <div className="flex flex-col items-center justify-center h-full py-12">
                <Loader2 className="w-8 h-8 text-primary-300 animate-spin mb-3" />
                <p className="text-sm text-gray-400">Raum wird geladen…</p>
              </div>
            ) : filteredCommunityMessages.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full py-12">
                {showSearch && searchQuery ? (
                  <>
                    <Search className="w-12 h-12 text-gray-200 mb-3" />
                    <p className="font-semibold text-gray-600 mb-1">Keine Treffer</p>
                    <p className="text-sm text-gray-400">Versuche andere Suchbegriffe</p>
                  </>
                ) : (
                  <>
                    <Hash className="w-12 h-12 text-gray-200 mb-3" />
                    <p className="font-semibold text-gray-600 mb-1">Noch keine Nachrichten</p>
                    <p className="text-sm text-gray-400">Sei der Erste! 👋</p>
                  </>
                )}
              </div>
            ) : (
              <>
                <MessageGroup
                  messages={filteredCommunityMessages}
                  userId={userId}
                  isAdmin={isAdmin}
                  onReply={msg => { setReplyTo(msg); inputRef.current?.focus() }}
                  onReaction={(msgId, emoji) => handleReaction(msgId, emoji)}
                  onDelete={(msgId, senderId) => handleDeleteMessage(msgId, senderId)}
                  onPin={(msgId, pinned) => handlePinMessage(msgId, pinned)}
                  onBanUser={(targetUserId, name) => handleBanUser(targetUserId, name)}
                  showEmojiFor={showEmojiFor}
                  setShowEmojiFor={setShowEmojiFor}
                  msgMenuFor={msgMenuFor}
                  setMsgMenuFor={setMsgMenuFor}
                />
                <div ref={messagesEndRef} />
              </>
            )}
          </div>

          {/* Typing Indicator */}
          {typingUsers.length > 0 && (
            <div className="px-5 py-1.5 text-xs text-gray-400 flex items-center gap-2 border-t border-warm-50">
              <span className="flex gap-0.5">
                <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style={{animationDelay:'0ms'}} />
                <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style={{animationDelay:'150ms'}} />
                <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style={{animationDelay:'300ms'}} />
              </span>
              <span className="font-medium text-gray-500">{typingUsers.join(', ')}</span> schreibt…
            </div>
          )}

          {/* Reply Preview */}
          {replyTo && (
            <div className="px-4 py-2 bg-primary-50 border-t border-primary-100 flex items-center gap-2">
              <Reply className="w-3.5 h-3.5 text-primary-500 flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <p className="text-xs text-primary-600 font-medium">Antwort auf {replyTo.profiles?.name ?? 'Nutzer'}</p>
                <p className="text-xs text-gray-500 truncate">{replyTo.content}</p>
              </div>
              <button onClick={() => setReplyTo(null)} className="p-1 text-gray-400 hover:text-gray-600">
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
          )}

          {/* Eingabe */}
          <form onSubmit={sendMessage} className="px-4 py-3 border-t border-warm-100 flex-shrink-0 bg-white">
            <div className="flex gap-2 items-center">
              <div className="flex-1 relative">
                <input
                  ref={inputRef}
                  type="text" value={newMessage}
                  onChange={e => handleInputChange(e.target.value)}
                  placeholder={
                    isBanned ? 'Du bist gesperrt…' :
                    isLocked ? 'Chat ist gesperrt…' :
                    'Nachricht an die Community…'
                  }
                  disabled={isLocked || isBanned}
                  maxLength={500}
                  className="input w-full text-sm disabled:opacity-60 disabled:cursor-not-allowed pr-16"
                />
                {newMessage.length > 400 && (
                  <span className={cn('absolute right-3 top-1/2 -translate-y-1/2 text-[10px]',
                    newMessage.length > 480 ? 'text-red-500' : 'text-gray-400')}>
                    {500 - newMessage.length}
                  </span>
                )}
              </div>
              <button type="submit"
                disabled={sending || !newMessage.trim() || isLocked || isBanned}
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
          <div className={cn('w-72 flex-shrink-0 flex flex-col bg-white rounded-2xl border border-warm-200 shadow-sm overflow-hidden',
            mobileShowChat ? 'hidden lg:flex' : 'flex')}>
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
              <div className="flex items-center gap-1">
                <button onClick={loadConversations}
                  className="p-1.5 rounded-lg hover:bg-warm-100 text-gray-400 hover:text-gray-600 transition-all"
                  title="Aktualisieren">
                  <RefreshCw className="w-3.5 h-3.5" />
                </button>
                <button onClick={() => setShowNewChat(true)}
                  className="p-1.5 rounded-lg hover:bg-warm-100 text-gray-500 hover:text-primary-600 transition-all">
                  <Plus className="w-4 h-4" />
                </button>
              </div>
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
                <p className="text-xs text-gray-400 mt-1 mb-4">Klicke bei einem Inserat auf „DM"</p>
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
          <div className={cn('flex-1 card flex flex-col min-h-0', !mobileShowChat ? 'hidden lg:flex' : 'flex')}>
            {activeConv ? (
              <>
                <div className="flex items-center gap-3 px-5 py-3.5 border-b border-warm-100 flex-shrink-0">
                  <button onClick={() => setMobileShowChat(false)}
                    className="lg:hidden p-1.5 rounded-lg hover:bg-warm-100 text-gray-500">
                    <ArrowLeft className="w-4 h-4" />
                  </button>
                  <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0 overflow-hidden">
                    {getConvAvatar(activeConv)
                      ? <img src={getConvAvatar(activeConv)!} alt="" className="w-full h-full object-cover" />
                      : activeConv.type === 'group' ? <Users className="w-5 h-5" /> : getConvInitials(activeConv)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-gray-900 text-sm truncate">{getConvTitle(activeConv)}</p>
                    {activeConv.post_id
                      ? <p className="text-xs text-primary-600">📋 Bezüglich einem Inserat</p>
                      : <p className="text-xs text-gray-400 flex items-center gap-1"><Lock className="w-2.5 h-2.5" /> Ende-zu-Ende privat</p>}
                  </div>
                  <span className="text-xs text-gray-400 hidden sm:block">
                    {messages.filter(m => !m.deleted_at).length} Nachrichten
                  </span>
                </div>

                <div className="flex-1 overflow-y-auto p-4 space-y-1 no-scrollbar"
                  onClick={() => { setShowEmojiFor(null); setMsgMenuFor(null) }}>
                  {messages.length === 0 ? (
                    <div className="flex flex-col items-center justify-center h-full py-12">
                      <div className="w-14 h-14 rounded-full bg-primary-50 flex items-center justify-center mb-3">
                        <Lock className="w-7 h-7 text-primary-300" />
                      </div>
                      <p className="font-semibold text-gray-600 mb-1">Neue Konversation</p>
                      <p className="text-sm text-gray-400">
                        {activeConv.post_id ? 'Schreib bezüglich des Inserats!' : 'Schreib die erste Nachricht!'}
                      </p>
                    </div>
                  ) : (
                    <>
                      <MessageGroup
                        messages={messages}
                        userId={userId}
                        isAdmin={isAdmin}
                        onReply={msg => { setReplyTo(msg); inputRef.current?.focus() }}
                        onReaction={(msgId, emoji) => handleReaction(msgId, emoji)}
                        onDelete={(msgId, senderId) => handleDeleteMessage(msgId, senderId)}
                        onPin={() => {}}
                        onBanUser={() => {}}
                        showEmojiFor={showEmojiFor}
                        setShowEmojiFor={setShowEmojiFor}
                        msgMenuFor={msgMenuFor}
                        setMsgMenuFor={setMsgMenuFor}
                      />
                      <div ref={messagesEndRef} />
                    </>
                  )}
                </div>

                {replyTo && (
                  <div className="px-4 py-2 bg-primary-50 border-t border-primary-100 flex items-center gap-2">
                    <Reply className="w-3.5 h-3.5 text-primary-500 flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-xs text-primary-600 font-medium">Antwort auf {replyTo.profiles?.name ?? 'Nutzer'}</p>
                      <p className="text-xs text-gray-500 truncate">{replyTo.content}</p>
                    </div>
                    <button onClick={() => setReplyTo(null)} className="p-1 text-gray-400 hover:text-gray-600">
                      <X className="w-3.5 h-3.5" />
                    </button>
                  </div>
                )}

                <form onSubmit={sendMessage} className="px-4 py-3 border-t border-warm-100 flex-shrink-0 bg-white">
                  <div className="flex gap-2 items-center">
                    <div className="flex-1 relative">
                      <input
                        ref={tab === 'dm' ? inputRef : undefined}
                        type="text" value={newMessage} onChange={e => setNewMessage(e.target.value)}
                        placeholder={`Nachricht an ${getConvTitle(activeConv)}…`}
                        maxLength={500}
                        className="input w-full text-sm pr-14"
                      />
                      {newMessage.length > 400 && (
                        <span className={cn('absolute right-3 top-1/2 -translate-y-1/2 text-[10px]',
                          newMessage.length > 480 ? 'text-red-500' : 'text-gray-400')}>
                          {500 - newMessage.length}
                        </span>
                      )}
                    </div>
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
                  <p className="text-sm text-gray-400 mb-5 max-w-xs">Oder klicke bei einem Inserat auf „DM"</p>
                  <button onClick={() => setShowNewChat(true)} className="btn-primary gap-2">
                    <Plus className="w-4 h-4" /> Neue Nachricht
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {showNewChat && (
        <NewChatModal userId={userId} onClose={() => setShowNewChat(false)}
          onCreated={(convId) => {
            setShowNewChat(false); setTab('dm')
            loadConversations().then(() => { setActiveConvId(convId); setMobileShowChat(true) })
          }} />
      )}
    </div>
  )
}

// ─── MessageGroup ─────────────────────────────────────────────────────────────
function MessageGroup({ messages, userId, isAdmin, onReply, onReaction, onDelete, onPin, onBanUser, showEmojiFor, setShowEmojiFor, msgMenuFor, setMsgMenuFor }: {
  messages: Message[]
  userId: string
  isAdmin: boolean
  onReply: (msg: Message) => void
  onReaction: (msgId: string, emoji: string) => void
  onDelete: (msgId: string, senderId: string) => void
  onPin: (msgId: string, pinned: boolean) => void
  onBanUser: (targetUserId: string, name: string) => void
  showEmojiFor: string | null
  setShowEmojiFor: (id: string | null) => void
  msgMenuFor: string | null
  setMsgMenuFor: (id: string | null) => void
}) {
  return (
    <>
      {messages.map((msg, i) => {
        const isMe = msg.sender_id === userId
        const isDeleted = !!msg.deleted_at
        const prevMsg = messages[i - 1]
        const nextMsg = messages[i + 1]
        const sameAuthorPrev = prevMsg?.sender_id === msg.sender_id && !prevMsg.deleted_at
        const sameAuthorNext = nextMsg?.sender_id === msg.sender_id && !nextMsg.deleted_at
        const timeDiff = prevMsg ? new Date(msg.created_at).getTime() - new Date(prevMsg.created_at).getTime() : Infinity
        const showAvatar = !sameAuthorPrev || timeDiff > 5 * 60 * 1000
        const isLast = !sameAuthorNext
        const isAdminMsg = msg.profiles?.role === 'admin' || ADMIN_EMAILS.includes(msg.profiles?.email ?? '')
        const reactionGroups: Record<string, number> = {}
        const myReactions: Record<string, boolean> = {}
        for (const r of msg.reactions ?? []) {
          reactionGroups[r.emoji] = (reactionGroups[r.emoji] ?? 0) + 1
          if (r.user_id === userId) myReactions[r.emoji] = true
        }
        const isPinned = !!msg.pinned

        // Time separator
        const showTimeSep = timeDiff > 30 * 60 * 1000 // 30min gap
        const msgName = msg.profiles?.name ?? msg.profiles?.nickname ?? 'Nutzer'

        return (
          <div key={msg.id}>
            {showTimeSep && (
              <div className="flex items-center gap-2 my-3">
                <div className="flex-1 h-px bg-warm-100" />
                <span className="text-[10px] text-gray-400 font-medium px-2">
                  {new Date(msg.created_at).toLocaleDateString('de-AT', { weekday: 'short', day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}
                </span>
                <div className="flex-1 h-px bg-warm-100" />
              </div>
            )}
            <div className={cn('group flex gap-2 mb-0.5 relative', isMe ? 'justify-end' : 'justify-start', !showAvatar && !isMe && 'pl-9',
              isPinned && !isDeleted && 'bg-amber-50/50 -mx-2 px-2 rounded-lg'
            )}>
              {isPinned && !isDeleted && (
                <Pin className="absolute -top-1 right-2 w-3 h-3 text-amber-400" />
              )}
              {!isMe && showAvatar && (
                <div className="w-7 h-7 rounded-full bg-warm-200 flex items-center justify-center text-xs font-bold text-gray-600 flex-shrink-0 mt-auto overflow-hidden relative">
                  {msg.profiles?.avatar_url
                    ? <img src={msg.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                    : (msg.profiles?.name ?? '?')[0].toUpperCase()}
                  {isAdminMsg && (
                    <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-amber-400 rounded-full flex items-center justify-center">
                      <Crown className="w-2 h-2 text-white" />
                    </span>
                  )}
                </div>
              )}
              {!isMe && !showAvatar && <div className="w-7 flex-shrink-0" />}

              <div className="max-w-[72%] space-y-0.5">
                {!isMe && showAvatar && (
                  <div className="flex items-center gap-1.5 ml-1">
                    <p className="text-[10px] font-semibold text-primary-600">{msgName}</p>
                    {isAdminMsg && (
                      <span className="text-[9px] font-bold bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full">ADMIN</span>
                    )}
                  </div>
                )}

                {/* Reply context */}
                {msg.reply_to && !isDeleted && (
                  <div className={cn('px-3 py-1.5 rounded-lg border-l-2 text-xs mb-0.5',
                    isMe ? 'bg-primary-700/30 border-primary-300 text-primary-100' : 'bg-warm-200 border-gray-300 text-gray-500')}>
                    <p className="font-semibold">{(msg.reply_to as any).profiles?.name ?? 'Nutzer'}</p>
                    <p className="truncate">{msg.reply_to.content}</p>
                  </div>
                )}

                <div className="relative">
                  <div className={cn(
                    'px-3.5 py-2.5 text-sm shadow-sm',
                    isDeleted
                      ? 'bg-gray-100 text-gray-400 italic rounded-2xl'
                      : isMe
                        ? cn('bg-primary-600 text-white', isLast ? 'rounded-2xl rounded-br-sm' : 'rounded-2xl')
                        : cn('bg-warm-100 text-gray-800', isLast ? 'rounded-2xl rounded-bl-sm' : 'rounded-2xl')
                  )}>
                    {isDeleted
                      ? <p>Nachricht gelöscht</p>
                      : <p className="leading-relaxed break-words whitespace-pre-wrap">{msg.content}</p>}
                    {!isDeleted && (
                      <div className={cn('flex items-center gap-1 mt-1', isMe ? 'justify-end' : 'justify-start')}>
                        <p className={cn('text-[10px]', isMe ? 'text-primary-200' : 'text-gray-400')}>
                          {formatRelativeTime(msg.created_at)}
                        </p>
                        {isMe && <CheckCheck className="w-3 h-3 text-primary-200" />}
                      </div>
                    )}
                  </div>

                  {/* Action Buttons – hover */}
                  {!isDeleted && (
                    <div className={cn(
                      'absolute top-0 flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity z-10',
                      isMe ? '-left-28' : '-right-28'
                    )}>
                      <button onClick={(e) => { e.stopPropagation(); onReply(msg) }}
                        className="p-1.5 rounded-lg bg-white shadow border border-warm-200 text-gray-500 hover:text-primary-600 transition-all"
                        title="Antworten">
                        <Reply className="w-3 h-3" />
                      </button>
                      <button onClick={(e) => { e.stopPropagation(); setShowEmojiFor(showEmojiFor === msg.id ? null : msg.id) }}
                        className="p-1.5 rounded-lg bg-white shadow border border-warm-200 text-gray-500 hover:text-yellow-500 transition-all"
                        title="Reaktion">
                        <Smile className="w-3 h-3" />
                      </button>
                      {(isMe || isAdmin) && (
                        <button onClick={(e) => { e.stopPropagation(); setMsgMenuFor(msgMenuFor === msg.id ? null : msg.id) }}
                          className="p-1.5 rounded-lg bg-white shadow border border-warm-200 text-gray-500 hover:text-gray-700 transition-all"
                          title="Mehr">
                          <MoreVertical className="w-3 h-3" />
                        </button>
                      )}
                    </div>
                  )}

                  {/* More Menu */}
                  {msgMenuFor === msg.id && (
                    <div className={cn(
                      'absolute z-30 top-8 bg-white rounded-2xl shadow-xl border border-warm-200 py-1 min-w-[140px]',
                      isMe ? 'right-0' : 'left-0'
                    )} onClick={e => e.stopPropagation()}>
                      {(isMe || isAdmin) && (
                        <button onClick={() => onDelete(msg.id, msg.sender_id)}
                          className="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-all">
                          <Trash2 className="w-3.5 h-3.5" /> Löschen
                        </button>
                      )}
                      {isAdmin && (
                        <button onClick={() => onPin(msg.id, !!msg.pinned)}
                          className="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm text-amber-600 hover:bg-amber-50 transition-all">
                          <Pin className="w-3.5 h-3.5" /> {msg.pinned ? 'Loslösen' : 'Anpinnen'}
                        </button>
                      )}
                      {isAdmin && !isMe && (
                        <button onClick={() => onBanUser(msg.sender_id, msgName)}
                          className="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm text-gray-600 hover:bg-gray-50 transition-all">
                          <UserX className="w-3.5 h-3.5" /> Nutzer sperren
                        </button>
                      )}
                    </div>
                  )}

                  {/* Emoji Picker */}
                  {showEmojiFor === msg.id && (
                    <div className={cn(
                      'absolute z-20 flex gap-1 p-2 bg-white rounded-2xl shadow-xl border border-warm-200 bottom-full mb-1',
                      isMe ? 'right-0' : 'left-0'
                    )} onClick={e => e.stopPropagation()}>
                      {QUICK_EMOJIS.map(emoji => (
                        <button key={emoji} onClick={() => onReaction(msg.id, emoji)}
                          className={cn('w-8 h-8 rounded-xl text-base flex items-center justify-center hover:bg-warm-100 transition-all',
                            myReactions[emoji] ? 'bg-primary-100 ring-1 ring-primary-400' : '')}>
                          {emoji}
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                {/* Reaction Bubbles */}
                {Object.keys(reactionGroups).length > 0 && !isDeleted && (
                  <div className={cn('flex flex-wrap gap-1 mt-0.5', isMe ? 'justify-end' : 'justify-start')}>
                    {Object.entries(reactionGroups).map(([emoji, count]) => (
                      <button key={emoji} onClick={() => onReaction(msg.id, emoji)}
                        className={cn(
                          'flex items-center gap-1 px-1.5 py-0.5 rounded-full text-xs border transition-all',
                          myReactions[emoji]
                            ? 'bg-primary-100 border-primary-300 text-primary-700'
                            : 'bg-white border-warm-200 text-gray-600 hover:bg-warm-50'
                        )}>
                        {emoji} {count > 1 && <span className="font-medium">{count}</span>}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        )
      })}
    </>
  )
}

// ─── ConversationItem ─────────────────────────────────────────────────────────
function ConversationItem({ conv, active, title, initials, avatarUrl, onClick, userId }: {
  conv: Conversation; active: boolean; title: string; initials: string; avatarUrl: string | null; onClick: () => void; userId: string
}) {
  const unread = conv.unread_count ?? 0
  return (
    <button onClick={onClick} className={cn(
      'w-full flex items-center gap-3 px-3 py-2.5 text-left transition-all',
      active ? 'bg-primary-50 border-l-2 border-primary-500' : 'hover:bg-warm-50 border-l-2 border-transparent',
      unread > 0 && !active && 'bg-blue-50/50'
    )}>
      <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0 relative overflow-hidden">
        {avatarUrl ? <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
          : conv.type === 'group' ? <Users className="w-5 h-5" /> : initials}
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <p className={cn('text-sm truncate', unread > 0 ? 'font-bold text-gray-900' : 'font-semibold text-gray-700')}>{title}</p>
        <p className={cn('text-xs truncate mt-0.5', unread > 0 ? 'text-gray-700 font-medium' : 'text-gray-400')}>
          {conv.last_message
            ? (conv.last_message.sender_id === userId ? '✓ Du: ' : '') + conv.last_message.content
            : conv.post_id ? '📋 Bezüglich einem Inserat' : 'Noch keine Nachrichten'}
        </p>
      </div>
      <div className="flex flex-col items-end gap-1 flex-shrink-0">
        {conv.last_message && <span className="text-[10px] text-gray-400">{formatRelativeTime(conv.last_message.created_at)}</span>}
        {unread > 0 ? <span className="w-4 h-4 bg-primary-600 rounded-full" />
          : conv.last_message?.sender_id === userId ? <Check className="w-3 h-3 text-gray-300" /> : null}
      </div>
    </button>
  )
}

// ─── NewChatModal ─────────────────────────────────────────────────────────────
function NewChatModal({ userId, onClose, onCreated }: { userId: string; onClose: () => void; onCreated: (convId: string) => void }) {
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
      const { data } = await supabase.from('profiles').select('id, name, email, avatar_url, nickname')
        .neq('id', userId).or(`name.ilike.%${query}%,nickname.ilike.%${query}%,email.ilike.%${query}%`).limit(8)
      setResults((data as Profile[]) ?? [])
      setSearching(false)
    }, 300)
    return () => clearTimeout(t)
  }, [query, userId, supabase])

  const toggle = (p: Profile) => setSelected(prev => prev.find(s => s.id === p.id) ? prev.filter(s => s.id !== p.id) : [...prev, p])

  const start = async () => {
    if (selected.length === 0 || creating) return
    setCreating(true)
    if (selected.length === 1) {
      const convId = await openOrCreateDM(userId, selected[0].id)
      if (convId) { onCreated(convId); return }
    } else {
      const { data: conv } = await supabase.from('conversations').insert({
        type: 'group', title: groupTitle || selected.map(s => s.name ?? s.email).join(', '),
      }).select().single()
      if (conv) {
        await supabase.from('conversation_members').insert(
          [userId, ...selected.map(s => s.id)].map(uid => ({ conversation_id: conv.id, user_id: uid }))
        )
        onCreated(conv.id); return
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
            <p className="text-xs text-gray-500 mt-0.5">Name, Nickname oder E-Mail suchen</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-warm-100 text-gray-500"><X className="w-5 h-5" /></button>
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
            <input value={groupTitle} onChange={e => setGroupTitle(e.target.value)} placeholder="Gruppenname (optional)" className="input" />
          )}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input value={query} onChange={e => setQuery(e.target.value)} placeholder="Suchen…" className="input pl-9" autoFocus />
          </div>
          <div className="space-y-1 max-h-60 overflow-y-auto no-scrollbar">
            {searching && <div className="flex justify-center py-4"><Loader2 className="w-5 h-5 text-primary-400 animate-spin" /></div>}
            {!searching && query.length >= 2 && results.length === 0 && <p className="text-sm text-gray-400 text-center py-4">Keine Nutzer gefunden</p>}
            {!searching && query.length < 2 && <p className="text-sm text-gray-400 text-center py-4">Mindestens 2 Zeichen…</p>}
            {results.map(p => {
              const isSel = selected.some(s => s.id === p.id)
              return (
                <button key={p.id} onClick={() => toggle(p)}
                  className={cn('w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all text-left',
                    isSel ? 'bg-primary-50 border border-primary-200' : 'hover:bg-warm-50 border border-transparent')}>
                  <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0 overflow-hidden">
                    {p.avatar_url ? <img src={p.avatar_url} alt="" className="w-full h-full rounded-full object-cover" /> : (p.name ?? p.email ?? '?')[0].toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-900 truncate">{p.name ?? p.email?.split('@')[0] ?? 'Unbekannt'}</p>
                    <p className="text-xs text-gray-500 truncate">{p.nickname ? '@' + p.nickname : p.email}</p>
                  </div>
                  {isSel && <div className="w-5 h-5 rounded-full bg-primary-600 flex items-center justify-center flex-shrink-0">
                    <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" /></svg>
                  </div>}
                </button>
              )
            })}
          </div>
        </div>
        <div className="p-5 border-t border-warm-100 flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1 justify-center">Abbrechen</button>
          <button onClick={start} disabled={selected.length === 0 || creating} className="btn-primary flex-1 justify-center">
            {creating ? <Loader2 className="w-4 h-4 animate-spin" /> : selected.length > 1 ? `Gruppe (${selected.length})` : 'Starten'}
          </button>
        </div>
      </div>
    </div>
  )
}
