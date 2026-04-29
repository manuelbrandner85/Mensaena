'use client'

import { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { createPortal } from 'react-dom'
import {
  Send, MessageCircle, Users, Plus, Search, X, ArrowLeft,
  Hash, Lock, CheckCheck, Check, Loader2, Mail, Smile,
  Trash2, Reply, ShieldOff, AlertCircle, Volume2, VolumeX, Crown,
  Pin, PinOff, Edit2, Megaphone, Heart,
  Image as ImageIcon, Link2, Download, Video,
  BarChart2, CalendarPlus, Radio, AtSign, Phone, PhoneCall, PhoneOff,
} from 'lucide-react'
import dynamic from 'next/dynamic'
const LiveRoomModal = dynamic(() => import('./LiveRoomModal'), { ssr: false })
const OutgoingCallScreen = dynamic(() => import('./OutgoingCallScreen'), { ssr: false })
import CreateChannelModal from './CreateChannelModal'
import UpgradeTierModal from './UpgradeTierModal'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { formatRelativeTime, cn } from '@/lib/utils'
import { openOrCreateDM, getUnreadDMCount } from '@/lib/chat-utils'
import { checkRateLimit } from '@/lib/rate-limit'
import { formatChatMessage, extractUrls, getMessagePermalink, exportChatAsText, downloadTextFile, generateSkeletonMessages } from '@/lib/chat-features'
import VoiceRecorder from './VoiceRecorder'
import { getTierInfo, canCreatePoll, canCreateChannel, canScheduleEvent, canPostAnnouncement } from '@/lib/donorTier'
import { useHaptic } from '@/hooks/useHaptic'
// (Ringtone-Steuerung lebt jetzt in IncomingCallScreen.tsx und OutgoingCallScreen.tsx)

// ─── Typen ────────────────────────────────────────────────────────────────────
interface Profile {
  id: string
  name: string | null
  email: string | null
  avatar_url: string | null
  nickname: string | null
  role?: string | null
  donor_tier?: number | null
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
  category?: string
  created_by?: string | null
}

interface Poll {
  id: string
  channel_id: string
  created_by: string
  question: string
  options: string[]
  ends_at: string | null
  created_at: string
  votes?: { option_index: number; user_id: string }[]
}

interface ChannelEvent {
  id: string
  channel_id: string
  created_by: string
  title: string
  scheduled_at: string
  room_name: string | null
  created_at: string
  rsvps?: { user_id: string }[]
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
// ─── Re-export utilities from chat-utils ─────────────────────────────────────
export { openOrCreateDM, getUnreadDMCount }

// ─── isAdminUser ─────────────────────────────────────────────────────────────
function isAdminUser(profile: Profile | null | undefined): boolean {
  if (!profile) return false
  return profile.role === 'admin' || profile.role === 'moderator'
}

// ─── PostgREST filter input sanitizers ───────────────────────────────────────
// Chars that break PostgREST `or()` parsing: `,()"` and backslash
function sanitizeForOrFilter(value: string): string {
  return value.replace(/[,()"\\]/g, ' ').trim()
}
// Escape ilike wildcards so user input is matched literally
function escapeIlike(value: string): string {
  return value.replace(/[%_\\]/g, '\\$&')
}

// ─── ChatView ─────────────────────────────────────────────────────────────────
export default function ChatView({ userId, initialConvId, initialTab, initialCallId }: { userId: string; initialConvId?: string | null; initialTab?: 'dm' | 'community'; initialCallId?: string | null }) {
  const haptic = useHaptic()
  const [tab, setTab] = useState<'dm' | 'community'>(initialTab || (initialConvId ? 'dm' : 'community'))

  // Community / Channels
  const [channels, setChannels] = useState<ChatChannel[]>([])
  const [activeChannelId, setActiveChannelId] = useState<string | null>(null)
  const [activeChannelConvId, setActiveChannelConvId] = useState<string | null>(null)
  const [communityMessages, setCommunityMessages] = useState<Message[]>([])
  const [communityRoom, setCommunityRoom] = useState<Conversation | null>(null)
  const [communityLoading, setCommunityLoading] = useState(true)
  const [showLiveRoom, setShowLiveRoom] = useState(false)
  const [liveRoomName, setLiveRoomName] = useState<string | null>(null)
  const [now, setNow] = useState(() => Date.now())
  const [myDisplayName, setMyDisplayName] = useState('Mitglied')
  const [myAvatarUrl, setMyAvatarUrl] = useState<string | null>(null)
  const [pinnedMessages, setPinnedMessages] = useState<Message[]>([])
  const [showPinned, setShowPinned] = useState(false)
  const [announcements, setAnnouncements] = useState<Announcement[]>([])
  const [dismissedAnnouncements, setDismissedAnnouncements] = useState<Set<string>>(() => {
    // Load persisted dismissed IDs from localStorage on mount
    if (typeof window !== 'undefined') {
      try {
        const stored = localStorage.getItem('mensaena_dismissed_announcements')
        if (stored) return new Set<string>(JSON.parse(stored))
      } catch { /* ignore */ }
    }
    return new Set<string>()
  })

  // DM
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [userPresence, setUserPresence] = useState<Record<string, { status: string; updated_at: string }>>({})
  const [activeConvId, setActiveConvId] = useState<string | null>(initialConvId ?? null)
  const [messages, setMessages] = useState<Message[]>([])

  // Search (innerhalb eines Chats)
  const [searchQuery, setSearchQuery] = useState('')
  const [showSearch, setShowSearch] = useState(false)
  // Search (Konversationsliste)
  const [convSearch, setConvSearch] = useState('')

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
  const [donorTier, setDonorTier] = useState(0)
  const [donationCount, setDonationCount] = useState(0)
  const [showCreateChannel, setShowCreateChannel] = useState(false)
  const [upgradeModal, setUpgradeModal] = useState<{ featureLabel: string; requiredTier: number } | null>(null)
  // DM Calls
  const [activeDMCall, setActiveDMCall] = useState<{ id: string; caller_id: string; call_type: 'audio' | 'video'; room_name: string; status: string } | null>(null)

  // Outgoing call state — gesetzt wenn der User den Call gestartet hat,
  // zeigt OutgoingCallScreen bis Annahme/Ablehnung/Timeout.
  const [outgoingCallState, setOutgoingCallState] = useState<{
    callId: string
    roomName: string
    callType: 'audio' | 'video'
    calleeName: string
    calleeAvatar: string | null
  } | null>(null)
  // Aktiver 1:1-Call (nach Annahme) – Token + URL für LiveRoomModal vorab geladen.
  const [activeDMCallSession, setActiveDMCallSession] = useState<{
    callId: string
    roomName: string
    token: string
    url: string
    callType: 'audio' | 'video'
  } | null>(null)
  const [dmCallLoading, setDmCallLoading] = useState(false)
  const [isBanned, setIsBanned] = useState(false)
  const [replyTo, setReplyTo] = useState<Message | null>(null)
  const [forwardMsg, setForwardMsg] = useState<Message | null>(null)
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

  const [uploadingImage, setUploadingImage] = useState(false)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [imageFile, setImageFile] = useState<File | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Drag & Drop
  const [isDragging, setIsDragging] = useState(false)

  // @Mentions
  const [mentionQuery, setMentionQuery] = useState('')
  const [showMentionMenu, setShowMentionMenu] = useState(false)
  const [mentionCaretPos, setMentionCaretPos] = useState(0)

  // Polls
  const [polls, setPolls] = useState<Poll[]>([])
  const [showPollModal, setShowPollModal] = useState(false)
  const [pollQuestion, setPollQuestion] = useState('')
  const [pollOptions, setPollOptions] = useState(['', ''])
  const [creatingPoll, setCreatingPoll] = useState(false)

  // Scheduled Events
  const [channelEvents, setChannelEvents] = useState<ChannelEvent[]>([])
  const [showEventModal, setShowEventModal] = useState(false)
  const [eventTitle, setEventTitle] = useState('')
  const [eventTime, setEventTime] = useState('')
  const [creatingEvent, setCreatingEvent] = useState(false)

  // Live indicator: who is in the live room for the active channel
  const [liveRoomCount, setLiveRoomCount] = useState(0)

  // Sekunden-Ticker für Event-Countdown
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(t)
  }, [])

  const messagesEndRef = useRef<HTMLDivElement>(null)
  const messagesContainerRef = useRef<HTMLDivElement>(null)
  const isNearBottomRef = useRef(true)
  const inputRef = useRef<HTMLInputElement>(null)
  const channelRef = useRef<ReturnType<ReturnType<typeof createClient>['channel']> | null>(null)
  const communityChannelRef = useRef<ReturnType<ReturnType<typeof createClient>['channel']> | null>(null)
  const presenceChannelRef = useRef<ReturnType<ReturnType<typeof createClient>['channel']> | null>(null)
  const typingTimeout = useRef<NodeJS.Timeout | null>(null)

  // Blocked users
  const [blockedUserIds, setBlockedUserIds] = useState<Set<string>>(new Set())

  // Fallback conversation when navigated to a conv not yet in the conversations list
  const [pendingConv, setPendingConv] = useState<Conversation | null>(null)

  // Keep a ref to supabase client so it's stable across renders
  const supabaseRef = useRef(createClient())
  const supabase = supabaseRef.current

  // ── Admin & Ban Check ─────────────────────────────────────────────────────
  useEffect(() => {
    async function checkUser() {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) return
        const { data: profile } = await supabase.from('profiles').select('role, email, donor_tier, donation_count').eq('id', user.id).single()
        setIsAdmin(isAdminUser(profile as Profile))
        setDonorTier((profile as any)?.donor_tier ?? 0)
        setDonationCount((profile as any)?.donation_count ?? 0)
        const { data: ban } = await supabase
          .from('chat_banned_users').select('id,user_id,expires_at').eq('user_id', userId).maybeSingle()
        if (ban && (!(ban as any).expires_at || new Date((ban as any).expires_at) > new Date())) setIsBanned(true)
        // Blocked Users laden
        const { data: blocks } = await supabase.from('user_blocks').select('blocked_id').eq('blocker_id', userId)
        if (blocks) setBlockedUserIds(new Set(blocks.map(b => b.blocked_id)))
      } catch { /* ignore – ban/block table might not exist yet */ }
    }
    checkUser()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  // ── Kanäle laden ─────────────────────────────────────────────────────────
  const loadChannels = useCallback(async (): Promise<ChatChannel[]> => {
    try {
      // 1. Versuche chat_channels zu laden
      const { data, error: chErr } = await supabase
        .from('chat_channels')
        .select('*')
        .order('sort_order', { ascending: true })

      if (!chErr && data && data.length > 0) {
        // User-eigene Kanäle immer ganz vorne, dann nach sort_order
        const sorted = [...(data as ChatChannel[])].sort((a, b) => {
          const aOwn = a.created_by === userId ? 0 : 1
          const bOwn = b.created_by === userId ? 0 : 1
          if (aOwn !== bOwn) return aOwn - bOwn
          return (a.sort_order ?? 0) - (b.sort_order ?? 0)
        })
        setChannels(sorted)
        const def = sorted.find(c => c.is_default) ?? sorted[0]
        setActiveChannelId(prev => prev ?? def.id)
        setActiveChannelConvId(prev => prev ?? def.conversation_id)
        return sorted
      }

      // 2. Fallback: Suche bestehenden Community Chat
      // Use select('*') first, then try extended columns (they may not exist yet)
      const { data: room, error: roomErr } = await supabase
        .from('conversations')
        .select('id, type, title, created_at')
        .eq('type', 'system')
        .or('title.eq.Community Chat,title.eq.Allgemein')
        .maybeSingle()

      if (room) {
        setCommunityRoom(room as any)
        setActiveChannelConvId(room.id)
        // Synthetischen Kanal erstellen damit die UI nicht leer ist
        setChannels([{
          id: 'fallback',
          name: 'Allgemein',
          description: 'Community Chat',
          emoji: '💬',
          slug: 'allgemein',
          is_default: true,
          is_locked: (room as any).is_locked ?? false,
          locked_reason: (room as any).locked_reason ?? null,
          sort_order: 1,
          conversation_id: room.id,
        }])
        setActiveChannelId('fallback')
        return []
      }

      // 3. Letzter Fallback: Neue System-Konversation erstellen
      const { data: newConv } = await supabase
        .from('conversations')
        .insert({ type: 'system', title: 'Community Chat' })
        .select()
        .single()

      if (newConv) {
        setCommunityRoom(newConv as any)
        setActiveChannelConvId(newConv.id)
        setChannels([{
          id: 'fallback',
          name: 'Allgemein',
          description: 'Community Chat',
          emoji: '💬',
          slug: 'allgemein',
          is_default: true,
          is_locked: false,
          locked_reason: null,
          sort_order: 1,
          conversation_id: newConv.id,
        }])
        setActiveChannelId('fallback')
      }
    } catch (err) {
      console.error('loadChannels error:', err)
    } finally {
      // Sicherstellen dass Loading immer beendet wird
      setCommunityLoading(false)
    }
    return []
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => { loadChannels() }, [loadChannels])

  // ── Ankündigungen laden ───────────────────────────────────────────────────
  useEffect(() => {
    async function loadAnnouncements() {
      try {
        const { data } = await supabase
          .from('chat_announcements')
          .select('*')
          .eq('is_active', true)
          .order('created_at', { ascending: false })
          .limit(5)
        if (data) setAnnouncements(data as Announcement[])
      } catch { /* ignore – announcements table might not exist yet */ }
    }
    loadAnnouncements()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Community-Nachrichten laden ───────────────────────────────────────────
  const loadCommunityMessages = useCallback(async (convId: string) => {
    try {
      // Gracefully handle missing columns by using a simpler select fallback
      let data: Message[] | null = null
      const { data: d1, error: e1 } = await supabase
        .from('messages')
        .select('*, profiles!messages_sender_id_fkey(id, name, avatar_url, nickname, role, email, donor_tier), reply_to:reply_to_id(content, profiles!messages_sender_id_fkey(name))')
        .eq('conversation_id', convId)
        .is('deleted_at', null)
        .order('created_at', { ascending: true })
        .limit(80)
      if (!e1) {
        data = d1 as Message[]
      } else {
        // Fallback: select without new columns (reply_to_id / deleted_at may not exist)
        const { data: d2 } = await supabase
          .from('messages')
          .select('*, profiles!messages_sender_id_fkey(id, name, avatar_url, nickname, email, donor_tier)')
          .eq('conversation_id', convId)
          .order('created_at', { ascending: true })
          .limit(80)
        data = d2 as Message[]
      }
      if (!data) return

      const msgIds = (data as Message[]).map(m => m.id)
      let reactionsMap: Record<string, Reaction[]> = {}
      if (msgIds.length > 0) {
        try {
          const { data: reactions } = await supabase.from('message_reactions').select('*').in('message_id', msgIds)
          if (reactions) {
            for (const r of reactions as Reaction[]) {
              if (!reactionsMap[r.message_id]) reactionsMap[r.message_id] = []
              reactionsMap[r.message_id].push(r)
            }
          }
        } catch { /* reactions table may not exist */ }
      }
      setCommunityMessages((data as Message[]).map(m => ({ ...m, reactions: reactionsMap[m.id] ?? [] })))

      // Angepinnte Nachrichten laden
      try {
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
      } catch { setPinnedMessages([]) /* pins table may not exist */ }
    } catch (err) {
      console.error('loadCommunityMessages error:', err)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Kanal wechseln ────────────────────────────────────────────────────────
  const switchChannel = useCallback(async (channel: ChatChannel) => {
    haptic.selection()
    setActiveChannelId(channel.id)
    setActiveChannelConvId(channel.conversation_id)
    // ── BUG FIX: Nachrichten sofort leeren damit keine alten Kanal-Nachrichten
    //            sichtbar sind während der neue Kanal lädt
    setCommunityMessages([])
    setPinnedMessages([])
    setCommunityLoading(true)
    setShowSearch(false)
    setSearchQuery('')

    const { data: conv } = await supabase
      .from('conversations')
      .select('*')
      .eq('id', channel.conversation_id).single()
    if (conv) setCommunityRoom(prev => ({ ...(prev ?? {}), ...conv, is_locked: (conv as any).is_locked ?? false, locked_reason: (conv as any).locked_reason ?? null } as any))
    await loadCommunityMessages(channel.conversation_id)
    setCommunityLoading(false)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loadCommunityMessages])

  // Initialer Kanal laden
  useEffect(() => {
    if (!activeChannelConvId) return
    if (tab !== 'community') return
    // BUG FIX: Nachrichten sofort leeren beim Kanalwechsel
    setCommunityMessages([])
    setPinnedMessages([])
    setCommunityLoading(true)
    const convId = activeChannelConvId
    Promise.all([
      supabase.from('conversations')
        .select('*')
        .eq('id', convId).single()
        .then(({ data }) => { if (data) setCommunityRoom(prev => ({ ...(prev ?? {}), ...data, is_locked: (data as any).is_locked ?? false, locked_reason: (data as any).locked_reason ?? null } as any)) }),
      loadCommunityMessages(convId),
    ])
      .catch(err => console.error('initial channel load error:', err))
      .finally(() => setCommunityLoading(false))
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

  // ── Profildaten für Live-Raum vorladen ─────────────────────
  useEffect(() => {
    let cancelled = false
    async function loadLiveProfile() {
      const supabase = createClient()
      const { data } = await supabase
        .from('profiles')
        .select('name, nickname, avatar_url')
        .eq('id', userId)
        .single()
      if (cancelled || !data) return
      setMyDisplayName(data.nickname || data.name || 'Mitglied')
      setMyAvatarUrl(data.avatar_url ?? null)
    }
    loadLiveProfile()
    return () => { cancelled = true }
  }, [userId])

  const handleOpenLiveRoom = () => {
    setLiveRoomName(null)
    setShowLiveRoom(true)

    // Notify all users with active push subscriptions (fire-and-forget)
    const activeChannel = channels.find(c => c.id === activeChannelId)
    if (activeChannel) {
      fetch('/api/live-room/notify', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({
          channelLabel: `# ${activeChannel.name}`,
          channelSlug:  activeChannel.slug ?? 'community',
        }),
      }).catch(() => { /* non-critical */ })
    }
  }

  // ── Live-Room Presence ────────────────────────────────────────────────────
  useEffect(() => {
    if (!activeChannelId) return
    const slug = channels.find(c => c.id === activeChannelId)?.slug ?? activeChannelId
    const liveChannel = supabase.channel(`live-room:${slug}`, {
      config: { presence: { key: userId } },
    })
    liveChannel
      .on('presence', { event: 'sync' }, () => {
        const state = liveChannel.presenceState()
        setLiveRoomCount(Object.keys(state).length)
      })
      .subscribe()

    // Broadcast self if currently in live room for this channel
    if (showLiveRoom) liveChannel.track({ user_id: userId, joined_at: Date.now() }).catch(() => {})

    return () => { supabase.removeChannel(liveChannel) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeChannelId, showLiveRoom])

  // ── Polls & Events laden wenn Kanal wechselt ─────────────────────────────
  useEffect(() => {
    if (!activeChannelId) return
    loadPolls(activeChannelId)
    loadEvents(activeChannelId)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeChannelId])

  // ── Realtime: Community Kanal ─────────────────────────────────────────────
  useEffect(() => {
    if (!activeChannelConvId) return
    if (communityChannelRef.current) supabase.removeChannel(communityChannelRef.current)
    const convId = activeChannelConvId
    const ch = supabase
      .channel(`cmsg:${convId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${convId}` },
        async (payload) => {
          const msg = payload.new as Message
          if (!msg.profiles) {
            const { data: p } = await supabase.from('profiles').select('id, name, avatar_url, nickname, role, email, donor_tier').eq('id', msg.sender_id).maybeSingle()
            if (p) msg.profiles = p as Profile
          }
          if (msg.reply_to_id) {
            const { data: rt } = await supabase.from('messages').select('content, profiles!messages_sender_id_fkey(name)').eq('id', msg.reply_to_id).maybeSingle()
            if (rt) msg.reply_to = rt as any
          }
          msg.reactions = []
          setCommunityMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg])
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages', filter: `conversation_id=eq.${convId}` },
        (payload) => {
          const updated = payload.new as Message
          // If message was soft-deleted, remove it from view
          if (updated.deleted_at) {
            setCommunityMessages(prev => prev.filter(m => m.id !== updated.id))
          } else {
            setCommunityMessages(prev => prev.map(m => m.id === updated.id ? { ...m, ...updated } : m))
          }
        })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'message_reactions' },
        (payload) => {
          const r = payload.new as Reaction
          setCommunityMessages(prev => prev.map(m =>
            m.id === r.message_id ? { ...m, reactions: [...(m.reactions ?? []).filter(x => !(x.user_id === r.user_id && x.emoji === r.emoji)), r] } : m
          ))
        })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'message_reactions' },
        (payload) => {
          const old = payload.old as Reaction
          setCommunityMessages(prev => prev.map(m =>
            m.id === old.message_id ? { ...m, reactions: (m.reactions ?? []).filter(r => !(r.user_id === old.user_id && r.emoji === old.emoji)) } : m
          ))
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'conversations', filter: `id=eq.${convId}` },
        (payload) => setCommunityRoom(prev => prev ? { ...prev, ...(payload.new as any) } : prev))
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'message_pins' },
        async (payload) => {
          const pin = payload.new as PinnedMessage
          // Fetch the actual message since communityMessages might be stale in closure
          const { data: msgData } = await supabase.from('messages')
            .select('*, profiles!messages_sender_id_fkey(id, name, avatar_url, nickname, role, email, donor_tier)')
            .eq('id', pin.message_id).maybeSingle()
          if (msgData) {
            setPinnedMessages(prev => prev.some(p => p.id === msgData.id) ? prev : [...prev, msgData as Message])
          }
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
    // Try full query with new columns first, fall back to basic if columns missing
    let data: unknown[] | null = null
    const { data: d1, error: e1 } = await supabase
      .from('conversation_members')
      .select(`conversation_id, last_read_at,
        conversations(id, type, title, post_id, updated_at, created_at,
          conversation_members(user_id, last_read_at, profiles(id, name, email, avatar_url, nickname)),
          messages(id, content, created_at, sender_id))`)
      .eq('user_id', userId).order('created_at', { ascending: false })
    if (!e1) {
      data = d1
    } else {
      // Fallback without new columns
      const { data: d2 } = await supabase
        .from('conversation_members')
        .select(`conversation_id,
          conversations(id, type, title, created_at,
            conversation_members(user_id, profiles(id, name, email, avatar_url, nickname)),
            messages(id, content, created_at, sender_id))`)
        .eq('user_id', userId).order('created_at', { ascending: false })
      data = d2
    }
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
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  useEffect(() => { loadConversations() }, [loadConversations])

  // ── Presence (Online-Status der DM-Partner) ───────────────────────────────
  useEffect(() => {
    const partnerIds = Array.from(new Set(
      conversations
        .filter(c => c.type === 'direct')
        .map(c => c.conversation_members?.find(m => m.user_id !== userId)?.user_id)
        .filter((id): id is string => !!id),
    ))
    if (partnerIds.length === 0) return
    let cancelled = false
    ;(async () => {
      const { data } = await supabase
        .from('user_status')
        .select('user_id, status, updated_at')
        .in('user_id', partnerIds)
      if (cancelled || !data) return
      const map: Record<string, { status: string; updated_at: string }> = {}
      ;(data as { user_id: string; status: string; updated_at: string }[]).forEach(r => {
        map[r.user_id] = { status: r.status, updated_at: r.updated_at }
      })
      setUserPresence(map)
    })()
    return () => { cancelled = true }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversations.length, userId])

  useEffect(() => {
    if (initialConvId) {
      setTab('dm')
      setActiveConvId(initialConvId)
      setMobileShowChat(true)
      // Focus input when navigating to chat with a specific conversation
      setTimeout(() => inputRef.current?.focus(), 300)
    }
  }, [initialConvId])

  // ── Fetch pending conversation when activeConvId set but not in list ──────
  useEffect(() => {
    if (!activeConvId) return
    // If already in conversations list, clear any pending conv
    if (conversations.find(c => c.id === activeConvId)) {
      setPendingConv(prev => prev?.id === activeConvId ? null : prev)
      return
    }
    // Not in list yet – fetch directly from DB
    let cancelled = false
    async function fetchPendingConv() {
      const { data: cm } = await supabase
        .from('conversation_members')
        .select('user_id, last_read_at, profiles(id, name, email, avatar_url, nickname)')
        .eq('conversation_id', activeConvId!)
      const { data: conv } = await supabase
        .from('conversations')
        .select('id, type, title, post_id, updated_at, created_at')
        .eq('id', activeConvId!)
        .single()
      if (cancelled || !conv) return
      setPendingConv({
        ...conv,
        is_locked: false,
        locked_reason: null,
        conversation_members: (cm ?? []) as ConvMember[],
        last_message: null,
        unread_count: 0,
      } as Conversation)
    }
    fetchPendingConv()
    return () => { cancelled = true }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeConvId, conversations])

  // ── DM-Nachrichten ────────────────────────────────────────────────────────
  const loadDMMessages = useCallback(async (convId: string) => {
    let data: Message[] | null = null
    const { data: d1, error: e1 } = await supabase
      .from('messages')
      .select('*, profiles!messages_sender_id_fkey(id, name, avatar_url, nickname, role, email, donor_tier), reply_to:reply_to_id(content, profiles!messages_sender_id_fkey(name))')
      .eq('conversation_id', convId)
      .is('deleted_at', null)
      .order('created_at', { ascending: true }).limit(80)
    if (!e1) {
      data = d1 as Message[]
    } else {
      const { data: d2 } = await supabase
        .from('messages')
        .select('*, profiles!messages_sender_id_fkey(id, name, avatar_url, nickname, email, donor_tier)')
        .eq('conversation_id', convId)
        .order('created_at', { ascending: true }).limit(80)
      data = d2 as Message[]
    }

    const msgs = (data ?? []) as Message[]
    const msgIds = msgs.map(m => m.id)
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
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  useEffect(() => {
    if (!activeConvId) return
    loadDMMessages(activeConvId)
    if (channelRef.current) supabase.removeChannel(channelRef.current)
    const convId = activeConvId
    const ch = supabase.channel(`dm:${convId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${convId}` },
        async (payload) => {
          try {
            const msg = payload.new as Message
            if (!msg.profiles) {
              const { data: p } = await supabase.from('profiles').select('id, name, avatar_url, nickname, role, email, donor_tier').eq('id', msg.sender_id).maybeSingle()
              if (p) msg.profiles = p as Profile
            }
            msg.reactions = []
            setMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg])
            await supabase.from('conversation_members')
              .update({ last_read_at: new Date().toISOString() })
              .eq('conversation_id', convId).eq('user_id', userId)
            setConversations(prev => prev.map(c => c.id === convId ? { ...c, unread_count: 0 } : c))
          } catch (err) {
            console.error('[ChatView] DM realtime INSERT handler failed:', err)
          }
        })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages', filter: `conversation_id=eq.${convId}` },
        (payload) => {
          const updated = payload.new as Message
          if (updated.deleted_at) {
            setMessages(prev => prev.filter(m => m.id !== updated.id))
          } else {
            setMessages(prev => prev.map(m => m.id === updated.id ? { ...m, ...updated } : m))
          }
        })
      .subscribe()
    channelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeConvId, loadDMMessages, userId])

  // (initialCallId und URL-Parameter werden jetzt von GlobalCallListener gehandelt –
  //  ChatView öffnet kein LiveRoomModal mehr direkt, der Listener orchestriert
  //  Annahme/Ablehnung über die /api/dm-calls/* Endpoints.)

  // ── DM Call Subscription ──────────────────────────────────────────────────
  useEffect(() => {
    if (!activeConvId || tab !== 'dm') { setActiveDMCall(null); return }
    const convId = activeConvId
    // Stale-Cleanup: ringing-Rows älter als 2 Min sind tot (App-Crash, Netzwerk-
    // Drop, Browser geschlossen). Markieren wir als ended, damit sie den nächsten
    // Call nicht blockieren (call-Button disabled wegen !!activeDMCall).
    const STALE_CUTOFF = new Date(Date.now() - 2 * 60 * 1000).toISOString()
    supabase.from('dm_calls')
      .update({ status: 'ended', ended_at: new Date().toISOString() })
      .eq('conversation_id', convId)
      .eq('status', 'ringing')
      .lt('created_at', STALE_CUTOFF)
      .then(() => {})
    // Load any active/ringing call (frische, nicht-stale Rows)
    supabase.from('dm_calls')
      .select('*').eq('conversation_id', convId).in('status', ['ringing', 'active'])
      .gte('created_at', STALE_CUTOFF)
      .order('created_at', { ascending: false }).limit(1).maybeSingle()
      .then(({ data }) => { if (data) setActiveDMCall(data as any) })
    // Realtime: new calls. Jeder terminale Status muss activeDMCall zurücksetzen,
    // sonst bleibt der Call-Button disabled (deaktiviert wegen !!activeDMCall).
    const TERMINAL_STATUSES = new Set(['ended', 'declined', 'missed', 'cancelled'])
    const ch = supabase.channel(`dm-calls-${convId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dm_calls', filter: `conversation_id=eq.${convId}` },
        (payload) => {
          const row = payload.new as any
          if (!row || TERMINAL_STATUSES.has(row.status)) setActiveDMCall(null)
          else setActiveDMCall(row)
        })
      .subscribe()
    return () => { supabase.removeChannel(ch); setActiveDMCall(null) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeConvId, tab])

  // Reset near-bottom flag when conversation/channel/tab changes so initial load always scrolls down
  useEffect(() => { isNearBottomRef.current = true }, [activeConvId, activeChannelConvId, tab])

  const handleMessagesScroll = useCallback(() => {
    const el = messagesContainerRef.current
    if (!el) return
    isNearBottomRef.current = el.scrollHeight - el.scrollTop - el.clientHeight < 120
  }, [])

  // Auto-Scroll – only scroll when user is near the bottom
  useEffect(() => {
    if (isNearBottomRef.current) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }
  }, [messages, communityMessages, tab, activeChannelConvId])

  // ── Filtered Messages for Search ──────────────────────────────────────────
  const filteredCommunityMessages = useMemo(() => {
    if (!searchQuery.trim()) return communityMessages
    const q = searchQuery.toLowerCase()
    return communityMessages.filter(m => m.content.toLowerCase().includes(q))
  }, [communityMessages, searchQuery])

  const filteredDMMessages = useMemo(() => {
    if (!searchQuery.trim()) return messages
    const q = searchQuery.toLowerCase()
    return messages.filter(m => m.content.toLowerCase().includes(q))
  }, [messages, searchQuery])

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
    const allowed = await checkRateLimit(userId, 'send_message', 10, 120)
    if (!allowed) { toast.error('Zu viele Nachrichten. Bitte warte kurz.'); setSending(false); return }
    const content = newMessage.trim()
    setNewMessage('')
    setReplyTo(null)
    setIsTyping(false)
    // Try insert with reply_to_id first, fallback without if column missing
    let insertError: any = null
    const insertPayload: any = { conversation_id: roomId, sender_id: userId, content }
    if (replyTo?.id) insertPayload.reply_to_id = replyTo.id
    const { error: err1 } = await supabase.from('messages').insert(insertPayload)
    if (err1) {
      // Fallback: send without reply_to_id if column error
      if (err1.message?.includes('reply_to_id') || err1.code === '42703') {
        const { error: err2 } = await supabase.from('messages').insert({
          conversation_id: roomId, sender_id: userId, content
        })
        insertError = err2
      } else {
        insertError = err1
      }
    }
    if (insertError) {
      console.error('Send message error:', insertError)
      toast.error('Nachricht konnte nicht gesendet werden')
      setNewMessage(content) // restore on error
      haptic.error()
    } else {
      haptic.success()
    }
    setSending(false)
    setTimeout(() => inputRef.current?.focus(), 50)
  }

  // ── Bild hochladen & senden ───────────────────────────────────────────────
  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 10 * 1024 * 1024) { toast.error('Bild zu groß (max. 10MB)'); return }
    setImageFile(file)
    setImagePreview(URL.createObjectURL(file))
  }

  const handleSendImage = async () => {
    if (!imageFile || uploadingImage) return
    const roomId = tab === 'community' ? activeChannelConvId : activeConvId
    if (!roomId) return
    setUploadingImage(true)
    try {
      const ext = imageFile.name.split('.').pop()?.toLowerCase() ?? 'jpg'
      // Einmaliger stabiler Dateiname – kein zweiter Date.now()-Aufruf!
      const uniqueName = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`
      const filePath = `chat/${userId}/${uniqueName}`

      // chat-images ist der primäre Bucket (öffentlich, 10MB limit)
      // avatars als Fallback falls chat-images Policy-Fehler hat
      const buckets = ['chat-images', 'avatars'] as const
      let publicUrl: string | null = null

      for (const bucket of buckets) {
        const { error: uploadErr } = await supabase.storage
          .from(bucket)
          .upload(filePath, imageFile, { upsert: false, contentType: imageFile.type })

        if (!uploadErr) {
          const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(filePath)
          publicUrl = urlData.publicUrl
          break
        }
        // Bucket nicht vorhanden oder sonstiger Fehler → nächsten probieren
        // Bucket not available or policy error - try next bucket silently
      }

      if (!publicUrl) {
        toast.error('Bild-Upload fehlgeschlagen – kein verfügbarer Speicher')
        setUploadingImage(false)
        return
      }

      // Nachricht mit Markdown-Bild-Link senden
      const content = `![Bild](${publicUrl})`
      const { error: msgErr } = await supabase.from('messages').insert({
        conversation_id: roomId,
        sender_id: userId,
        content,
      })
      if (msgErr) {
        toast.error('Nachricht konnte nicht gesendet werden')
        setUploadingImage(false)
        return
      }

      setImageFile(null)
      setImagePreview(null)
      if (fileInputRef.current) fileInputRef.current.value = ''
      toast.success('Bild gesendet!')
    } catch (err) {
      console.error('handleSendImage error:', err)
      toast.error('Fehler beim Senden')
    }
    setUploadingImage(false)
  }

  const cancelImage = () => {
    setImageFile(null)
    setImagePreview(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  // ── Nachricht bearbeiten ──────────────────────────────────────────────────
  const handleEditMessage = async (msgId: string) => {
    if (!editContent.trim()) return
    const { error } = await supabase.from('messages').update({
      content: editContent.trim(),
      edited_at: new Date().toISOString(),
    }).eq('id', msgId)
    if (!error) {
      const update = (msgs: Message[]) => msgs.map(m => m.id === msgId ? { ...m, content: editContent.trim(), edited_at: new Date().toISOString() } : m)
      if (tab === 'community') setCommunityMessages(update)
      else setMessages(update)
    }
    setEditingMsgId(null)
    setEditContent('')
  }

  // ── Drag & Drop ───────────────────────────────────────────────────────────
  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(true)
  }, [])

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    if (!e.currentTarget.contains(e.relatedTarget as Node)) setIsDragging(false)
  }, [])

  const handleDropFile = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
    const file = e.dataTransfer.files[0]
    if (!file) return
    if (file.size > 10 * 1024 * 1024) { toast.error('Datei zu groß (max. 10MB)'); return }
    if (!file.type.startsWith('image/')) { toast.error('Nur Bilder können gesendet werden'); return }
    setImageFile(file)
    setImagePreview(URL.createObjectURL(file))
  }, [])

  // ── @Mentions ─────────────────────────────────────────────────────────────
  const selectMention = useCallback((name: string) => {
    const before = newMessage.slice(0, mentionCaretPos)
    const after = newMessage.slice(mentionCaretPos + 1 + mentionQuery.length)
    setNewMessage(`${before}@${name} ${after}`)
    setShowMentionMenu(false)
    setTimeout(() => inputRef.current?.focus(), 10)
  }, [newMessage, mentionCaretPos, mentionQuery])

  // ── Typing ────────────────────────────────────────────────────────────────
  const handleInputChange = (val: string) => {
    setNewMessage(val)

    // @mention detection
    const lastAt = val.lastIndexOf('@')
    if (lastAt !== -1) {
      const afterAt = val.slice(lastAt + 1)
      if (!afterAt.includes(' ')) {
        setMentionQuery(afterAt.toLowerCase())
        setMentionCaretPos(lastAt)
        setShowMentionMenu(true)
        return
      }
    }
    setShowMentionMenu(false)

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

  // ── Polls laden & erstellen ───────────────────────────────────────────────
  const loadPolls = useCallback(async (channelId: string) => {
    try {
      const { data } = await supabase
        .from('channel_polls')
        .select('*, votes:poll_votes(option_index, user_id)')
        .eq('channel_id', channelId)
        .order('created_at', { ascending: false })
        .limit(5)
      if (data) setPolls(data.map((p: any) => ({ ...p, options: Array.isArray(p.options) ? p.options : [], votes: p.votes ?? [] })))
    } catch { /* table not yet created */ }
  }, [supabase])

  const createPoll = async () => {
    const opts = pollOptions.filter(o => o.trim())
    if (!pollQuestion.trim() || opts.length < 2 || !activeChannelId) return
    setCreatingPoll(true)
    try {
      const { error } = await supabase.from('channel_polls').insert({
        channel_id: activeChannelId, created_by: userId,
        question: pollQuestion.trim(), options: opts,
      })
      if (!error) {
        toast.success('Abstimmung erstellt!')
        setShowPollModal(false)
        setPollQuestion('')
        setPollOptions(['', ''])
        loadPolls(activeChannelId)
      } else { toast.error('Fehler: ' + error.message) }
    } finally { setCreatingPoll(false) }
  }

  const votePoll = async (pollId: string, optionIndex: number) => {
    const poll = polls.find(p => p.id === pollId)
    const existing = poll?.votes?.find(v => v.user_id === userId)
    if (existing) {
      await supabase.from('poll_votes').delete().eq('poll_id', pollId).eq('user_id', userId)
    }
    await supabase.from('poll_votes').insert({ poll_id: pollId, user_id: userId, option_index: optionIndex })
    if (activeChannelId) loadPolls(activeChannelId)
  }

  // ── Events laden & erstellen ──────────────────────────────────────────────
  const loadEvents = useCallback(async (channelId: string) => {
    try {
      const { data } = await supabase
        .from('channel_events')
        .select('*, rsvps:event_rsvps(user_id)')
        .eq('channel_id', channelId)
        .gte('scheduled_at', new Date().toISOString())
        .order('scheduled_at', { ascending: true })
        .limit(3)
      if (data) setChannelEvents(data.map((e: any) => ({ ...e, rsvps: e.rsvps ?? [] })))
    } catch { /* table not yet created */ }
  }, [supabase])

  const createEvent = async () => {
    if (!eventTitle.trim() || !eventTime || !activeChannelId) return
    setCreatingEvent(true)
    try {
      const activeChannel = channels.find(c => c.id === activeChannelId)
      const { error } = await supabase.from('channel_events').insert({
        channel_id: activeChannelId, created_by: userId,
        title: eventTitle.trim(),
        scheduled_at: new Date(eventTime).toISOString(),
        room_name: `mensaena-${activeChannel?.slug ?? 'community'}`,
      })
      if (!error) {
        toast.success('Event erstellt!')
        setShowEventModal(false)
        setEventTitle('')
        setEventTime('')
        loadEvents(activeChannelId)
      } else { toast.error('Fehler: ' + error.message) }
    } finally { setCreatingEvent(false) }
  }

  const toggleRsvp = async (eventId: string) => {
    const ev = channelEvents.find(e => e.id === eventId)
    const hasRsvp = ev?.rsvps?.some(r => r.user_id === userId)
    if (hasRsvp) {
      await supabase.from('event_rsvps').delete().eq('event_id', eventId).eq('user_id', userId)
    } else {
      await supabase.from('event_rsvps').insert({ event_id: eventId, user_id: userId })
    }
    if (activeChannelId) loadEvents(activeChannelId)
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
      haptic.light()
      await supabase.from('message_reactions').insert({ message_id: msgId, user_id: userId, emoji })
    }
    // Optimistic update for both tabs
    const updateReactions = (msgs: Message[]) => msgs.map(m => {
      if (m.id !== msgId) return m
      return existing
        ? { ...m, reactions: (m.reactions ?? []).filter(r => !(r.user_id === userId && r.emoji === emoji)) }
        : { ...m, reactions: [...(m.reactions ?? []), { message_id: msgId, user_id: userId, emoji }] }
    })
    if (tab === 'community') setCommunityMessages(updateReactions)
    else setMessages(updateReactions)
  }

  // ── Nachricht löschen ─────────────────────────────────────────────────────
  const handleDeleteMessage = async (msgId: string, senderId: string) => {
    setMsgMenuFor(null)
    if (!isAdmin && senderId !== userId) return
    haptic.warning()
    // Snapshot for rollback
    const prevCommunity = communityMessages
    const prevDM = messages
    // Optimistic removal
    if (tab === 'community') setCommunityMessages(prev => prev.filter(m => m.id !== msgId))
    else setMessages(prev => prev.filter(m => m.id !== msgId))
    const { error } = await supabase.from('messages').update({ deleted_at: new Date().toISOString() }).eq('id', msgId)
    if (error) {
      toast.error('Nachricht konnte nicht gelöscht werden')
      if (tab === 'community') setCommunityMessages(prevCommunity)
      else setMessages(prevDM)
    }
  }

  // ── Nachricht anpinnen ────────────────────────────────────────────────────
  const handlePinMessage = async (msg: Message) => {
    setMsgMenuFor(null)
    if (!isAdmin) return
    const convId = tab === 'community' ? activeChannelConvId : activeConvId
    if (!convId) return
    const alreadyPinned = pinnedMessages.some(p => p.id === msg.id)
    if (alreadyPinned) {
      // Optimistic
      setPinnedMessages(prev => prev.filter(p => p.id !== msg.id))
      const { error } = await supabase.from('message_pins').delete().eq('message_id', msg.id)
      if (error) {
        toast.error('Pin konnte nicht entfernt werden')
        setPinnedMessages(prev => prev.some(p => p.id === msg.id) ? prev : [...prev, msg])
      }
    } else {
      setPinnedMessages(prev => [...prev, msg])
      const { error } = await supabase.from('message_pins').insert({ message_id: msg.id, pinned_by: userId })
      if (error) {
        toast.error('Nachricht konnte nicht angepinnt werden')
        setPinnedMessages(prev => prev.filter(p => p.id !== msg.id))
      }
    }
  }

  // ── DM 1:1 Call starten – nutzt /api/dm-calls/start, zeigt OutgoingCallScreen ─
  const handleStartCall = async (type: 'audio' | 'video') => {
    if (!activeConvId) return
    haptic.heavy()
    setDmCallLoading(true)
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const accessToken = session?.access_token ?? ''
      const res = await fetch('/api/dm-calls/start', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        },
        body: JSON.stringify({ conversationId: activeConvId, callType: type }),
      })
      if (!res.ok) {
        const errBody = await res.json().catch(() => ({ error: 'Unbekannt' }))
        toast.error(errBody.error ?? 'Call konnte nicht gestartet werden.')
        return
      }
      const result = await res.json() as { callId: string; roomName: string }
      // Partner-Profil aus conversations holen.
      const conv = conversations.find(c => c.id === activeConvId)
      const convPartner = conv?.conversation_members.find(m => m.user_id !== userId)?.profiles
      let partnerName: string | null = convPartner?.name ?? null
      let partnerAvatar: string | null = convPartner?.avatar_url ?? null
      // Direkt-Navigation per ?conv=<id>: conv steht im State noch nicht
      // bzw. hat keine populated profiles. Fallback: Members + Profile direkt laden.
      if (!convPartner) {
        const { data: members } = await supabase
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', activeConvId)
        const partnerId = (members ?? []).find((m: { user_id: string }) => m.user_id !== userId)?.user_id
        if (partnerId) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('name, avatar_url')
            .eq('id', partnerId)
            .maybeSingle<{ name: string | null; avatar_url: string | null }>()
          if (profile) {
            partnerName = profile.name
            partnerAvatar = profile.avatar_url
          }
        }
      }
      setOutgoingCallState({
        callId: result.callId,
        roomName: result.roomName,
        callType: type,
        calleeName: partnerName ?? 'Empfänger',
        calleeAvatar: partnerAvatar,
      })
    } catch { toast.error('Call konnte nicht gestartet werden.') }
    finally { setDmCallLoading(false) }
  }

  const handleEndCall = async () => {
    if (!activeDMCall) return
    try {
      await fetch('/api/dm-calls/cancel', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId: activeDMCall.id }),
      })
    } catch { /* server timeout will catch */ }
    setActiveDMCall(null)
  }

  // (Ringtone + 45s-Timeout-Logik wurde nach OutgoingCallScreen / IncomingCallScreen verlagert.)

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
    const { data } = await supabase.from('chat_announcements').insert({
      title: announceTitle.trim(),
      content: announceContent.trim(),
      type: announceType,
      is_active: true,
      created_by: userId,
    }).select().single()
    // Also remove from locally-dismissed list so newly created ones show immediately
    if (data) {
      setDismissedAnnouncements(prev => {
        const next = new Set([...prev])
        next.delete(data.id)
        try {
          localStorage.setItem('mensaena_dismissed_announcements', JSON.stringify([...next]))
        } catch { /* ignore */ }
        return next
      })
      setAnnouncements(prev => [data as Announcement, ...prev])
    }
    setShowAnnounceModal(false)
    setAnnounceTitle('')
    setAnnounceContent('')
    setAnnounceType('info')
  }

  // ── Admin: Ankündigung löschen ────────────────────────────────────────────
  const handleDeleteAnnouncement = async (id: string) => {
    await supabase.from('chat_announcements').update({ is_active: false }).eq('id', id)
    setAnnouncements(prev => prev.filter(a => a.id !== id))
    // Also remove from dismissed so no stale entries
    setDismissedAnnouncements(prev => {
      const next = new Set([...prev])
      next.delete(id)
      try {
        localStorage.setItem('mensaena_dismissed_announcements', JSON.stringify([...next]))
      } catch { /* ignore */ }
      return next
    })
  }

  // ── Ankündigung schließen ─────────────────────────────────────────────────
  const dismissAnnouncement = (id: string) => {
    setDismissedAnnouncements(prev => {
      const next = new Set([...prev, id])
      // Persist to localStorage so dismissals survive page navigation
      try {
        localStorage.setItem('mensaena_dismissed_announcements', JSON.stringify([...next]))
      } catch { /* ignore */ }
      return next
    })
  }

  // ── Nachricht weiterleiten ──────────────────────────────────────────────
  const handleForward = async (targetConvId: string) => {
    if (!forwardMsg) return
    const { error } = await supabase.from('messages').insert({
      conversation_id: targetConvId,
      sender_id: userId,
      content: `↪ Weitergeleitete Nachricht:\n${forwardMsg.content}`,
    })
    if (error) { toast.error('Weiterleiten fehlgeschlagen'); return }
    toast.success('Nachricht weitergeleitet')
    setForwardMsg(null)
  }

  // ── User blockieren / entblocken ────────────────────────────────────────
  const handleBlockUser = async (targetUserId: string) => {
    const isBlocked = blockedUserIds.has(targetUserId)
    if (isBlocked) {
      await supabase.from('user_blocks').delete().eq('blocker_id', userId).eq('blocked_id', targetUserId)
      setBlockedUserIds(prev => { const next = new Set(prev); next.delete(targetUserId); return next })
      toast.success('Nutzer entblockt')
    } else {
      await supabase.from('user_blocks').insert({ blocker_id: userId, blocked_id: targetUserId, type: 'chat' })
      setBlockedUserIds(prev => new Set(prev).add(targetUserId))
      toast.success('Nutzer blockiert — keine Nachrichten mehr')
    }
  }

  // ── Konversation löschen ─────────────────────────────────────────────────
  const handleDeleteConversation = async (convId: string) => {
    const { error } = await supabase
      .from('conversation_members')
      .delete()
      .eq('conversation_id', convId)
      .eq('user_id', userId)
    if (error) { toast.error('Konversation konnte nicht gelöscht werden'); return }
    setConversations(prev => prev.filter(c => c.id !== convId))
    if (activeConvId === convId) {
      setActiveConvId(null)
      setMobileShowChat(false)
      setMessages([])
    }
    toast.success('Konversation gelöscht')
  }

  // ── Konversation öffnen ───────────────────────────────────────────────────
  const openConv = (conv: Conversation) => {
    setActiveConvId(conv.id)
    setMobileShowChat(true)
    setSearchQuery('')
    setShowSearch(false)
    setConversations(prev => prev.map(c => c.id === conv.id ? { ...c, unread_count: 0 } : c))
    // Focus the message input after the conversation view renders
    setTimeout(() => inputRef.current?.focus(), 150)
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

  const activeConv = conversations.find(c => c.id === activeConvId) ?? pendingConv
  const allMembers = activeConv?.conversation_members ?? communityRoom?.conversation_members ?? []
  const activeChannel = channels.find(c => c.id === activeChannelId)

  // @mention candidates from channel members
  const mentionCandidates = showMentionMenu
    ? allMembers
        .filter(m => m.user_id !== userId && (
          m.profiles?.name?.toLowerCase().includes(mentionQuery) ||
          m.profiles?.nickname?.toLowerCase().includes(mentionQuery)
        ))
        .slice(0, 6)
    : []

  // Partner's last_read_at for DM read receipts
  const partnerLastReadAt = activeConv?.conversation_members
    .find(m => m.user_id !== userId)?.last_read_at ?? null
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

  const displayCommunityMessages = showSearch && searchQuery ? filteredCommunityMessages : communityMessages
  const displayDMMessages = showSearch && searchQuery ? filteredDMMessages : messages

  return (
    <div className="h-[calc(100dvh-5rem)] md:h-[calc(100vh-8rem)] flex flex-col" onClick={() => { setShowEmojiFor(null); setMsgMenuFor(null) }}>

      {/* Header */}
      <div className="mb-3 flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-2xl bg-gradient-to-br from-primary-500 to-primary-600 flex items-center justify-center shadow-md shadow-primary-400/30 flex-shrink-0">
            <MessageCircle className="w-4.5 h-4.5 text-white" style={{ width: '18px', height: '18px' }} />
          </div>
          <div>
            <h1 className="text-lg font-bold text-gray-900 leading-tight">
              {tab === 'community' ? 'Community' : 'Nachrichten'}
            </h1>
            <p className="text-xs text-gray-500">
              {tab === 'community' ? 'Kanäle & Live-Räume' : 'Direktnachrichten'}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {tab === 'dm' && (
            <button onClick={() => setShowNewChat(true)} className="btn-primary gap-2 flex items-center text-sm">
              <Plus className="w-4 h-4" /> Neu
            </button>
          )}
          {tab === 'community' && (
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => canPostAnnouncement(donorTier, isAdmin)
                  ? setShowAnnounceModal(true)
                  : setUpgradeModal({ featureLabel: 'Ankündigungen posten', requiredTier: 3 })}
                className={cn('flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shadow-sm relative',
                  canPostAnnouncement(donorTier, isAdmin)
                    ? 'bg-primary-600 text-white hover:bg-primary-700'
                    : 'bg-gray-200 text-gray-400 hover:bg-gray-300')}>
                {!canPostAnnouncement(donorTier, isAdmin) && <Lock className="w-3 h-3 absolute -top-1 -right-1 bg-gray-400 text-white rounded-full p-0.5" style={{ width: '14px', height: '14px', padding: '2px' }} />}
                <Megaphone className="w-3.5 h-3.5" /> Ankündigung
              </button>
              {isAdmin && (
                <button
                  onClick={() => communityRoom?.is_locked ? handleToggleLock() : setShowLockModal(true)}
                  className={cn('flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shadow-sm',
                    communityRoom?.is_locked ? 'bg-primary-600 text-white hover:bg-primary-700' : 'bg-red-500 text-white hover:bg-red-600')}>
                  {communityRoom?.is_locked
                    ? <><Volume2 className="w-3.5 h-3.5" /> Freigeben</>
                    : <><VolumeX className="w-3.5 h-3.5" /> Sperren</>}
                </button>
              )}
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
              <button onClick={() => dismissAnnouncement(a.id)} aria-label="Ankündigung schließen" className="p-1.5 opacity-60 hover:opacity-100 flex-shrink-0">
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Tabs — nur anzeigen wenn KEIN initialTab gesetzt (alte Kombi-Ansicht) */}
      {!initialTab && (
      <div className="flex gap-0.5 bg-gray-100/80 p-1 rounded-2xl mb-3 flex-shrink-0 border border-gray-200/50">
        <button onClick={() => { haptic.selection(); setTab('community'); setShowSearch(false); setSearchQuery('') }}
          className={cn('flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl text-sm font-semibold transition-all',
            tab === 'community' ? 'bg-white shadow-sm text-gray-900 shadow-gray-200' : 'text-gray-500 hover:text-gray-700 hover:bg-white/50')}>
          <Hash className="w-4 h-4" />
          <span className="hidden sm:inline">Community</span>
          <span className="sm:hidden">Kanäle</span>
          {(activeChannel?.is_locked || communityRoom?.is_locked) && <Lock className="w-3 h-3 text-red-400" />}
        </button>
        <button onClick={() => { haptic.selection(); setTab('dm'); setShowSearch(false); setSearchQuery('') }}
          className={cn('flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl text-sm font-semibold transition-all',
            tab === 'dm' ? 'bg-white shadow-sm text-gray-900 shadow-gray-200' : 'text-gray-500 hover:text-gray-700 hover:bg-white/50')}>
          <Mail className="w-4 h-4" />
          <span className="hidden sm:inline">Nachrichten</span>
          <span className="sm:hidden">DMs</span>
          {totalUnread > 0 && (
            <span className="min-w-[18px] h-[18px] bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1">
              {totalUnread > 9 ? '9+' : totalUnread}
            </span>
          )}
        </button>
      </div>
      )}

      {/* ══ Community-Tab ══ */}
      {tab === 'community' && (
        <div className="flex-1 flex flex-col md:flex-row min-h-0 gap-3">

          {/* ─── Channel-Sidebar (Desktop) ─── */}
          <div className="hidden md:flex flex-col w-52 flex-shrink-0 bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
            <div className="px-3 pt-3 pb-2 border-b border-gray-100">
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1">Kanäle</p>
            </div>
            <div className="flex-1 overflow-y-auto py-2 no-scrollbar">
              {channels.length === 0 ? (
                <div className="flex items-center gap-2 px-3 py-2 text-xs text-gray-400">
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  <span>Laden…</span>
                </div>
              ) : (() => {
                const cats = [...new Set(channels.map(ch => ch.category ?? 'Allgemein'))]
                return cats.map(cat => (
                  <div key={cat} className="mb-2">
                    {cats.length > 1 && (
                      <p className="text-[9px] font-bold text-gray-400 uppercase tracking-widest px-4 py-1">{cat}</p>
                    )}
                    {channels.filter(ch => (ch.category ?? 'Allgemein') === cat).map(ch => (
                      <button
                        key={ch.id}
                        onClick={() => switchChannel(ch)}
                        className={cn(
                          'w-full flex items-center gap-2.5 px-3 py-2 mx-1 rounded-xl text-sm transition-all text-left',
                          activeChannelId === ch.id
                            ? 'bg-primary-50 text-primary-700 font-semibold'
                            : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                        )}
                        style={{ width: 'calc(100% - 8px)' }}
                      >
                        <span className="text-base leading-none flex-shrink-0">{ch.emoji}</span>
                        <span className="flex-1 truncate">{ch.name}</span>
                        {ch.is_locked && <Lock className="w-3 h-3 opacity-50 flex-shrink-0" />}
                      </button>
                    ))}
                  </div>
                ))
              })()}
            </div>
            {/* Sticky create button – immer sichtbar, kein Scrollen nötig */}
            <div className="p-2 border-t border-gray-100 flex-shrink-0">
              <button
                onClick={() => canCreateChannel(donorTier, isAdmin)
                  ? setShowCreateChannel(true)
                  : setUpgradeModal({ featureLabel: 'Eigenen Kanal erstellen', requiredTier: 2 })}
                className={cn(
                  'w-full flex items-center justify-center gap-2 py-2 rounded-xl text-xs font-semibold transition-all',
                  canCreateChannel(donorTier, isAdmin)
                    ? 'bg-primary-50 text-primary-600 hover:bg-primary-100 border border-primary-200'
                    : 'bg-gray-50 text-gray-400 border border-dashed border-gray-300 hover:bg-gray-100'
                )}
                title={canCreateChannel(donorTier, isAdmin) ? 'Neuen Kanal erstellen' : '🔒 Förderer-Funktion (Tier 2)'}>
                {canCreateChannel(donorTier, isAdmin)
                  ? <Plus className="w-3.5 h-3.5" />
                  : <Lock className="w-3 h-3" />}
                Neuen Kanal
              </button>
            </div>
          </div>

          {/* ─── Mobile: horizontale Kanal-Pills ─── */}
          <div className="md:hidden flex-shrink-0 -mx-1">
            {/* Neuen Kanal Button – prominent ganz oben, immer sichtbar */}
            <div className="flex items-center gap-2 px-1 mb-2">
              <button
                onClick={() => canCreateChannel(donorTier, isAdmin)
                  ? setShowCreateChannel(true)
                  : setUpgradeModal({ featureLabel: 'Eigenen Kanal erstellen', requiredTier: 2 })}
                className={cn(
                  'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all flex-shrink-0',
                  canCreateChannel(donorTier, isAdmin)
                    ? 'bg-primary-600 text-white shadow-sm hover:bg-primary-700'
                    : 'bg-gray-100 text-gray-400 border border-dashed border-gray-300'
                )}
                title={canCreateChannel(donorTier, isAdmin) ? 'Neuen Kanal erstellen' : '🔒 Förderer-Funktion'}>
                {canCreateChannel(donorTier, isAdmin) ? <Plus className="w-3 h-3" /> : <Lock className="w-3 h-3" />}
                Neuen Kanal
              </button>
            </div>
            {(() => {
              const cats = [...new Set(channels.map(ch => ch.category ?? 'Allgemein'))]
              return cats.map(cat => (
                <div key={cat} className="mb-1.5">
                  {cats.length > 1 && <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 mb-1">{cat}</p>}
                  <div className="flex gap-1.5 overflow-x-auto no-scrollbar pb-0.5 px-1">
                    {channels.filter(ch => (ch.category ?? 'Allgemein') === cat).map(ch => (
                      <button key={ch.id} onClick={() => switchChannel(ch)}
                        className={cn(
                          'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-all flex-shrink-0',
                          activeChannelId === ch.id
                            ? 'bg-primary-600 text-white shadow-sm'
                            : 'bg-white text-gray-700 border border-gray-200 hover:bg-gray-50'
                        )}>
                        <span>{ch.emoji}</span>
                        <span>{ch.name}</span>
                        {ch.is_locked && <Lock className="w-3 h-3 opacity-70 flex-shrink-0" />}
                      </button>
                    ))}
                  </div>
                </div>
              ))
            })()}
          </div>

          {/* Chat-Bereich */}
          <div className="flex-1 card flex flex-col min-h-0 overflow-hidden">
            {/* Room Header */}
            <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-100/80 flex-shrink-0 bg-white/90 backdrop-blur-xl">
              <div className={cn('w-9 h-9 rounded-2xl flex items-center justify-center text-lg shadow-sm',
                (activeChannel?.is_locked || communityRoom?.is_locked) ? 'bg-red-50 border border-red-100' : 'bg-gradient-to-br from-primary-50 to-primary-100 border border-primary-100')}>
                {(activeChannel?.is_locked || communityRoom?.is_locked)
                  ? <Lock className="w-4 h-4 text-red-500" />
                  : <span className="leading-none">{activeChannel?.emoji ?? '💬'}</span>}
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-bold text-gray-900 text-sm leading-tight">{activeChannel?.name ?? 'Community Chat'}</p>
                {(activeChannel?.is_locked || communityRoom?.is_locked) ? (
                  <p className="text-xs text-red-500 flex items-center gap-1 mt-0.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-red-400 inline-block" />
                    Gesperrt
                  </p>
                ) : (
                  <p className="text-xs text-primary-600 flex items-center gap-1 mt-0.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-primary-400 inline-block animate-pulse" />
                    {activeChannel?.description ?? 'Aktiv'}
                  </p>
                )}
              </div>
              <div className="flex items-center gap-1.5">
                {/* Abstimmung: Förderer (tier >= 2) oder Admin */}
                <button
                  onClick={() => canCreatePoll(donorTier, isAdmin)
                    ? setShowPollModal(true)
                    : setUpgradeModal({ featureLabel: 'Umfragen erstellen', requiredTier: 2 })}
                  className={cn('p-2 rounded-xl transition-all relative',
                    canCreatePoll(donorTier, isAdmin)
                      ? 'text-gray-400 hover:bg-gray-100 hover:text-primary-600'
                      : 'text-gray-300 hover:bg-gray-50')}
                  title={canCreatePoll(donorTier, isAdmin) ? 'Abstimmung erstellen' : '🔒 Förderer-Funktion'}>
                  {!canCreatePoll(donorTier, isAdmin) && <Lock className="absolute bottom-0.5 right-0.5 text-gray-400" style={{ width: '9px', height: '9px' }} />}
                  <BarChart2 className="w-4 h-4" />
                </button>
                {/* Event planen: Partner (tier >= 3) oder Admin */}
                <button
                  onClick={() => canScheduleEvent(donorTier, isAdmin)
                    ? setShowEventModal(true)
                    : setUpgradeModal({ featureLabel: 'Livestream-Events planen', requiredTier: 3 })}
                  className={cn('p-2 rounded-xl transition-all relative',
                    canScheduleEvent(donorTier, isAdmin)
                      ? 'text-gray-400 hover:bg-gray-100 hover:text-primary-600'
                      : 'text-gray-300 hover:bg-gray-50')}
                  title={canScheduleEvent(donorTier, isAdmin) ? 'Event / Livestream planen' : '🔒 Partner-Funktion'}>
                  {!canScheduleEvent(donorTier, isAdmin) && <Lock className="absolute bottom-0.5 right-0.5 text-gray-400" style={{ width: '9px', height: '9px' }} />}
                  <CalendarPlus className="w-4 h-4" />
                </button>
                {/* Online count */}
                <div className="hidden sm:flex items-center gap-1 px-2 py-1 rounded-lg bg-primary-50">
                  <span className="w-1.5 h-1.5 rounded-full bg-primary-400 animate-pulse" />
                  <span className="text-xs font-medium text-primary-700">{onlineCount}</span>
                </div>
                {/* Pinned */}
                {pinnedMessages.length > 0 && (
                  <button onClick={() => setShowPinned(!showPinned)}
                    className="p-2 rounded-xl text-amber-500 hover:bg-amber-50 transition-all"
                    title={`${pinnedMessages.length} angepinnte Nachrichten`}>
                    <Pin className="w-4 h-4" />
                  </button>
                )}
                {/* Search Toggle */}
                <button
                  onClick={() => { setShowSearch(s => !s); setSearchQuery('') }}
                  className={cn('p-2 rounded-xl transition-all', showSearch ? 'bg-primary-50 text-primary-600' : 'text-gray-400 hover:bg-gray-100 hover:text-gray-700')}>
                  <Search className="w-4 h-4" />
                </button>
                {/* Live-Raum Button */}
                <button
                  onClick={handleOpenLiveRoom}
                  className={cn(
                    'flex items-center gap-1.5 px-3 py-2 rounded-xl text-white text-xs font-bold transition-all shadow-md',
                    liveRoomCount > 0
                      ? 'bg-red-500 hover:bg-red-600 shadow-red-400/30 animate-pulse-subtle'
                      : 'bg-gradient-to-br from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 shadow-primary-400/30'
                  )}
                >
                  {liveRoomCount > 0 ? <Radio className="w-3.5 h-3.5" /> : <Video className="w-3.5 h-3.5" />}
                  <span>{liveRoomCount > 0 ? 'LIVE' : 'Live'}</span>
                  {liveRoomCount > 0 && (
                    <span className="w-4 h-4 bg-white/25 rounded-full flex items-center justify-center text-[10px] font-bold">
                      {liveRoomCount}
                    </span>
                  )}
                </button>
              </div>
            </div>

            {/* Search Bar */}
            {showSearch && (
              <div className="px-4 py-2 border-b border-gray-100 flex-shrink-0">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
                  <input
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                    placeholder="Nachrichten durchsuchen…"
                    autoFocus
                    className="w-full pl-9 pr-8 py-1.5 text-sm bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-300"
                  />
                  {searchQuery && (
                    <button onClick={() => setSearchQuery('')} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                      <X className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
                {searchQuery && (
                  <p className="text-[11px] text-gray-400 mt-1">{filteredCommunityMessages.length} Treffer</p>
                )}
              </div>
            )}

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

            {/* Upcoming Events mit Countdown */}
            {channelEvents.length > 0 && (
              <div className="px-4 pt-3 pb-0 flex-shrink-0 space-y-2">
                {channelEvents.map(ev => {
                  const hasRsvp = ev.rsvps?.some(r => r.user_id === userId)
                  const rsvpCount = ev.rsvps?.length ?? 0
                  const secsLeft = Math.floor((new Date(ev.scheduled_at).getTime() - now) / 1000)
                  const started = secsLeft <= 0
                  const h = Math.floor(secsLeft / 3600)
                  const m = Math.floor((secsLeft % 3600) / 60)
                  const s = secsLeft % 60
                  const countdownStr = h > 0
                    ? `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`
                    : `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`

                  const channelSlug = channels.find(c => c.id === activeChannelId)?.slug ?? 'community'
                  const roomName = ev.room_name || `mensaena-event-${ev.id.slice(0, 8)}`

                  return (
                    <div key={ev.id} className={cn(
                      'flex items-center gap-3 px-3 py-2 rounded-xl border',
                      started ? 'bg-green-50 border-green-200' : 'bg-violet-50 border-violet-200'
                    )}>
                      <CalendarPlus className={cn('w-4 h-4 flex-shrink-0', started ? 'text-green-600' : 'text-violet-600')} />
                      <div className="flex-1 min-w-0">
                        <p className={cn('text-xs font-bold', started ? 'text-green-900' : 'text-violet-900')}>{ev.title}</p>
                        <p className={cn('text-xs', started ? 'text-green-700' : 'text-violet-600')}>
                          {started
                            ? '🔴 Läuft jetzt'
                            : `Startet in ${countdownStr} · ${rsvpCount} dabei`}
                        </p>
                      </div>
                      <div className="flex gap-1.5 flex-shrink-0">
                        <button onClick={() => toggleRsvp(ev.id)}
                          className={cn('text-xs font-semibold px-2.5 py-1 rounded-lg transition-all',
                            hasRsvp ? 'bg-violet-200 text-violet-800 hover:bg-violet-300' : 'bg-violet-100 text-violet-700 hover:bg-violet-200')}>
                          {hasRsvp ? '✓' : '+'}
                        </button>
                        <button
                          disabled={!started}
                          onClick={() => {
                            if (!started) return
                            setLiveRoomName(roomName)
                            setShowLiveRoom(true)
                          }}
                          className={cn(
                            'text-xs font-semibold px-2.5 py-1 rounded-lg transition-all',
                            started
                              ? 'bg-green-600 text-white hover:bg-green-700 animate-pulse'
                              : 'bg-gray-200 text-gray-400 cursor-not-allowed'
                          )}
                        >
                          {started ? '▶ Beitreten' : '🔒 Gesperrt'}
                        </button>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}

            {/* Active Polls */}
            {polls.length > 0 && (
              <div className="px-4 pt-2 pb-0 flex-shrink-0 space-y-2">
                {polls.map(poll => {
                  const totalVotes = poll.votes?.length ?? 0
                  const myVote = poll.votes?.find(v => v.user_id === userId)
                  return (
                    <div key={poll.id} className="px-3 py-2.5 bg-primary-50 border border-primary-200 rounded-xl">
                      <p className="text-xs font-bold text-primary-900 mb-2 flex items-center gap-1.5">
                        <BarChart2 className="w-3.5 h-3.5 text-primary-600" /> {poll.question}
                      </p>
                      <div className="space-y-1">
                        {poll.options.map((opt, idx) => {
                          const count = poll.votes?.filter(v => v.option_index === idx).length ?? 0
                          const pct = totalVotes ? Math.round(count / totalVotes * 100) : 0
                          const voted = myVote?.option_index === idx
                          return (
                            <button key={idx} onClick={() => votePoll(poll.id, idx)}
                              className={cn('w-full text-left px-2.5 py-1.5 rounded-lg text-xs font-medium border relative overflow-hidden transition-all',
                                voted ? 'border-primary-400 text-primary-900' : 'border-gray-200 bg-white text-gray-700 hover:bg-gray-50')}>
                              <div className="absolute inset-0 left-0 bg-primary-100 transition-all" style={{ width: `${pct}%` }} />
                              <span className="relative flex justify-between">
                                <span>{opt}</span>
                                <span className="text-gray-500">{pct}%</span>
                              </span>
                            </button>
                          )
                        })}
                      </div>
                      <p className="text-[10px] text-gray-400 mt-1">{totalVotes} Stimme{totalVotes !== 1 ? 'n' : ''}</p>
                    </div>
                  )
                })}
              </div>
            )}

            {/* Nachrichten */}
            <div ref={messagesContainerRef} onScroll={handleMessagesScroll}
              onDragOver={handleDragOver} onDragLeave={handleDragLeave} onDrop={handleDropFile}
              data-no-pull-refresh="true"
              className={cn('flex-1 overflow-y-auto px-4 py-5 space-y-0.5 no-scrollbar relative transition-all bg-gray-50/50 chat-messages-container',
                isDragging && 'ring-2 ring-inset ring-primary-400 bg-primary-50/40')}>
              {isDragging && (
                <div className="absolute inset-4 rounded-xl border-2 border-dashed border-primary-400 flex items-center justify-center pointer-events-none z-10">
                  <div className="text-center">
                    <ImageIcon className="w-8 h-8 text-primary-400 mx-auto mb-2" />
                    <p className="text-sm font-semibold text-primary-600">Bild hier ablegen</p>
                  </div>
                </div>
              )}
              {communityLoading ? (
                <div className="flex flex-col space-y-3 py-4">
                  {generateSkeletonMessages(6).map(s => (
                    <div key={s.id} className={`flex ${s.isOwnMessage ? 'justify-end' : 'justify-start'}`}>
                      <div className="animate-pulse flex gap-2">
                        {!s.isOwnMessage && <div className="w-8 h-8 rounded-full bg-stone-200" />}
                        <div className={`rounded-2xl bg-stone-200 h-10`} style={{ width: `${s.width}%`, minWidth: 120 }} />
                      </div>
                    </div>
                  ))}
                </div>
              ) : displayCommunityMessages.length === 0 ? (
                <div className="flex flex-col items-center justify-center h-full py-12">
                  {searchQuery ? (
                    <>
                      <Search className="w-10 h-10 text-stone-300 mb-3" />
                      <p className="font-semibold text-gray-500">Keine Treffer für „{searchQuery}"</p>
                    </>
                  ) : (
                    <>
                      <span className="text-4xl mb-3">{activeChannel?.emoji ?? '💬'}</span>
                      <p className="font-semibold text-gray-600 mb-1">{activeChannel?.name ?? 'Community Chat'}</p>
                      <p className="text-sm text-gray-400">{activeChannel?.description ?? 'Noch keine Nachrichten – sei der Erste!'}</p>
                    </>
                  )}
                </div>
              ) : (
                <>
                  <MessageGroup
                    messages={displayCommunityMessages} userId={userId} isAdmin={isAdmin}
                    pinnedIds={new Set(pinnedMessages.map(p => p.id))}
                    onReply={msg => { setReplyTo(msg); inputRef.current?.focus() }}
                    onForward={msg => setForwardMsg(msg)}
                    onReaction={handleReaction} onDelete={handleDeleteMessage}
                    onPin={handlePinMessage}
                    onEdit={(msg) => { setEditingMsgId(msg.id); setEditContent(msg.content) }}
                    showEmojiFor={showEmojiFor} setShowEmojiFor={setShowEmojiFor}
                    msgMenuFor={msgMenuFor} setMsgMenuFor={setMsgMenuFor}
                    editingMsgId={editingMsgId} editContent={editContent}
                    setEditContent={setEditContent} onEditSubmit={handleEditMessage}
                    onEditCancel={() => { setEditingMsgId(null); setEditContent('') }}
                    allMembers={allMembers}
                  />
                  <div ref={messagesEndRef} />
                </>
              )}
            </div>

            {/* Typing Indicator */}
            {typingUsers.length > 0 && (
              <div className="px-5 py-2 text-xs text-gray-400 flex items-center gap-2 border-t border-gray-100 flex-shrink-0 animate-slide-down">
                <span className="flex gap-1 items-end">
                  <span className="typing-dot" />
                  <span className="typing-dot" />
                  <span className="typing-dot" />
                </span>
                <span className="italic">{typingUsers.slice(0, 2).join(', ')} schreibt…</span>
              </div>
            )}

            {/* Reply Preview */}
            {replyTo && (
              <div className="px-4 py-2 bg-primary-50/80 border-t border-primary-100 flex items-center gap-2.5 flex-shrink-0">
                <div className="w-0.5 h-8 bg-primary-400 rounded-full flex-shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="text-[11px] text-primary-600 font-semibold">↩ {replyTo.profiles?.name ?? 'Nutzer'}</p>
                  <p className="text-xs text-gray-500 truncate">{replyTo.content}</p>
                </div>
                <button onClick={() => setReplyTo(null)} aria-label="Antwort aufheben" className="p-1 rounded-lg text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-all"><X className="w-3.5 h-3.5" /></button>
              </div>
            )}

            {/* Input */}
            <form onSubmit={sendMessage} className="px-4 py-3 border-t border-gray-100 flex-shrink-0 bg-white relative chat-input-container">
              {/* @Mention Dropdown */}
              {showMentionMenu && mentionCandidates.length > 0 && (
                <div className="absolute bottom-full left-4 right-4 mb-1 bg-white border border-gray-200 rounded-xl shadow-lg overflow-hidden z-20">
                  {mentionCandidates.map(m => (
                    <button key={m.user_id} type="button"
                      onClick={() => selectMention(m.profiles?.name ?? m.profiles?.nickname ?? '')}
                      className="w-full flex items-center gap-2.5 px-3 py-2 hover:bg-primary-50 transition-all text-left">
                      <div className="w-7 h-7 rounded-full bg-primary-100 flex items-center justify-center text-xs font-bold text-primary-700 flex-shrink-0 overflow-hidden">
                        {m.profiles?.avatar_url
                          ? <img src={m.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                          : (m.profiles?.name ?? '?')[0].toUpperCase()}
                      </div>
                      <div>
                        <p className="text-xs font-semibold text-gray-900">{m.profiles?.name}</p>
                        {m.profiles?.nickname && <p className="text-[10px] text-gray-400">@{m.profiles.nickname}</p>}
                      </div>
                    </button>
                  ))}
                </div>
              )}
              {/* Image Preview */}
              {imagePreview && (
                <div className="mb-2 flex items-center gap-2 p-2 bg-primary-50 rounded-xl border border-primary-200">
                  <img src={imagePreview} alt="" className="w-12 h-12 object-cover rounded-lg flex-shrink-0" />
                  <span className="text-xs text-gray-600 flex-1 truncate">{imageFile?.name}</span>
                  <button type="button" onClick={cancelImage} className="text-gray-400 hover:text-red-500">
                    <X className="w-4 h-4" />
                  </button>
                  <button type="button" onClick={handleSendImage} disabled={uploadingImage}
                    className="flex items-center gap-1 px-3 py-1.5 bg-primary-600 text-white text-xs font-medium rounded-lg hover:bg-primary-700 disabled:opacity-50">
                    {uploadingImage ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
                    Senden
                  </button>
                </div>
              )}
              <div className="flex gap-2 items-center bg-gray-50 rounded-2xl px-3 py-1.5 border border-gray-200 focus-within:border-primary-400 focus-within:ring-2 focus-within:ring-primary-100 shadow-sm transition-all">
                {/* Image upload button */}
                <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleImageSelect} />
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  disabled={isLocked || isBanned}
                  className="p-1.5 text-gray-400 hover:text-primary-600 rounded-full transition-all flex-shrink-0 disabled:opacity-40"
                  title="Bild senden"
                >
                  <ImageIcon className="w-4 h-4" />
                </button>
                <VoiceRecorder
                  userId={userId}
                  conversationId={activeChannelConvId ?? ''}
                  disabled={isLocked || isBanned || !activeChannelConvId}
                />
                <input
                  ref={inputRef} type="text" value={newMessage}
                  onChange={e => handleInputChange(e.target.value)}
                  onKeyDown={e => { if (e.key === 'Escape') setShowMentionMenu(false) }}
                  placeholder={isBanned ? 'Du bist gesperrt…' : isLocked ? 'Kanal ist gesperrt…' : `Nachricht… (@ für Mention)`}
                  disabled={isLocked || isBanned}
                  className="flex-1 text-sm bg-transparent border-none outline-none text-gray-900 placeholder-gray-400 py-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
                />
                <button type="submit" disabled={sending || !newMessage.trim() || isLocked || isBanned}
                  className="p-2 bg-gradient-to-br from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 disabled:opacity-40 disabled:from-gray-200 disabled:to-gray-200 text-white rounded-xl shadow-sm transition-all flex-shrink-0">
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
          <div className={cn('w-full lg:w-64 xl:w-72 flex-shrink-0 flex flex-col bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden',
            mobileShowChat ? 'hidden lg:flex' : 'flex')}>
            <div className="px-4 py-3 border-b border-gray-100 space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Mail className="w-4 h-4 text-primary-600" />
                  <span className="font-semibold text-gray-900 text-sm">Nachrichten</span>
                  {totalUnread > 0 && (
                    <span className="w-5 h-5 bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center">
                      {totalUnread > 9 ? '9+' : totalUnread}
                    </span>
                  )}
                </div>
                <button onClick={() => setShowNewChat(true)}
                  className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500 hover:text-primary-600 transition-all">
                  <Plus className="w-4 h-4" />
                </button>
              </div>
              {conversations.length > 0 && (
                <div className="relative">
                  <Search className="w-3.5 h-3.5 text-gray-400 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                  <input
                    type="text"
                    value={convSearch}
                    onChange={e => setConvSearch(e.target.value)}
                    placeholder="Gespräche durchsuchen..."
                    className="w-full pl-8 pr-7 py-1.5 text-xs rounded-lg border border-gray-200 bg-gray-50 focus:bg-white focus:border-primary-300 focus:ring-1 focus:ring-primary-200 outline-none transition-all placeholder:text-gray-400"
                    aria-label="Konversationen durchsuchen"
                  />
                  {convSearch && (
                    <button
                      onClick={() => setConvSearch('')}
                      className="absolute right-1.5 top-1/2 -translate-y-1/2 p-0.5 rounded hover:bg-gray-100 text-gray-400 hover:text-gray-600"
                      aria-label="Suche zurücksetzen"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  )}
                </div>
              )}
            </div>
            {loadingConvs ? (
              <div className="flex flex-col items-center py-12 flex-1">
                <Loader2 className="w-6 h-6 text-primary-300 animate-spin mb-2" />
                <p className="text-xs text-gray-400">Lade Gespräche…</p>
              </div>
            ) : conversations.length === 0 ? (
              <div className="flex flex-col items-center py-8 px-4 text-center flex-1">
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary-50 to-violet-50 flex items-center justify-center mb-4 border border-primary-100">
                  <span className="text-2xl">💌</span>
                </div>
                <p className="text-sm text-gray-700 font-semibold">Noch keine Nachrichten</p>
                <p className="text-xs text-gray-400 mt-1.5 mb-5 leading-relaxed">
                  Klicke bei einem Inserat auf „DM" oder starte eine neue Unterhaltung
                </p>
                <button onClick={() => setShowNewChat(true)}
                  className="flex items-center gap-1.5 px-4 py-2 bg-primary-600 text-white text-sm font-semibold rounded-xl hover:bg-primary-700 transition-all shadow-sm">
                  <Plus className="w-4 h-4" /> Neue Nachricht
                </button>
                <p className="text-xs text-gray-400 mt-4">Tip: Über Beiträge kannst du direkt DMs senden</p>
              </div>
            ) : (
              <div className="overflow-y-auto flex-1 no-scrollbar py-1">
                {(() => {
                  const q = convSearch.trim().toLowerCase()
                  const visible = q
                    ? conversations.filter(c => {
                        const title = getConvTitle(c).toLowerCase()
                        const lastMsg = (c.last_message?.content ?? '').toLowerCase()
                        return title.includes(q) || lastMsg.includes(q)
                      })
                    : conversations
                  if (visible.length === 0) {
                    return (
                      <div className="px-4 py-6 text-center text-xs text-gray-400">
                        Keine Gespräche gefunden
                      </div>
                    )
                  }
                  return visible.map(conv => {
                    const partnerId = conv.type === 'direct'
                      ? conv.conversation_members?.find(m => m.user_id !== userId)?.user_id
                      : undefined
                    const presence = partnerId ? userPresence[partnerId] : undefined
                    return (
                      <ConversationItem key={conv.id} conv={conv} active={activeConvId === conv.id}
                        title={getConvTitle(conv)} initials={getConvInitials(conv)}
                        avatarUrl={getConvAvatar(conv)} onClick={() => openConv(conv)} userId={userId}
                        onDelete={handleDeleteConversation} presence={presence} />
                    )
                  })
                })()}
              </div>
            )}
          </div>

          {/* Chat-Fenster */}
          <div className={cn('flex-1 card flex flex-col min-h-0', !mobileShowChat ? 'hidden lg:flex' : 'flex')}>
            {activeConv ? (
              <>
                <div className="flex items-center gap-3 px-5 py-3.5 border-b border-gray-100 flex-shrink-0">
                  <button onClick={() => setMobileShowChat(false)} data-chat-back="true" aria-label="Zurück zur Chat-Übersicht" className="lg:hidden p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
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
                  {/* DM Call buttons */}
                  {activeConv.type === 'direct' && (
                    <>
                      <button
                        onClick={() => handleStartCall('audio')}
                        disabled={dmCallLoading || !!activeDMCall}
                        className="p-1.5 rounded-lg text-gray-400 hover:text-green-600 hover:bg-green-50 transition-all disabled:opacity-40"
                        title="Sprachanruf starten">
                        <Phone className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleStartCall('video')}
                        disabled={dmCallLoading || !!activeDMCall}
                        className="p-1.5 rounded-lg text-gray-400 hover:text-primary-600 hover:bg-primary-50 transition-all disabled:opacity-40"
                        title="Videoanruf starten">
                        <Video className="w-4 h-4" />
                      </button>
                    </>
                  )}
                  {/* DM Search */}
                  <button
                    onClick={() => { setShowSearch(s => !s); setSearchQuery('') }}
                    className={cn('p-1.5 rounded-lg transition-all', showSearch ? 'bg-primary-100 text-primary-600' : 'text-gray-400 hover:text-gray-600 hover:bg-gray-100')}>
                    <Search className="w-4 h-4" />
                  </button>
                </div>

                {/* DM Search Bar */}
                {showSearch && (
                  <div className="px-4 py-2 border-b border-gray-100 flex-shrink-0">
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
                      <input
                        value={searchQuery}
                        onChange={e => setSearchQuery(e.target.value)}
                        placeholder="Nachrichten durchsuchen…"
                        autoFocus
                        className="w-full pl-9 pr-8 py-1.5 text-sm bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-300"
                      />
                      {searchQuery && (
                        <button onClick={() => setSearchQuery('')} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                          <X className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                    {searchQuery && (
                      <p className="text-[11px] text-gray-400 mt-1">{filteredDMMessages.length} Treffer</p>
                    )}
                  </div>
                )}

                {/* Aktiver-Call-Banner: nur Anzeige, keine Aktionen (Screens handeln Annahme) */}
                {activeDMCall && activeDMCall.status === 'active' && !activeDMCallSession && (
                  <div className="flex items-center gap-3 px-4 py-3 flex-shrink-0 border-b bg-green-50 border-green-100">
                    {activeDMCall.call_type === 'video'
                      ? <Video className="w-5 h-5 text-green-600 flex-shrink-0" />
                      : <PhoneCall className="w-5 h-5 text-green-600 flex-shrink-0" />}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-gray-900">
                        {activeDMCall.call_type === 'video' ? '📹 Videoanruf läuft…' : '📞 Sprachanruf läuft…'}
                      </p>
                    </div>
                    <button onClick={handleEndCall}
                      className="p-1.5 rounded-xl text-gray-400 hover:bg-red-50 hover:text-red-500 transition-all"
                      aria-label="Anruf beenden">
                      <PhoneOff className="w-4 h-4" />
                    </button>
                  </div>
                )}

                <div ref={messagesContainerRef} onScroll={handleMessagesScroll} data-no-pull-refresh="true" className="flex-1 overflow-y-auto p-4 space-y-1 no-scrollbar chat-messages-container">
                  {displayDMMessages.length === 0 ? (
                    <div className="flex flex-col items-center justify-center h-full py-12">
                      {searchQuery ? (
                        <>
                          <Search className="w-10 h-10 text-stone-300 mb-3" />
                          <p className="font-semibold text-gray-500">Keine Treffer für „{searchQuery}"</p>
                        </>
                      ) : (
                        <>
                          <div className="w-14 h-14 rounded-full bg-primary-50 flex items-center justify-center mb-3">
                            <Lock className="w-7 h-7 text-primary-300" />
                          </div>
                          <p className="font-semibold text-gray-600 mb-1">Neue Konversation</p>
                          <p className="text-sm text-gray-400">
                            {activeConv.post_id ? 'Schreib bezüglich des Inserats!' : 'Schreib die erste Nachricht!'}
                          </p>
                        </>
                      )}
                    </div>
                  ) : (
                    <>
                      <MessageGroup messages={displayDMMessages} userId={userId} isAdmin={isAdmin}
                        pinnedIds={new Set()}
                        onReply={msg => { setReplyTo(msg); inputRef.current?.focus() }}
                        onForward={msg => setForwardMsg(msg)}
                        onReaction={handleReaction} onDelete={handleDeleteMessage}
                        onPin={() => {}}
                        onEdit={(msg) => { setEditingMsgId(msg.id); setEditContent(msg.content) }}
                        showEmojiFor={showEmojiFor} setShowEmojiFor={setShowEmojiFor}
                        msgMenuFor={msgMenuFor} setMsgMenuFor={setMsgMenuFor}
                        editingMsgId={editingMsgId} editContent={editContent}
                        setEditContent={setEditContent} onEditSubmit={handleEditMessage}
                        onEditCancel={() => { setEditingMsgId(null); setEditContent('') }}
                        allMembers={allMembers}
                      />
                      <div ref={messagesEndRef} />
                    </>
                  )}
                </div>

                {replyTo && (
                  <div className="px-4 py-2 bg-primary-50/80 border-t border-primary-100 flex items-center gap-2.5 flex-shrink-0">
                    <div className="w-0.5 h-8 bg-primary-400 rounded-full flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-[11px] text-primary-600 font-semibold">↩ {replyTo.profiles?.name ?? 'Nutzer'}</p>
                      <p className="text-xs text-gray-500 truncate">{replyTo.content}</p>
                    </div>
                    <button onClick={() => setReplyTo(null)} aria-label="Antwort aufheben" className="p-1 rounded-lg text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-all"><X className="w-3.5 h-3.5" /></button>
                  </div>
                )}

                <form onSubmit={sendMessage} className="px-4 py-3 border-t border-gray-100 flex-shrink-0 bg-white/95 backdrop-blur-sm chat-input-container">
                  {imagePreview && (
                    <div className="mb-2 flex items-center gap-2 p-2 bg-primary-50 rounded-xl border border-primary-200">
                      <img src={imagePreview} alt="" className="w-12 h-12 object-cover rounded-lg flex-shrink-0" />
                      <span className="text-xs text-gray-600 flex-1 truncate">{imageFile?.name}</span>
                      <button type="button" onClick={cancelImage} className="text-gray-400 hover:text-red-500">
                        <X className="w-4 h-4" />
                      </button>
                      <button type="button" onClick={handleSendImage} disabled={uploadingImage}
                        className="flex items-center gap-1 px-3 py-1.5 bg-primary-600 text-white text-xs font-medium rounded-lg hover:bg-primary-700 disabled:opacity-50">
                        {uploadingImage ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
                        Senden
                      </button>
                    </div>
                  )}
                  <div className="flex gap-2 items-center bg-gray-50 rounded-2xl px-3 py-1.5 border border-gray-200 focus-within:border-primary-400 focus-within:ring-2 focus-within:ring-primary-100 shadow-sm transition-all">
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={isBanned}
                      className="p-1.5 text-gray-400 hover:text-primary-600 rounded-full transition-all flex-shrink-0 disabled:opacity-40"
                      title="Bild senden"
                    >
                      <ImageIcon className="w-4 h-4" />
                    </button>
                    <VoiceRecorder
                      userId={userId}
                      conversationId={activeConvId ?? ''}
                      disabled={isBanned || !activeConvId}
                    />
                    <input
                      ref={inputRef}
                      type="text" value={newMessage} onChange={e => setNewMessage(e.target.value)}
                      placeholder={`Nachricht an ${getConvTitle(activeConv)}…`}
                      className="flex-1 text-sm bg-transparent border-none outline-none text-gray-900 placeholder-gray-400 py-1.5"
                    />
                    <button type="submit" disabled={sending || !newMessage.trim()}
                      className="p-2 bg-gradient-to-br from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 disabled:opacity-40 disabled:from-gray-200 disabled:to-gray-200 text-white rounded-xl shadow-sm transition-all flex-shrink-0">
                      {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                    </button>
                  </div>
                </form>
              </>
            ) : (
              <div className="flex-1 flex items-center justify-center text-center px-6">
                <div>
                  <div className="relative w-24 h-24 rounded-2xl bg-gradient-to-br from-primary-50 via-violet-50 to-blue-50 flex items-center justify-center mx-auto mb-5 border border-primary-100 shadow-glow-teal overflow-hidden">
                    <div className="bg-noise absolute inset-0 opacity-30 pointer-events-none" />
                    <div
                      className="absolute inset-0 pointer-events-none"
                      style={{ background: 'radial-gradient(circle at 50% 30%, rgba(30,170,166,0.18), transparent 65%)' }}
                    />
                    <span className="relative text-4xl float-idle">💬</span>
                  </div>
                  <h3 className="font-bold text-gray-800 text-lg mb-2">Private Nachrichten</h3>
                  <p className="text-sm text-gray-500 mb-6 max-w-xs leading-relaxed">
                    Wähle eine Konversation oder starte eine neue Unterhaltung – 100% privat
                  </p>
                  <button onClick={() => setShowNewChat(true)}
                    className="shine flex items-center gap-2 px-5 py-2.5 bg-primary-600 text-white font-semibold rounded-xl hover:bg-primary-700 transition-all shadow-glow-teal mx-auto">
                    <Plus className="w-4 h-4" /> Neue Unterhaltung
                  </button>
                  <div className="mt-4 grid grid-cols-3 gap-2 text-center">
                    {[['🔒', 'Privat'], ['⚡', 'Echtzeit'], ['📎', 'Bilder']].map(([icon, label]) => (
                      <div key={label} className="p-2 bg-gray-50 rounded-xl shadow-soft">
                        <div className="text-lg">{icon}</div>
                        <div className="text-xs text-gray-500 font-medium mt-0.5">{label}</div>
                      </div>
                    ))}
                  </div>
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
            loadConversations().then(() => {
              setActiveConvId(convId)
              setMobileShowChat(true)
              // Focus the message input so the user can start typing immediately
              setTimeout(() => inputRef.current?.focus(), 200)
            })
          }} />
      )}

      {/* ── Forward Modal ── */}
      {forwardMsg && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-5 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-bold text-gray-900">Nachricht weiterleiten</h3>
              <button onClick={() => setForwardMsg(null)} className="text-gray-400 hover:text-gray-700" aria-label="Schließen">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="bg-stone-50 rounded-xl p-3 text-xs text-gray-600 line-clamp-3">{forwardMsg.content}</div>
            <p className="text-xs text-gray-500">Wähle eine Konversation:</p>
            <div className="max-h-48 overflow-y-auto space-y-1">
              {conversations.filter(c => c.id !== activeConvId).map(c => {
                const other = c.conversation_members?.find(m => m.user_id !== userId)
                const name = c.title || other?.profiles?.name || 'Chat'
                return (
                  <button key={c.id} onClick={() => handleForward(c.id)}
                    className="w-full text-left px-3 py-2 rounded-xl text-sm hover:bg-primary-50 transition-colors truncate">
                    {name}
                  </button>
                )
              })}
            </div>
          </div>
        </div>
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

      {/* ── Create Channel Modal (Förderer+) ── */}
      {showCreateChannel && (
        <CreateChannelModal
          userId={userId}
          onClose={() => setShowCreateChannel(false)}
          onCreated={async (newChannelId: string) => {
            setShowCreateChannel(false)
            const loaded = await loadChannels()
            const newCh = loaded.find(c => c.id === newChannelId)
            if (newCh) switchChannel(newCh)
          }}
        />
      )}

      {/* ── Announcement Modal ── */}
      {showAnnounceModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 text-lg flex items-center gap-2">
                <Megaphone className="w-5 h-5 text-blue-500" /> Ankündigungen verwalten
              </h3>
              <button onClick={() => setShowAnnounceModal(false)} className="p-1.5 rounded-lg hover:bg-stone-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Existing active announcements */}
            {announcements.length > 0 && (
              <div className="space-y-2">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Aktive Ankündigungen</p>
                {announcements.map(a => (
                  <div key={a.id} className={cn('flex items-start gap-2 px-3 py-2 rounded-xl border text-sm', announcementColors[a.type])}>
                    <span className="flex-shrink-0 mt-0.5">{announcementIcons[a.type]}</span>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-xs">{a.title}</p>
                      <p className="text-xs opacity-70 truncate">{a.content}</p>
                    </div>
                    <button onClick={() => handleDeleteAnnouncement(a.id)}
                      className="p-1 rounded-lg hover:bg-red-100 text-red-500 flex-shrink-0" title="Ankündigung löschen">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            )}

            <div className="border-t border-stone-100 pt-3">
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Neue Ankündigung</p>
              <div className="space-y-3">
                <div className="flex gap-2">
                  {(isAdmin ? ['info', 'warning', 'success', 'error'] as const : ['info', 'success'] as const).map(t => (
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
            </div>
            <div className="flex gap-3">
              <button onClick={() => setShowAnnounceModal(false)} className="btn-secondary flex-1 justify-center">Abbrechen</button>
              <button onClick={handleCreateAnnouncement} disabled={!announceTitle.trim() || !announceContent.trim()}
                className="flex-1 px-4 py-2.5 bg-primary-600 text-white rounded-xl font-semibold hover:bg-primary-700 disabled:opacity-40 transition-all text-sm">
                Veröffentlichen
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Poll Modal ── */}
      {showPollModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <BarChart2 className="w-5 h-5 text-primary-600" /> Abstimmung erstellen
              </h3>
              <button onClick={() => setShowPollModal(false)} className="text-gray-400 hover:text-gray-700"><X className="w-5 h-5" /></button>
            </div>
            <input value={pollQuestion} onChange={e => setPollQuestion(e.target.value)}
              placeholder="Frage…" className="input w-full" />
            <div className="space-y-2">
              {pollOptions.map((opt, idx) => (
                <div key={idx} className="flex gap-2">
                  <input value={opt} onChange={e => setPollOptions(prev => prev.map((o, i) => i === idx ? e.target.value : o))}
                    placeholder={`Option ${idx + 1}…`} className="input flex-1" />
                  {pollOptions.length > 2 && (
                    <button type="button" onClick={() => setPollOptions(prev => prev.filter((_, i) => i !== idx))}
                      className="text-red-400 hover:text-red-600"><X className="w-4 h-4" /></button>
                  )}
                </div>
              ))}
              {pollOptions.length < 6 && (
                <button type="button" onClick={() => setPollOptions(prev => [...prev, ''])}
                  className="text-xs text-primary-600 hover:underline flex items-center gap-1">
                  <Plus className="w-3 h-3" /> Option hinzufügen
                </button>
              )}
            </div>
            <div className="flex gap-3">
              <button onClick={() => setShowPollModal(false)} className="btn-secondary flex-1 justify-center">Abbrechen</button>
              <button onClick={createPoll} disabled={creatingPoll || !pollQuestion.trim() || pollOptions.filter(o => o.trim()).length < 2}
                className="flex-1 px-4 py-2.5 bg-primary-600 text-white rounded-xl font-semibold hover:bg-primary-700 disabled:opacity-40 transition-all text-sm">
                {creatingPoll ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Erstellen'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Event Modal ── */}
      {showEventModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <CalendarPlus className="w-5 h-5 text-violet-600" /> Live Room Event planen
              </h3>
              <button onClick={() => setShowEventModal(false)} className="text-gray-400 hover:text-gray-700"><X className="w-5 h-5" /></button>
            </div>
            <input value={eventTitle} onChange={e => setEventTitle(e.target.value)}
              placeholder="Titel des Events…" className="input w-full" />
            <input type="datetime-local" value={eventTime} onChange={e => setEventTime(e.target.value)}
              min={new Date().toISOString().slice(0, 16)} className="input w-full" />
            <p className="text-xs text-gray-400">Der Live Room wird automatisch mit diesem Kanal verknüpft.</p>
            <div className="flex gap-3">
              <button onClick={() => setShowEventModal(false)} className="btn-secondary flex-1 justify-center">Abbrechen</button>
              <button onClick={createEvent} disabled={creatingEvent || !eventTitle.trim() || !eventTime}
                className="flex-1 px-4 py-2.5 bg-violet-600 text-white rounded-xl font-semibold hover:bg-violet-700 disabled:opacity-40 transition-all text-sm">
                {creatingEvent ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Planen'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Live-Raum Modal — via Portal an document.body, damit z-index korrekt greift */}
      {/* Upgrade Tier Modal */}
      {upgradeModal && (
        <UpgradeTierModal
          featureLabel={upgradeModal.featureLabel}
          requiredTier={upgradeModal.requiredTier}
          currentTier={donorTier}
          donationCount={donationCount}
          onClose={() => setUpgradeModal(null)}
        />
      )}

      {/* Community-Livestream LiveRoomModal (kein DM-Call) */}
      {showLiveRoom && typeof document !== 'undefined' && createPortal(
        <LiveRoomModal
          roomName={liveRoomName ?? `mensaena-${channels.find(c => c.id === activeChannelId)?.slug ?? 'community'}`}
          channelLabel={`# ${channels.find(c => c.id === activeChannelId)?.name ?? 'allgemein'}`}
          userName={myDisplayName}
          userAvatar={myAvatarUrl}
          onClose={() => {
            setShowLiveRoom(false)
            setLiveRoomName(null)
            if (activeChannelId) loadEvents(activeChannelId)
          }}
        />,
        document.body,
      )}

      {/* Outgoing 1:1 Call (Anrufer-Seite) */}
      {outgoingCallState && typeof document !== 'undefined' && createPortal(
        <OutgoingCallScreen
          callId={outgoingCallState.callId}
          calleeName={outgoingCallState.calleeName}
          calleeAvatar={outgoingCallState.calleeAvatar}
          callType={outgoingCallState.callType}
          onCancel={() => {
            setOutgoingCallState(null)
            setActiveDMCall(null)
          }}
          onConnected={(token, url, roomName) => {
            setActiveDMCallSession({
              callId:    outgoingCallState.callId,
              roomName,
              token,
              url,
              callType:  outgoingCallState.callType,
            })
            setOutgoingCallState(null)
          }}
        />,
        document.body,
      )}

      {/* Aktive 1:1-Call-Session (Anrufer-Seite, mit pre-loaded Token) */}
      {activeDMCallSession && typeof document !== 'undefined' && createPortal(
        <LiveRoomModal
          roomName={activeDMCallSession.roomName}
          channelLabel={activeDMCallSession.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'}
          userName={myDisplayName}
          userAvatar={myAvatarUrl}
          preToken={activeDMCallSession.token}
          preUrl={activeDMCallSession.url}
          dmCallId={activeDMCallSession.callId}
          onClose={() => {
            setActiveDMCallSession(null)
            setActiveDMCall(null)
          }}
        />,
        document.body,
      )}
    </div>
  )
}

// ─── MessageGroup ─────────────────────────────────────────────────────────────
function MessageGroup({ messages, userId, isAdmin, pinnedIds, onReply, onForward, onReaction, onDelete, onPin, onEdit,
  showEmojiFor, setShowEmojiFor, msgMenuFor, setMsgMenuFor,
  editingMsgId, editContent, setEditContent, onEditSubmit, onEditCancel, allMembers
}: {
  messages: Message[]; userId: string; isAdmin: boolean; pinnedIds: Set<string>
  onReply: (m: Message) => void
  onForward?: (m: Message) => void
  onReaction: (msgId: string, emoji: string) => void
  onDelete: (msgId: string, senderId: string) => void
  onPin: (m: Message) => void
  onEdit: (m: Message) => void
  allMembers: ConvMember[]
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
        const reactionUsers: Record<string, string[]> = {}
        const myReactions: Record<string, boolean> = {}
        for (const r of msg.reactions ?? []) {
          reactionGroups[r.emoji] = (reactionGroups[r.emoji] ?? 0) + 1
          if (!reactionUsers[r.emoji]) reactionUsers[r.emoji] = []
          // User-ID zu Name aus dem Konversations-Kontext auflösen
          const memberName = allMembers.find(m => m.user_id === r.user_id)?.profiles?.name || 'Jemand'
          reactionUsers[r.emoji].push(memberName)
          if (r.user_id === userId) myReactions[r.emoji] = true
        }

        // System-Call-Messages (Anrufverlauf) zentriert mit Icon rendern
        if (msg.content?.startsWith('[SYSTEM_CALL]')) {
          const text = msg.content.replace(/^\[SYSTEM_CALL\]\s*/, '')
          const isMissed = text.includes('Verpasster')
          return (
            <div key={msg.id} className="flex justify-center my-2">
              <div className={cn(
                'inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs',
                isMissed
                  ? 'bg-red-50 text-red-700 border border-red-100'
                  : 'bg-gray-100 text-gray-600 border border-gray-200',
              )}>
                <span>{text}</span>
                <span className="text-[10px] opacity-60">{new Date(msg.created_at).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}</span>
              </div>
            </div>
          )
        }

        return (
          <div key={msg.id}
            className={cn('group flex gap-2.5 mb-0.5', isMe ? 'justify-end' : 'justify-start', !showHeader && !isMe && 'pl-[42px]')}
            style={{ animation: `${isMe ? 'messageInRight' : 'messageInLeft'} 0.28s cubic-bezier(0.34,1.2,0.64,1) both` }}
          >
            {/* Avatar */}
            {!isMe && showHeader && (
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-200 to-primary-300 flex items-center justify-center text-xs font-bold text-primary-800 flex-shrink-0 mt-auto overflow-hidden relative ring-2 ring-white shadow-sm">
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
            {!isMe && !showHeader && <div className="w-8 flex-shrink-0" />}

            <div className="max-w-[72%] space-y-0.5">
              {/* Name + Admin badge + Donor tier + Pinned */}
              {!isMe && showHeader && (() => {
                const senderTier = getTierInfo(msg.profiles?.donor_tier)
                return (
                  <div className="flex items-center gap-1.5 ml-1">
                    <p className="text-xs font-semibold text-gray-700">
                      {msg.profiles?.name ?? msg.profiles?.nickname ?? 'Nutzer'}
                    </p>
                    {msgIsAdmin && (
                      <span className="text-[9px] font-bold bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full flex items-center gap-0.5">
                        <Crown className="w-2 h-2" /> Admin
                      </span>
                    )}
                    {senderTier.tier > 0 && (
                      <span className={cn('text-[9px] font-semibold px-1.5 py-0.5 rounded-full flex items-center gap-0.5', senderTier.pillClass)}
                        title={senderTier.name}>
                        {senderTier.emoji} {senderTier.name}
                      </span>
                    )}
                    {isPinned && <span className="text-[9px] text-amber-600 flex items-center gap-0.5"><Pin className="w-2.5 h-2.5" />Angepinnt</span>}
                  </div>
                )
              })()}

              {/* Reply context */}
              {msg.reply_to && !isDeleted && (
                <div className={cn('px-3 py-1.5 rounded-xl border-l-2 text-xs mb-0.5 max-w-full',
                  isMe ? 'bg-primary-700/40 border-primary-200 text-primary-100' : 'bg-gray-100 border-gray-200 text-gray-500')}>
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
                      className="text-sm text-gray-800 bg-transparent outline-none border-b border-stone-200 pb-1"
                      autoFocus
                    />
                    <div className="flex gap-2 justify-end">
                      <button onClick={onEditCancel} className="text-xs text-gray-400 hover:text-gray-600">Abbrechen</button>
                      <button onClick={() => onEditSubmit(msg.id)} className="text-xs text-primary-600 font-semibold hover:text-primary-800">Speichern</button>
                    </div>
                  </div>
                ) : (
                  <div className={cn('px-4 py-2.5 text-sm',
                    isDeleted ? 'bg-gray-100 text-gray-400 italic rounded-2xl shadow-sm'
                      : isMe ? cn('bg-gradient-to-br from-primary-500 to-primary-600 text-white shadow-md shadow-primary-500/20', isLast ? 'rounded-2xl rounded-br-sm' : 'rounded-2xl')
                      : cn('bg-white border border-gray-100 text-gray-800 shadow-sm', isLast ? 'rounded-2xl rounded-bl-sm' : 'rounded-2xl'))}>
                    {isDeleted
                      ? <p className="text-xs">🗑 Nachricht gelöscht</p>
                      : (() => {
                          // Sprachnachricht: `[Sprachnachricht 42s](url)`
                          const voiceMatch = msg.content.match(/^\[Sprachnachricht\s*(\d+)s\]\((.+)\)$/)
                          if (voiceMatch) return (
                            <audio
                              src={voiceMatch[2]}
                              controls
                              className="max-w-[240px] h-10"
                            />
                          )
                          // Unterstütze sowohl ![Bild](url) als auch [Bild](url)
                          const imgMatch = msg.content.match(/^!?\[Bild\]\((.+)\)$/)
                          if (imgMatch) return (
                            <a href={imgMatch[1]} target="_blank" rel="noopener noreferrer">
                              <img
                                src={imgMatch[1]}
                                alt="Bild"
                                className="max-w-[240px] max-h-64 rounded-xl object-cover cursor-pointer hover:opacity-90 transition-opacity"
                                onError={(e) => {
                                  // Fallback bei defektem Bild
                                  const t = e.currentTarget
                                  t.style.display = 'none'
                                  t.parentElement?.insertAdjacentHTML('afterend', '<p class="text-xs text-gray-400 italic">Bild nicht verfügbar</p>')
                                }}
                              />
                            </a>
                          )
                          return <p className="leading-relaxed break-words whitespace-pre-wrap" dangerouslySetInnerHTML={{ __html: formatChatMessage(msg.content) }} />
                        })()
                    }
                    {!isDeleted && (
                      <div className={cn('flex items-center gap-1 mt-1', isMe ? 'justify-end' : 'justify-start')}>
                        <p className={cn('text-xs', isMe ? 'text-primary-200' : 'text-gray-400')}>
                          {formatRelativeTime(msg.created_at)}
                          {msg.edited_at && <span className="ml-1 italic opacity-70">bearbeitet</span>}
                        </p>
                        {isMe && (() => {
                          // Gelesen-Häkchen: blau wenn andere Person gelesen hat
                          const otherMember = allMembers.find(m => m.user_id !== userId)
                          const otherReadAt = otherMember?.last_read_at ? new Date(otherMember.last_read_at).getTime() : 0
                          const msgTime = new Date(msg.created_at).getTime()
                          const isRead = otherReadAt >= msgTime
                          return isRead
                            ? <CheckCheck className="w-3 h-3 text-blue-400" aria-label="Gelesen" />
                            : <Check className="w-3 h-3 text-primary-200" aria-label="Gesendet" />
                        })()}
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
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-primary-600 hover:border-primary-300 transition-all"
                      title="Antworten">
                      <Reply className="w-3 h-3" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); onForward?.(msg) }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-primary-500 hover:border-primary-300 transition-all"
                      title="Weiterleiten">
                      <Send className="w-3 h-3 rotate-45" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); setShowEmojiFor(showEmojiFor === msg.id ? null : msg.id) }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-yellow-500 hover:border-yellow-300 transition-all"
                      title="Reaktion">
                      <Smile className="w-3 h-3" />
                    </button>
                    {isMe && (
                      <button onClick={e => { e.stopPropagation(); onEdit(msg) }}
                        className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-blue-500 hover:border-blue-300 transition-all"
                        title="Bearbeiten">
                        <Edit2 className="w-3 h-3" />
                      </button>
                    )}
                    {(isMe || isAdmin) && (
                      <button onClick={e => { e.stopPropagation(); onDelete(msg.id, msg.sender_id) }}
                        className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-red-500 hover:border-red-300 transition-all"
                        title="Löschen">
                        <Trash2 className="w-3 h-3" />
                      </button>
                    )}
                    <button onClick={e => {
                        e.stopPropagation()
                        const link = `${window.location.origin}${getMessagePermalink(msg.conversation_id, msg.id)}`
                        navigator.clipboard.writeText(link)
                        toast.success('Link kopiert')
                      }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-primary-500 hover:border-primary-300 transition-all"
                      title="Link kopieren">
                      <Link2 className="w-3 h-3" />
                    </button>
                    {isAdmin && (
                      <button onClick={e => { e.stopPropagation(); onPin(msg) }}
                        className={cn('w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border transition-all',
                          isPinned ? 'border-amber-300 text-amber-500 hover:text-amber-700' : 'border-gray-200 text-gray-500 hover:text-amber-500 hover:border-amber-300')}
                        title={isPinned ? 'Loslösen' : 'Anpinnen'}>
                        {isPinned ? <PinOff className="w-3 h-3" /> : <Pin className="w-3 h-3" />}
                      </button>
                    )}
                  </div>
                )}

                {/* Emoji Picker Popup */}
                {showEmojiFor === msg.id && (
                  <div
                    className={cn('absolute z-30 flex gap-1 p-2 bg-white rounded-2xl shadow-2xl border border-gray-200 bottom-full mb-2',
                      isMe ? 'right-0' : 'left-0')}
                    onClick={e => e.stopPropagation()}
                  >
                    {QUICK_EMOJIS.map(emoji => (
                      <button key={emoji} onClick={() => onReaction(msg.id, emoji)}
                        className={cn('w-8 h-8 rounded-xl text-base flex items-center justify-center hover:bg-gray-100 transition-all hover:scale-110',
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
                      title={reactionUsers[emoji]?.join(', ') || ''}
                      className={cn('flex items-center gap-1 px-2 py-0.5 rounded-full text-xs border transition-all hover:scale-105',
                        myReactions[emoji]
                          ? 'bg-primary-100 border-primary-300 text-primary-700 shadow-sm'
                          : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50')}>
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
function ConversationItem({ conv, active, title, initials, avatarUrl, onClick, onDelete, userId, presence }: {
  conv: Conversation; active: boolean; title: string; initials: string; avatarUrl: string | null
  onClick: () => void; onDelete: (id: string) => void; userId: string
  presence?: { status: string; updated_at: string }
}) {
  const unread = conv.unread_count ?? 0
  const [confirmDelete, setConfirmDelete] = useState(false)

  // Online wenn status=online UND zuletzt vor weniger als 5 Min aktiv
  const ONLINE_THRESHOLD_MS = 5 * 60 * 1000
  const presenceAgeMs = presence ? Date.now() - new Date(presence.updated_at).getTime() : Infinity
  const isOnline = presence?.status === 'online' && presenceAgeMs < ONLINE_THRESHOLD_MS
  const lastSeenLabel = (() => {
    if (!presence || conv.type !== 'direct') return null
    if (isOnline) return null
    const mins = Math.floor(presenceAgeMs / 60000)
    if (mins < 1) return 'gerade aktiv'
    if (mins < 60) return `vor ${mins}m`
    const hrs = Math.floor(mins / 60)
    if (hrs < 24) return `vor ${hrs}h`
    const days = Math.floor(hrs / 24)
    if (days < 7) return `vor ${days}d`
    return null
  })()

  return (
    <div className={cn(
      'relative group flex items-center gap-3 px-3 py-2.5 cursor-pointer',
      'transition-all duration-200',
      active
        ? 'bg-primary-50 border-l-2 border-primary-500 shadow-[inset_3px_0_0_#1EAAA6]'
        : 'hover:bg-gray-50 border-l-2 border-transparent hover:translate-x-0.5',
      unread > 0 && !active && 'bg-blue-50/50'
    )} onClick={onClick}>
      <div className="relative flex-shrink-0">
        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-100 to-primary-50 flex items-center justify-center text-primary-700 text-sm font-bold relative overflow-hidden transition-transform duration-200 group-hover:scale-105 shadow-soft ring-1 ring-primary-100/50">
          {avatarUrl ? <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
            : conv.type === 'group' ? <Users className="w-5 h-5" /> : initials}
        </div>
        {isOnline && (
          <span
            className="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-primary-500 border-2 border-white shadow-glow"
            title="Online"
          />
        )}
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-badge-pop">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <p className={cn('text-sm truncate', unread > 0 ? 'font-bold text-gray-900' : 'font-semibold text-gray-700')}>{title}</p>
        <p className={cn('text-xs truncate mt-0.5', unread > 0 ? 'text-gray-700 font-medium' : 'text-gray-400')}>
          {conv.last_message
            ? (conv.last_message.sender_id === userId ? '✓ Du: ' : '') +
              (conv.last_message.content.match(/^!?\[Bild\]\(/) ? '📷 Bild' : conv.last_message.content)
            : conv.post_id ? '📋 Bezüglich einem Inserat' : 'Noch keine Nachrichten'}
        </p>
      </div>
      <div className="flex flex-col items-end gap-1 flex-shrink-0">
        {conv.last_message && <span className="text-xs text-gray-400">{formatRelativeTime(conv.last_message.created_at)}</span>}
        {isOnline ? (
          <span className="text-[9px] font-semibold text-primary-600 uppercase tracking-wide">Online</span>
        ) : lastSeenLabel ? (
          <span className="text-[9px] text-gray-400">{lastSeenLabel}</span>
        ) : unread > 0 ? <span className="w-4 h-4 bg-primary-600 rounded-full" />
          : conv.last_message?.sender_id === userId ? <Check className="w-3 h-3 text-stone-400" /> : null}
      </div>

      {/* Delete button – visible on hover */}
      {confirmDelete ? (
        <div className="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-1 bg-white rounded-lg shadow-md border border-red-200 px-2 py-1"
          onClick={e => e.stopPropagation()}>
          <span className="text-xs text-red-600 font-semibold whitespace-nowrap">Löschen?</span>
          <button onClick={e => { e.stopPropagation(); onDelete(conv.id) }}
            className="text-xs font-bold text-red-600 hover:text-red-800 px-1">Ja</button>
          <button onClick={e => { e.stopPropagation(); setConfirmDelete(false) }}
            className="text-xs font-bold text-gray-500 hover:text-gray-700 px-1">Nein</button>
        </div>
      ) : (
        <div className="absolute right-2 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 flex items-center gap-0.5">
          <button
            onClick={e => { e.stopPropagation(); setConfirmDelete(true) }}
            className="w-6 h-6 flex items-center justify-center rounded-md text-stone-400 hover:text-red-500 hover:bg-red-50 transition-all"
            title="Konversation löschen">
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      )}
    </div>
  )
}

// ─── NewChatModal ─────────────────────────────────────────────────────────────
function NewChatModal({ userId, onClose, onCreated }: { userId: string; onClose: () => void; onCreated: (convId: string) => void }) {
  const supabaseRef = useRef(createClient())
  const supabase = supabaseRef.current
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
      const safe = escapeIlike(sanitizeForOrFilter(query))
      if (!safe) { setResults([]); setSearching(false); return }
      const { data, error } = await supabase.from('profiles').select('id, name, email, avatar_url, nickname')
        .neq('id', userId).or(`name.ilike.%${safe}%,nickname.ilike.%${safe}%,email.ilike.%${safe}%`).limit(8)
      if (error) console.error('profile search failed:', error.message)
      setResults((data as Profile[]) ?? [])
      setSearching(false)
    }, 300)
    return () => clearTimeout(t)
  }, [query, userId])

  const toggle = (p: Profile) => setSelected(prev => prev.find(s => s.id === p.id) ? prev.filter(s => s.id !== p.id) : [...prev, p])

  const start = async () => {
    if (selected.length === 0 || creating) return
    setCreating(true)
    try {
      if (selected.length === 1) {
        const convId = await openOrCreateDM(userId, selected[0].id)
        if (convId) { onCreated(convId); return }
        toast.error('Konversation konnte nicht gestartet werden')
      } else {
        // Generate UUID client-side to avoid RLS .select() issue
        const groupConvId = crypto.randomUUID()
        const { error } = await supabase.from('conversations').insert({
          id: groupConvId, type: 'group', title: groupTitle || selected.map(s => s.name ?? s.email).join(', '),
        })
        if (error) { toast.error('Gruppe konnte nicht erstellt werden: ' + error.message); setCreating(false); return }
        // Insert current user first (allowed by conversation_members_insert_secure)
        await supabase.from('conversation_members').insert({ conversation_id: groupConvId, user_id: userId })
        // Then insert other members one by one (allowed by cm_insert)
        for (const s of selected) {
          const { error: memErr } = await supabase.from('conversation_members').insert({ conversation_id: groupConvId, user_id: s.id })
          if (memErr) console.warn('Member insert warn:', memErr.message)
        }
        onCreated(groupConvId); return
      }
    } catch (err) {
      console.error('Start DM error:', err)
      toast.error('Fehler beim Starten der Konversation')
    }
    setCreating(false)
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <div>
            <h3 className="font-bold text-gray-900 text-lg">Neue Unterhaltung</h3>
            <p className="text-xs text-gray-500 mt-0.5">Name, Nickname oder E-Mail suchen</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-gray-100 text-gray-500"><X className="w-5 h-5" /></button>
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
                    isSel ? 'bg-primary-50 border border-primary-200' : 'hover:bg-gray-50 border border-transparent')}>
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
        <div className="p-5 border-t border-gray-100 flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1 justify-center">Abbrechen</button>
          <button onClick={start} disabled={selected.length === 0 || creating} className="btn-primary flex-1 justify-center">
            {creating ? <Loader2 className="w-4 h-4 animate-spin" /> : selected.length > 1 ? `Gruppe (${selected.length})` : 'Starten'}
          </button>
        </div>
      </div>
    </div>
  )
}
