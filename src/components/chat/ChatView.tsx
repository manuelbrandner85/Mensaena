'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import {
  Send, MessageCircle, Users, Plus, Search, X, ArrowLeft,
  Hash, Lock, CheckCheck, Check, Loader2, Mail, Smile,
  Trash2, Reply, ShieldOff, AlertCircle, Volume2, VolumeX, Crown,
  Pin, PinOff, Bell, BellOff, Edit2, MoreVertical, Megaphone,
  Image as ImageIcon, Paperclip, ChevronDown, ChevronRight,
  Wifi, WifiOff, Circle
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

interface ChatChannel {
  id: string
  name: string
  description: string | null
  emoji: string
  slug: string
  is_default: boolean
  is_locked: boolean
  locked_reason: string | null
  sort_order: number
  conversation_id: string
}

interface Reaction {
  emoji: string
  user_id: string
  message_id: string
}

interface PinnedMessage {
  id: string
  message_id: string
  conversation_id: string
  pinned_by: string
}

interface Announcement {
  id: string
  title: string
  content: string
  type: 'info' | 'warning' | 'success' | 'error'
  is_active: boolean
  created_at: string
  expires_at: string | null
}

interface Message {
  id: string
  conversation_id: string
  sender_id: string
  content: string
  created_at: string
  deleted_at?: string | null
  edited_at?: string | null
  is_pinned?: boolean
  reply_to_id?: string | null
  profiles?: Profile | null
  reactions?: Reaction[]
  reply_to?: { content: string; profiles?: { name?: string | null } | null } | null
}

const QUICK_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '✅']
const ADMIN_EMAILS = ['brandy13062@gmail.com', 'uwevetter@gmx.at']

// ─── openOrCreateDM ───────────────────────────────────────────────────────────
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
    .from('conversations').insert({ type: 'direct', title: null, post_id: postId ?? null }).select().single()
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

// ─── isAdminUser ─────────────────────────────────────────────────────────────
function isAdminUser(profile: Profile | null | undefined, email?: string | null): boolean {
  if (!profile && !email) return false
  return profile?.role === 'admin'
    || ADMIN_EMAILS.includes(profile?.email ?? '')
    || ADMIN_EMAILS.includes(email ?? '')
}

// ─── ChatView ─────────────────────────────────────────────────────────────────
export default function ChatView({ userId, initialConvId }: { userId: string; initialConvId?: string | null }) {
  const supabase = createClient()
  const [tab, setTab] = useState<'dm' | 'community'>(initialConvId ? 'dm' : 'community')

  // Community / Channels
  const [channels, setChannels] = useState<ChatChannel[]>([])
  const [activeChannelId, setActiveChannelId] = useState<string | null>(null)
  const [activeChannelConvId, setActiveChannelConvId] = useState<string | null>(null)
  const [communityMessages, setCommunityMessages] = useState<Message[]>([])
  const [communityRoom, setCommunityRoom] = useState<Conversation | null>(null)
  const [communityLoading, setCommunityLoading] = useState(true)
  const [pinnedMessages, setPinnedMessages] = useState<Message[]>([])
  const [showPinned, setShowPinned] = useState(false)
  const [announcements, setAnnouncements] = useState<Announcement[]>([])
  const [dismissedAnnouncements, setDismissedAnnouncements] = useState<Set<string>>(new Set())

  // DM
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [activeConvId, setActiveConvId] = useState<string | null>(initialConvId ?? null)
  const [messages, setMessages] = useState<Message[]>([])

  // UI State
  const [newMessage, setNewMessage] = useState('')
  const [editingMsgId, setEditingMsgId] = useState<string | null>(null)
  const [editContent, setEditContent] = useState('')
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
  const [lockReason, setLockReason] = useState('')
  const [showLockModal, setShowLockModal] = useState(false)
  const [showAnnounceModal, setShowAnnounceModal] = useState(false)
  const [announceTitle, setAnnounceTitle] = useState('')
  const [announceContent, setAnnounceContent] = useState('')
  const [announceType, setAnnounceType] = useState<'info' | 'warning' | 'success' | 'error'>('info')
  const [mobileShowChannels, setMobileShowChannels] = useState(false)

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
      const { data: profile } = await supabase.from('profiles').select('role, email').eq('id', user.id).single()
      setIsAdmin(isAdminUser(profile as Profile, user.email))
      try {
        const { data: ban } = await supabase.from('chat_banned_users').select('expires_at').eq('user_id', userId).single()
        if (ban && (!ban.expires_at || new Date(ban.expires_at) > new Date())) setIsBanned(true)
      } catch { /* not banned */ }
    }
    checkUser()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  // ── Kanäle laden ─────────────────────────────────────────────────────────
  const loadChannels = useCallback(async () => {
    const { data } = await supabase
      .from('chat_channels')
      .select('*')
      .order('sort_order', { ascending: true })
    if (data && data.length > 0) {
      setChannels(data as ChatChannel[])
      // Standardkanal setzen
      const def = (data as ChatChannel[]).find(c => c.is_default) ?? (data as ChatChannel[])[0]
      if (!activeChannelId) {
        setActiveChannelId(def.id)
        setActiveChannelConvId(def.conversation_id)
      }
    } else {
      // Fallback: Lade Community Chat direkt
      const { data: room } = await supabase
        .from('conversations')
        .select('id, type, title, is_locked, locked_reason, created_at, conversation_members(user_id, last_read_at, profiles(id, name, email, avatar_url, nickname))')
        .eq('type', 'system').eq('title', 'Community Chat').single()
      if (room) {
        setCommunityRoom(room as any)
        setActiveChannelConvId(room.id)
      }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => { loadChannels() }, [loadChannels])

  // ── Ankündigungen laden ───────────────────────────────────────────────────
  useEffect(() => {
    async function loadAnnouncements() {
      const { data } = await supabase
        .from('chat_announcements')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false })
        .limit(5)
      if (data) setAnnouncements(data as Announcement[])
    }
    loadAnnouncements()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Community-Nachrichten laden ───────────────────────────────────────────
  const loadCommunityMessages = useCallback(async (convId: string) => {
    const { data } = await supabase
      .from('messages')
      .select('*, profiles(id, name, avatar_url, nickname, role, email), reply_to:reply_to_id(content, profiles(name))')
      .eq('conversation_id', convId)
      .order('created_at', { ascending: true })
      .limit(200)
    if (!data) return

    const msgIds = (data as Message[]).filter(m => !m.deleted_at).map(m => m.id)
    let reactionsMap: Record<string, Reaction[]> = {}
    if (msgIds.length > 0) {
      const { data: reactions } = await supabase.from('message_reactions').select('*').in('message_id', msgIds)
      if (reactions) {
        for (const r of reactions as Reaction[]) {
          if (!reactionsMap[r.message_id]) reactionsMap[r.message_id] = []
          reactionsMap[r.message_id].push(r)
        }
      }
    }
    setCommunityMessages((data as Message[]).map(m => ({ ...m, reactions: reactionsMap[m.id] ?? [] })))

    // Angepinnte Nachrichten laden
    const { data: pins } = await supabase
      .from('message_pins')
      .select('message_id')
      .eq('conversation_id', convId)
    if (pins && pins.length > 0) {
      const pinnedIds = (pins as any[]).map(p => p.message_id)
      const pinned = (data as Message[]).filter(m => pinnedIds.includes(m.id))
      setPinnedMessages(pinned)
    } else {
      setPinnedMessages([])
    }
  }, [supabase])

  // ── Kanal wechseln ────────────────────────────────────────────────────────
  const switchChannel = useCallback(async (channel: ChatChannel) => {
    setActiveChannelId(channel.id)
    setActiveChannelConvId(channel.conversation_id)
    setCommunityLoading(true)
    setMobileShowChannels(false)

    // Lade Konversationsdaten für diesen Kanal
    const { data: conv } = await supabase
      .from('conversations')
      .select('id, type, title, is_locked, locked_reason, created_at, conversation_members(user_id, last_read_at, profiles(id, name, email, avatar_url, nickname))')
      .eq('id', channel.conversation_id).single()
    if (conv) setCommunityRoom(conv as any)
    await loadCommunityMessages(channel.conversation_id)
    setCommunityLoading(false)
  }, [supabase, loadCommunityMessages])

  // Initialer Kanal laden
  useEffect(() => {
    if (activeChannelConvId && tab === 'community') {
      setCommunityLoading(true)
      supabase.from('conversations')
        .select('id, type, title, is_locked, locked_reason, created_at, conversation_members(user_id, last_read_at, profiles(id, name, email, avatar_url, nickname))')
        .eq('id', activeChannelConvId).single()
        .then(({ data }) => {
          if (data) setCommunityRoom(data as any)
        })
      loadCommunityMessages(activeChannelConvId).then(() => setCommunityLoading(false))
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeChannelConvId])

  // ── Presence: Online-Zähler + Typing ─────────────────────────────────────
  useEffect(() => {
    if (!activeChannelConvId) return
    if (presenceChannelRef.current) supabase.removeChannel(presenceChannelRef.current)
    const ch = supabase.channel(`presence:community:${activeChannelConvId}`, { config: { presence: { key: userId } } })
      .on('presence', { event: 'sync' }, () => {
        setOnlineCount(Object.keys(ch.presenceState()).length)
      })
      .on('broadcast', { event: 'typing' }, ({ payload }: any) => {
        if (payload.userId !== userId) {
          const name = payload.name ?? 'Jemand'
          setTypingUsers(prev => prev.includes(name) ? prev : [...prev, name])
          setTimeout(() => setTypingUsers(prev => prev.filter(u => u !== name)), 3000)
        }
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') await ch.track({ userId, online_at: Date.now() })
      })
    presenceChannelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeChannelConvId, userId])

  const broadcastTyping = useCallback((name: string) => {
    presenceChannelRef.current?.send({ type: 'broadcast', event: 'typing', payload: { userId, name } })
  }, [userId])

  // ── Realtime: Community Kanal ─────────────────────────────────────────────
  useEffect(() => {
    if (!activeChannelConvId) return
    if (communityChannelRef.current) supabase.removeChannel(communityChannelRef.current)
    const ch = supabase
      .channel(`cmsg:${activeChannelConvId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${activeChannelConvId}` },
        async (payload) => {
          const msg = payload.new as Message
          if (!msg.profiles) {
            const { data: p } = await supabase.from('profiles').select('id, name, avatar_url, nickname, role, email').eq('id', msg.sender_id).single()
            msg.profiles = p as Profile
          }
          if (msg.reply_to_id) {
            const { data: rt } = await supabase.from('messages').select('content, profiles(name)').eq('id', msg.reply_to_id).single()
            msg.reply_to = rt as any
          }
          msg.reactions = []
          setCommunityMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg])
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages', filter: `conversation_id=eq.${activeChannelConvId}` },
        (payload) => setCommunityMessages(prev => prev.map(m => m.id === (payload.new as Message).id ? { ...m, ...(payload.new as Message) } : m)))
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'message_reactions' },
        (payload) => {
          const r = payload.new as Reaction
          setCommunityMessages(prev => prev.map(m => m.id === r.message_id ? { ...m, reactions: [...(m.reactions ?? []), r] } : m))
        })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'message_reactions' },
        (payload) => {
          const old = payload.old as Reaction
          setCommunityMessages(prev => prev.map(m =>
            m.id === old.message_id ? { ...m, reactions: (m.reactions ?? []).filter(r => !(r.user_id === old.user_id && r.emoji === old.emoji)) } : m
          ))
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'conversations', filter: `id=eq.${activeChannelConvId}` },
        (payload) => setCommunityRoom(prev => prev ? { ...prev, ...(payload.new as any) } : prev))
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'message_pins', filter: `conversation_id=eq.${activeChannelConvId}` },
        async (payload) => {
          const pin = payload.new as PinnedMessage
          const msg = communityMessages.find(m => m.id === pin.message_id)
          if (msg) setPinnedMessages(prev => prev.some(p => p.id === msg.id) ? prev : [...prev, msg])
        })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'message_pins' },
        (payload) => {
          const old = payload.old as PinnedMessage
          setPinnedMessages(prev => prev.filter(m => m.id !== old.message_id))
        })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'chat_announcements' },
        (payload) => setAnnouncements(prev => [payload.new as Announcement, ...prev]))
      .subscribe()
    communityChannelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeChannelConvId])

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
        const msgs: LastMsg[] = (c.messages || []).sort((a: LastMsg, b: LastMsg) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        const lastMsg = msgs[0] || null
        const myMember = c.conversation_members?.find((m: ConvMember) => m.user_id === userId)
        const lastRead = myMember?.last_read_at ? new Date(myMember.last_read_at).getTime() : 0
        const unread = msgs.filter(m => m.sender_id !== userId && new Date(m.created_at).getTime() > lastRead).length
        return { ...c, last_message: lastMsg, unread_count: unread }
      }).filter(Boolean) as Conversation[]
      convs.sort((a, b) => {
        const aT = a.last_message?.created_at ?? a.updated_at ?? a.created_at
        const bT = b.last_message?.created_at ?? b.updated_at ?? b.created_at
        return new Date(bT).getTime() - new Date(aT).getTime()
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
      .select('*, profiles(id, name, avatar_url, nickname, role, email), reply_to:reply_to_id(content, profiles(name))')
      .eq('conversation_id', convId).order('created_at', { ascending: true }).limit(100)

    const msgs = (data as Message[]) ?? []
    const msgIds = msgs.filter(m => !m.deleted_at).map(m => m.id)
    let reactionsMap: Record<string, Reaction[]> = {}
    if (msgIds.length > 0) {
      const { data: reactions } = await supabase.from('message_reactions').select('*').in('message_id', msgIds)
      if (reactions) for (const r of reactions as Reaction[]) {
        if (!reactionsMap[r.message_id]) reactionsMap[r.message_id] = []
        reactionsMap[r.message_id].push(r)
      }
    }
    setMessages(msgs.map(m => ({ ...m, reactions: reactionsMap[m.id] ?? [] })))

    await supabase.from('conversation_members')
      .update({ last_read_at: new Date().toISOString() })
      .eq('conversation_id', convId).eq('user_id', userId)
    setConversations(prev => prev.map(c => c.id === convId ? { ...c, unread_count: 0 } : c))
  }, [userId, supabase])

  useEffect(() => {
    if (!activeConvId) return
    loadDMMessages(activeConvId)
    if (channelRef.current) supabase.removeChannel(channelRef.current)
    const ch = supabase.channel(`dm:${activeConvId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${activeConvId}` },
        async (payload) => {
          const msg = payload.new as Message
          if (!msg.profiles) {
            const { data: p } = await supabase.from('profiles').select('id, name, avatar_url, nickname, role, email').eq('id', msg.sender_id).single()
            msg.profiles = p as Profile
          }
          msg.reactions = []
          setMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg])
          await supabase.from('conversation_members')
            .update({ last_read_at: new Date().toISOString() })
            .eq('conversation_id', activeConvId).eq('user_id', userId)
          setConversations(prev => prev.map(c => c.id === activeConvId ? { ...c, unread_count: 0 } : c))
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages', filter: `conversation_id=eq.${activeConvId}` },
        (payload) => setMessages(prev => prev.map(m => m.id === (payload.new as Message).id ? { ...m, ...(payload.new as Message) } : m)))
      .subscribe()
    channelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeConvId, loadDMMessages, userId])

  // Auto-Scroll
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, communityMessages, tab, activeChannelConvId])

  // ── Nachricht senden ──────────────────────────────────────────────────────
  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || sending) return
    const roomId = tab === 'community' ? activeChannelConvId : activeConvId
    if (!roomId) return
    const activeChannel = channels.find(c => c.id === activeChannelId)
    if (tab === 'community' && (activeChannel?.is_locked || communityRoom?.is_locked) && !isAdmin) return
    if (isBanned) return
    setSending(true)
    const content = newMessage.trim()
    setNewMessage('')
    setReplyTo(null)
    setIsTyping(false)
    await supabase.from('messages').insert({
      conversation_id: roomId,
      sender_id: userId,
      content,
      reply_to_id: replyTo?.id ?? null,
    })
    setSending(false)
    setTimeout(() => inputRef.current?.focus(), 50)
  }

  // ── Nachricht bearbeiten ──────────────────────────────────────────────────
  const handleEditMessage = async (msgId: string) => {
    if (!editContent.trim()) return
    await supabase.from('messages').update({
      content: editContent.trim(),
      edited_at: new Date().toISOString(),
    }).eq('id', msgId)
    const update = (msgs: Message[]) => msgs.map(m => m.id === msgId ? { ...m, content: editContent.trim(), edited_at: new Date().toISOString() } : m)
    if (tab === 'community') setCommunityMessages(update)
    else setMessages(update)
    setEditingMsgId(null)
    setEditContent('')
  }

  // ── Typing ────────────────────────────────────────────────────────────────
  const handleInputChange = (val: string) => {
    setNewMessage(val)
    if (tab === 'community' && val.length > 0 && !isBanned) {
      if (!isTyping) {
        setIsTyping(true)
        supabase.from('profiles').select('name').eq('id', userId).single()
          .then(({ data }) => broadcastTyping(data?.name ?? 'Jemand'))
      }
      if (typingTimeout.current) clearTimeout(typingTimeout.current)
      typingTimeout.current = setTimeout(() => setIsTyping(false), 2500)
    }
  }

  // ── Reaktion ──────────────────────────────────────────────────────────────
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
    if (tab === 'dm') {
      setMessages(prev => prev.map(m => {
        if (m.id !== msgId) return m
        return existing
          ? { ...m, reactions: (m.reactions ?? []).filter(r => !(r.user_id === userId && r.emoji === emoji)) }
          : { ...m, reactions: [...(m.reactions ?? []), { message_id: msgId, user_id: userId, emoji }] }
      }))
    }
  }

  // ── Nachricht löschen ─────────────────────────────────────────────────────
  const handleDeleteMessage = async (msgId: string, senderId: string) => {
    setMsgMenuFor(null)
    if (!isAdmin && senderId !== userId) return
    await supabase.from('messages').update({ deleted_at: new Date().toISOString() }).eq('id', msgId)
    const update = (msgs: Message[]) => msgs.map(m => m.id === msgId ? { ...m, deleted_at: new Date().toISOString() } : m)
    if (tab === 'community') setCommunityMessages(update)
    else setMessages(update)
  }

  // ── Nachricht anpinnen ────────────────────────────────────────────────────
  const handlePinMessage = async (msg: Message) => {
    setMsgMenuFor(null)
    if (!isAdmin) return
    const convId = tab === 'community' ? activeChannelConvId : activeConvId
    if (!convId) return
    const alreadyPinned = pinnedMessages.some(p => p.id === msg.id)
    if (alreadyPinned) {
      await supabase.from('message_pins').delete().eq('message_id', msg.id)
      setPinnedMessages(prev => prev.filter(p => p.id !== msg.id))
    } else {
      await supabase.from('message_pins').insert({ message_id: msg.id, conversation_id: convId, pinned_by: userId })
      setPinnedMessages(prev => [...prev, msg])
    }
  }

  // ── Admin: Chat sperren/entsperren ────────────────────────────────────────
  const handleToggleLock = async (reason?: string) => {
    if (!isAdmin) return
    const convId = activeChannelConvId ?? communityRoom?.id
    if (!convId) return
    const newLocked = !communityRoom?.is_locked
    await supabase.from('conversations').update({
      is_locked: newLocked,
      locked_by: newLocked ? userId : null,
      locked_at: newLocked ? new Date().toISOString() : null,
      locked_reason: newLocked ? (reason ?? null) : null,
    }).eq('id', convId)

    // Auch Kanal-Objekt aktualisieren
    if (activeChannelId) {
      await supabase.from('chat_channels').update({ is_locked: newLocked, locked_reason: reason ?? null }).eq('id', activeChannelId)
      setChannels(prev => prev.map(c => c.id === activeChannelId ? { ...c, is_locked: newLocked, locked_reason: reason ?? null } : c))
    }
    setCommunityRoom(prev => prev ? { ...prev, is_locked: newLocked, locked_reason: reason ?? null } : prev)
    setShowLockModal(false)
    setLockReason('')
  }

  // ── Admin: Ankündigung erstellen ──────────────────────────────────────────
  const handleCreateAnnouncement = async () => {
    if (!announceTitle.trim() || !announceContent.trim()) return
    await supabase.from('chat_announcements').insert({
      title: announceTitle.trim(),
      content: announceContent.trim(),
      type: announceType,
      is_active: true,
      created_by: userId,
    })
    setShowAnnounceModal(false)
    setAnnounceTitle('')
    setAnnounceContent('')
    setAnnounceType('info')
  }

  // ── Ankündigung schließen ─────────────────────────────────────────────────
  const dismissAnnouncement = (id: string) => {
    setDismissedAnnouncements(prev => new Set([...prev, id]))
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
  const getConvInitials = (conv: Conversation) =>
    getConvTitle(conv).split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  const getConvAvatar = (conv: Conversation): string | null => {
    if (conv.type === 'group') return null
    return conv.conversation_members?.find(m => m.user_id !== userId)?.profiles?.avatar_url ?? null
  }

  const activeConv = conversations.find(c => c.id === activeConvId) ?? null
  const activeChannel = channels.find(c => c.id === activeChannelId)
  const isLocked = tab === 'community' && (!!activeChannel?.is_locked || !!communityRoom?.is_locked) && !isAdmin
  const visibleAnnouncements = announcements.filter(a => !dismissedAnnouncements.has(a.id))

  const announcementColors: Record<string, string> = {
    info: 'bg-blue-50 border-blue-200 text-blue-800',
    warning: 'bg-amber-50 border-amber-200 text-amber-800',
    success: 'bg-green-50 border-green-200 text-green-800',
    error: 'bg-red-50 border-red-200 text-red-800',
  }
  const announcementIcons: Record<string, string> = {
    info: 'ℹ️', warning: '⚠️', success: '✅', error: '🚨'
  }

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col" onClick={() => { setShowEmojiFor(null); setMsgMenuFor(null) }}>

      {/* Header */}
      <div className="mb-4 flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Nachrichten & Chat</h1>
          <p className="text-sm text-gray-500 mt-0.5">Community-Kanäle & private Direktnachrichten</p>
        </div>
        <div className="flex items-center gap-2">
          {tab === 'dm' && (
            <button onClick={() => setShowNewChat(true)} className="btn-primary gap-2 flex items-center">
              <Plus className="w-4 h-4" /> Neue Nachricht
            </button>
          )}
          {tab === 'community' && isAdmin && (
            <div className="flex items-center gap-2">
              <button
                onClick={() => setShowAnnounceModal(true)}
                className="flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-semibold bg-blue-600 text-white hover:bg-blue-700 transition-all">
                <Megaphone className="w-4 h-4" /> Ankündigung
              </button>
              <button
                onClick={() => communityRoom?.is_locked ? handleToggleLock() : setShowLockModal(true)}
                className={cn('flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-semibold transition-all',
                  communityRoom?.is_locked ? 'bg-green-600 text-white hover:bg-green-700' : 'bg-red-500 text-white hover:bg-red-600')}>
                {communityRoom?.is_locked
                  ? <><Volume2 className="w-4 h-4" /> Freigeben</>
                  : <><VolumeX className="w-4 h-4" /> Sperren</>}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Ban Banner */}
      {isBanned && (
        <div className="flex items-center gap-3 px-4 py-3 bg-red-50 border border-red-200 rounded-xl mb-4">
          <ShieldOff className="w-5 h-5 text-red-500 flex-shrink-0" />
          <p className="text-sm text-red-700 font-medium">Du wurdest vom Chat gesperrt und kannst keine Nachrichten senden.</p>
        </div>
      )}

      {/* Announcements */}
      {visibleAnnouncements.length > 0 && tab === 'community' && (
        <div className="space-y-2 mb-3">
          {visibleAnnouncements.map(a => (
            <div key={a.id} className={cn('flex items-start gap-3 px-4 py-3 border rounded-xl', announcementColors[a.type])}>
              <span className="text-base flex-shrink-0">{announcementIcons[a.type]}</span>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-sm">{a.title}</p>
                <p className="text-xs mt-0.5 opacity-80">{a.content}</p>
              </div>
              <button onClick={() => dismissAnnouncement(a.id)} className="p-1 opacity-60 hover:opacity-100 flex-shrink-0">
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-warm-100 p-1 rounded-xl mb-4 flex-shrink-0">
        <button onClick={() => setTab('community')}
          className={cn('flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-sm font-semibold transition-all',
            tab === 'community' ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700')}>
          <Hash className="w-4 h-4" />
          <span className="hidden sm:inline">Community-Kanäle</span>
          <span className="sm:hidden">Kanäle</span>
          {(activeChannel?.is_locked || communityRoom?.is_locked) && <Lock className="w-3 h-3 text-red-500" />}
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

      {/* ══ Community-Tab ══ */}
      {tab === 'community' && (
        <div className="flex-1 flex gap-3 min-h-0">

          {/* Kanal-Sidebar (Desktop) */}
          <div className={cn(
            'w-48 flex-shrink-0 flex-col bg-white rounded-2xl border border-warm-200 shadow-sm overflow-hidden',
            'hidden lg:flex'
          )}>
            <div className="px-4 py-3 border-b border-warm-100">
              <p className="text-xs font-bold text-gray-500 uppercase tracking-wider">Kanäle</p>
            </div>
            <div className="overflow-y-auto flex-1 py-1">
              {channels.length === 0 ? (
                <div className="flex flex-col items-center py-6 px-3 text-center">
                  <Hash className="w-6 h-6 text-gray-300 mb-2" />
                  <p className="text-xs text-gray-400">Keine Kanäle</p>
                  <p className="text-[10px] text-gray-300 mt-1">Führe Migration 007 aus</p>
                </div>
              ) : (
                channels.map(ch => (
                  <button key={ch.id} onClick={() => switchChannel(ch)}
                    className={cn(
                      'w-full flex items-center gap-2 px-3 py-2 text-left transition-all text-sm',
                      activeChannelId === ch.id ? 'bg-primary-50 text-primary-700 font-semibold' : 'text-gray-600 hover:bg-warm-50 hover:text-gray-900'
                    )}>
                    <span className="text-base">{ch.emoji}</span>
                    <span className="flex-1 truncate">{ch.name}</span>
                    {ch.is_locked && <Lock className="w-3 h-3 text-red-400 flex-shrink-0" />}
                  </button>
                ))
              )}
            </div>
          </div>

          {/* Mobile Kanal-Toggle */}
          <div className="lg:hidden mb-2 flex-shrink-0">
            <button
              onClick={() => setMobileShowChannels(!mobileShowChannels)}
              className="flex items-center gap-2 px-3 py-2 bg-white border border-warm-200 rounded-xl text-sm font-medium text-gray-700">
              {activeChannel ? <><span>{activeChannel.emoji}</span><span>{activeChannel.name}</span></> : <><Hash className="w-4 h-4" /><span>Kanal wählen</span></>}
              <ChevronDown className="w-4 h-4 ml-auto" />
            </button>
            {mobileShowChannels && (
              <div className="absolute z-30 mt-1 bg-white border border-warm-200 rounded-xl shadow-lg py-1 w-48">
                {channels.map(ch => (
                  <button key={ch.id} onClick={() => switchChannel(ch)}
                    className={cn('w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-warm-50',
                      activeChannelId === ch.id && 'bg-primary-50 text-primary-700 font-semibold')}>
                    <span>{ch.emoji}</span><span>{ch.name}</span>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Chat-Bereich */}
          <div className="flex-1 card flex flex-col min-h-0">
            {/* Room Header */}
            <div className="flex items-center gap-3 px-5 py-3.5 border-b border-warm-100 flex-shrink-0">
              <div className={cn('w-8 h-8 rounded-xl flex items-center justify-center text-base',
                (activeChannel?.is_locked || communityRoom?.is_locked) ? 'bg-red-100' : 'bg-primary-100')}>
                {(activeChannel?.is_locked || communityRoom?.is_locked)
                  ? <Lock className="w-4 h-4 text-red-600" />
                  : <span>{activeChannel?.emoji ?? '💬'}</span>}
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-gray-900 text-sm">{activeChannel?.name ?? 'Community Chat'}</p>
                {(activeChannel?.is_locked || communityRoom?.is_locked) ? (
                  <p className="text-xs text-red-600 flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-red-500 inline-block" />
                    Gesperrt – nur Admins können schreiben
                  </p>
                ) : (
                  <p className="text-xs text-green-600 flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-green-500 inline-block animate-pulse" />
                    Live – {activeChannel?.description ?? 'alle können mitmachen'}
                  </p>
                )}
              </div>
              <div className="flex items-center gap-2">
                {pinnedMessages.length > 0 && (
                  <button onClick={() => setShowPinned(!showPinned)}
                    className="flex items-center gap-1.5 px-2 py-1 rounded-lg bg-amber-50 border border-amber-200 text-amber-700 text-xs hover:bg-amber-100 transition-all">
                    <Pin className="w-3 h-3" />
                    <span className="hidden sm:inline">{pinnedMessages.length} angepinnt</span>
                    <span className="sm:hidden">{pinnedMessages.length}</span>
                  </button>
                )}
                <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-green-50 border border-green-200">
                  <Users className="w-3.5 h-3.5 text-green-600" />
                  <span className="text-xs font-medium text-green-700">{onlineCount} online</span>
                </div>
              </div>
            </div>

            {/* Lock Banner */}
            {(activeChannel?.is_locked || communityRoom?.is_locked) && (
              <div className="flex items-center gap-3 px-5 py-3 bg-red-50 border-b border-red-100">
                <AlertCircle className="w-4 h-4 text-red-500 flex-shrink-0" />
                <p className="text-sm text-red-700">
                  {isAdmin
                    ? '⚙️ Admin-Modus: Du kannst trotz Sperre schreiben.'
                    : `Dieser Kanal wurde gesperrt.${(activeChannel?.locked_reason ?? communityRoom?.locked_reason) ? ` Grund: ${activeChannel?.locked_reason ?? communityRoom?.locked_reason}` : ''}`}
                </p>
              </div>
            )}

            {/* Angepinnte Nachrichten Panel */}
            {showPinned && pinnedMessages.length > 0 && (
              <div className="px-4 py-3 bg-amber-50 border-b border-amber-100 flex-shrink-0">
                <div className="flex items-center justify-between mb-2">
                  <p className="text-xs font-bold text-amber-700 flex items-center gap-1.5">
                    <Pin className="w-3.5 h-3.5" /> Angepinnte Nachrichten ({pinnedMessages.length})
                  </p>
                  <button onClick={() => setShowPinned(false)} className="text-amber-600 hover:text-amber-800">
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
                <div className="space-y-1.5 max-h-28 overflow-y-auto">
                  {pinnedMessages.map(pm => (
                    <div key={pm.id} className="bg-white rounded-lg px-3 py-2 border border-amber-200">
                      <p className="text-[11px] font-semibold text-amber-700">{pm.profiles?.name ?? 'Nutzer'}</p>
                      <p className="text-xs text-gray-700 line-clamp-1">{pm.content}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Nachrichten */}
            <div className="flex-1 overflow-y-auto p-4 space-y-1 no-scrollbar">
              {communityLoading ? (
                <div className="flex flex-col items-center justify-center h-full py-12">
                  <Loader2 className="w-8 h-8 text-primary-300 animate-spin mb-3" />
                  <p className="text-sm text-gray-400">Kanal wird geladen…</p>
                </div>
              ) : communityMessages.length === 0 ? (
                <div className="flex flex-col items-center justify-center h-full py-12">
                  <span className="text-4xl mb-3">{activeChannel?.emoji ?? '💬'}</span>
                  <p className="font-semibold text-gray-600 mb-1">{activeChannel?.name ?? 'Community Chat'}</p>
                  <p className="text-sm text-gray-400">{activeChannel?.description ?? 'Noch keine Nachrichten – sei der Erste!'}</p>
                </div>
              ) : (
                <>
                  <MessageGroup
                    messages={communityMessages} userId={userId} isAdmin={isAdmin}
                    pinnedIds={new Set(pinnedMessages.map(p => p.id))}
                    onReply={msg => { setReplyTo(msg); inputRef.current?.focus() }}
                    onReaction={handleReaction} onDelete={handleDeleteMessage}
                    onPin={handlePinMessage}
                    onEdit={(msg) => { setEditingMsgId(msg.id); setEditContent(msg.content) }}
                    showEmojiFor={showEmojiFor} setShowEmojiFor={setShowEmojiFor}
                    msgMenuFor={msgMenuFor} setMsgMenuFor={setMsgMenuFor}
                    editingMsgId={editingMsgId} editContent={editContent}
                    setEditContent={setEditContent} onEditSubmit={handleEditMessage}
                    onEditCancel={() => { setEditingMsgId(null); setEditContent('') }}
                  />
                  <div ref={messagesEndRef} />
                </>
              )}
            </div>

            {/* Typing Indicator */}
            {typingUsers.length > 0 && (
              <div className="px-5 py-1.5 text-xs text-gray-400 flex items-center gap-2 border-t border-warm-50 flex-shrink-0">
                <span className="flex gap-0.5 items-end">
                  {[0, 150, 300].map((d, i) => (
                    <span key={i} className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: `${d}ms` }} />
                  ))}
                </span>
                <span>{typingUsers.slice(0, 2).join(', ')} schreibt…</span>
              </div>
            )}

            {/* Reply Preview */}
            {replyTo && (
              <div className="px-4 py-2 bg-primary-50 border-t border-primary-100 flex items-center gap-2 flex-shrink-0">
                <Reply className="w-3.5 h-3.5 text-primary-500 flex-shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-primary-600 font-medium">Antwort auf {replyTo.profiles?.name ?? 'Nutzer'}</p>
                  <p className="text-xs text-gray-500 truncate">{replyTo.content}</p>
                </div>
                <button onClick={() => setReplyTo(null)} className="p-1 text-gray-400 hover:text-gray-600"><X className="w-3.5 h-3.5" /></button>
              </div>
            )}

            {/* Input */}
            <form onSubmit={sendMessage} className="px-4 py-3 border-t border-warm-100 flex-shrink-0 bg-white">
              <div className="flex gap-2 items-center">
                <input
                  ref={inputRef} type="text" value={newMessage}
                  onChange={e => handleInputChange(e.target.value)}
                  placeholder={isBanned ? 'Du bist gesperrt…' : isLocked ? 'Kanal ist gesperrt…' : `Nachricht in #${activeChannel?.name ?? 'allgemein'}…`}
                  disabled={isLocked || isBanned}
                  className="input flex-1 text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                />
                <button type="submit" disabled={sending || !newMessage.trim() || isLocked || isBanned}
                  className="p-2.5 bg-primary-600 hover:bg-primary-700 disabled:opacity-40 text-white rounded-xl transition-all flex-shrink-0">
                  {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                </button>
              </div>
            </form>
          </div>
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
              <button onClick={() => setShowNewChat(true)}
                className="p-1.5 rounded-lg hover:bg-warm-100 text-gray-500 hover:text-primary-600 transition-all">
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
                <p className="text-xs text-gray-400 mt-1 mb-4">Klicke bei einem Inserat auf „DM"</p>
                <button onClick={() => setShowNewChat(true)} className="btn-primary text-sm py-2 gap-1.5">
                  <Plus className="w-3.5 h-3.5" /> Neue Nachricht
                </button>
              </div>
            ) : (
              <div className="overflow-y-auto flex-1 no-scrollbar py-1">
                {conversations.map(conv => (
                  <ConversationItem key={conv.id} conv={conv} active={activeConvId === conv.id}
                    title={getConvTitle(conv)} initials={getConvInitials(conv)}
                    avatarUrl={getConvAvatar(conv)} onClick={() => openConv(conv)} userId={userId} />
                ))}
              </div>
            )}
          </div>

          {/* Chat-Fenster */}
          <div className={cn('flex-1 card flex flex-col min-h-0', !mobileShowChat ? 'hidden lg:flex' : 'flex')}>
            {activeConv ? (
              <>
                <div className="flex items-center gap-3 px-5 py-3.5 border-b border-warm-100 flex-shrink-0">
                  <button onClick={() => setMobileShowChat(false)} className="lg:hidden p-1.5 rounded-lg hover:bg-warm-100 text-gray-500">
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
                </div>

                <div className="flex-1 overflow-y-auto p-4 space-y-1 no-scrollbar">
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
                      <MessageGroup messages={messages} userId={userId} isAdmin={isAdmin}
                        pinnedIds={new Set()}
                        onReply={msg => { setReplyTo(msg); inputRef.current?.focus() }}
                        onReaction={handleReaction} onDelete={handleDeleteMessage}
                        onPin={() => {}}
                        onEdit={(msg) => { setEditingMsgId(msg.id); setEditContent(msg.content) }}
                        showEmojiFor={showEmojiFor} setShowEmojiFor={setShowEmojiFor}
                        msgMenuFor={msgMenuFor} setMsgMenuFor={setMsgMenuFor}
                        editingMsgId={editingMsgId} editContent={editContent}
                        setEditContent={setEditContent} onEditSubmit={handleEditMessage}
                        onEditCancel={() => { setEditingMsgId(null); setEditContent('') }}
                      />
                      <div ref={messagesEndRef} />
                    </>
                  )}
                </div>

                {replyTo && (
                  <div className="px-4 py-2 bg-primary-50 border-t border-primary-100 flex items-center gap-2 flex-shrink-0">
                    <Reply className="w-3.5 h-3.5 text-primary-500 flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-xs text-primary-600 font-medium">Antwort auf {replyTo.profiles?.name ?? 'Nutzer'}</p>
                      <p className="text-xs text-gray-500 truncate">{replyTo.content}</p>
                    </div>
                    <button onClick={() => setReplyTo(null)} className="p-1 text-gray-400 hover:text-gray-600"><X className="w-3.5 h-3.5" /></button>
                  </div>
                )}

                <form onSubmit={sendMessage} className="px-4 py-3 border-t border-warm-100 flex-shrink-0 bg-white">
                  <div className="flex gap-2 items-center">
                    <input ref={tab === 'dm' ? inputRef : undefined}
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
                  <p className="text-sm text-gray-400 mb-5 max-w-xs">Oder klicke bei einem Inserat auf „DM" um direkt zu schreiben</p>
                  <button onClick={() => setShowNewChat(true)} className="btn-primary gap-2">
                    <Plus className="w-4 h-4" /> Neue Nachricht
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── New Chat Modal ── */}
      {showNewChat && (
        <NewChatModal userId={userId} onClose={() => setShowNewChat(false)}
          onCreated={(convId) => {
            setShowNewChat(false); setTab('dm')
            loadConversations().then(() => { setActiveConvId(convId); setMobileShowChat(true) })
          }} />
      )}

      {/* ── Lock Modal (Admin) ── */}
      {showLockModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <h3 className="font-bold text-gray-900 text-lg flex items-center gap-2">
              <VolumeX className="w-5 h-5 text-red-500" /> Kanal sperren
            </h3>
            <p className="text-sm text-gray-500">Nutzer können dann keine Nachrichten mehr senden.</p>
            <input
              value={lockReason} onChange={e => setLockReason(e.target.value)}
              placeholder="Grund (optional, wird angezeigt)…"
              className="input w-full"
            />
            <div className="flex gap-3">
              <button onClick={() => setShowLockModal(false)} className="btn-secondary flex-1 justify-center">Abbrechen</button>
              <button onClick={() => handleToggleLock(lockReason || undefined)}
                className="flex-1 px-4 py-2.5 bg-red-600 text-white rounded-xl font-semibold hover:bg-red-700 transition-all text-sm">
                Sperren
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Announcement Modal (Admin) ── */}
      {showAnnounceModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 text-lg flex items-center gap-2">
                <Megaphone className="w-5 h-5 text-blue-500" /> Ankündigung erstellen
              </h3>
              <button onClick={() => setShowAnnounceModal(false)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div className="flex gap-2">
                {(['info', 'warning', 'success', 'error'] as const).map(t => (
                  <button key={t} onClick={() => setAnnounceType(t)}
                    className={cn('flex-1 py-1.5 rounded-lg text-xs font-semibold border transition-all',
                      announceType === t ? 'bg-gray-900 text-white border-gray-900' : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50')}>
                    {announcementIcons[t]} {t}
                  </button>
                ))}
              </div>
              <input
                value={announceTitle} onChange={e => setAnnounceTitle(e.target.value)}
                placeholder="Titel der Ankündigung…"
                className="input w-full"
              />
              <textarea
                value={announceContent} onChange={e => setAnnounceContent(e.target.value)}
                placeholder="Nachricht an alle Nutzer…"
                rows={3} className="input w-full resize-none"
              />
            </div>
            <div className="flex gap-3">
              <button onClick={() => setShowAnnounceModal(false)} className="btn-secondary flex-1 justify-center">Abbrechen</button>
              <button onClick={handleCreateAnnouncement} disabled={!announceTitle.trim() || !announceContent.trim()}
                className="flex-1 px-4 py-2.5 bg-blue-600 text-white rounded-xl font-semibold hover:bg-blue-700 disabled:opacity-40 transition-all text-sm">
                Veröffentlichen
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── MessageGroup ─────────────────────────────────────────────────────────────
function MessageGroup({ messages, userId, isAdmin, pinnedIds, onReply, onReaction, onDelete, onPin, onEdit,
  showEmojiFor, setShowEmojiFor, msgMenuFor, setMsgMenuFor,
  editingMsgId, editContent, setEditContent, onEditSubmit, onEditCancel
}: {
  messages: Message[]; userId: string; isAdmin: boolean; pinnedIds: Set<string>
  onReply: (m: Message) => void
  onReaction: (msgId: string, emoji: string) => void
  onDelete: (msgId: string, senderId: string) => void
  onPin: (m: Message) => void
  onEdit: (m: Message) => void
  showEmojiFor: string | null; setShowEmojiFor: (id: string | null) => void
  msgMenuFor: string | null; setMsgMenuFor: (id: string | null) => void
  editingMsgId: string | null; editContent: string; setEditContent: (v: string) => void
  onEditSubmit: (id: string) => void; onEditCancel: () => void
}) {
  return (
    <>
      {messages.map((msg, i) => {
        const isMe = msg.sender_id === userId
        const isDeleted = !!msg.deleted_at
        const prevMsg = messages[i - 1]
        const nextMsg = messages[i + 1]
        const sameAuthorPrev = prevMsg?.sender_id === msg.sender_id
        const sameAuthorNext = nextMsg?.sender_id === msg.sender_id
        const timeDiff = prevMsg ? new Date(msg.created_at).getTime() - new Date(prevMsg.created_at).getTime() : Infinity
        const showHeader = !sameAuthorPrev || timeDiff > 5 * 60 * 1000
        const isLast = !sameAuthorNext
        const msgIsAdmin = isAdminUser(msg.profiles as Profile)
        const isPinned = pinnedIds.has(msg.id)
        const isEditing = editingMsgId === msg.id

        const reactionGroups: Record<string, number> = {}
        const myReactions: Record<string, boolean> = {}
        for (const r of msg.reactions ?? []) {
          reactionGroups[r.emoji] = (reactionGroups[r.emoji] ?? 0) + 1
          if (r.user_id === userId) myReactions[r.emoji] = true
        }

        return (
          <div key={msg.id} className={cn('group flex gap-2 mb-0.5', isMe ? 'justify-end' : 'justify-start', !showHeader && !isMe && 'pl-9')}>
            {/* Avatar */}
            {!isMe && showHeader && (
              <div className="w-7 h-7 rounded-full bg-warm-200 flex items-center justify-center text-xs font-bold text-gray-600 flex-shrink-0 mt-auto overflow-hidden relative">
                {msg.profiles?.avatar_url
                  ? <img src={msg.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                  : (msg.profiles?.name ?? '?')[0].toUpperCase()}
                {msgIsAdmin && (
                  <span className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-amber-400 border-2 border-white rounded-full flex items-center justify-center">
                    <Crown className="w-2 h-2 text-white" />
                  </span>
                )}
              </div>
            )}
            {!isMe && !showHeader && <div className="w-7 flex-shrink-0" />}

            <div className="max-w-[72%] space-y-0.5">
              {/* Name + Admin badge + Pinned */}
              {!isMe && showHeader && (
                <div className="flex items-center gap-1.5 ml-1">
                  <p className="text-[10px] font-semibold text-primary-600">
                    {msg.profiles?.name ?? msg.profiles?.nickname ?? 'Nutzer'}
                  </p>
                  {msgIsAdmin && (
                    <span className="text-[9px] font-bold bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full flex items-center gap-0.5">
                      <Crown className="w-2 h-2" /> Admin
                    </span>
                  )}
                  {isPinned && <span className="text-[9px] text-amber-600 flex items-center gap-0.5"><Pin className="w-2.5 h-2.5" />Angepinnt</span>}
                </div>
              )}

              {/* Reply context */}
              {msg.reply_to && !isDeleted && (
                <div className={cn('px-3 py-1.5 rounded-xl border-l-2 text-xs mb-0.5 max-w-full',
                  isMe ? 'bg-primary-700/40 border-primary-200 text-primary-100' : 'bg-warm-200 border-gray-300 text-gray-500')}>
                  <p className="font-semibold text-[11px]">{(msg.reply_to as any).profiles?.name ?? 'Nutzer'}</p>
                  <p className="truncate">{msg.reply_to.content}</p>
                </div>
              )}

              {/* Bubble */}
              <div className={cn('relative', isPinned && !isDeleted && 'ring-1 ring-amber-300 rounded-2xl')}>
                {isEditing ? (
                  <div className="flex flex-col gap-2 bg-white border border-primary-300 rounded-2xl p-3 shadow-md min-w-48">
                    <input
                      value={editContent}
                      onChange={e => setEditContent(e.target.value)}
                      onKeyDown={e => { if (e.key === 'Enter') onEditSubmit(msg.id); if (e.key === 'Escape') onEditCancel() }}
                      className="text-sm text-gray-800 bg-transparent outline-none border-b border-gray-200 pb-1"
                      autoFocus
                    />
                    <div className="flex gap-2 justify-end">
                      <button onClick={onEditCancel} className="text-xs text-gray-400 hover:text-gray-600">Abbrechen</button>
                      <button onClick={() => onEditSubmit(msg.id)} className="text-xs text-primary-600 font-semibold hover:text-primary-800">Speichern</button>
                    </div>
                  </div>
                ) : (
                  <div className={cn('px-3.5 py-2.5 text-sm shadow-sm',
                    isDeleted ? 'bg-gray-100 text-gray-400 italic rounded-2xl'
                      : isMe ? cn('bg-primary-600 text-white', isLast ? 'rounded-2xl rounded-br-sm' : 'rounded-2xl')
                      : cn('bg-warm-100 text-gray-800', isLast ? 'rounded-2xl rounded-bl-sm' : 'rounded-2xl'))}>
                    {isDeleted
                      ? <p className="text-xs">🗑 Nachricht gelöscht</p>
                      : <p className="leading-relaxed break-words whitespace-pre-wrap">{msg.content}</p>}
                    {!isDeleted && (
                      <div className={cn('flex items-center gap-1 mt-1', isMe ? 'justify-end' : 'justify-start')}>
                        <p className={cn('text-[10px]', isMe ? 'text-primary-200' : 'text-gray-400')}>
                          {formatRelativeTime(msg.created_at)}
                          {msg.edited_at && <span className="ml-1 italic opacity-70">bearbeitet</span>}
                        </p>
                        {isMe && <CheckCheck className="w-3 h-3 text-primary-200" />}
                      </div>
                    )}
                  </div>
                )}

                {/* Hover Actions */}
                {!isDeleted && !isEditing && (
                  <div className={cn(
                    'absolute -top-1 flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-all duration-150 z-10',
                    isMe ? 'right-full mr-1' : 'left-full ml-1'
                  )}>
                    <button onClick={e => { e.stopPropagation(); onReply(msg) }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-warm-200 text-gray-500 hover:text-primary-600 hover:border-primary-300 transition-all"
                      title="Antworten">
                      <Reply className="w-3 h-3" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); setShowEmojiFor(showEmojiFor === msg.id ? null : msg.id) }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-warm-200 text-gray-500 hover:text-yellow-500 hover:border-yellow-300 transition-all"
                      title="Reaktion">
                      <Smile className="w-3 h-3" />
                    </button>
                    {isMe && (
                      <button onClick={e => { e.stopPropagation(); onEdit(msg) }}
                        className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-warm-200 text-gray-500 hover:text-blue-500 hover:border-blue-300 transition-all"
                        title="Bearbeiten">
                        <Edit2 className="w-3 h-3" />
                      </button>
                    )}
                    {(isMe || isAdmin) && (
                      <button onClick={e => { e.stopPropagation(); onDelete(msg.id, msg.sender_id) }}
                        className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-warm-200 text-gray-500 hover:text-red-500 hover:border-red-300 transition-all"
                        title="Löschen">
                        <Trash2 className="w-3 h-3" />
                      </button>
                    )}
                    {isAdmin && (
                      <button onClick={e => { e.stopPropagation(); onPin(msg) }}
                        className={cn('w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border transition-all',
                          isPinned ? 'border-amber-300 text-amber-500 hover:text-amber-700' : 'border-warm-200 text-gray-500 hover:text-amber-500 hover:border-amber-300')}
                        title={isPinned ? 'Loslösen' : 'Anpinnen'}>
                        {isPinned ? <PinOff className="w-3 h-3" /> : <Pin className="w-3 h-3" />}
                      </button>
                    )}
                  </div>
                )}

                {/* Emoji Picker Popup */}
                {showEmojiFor === msg.id && (
                  <div
                    className={cn('absolute z-30 flex gap-1 p-2 bg-white rounded-2xl shadow-2xl border border-warm-200 bottom-full mb-2',
                      isMe ? 'right-0' : 'left-0')}
                    onClick={e => e.stopPropagation()}
                  >
                    {QUICK_EMOJIS.map(emoji => (
                      <button key={emoji} onClick={() => onReaction(msg.id, emoji)}
                        className={cn('w-8 h-8 rounded-xl text-base flex items-center justify-center hover:bg-warm-100 transition-all hover:scale-110',
                          myReactions[emoji] ? 'bg-primary-100 ring-2 ring-primary-400' : '')}>
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
                      className={cn('flex items-center gap-1 px-2 py-0.5 rounded-full text-xs border transition-all hover:scale-105',
                        myReactions[emoji]
                          ? 'bg-primary-100 border-primary-300 text-primary-700 shadow-sm'
                          : 'bg-white border-warm-200 text-gray-600 hover:bg-warm-50')}>
                      <span>{emoji}</span>
                      {count > 1 && <span className="font-semibold">{count}</span>}
                    </button>
                  ))}
                </div>
              )}
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
            {!searching && query.length < 2 && <p className="text-sm text-gray-400 text-center py-4">Mindestens 2 Zeichen eingeben…</p>}
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
