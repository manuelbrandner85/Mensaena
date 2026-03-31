'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { Send, MessageCircle, Users, Plus, Search, X, UserCircle2, ArrowLeft } from 'lucide-react'
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
  created_at: string
  conversation_members: ConvMember[]
  last_message?: LastMsg | null
}

interface Message {
  id: string
  conversation_id: string
  sender_id: string
  content: string
  created_at: string
  profiles?: Profile | null
}

// ─── Haupt-Komponente ─────────────────────────────────────────────────────────
export default function ChatView({ userId }: { userId: string }) {
  const supabase = createClient()

  const [conversations, setConversations] = useState<Conversation[]>([])
  const [activeConv, setActiveConv] = useState<Conversation | null>(null)
  const [messages, setMessages]     = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [sending, setSending]       = useState(false)
  const [loadingConvs, setLoadingConvs] = useState(true)
  const [showNewChat, setShowNewChat]   = useState(false)
  const [mobileShowChat, setMobileShowChat] = useState(false)

  const messagesEndRef  = useRef<HTMLDivElement>(null)
  const channelRef      = useRef<ReturnType<typeof supabase.channel> | null>(null)

  // ── Konversationen laden ──────────────────────────────────────────────────
  const loadConversations = useCallback(async () => {
    setLoadingConvs(true)
    const { data } = await supabase
      .from('conversation_members')
      .select(`
        conversation_id,
        conversations(
          id, type, title, created_at,
          conversation_members(user_id, profiles(id, name, email, avatar_url, nickname)),
          messages(id, content, created_at, sender_id)
        )
      `)
      .eq('user_id', userId)
      .order('created_at', { ascending: false })

    if (data) {
      const convs: Conversation[] = data
        .map((row: any) => row.conversations)
        .filter(Boolean)
        .map((conv: any) => {
          const msgs: LastMsg[] = conv.messages || []
          msgs.sort((a: LastMsg, b: LastMsg) =>
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          )
          return { ...conv, last_message: msgs[0] || null }
        })
      setConversations(convs)
    }
    setLoadingConvs(false)
  }, [supabase, userId])

  useEffect(() => { loadConversations() }, [loadConversations])

  // ── Nachrichten laden ─────────────────────────────────────────────────────
  const loadMessages = useCallback(async (convId: string) => {
    const { data } = await supabase
      .from('messages')
      .select('*, profiles(id, name, avatar_url, nickname)')
      .eq('conversation_id', convId)
      .order('created_at', { ascending: true })
      .limit(100)
    setMessages((data as Message[]) || [])
  }, [supabase])

  // ── Realtime-Subscription ─────────────────────────────────────────────────
  useEffect(() => {
    if (!activeConv) return

    loadMessages(activeConv.id)

    // Alten Channel entfernen
    if (channelRef.current) supabase.removeChannel(channelRef.current)

    const ch = supabase
      .channel(`chat:${activeConv.id}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `conversation_id=eq.${activeConv.id}`,
      }, (payload) => {
        setMessages(prev => {
          // Duplikat-Schutz
          if (prev.some(m => m.id === (payload.new as Message).id)) return prev
          return [...prev, payload.new as Message]
        })
      })
      .subscribe()

    channelRef.current = ch
    return () => { supabase.removeChannel(ch) }
  }, [activeConv, loadMessages, supabase])

  // ── Auto-Scroll ───────────────────────────────────────────────────────────
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  // ── Nachricht senden ──────────────────────────────────────────────────────
  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || !activeConv || sending) return

    setSending(true)
    const content = newMessage.trim()
    setNewMessage('')

    await supabase.from('messages').insert({
      conversation_id: activeConv.id,
      sender_id: userId,
      content,
    })
    setSending(false)
  }

  // ── Konversation öffnen ───────────────────────────────────────────────────
  const openConv = (conv: Conversation) => {
    setActiveConv(conv)
    setMobileShowChat(true)
  }

  // ── Gesprächspartner-Name ─────────────────────────────────────────────────
  const getConvTitle = (conv: Conversation) => {
    if (conv.title) return conv.title
    const other = conv.conversation_members?.find(m => m.user_id !== userId)
    return other?.profiles?.name || other?.profiles?.nickname || other?.profiles?.email?.split('@')[0] || 'Direktnachricht'
  }

  const getConvInitials = (conv: Conversation) => {
    const title = getConvTitle(conv)
    return title.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Nachrichten</h1>
          <p className="text-sm text-gray-600 mt-0.5">Direkte Kommunikation mit der Community</p>
        </div>
        <button
          onClick={() => setShowNewChat(true)}
          className="btn-primary gap-2"
        >
          <Plus className="w-4 h-4" /> Neue Nachricht
        </button>
      </div>

      <div className="flex-1 flex gap-4 min-h-0">
        {/* ── Konversationsliste ── */}
        <div className={cn(
          'w-72 flex-shrink-0 flex flex-col gap-2',
          mobileShowChat ? 'hidden lg:flex' : 'flex'
        )}>
          <div className="flex-1 overflow-y-auto space-y-1 no-scrollbar">
            {loadingConvs ? (
              <div className="text-center py-12">
                <div className="w-6 h-6 border-2 border-primary-300 border-t-primary-600 rounded-full animate-spin mx-auto mb-2" />
                <p className="text-xs text-gray-400">Lade Gespräche…</p>
              </div>
            ) : conversations.length === 0 ? (
              <div className="text-center py-12">
                <MessageCircle className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p className="text-sm text-gray-500 font-medium">Noch keine Gespräche</p>
                <p className="text-xs text-gray-400 mt-1">Starte eine neue Unterhaltung</p>
                <button
                  onClick={() => setShowNewChat(true)}
                  className="mt-4 btn-primary text-sm py-2 px-4"
                >
                  <Plus className="w-3.5 h-3.5" /> Jetzt starten
                </button>
              </div>
            ) : (
              conversations.map(conv => (
                <ConversationItem
                  key={conv.id}
                  conv={conv}
                  active={activeConv?.id === conv.id}
                  title={getConvTitle(conv)}
                  initials={getConvInitials(conv)}
                  onClick={() => openConv(conv)}
                  userId={userId}
                />
              ))
            )}
          </div>
        </div>

        {/* ── Chat-Bereich ── */}
        <div className={cn(
          'flex-1 card flex flex-col min-h-0',
          !mobileShowChat ? 'hidden lg:flex' : 'flex'
        )}>
          {activeConv ? (
            <>
              {/* Header */}
              <div className="flex items-center gap-3 px-5 py-4 border-b border-warm-100">
                <button
                  onClick={() => setMobileShowChat(false)}
                  className="lg:hidden p-1.5 rounded-lg hover:bg-warm-100 text-gray-500"
                >
                  <ArrowLeft className="w-4 h-4" />
                </button>
                <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold">
                  {getConvInitials(activeConv)}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-gray-900 text-sm truncate">{getConvTitle(activeConv)}</p>
                  <p className="text-xs text-primary-600">● Online</p>
                </div>
              </div>

              {/* Nachrichten */}
              <div className="flex-1 overflow-y-auto p-5 space-y-3 no-scrollbar">
                {messages.length === 0 ? (
                  <div className="flex-1 flex items-center justify-center text-center py-12">
                    <div>
                      <MessageCircle className="w-10 h-10 text-gray-200 mx-auto mb-3" />
                      <p className="text-sm text-gray-400">Noch keine Nachrichten</p>
                      <p className="text-xs text-gray-300 mt-1">Schreib die erste Nachricht!</p>
                    </div>
                  </div>
                ) : (
                  messages.map(msg => {
                    const isMe = msg.sender_id === userId
                    return (
                      <div key={msg.id} className={cn('flex gap-2', isMe ? 'justify-end' : 'justify-start')}>
                        {!isMe && (
                          <div className="w-7 h-7 rounded-full bg-warm-200 flex items-center justify-center text-xs font-bold text-gray-600 flex-shrink-0 mt-auto">
                            {(msg.profiles?.name || msg.profiles?.email || '?')[0].toUpperCase()}
                          </div>
                        )}
                        <div className={cn(
                          'max-w-[72%] px-4 py-2.5 rounded-2xl text-sm shadow-sm',
                          isMe
                            ? 'bg-primary-600 text-white rounded-br-sm'
                            : 'bg-warm-100 text-gray-800 rounded-bl-sm'
                        )}>
                          {!isMe && msg.profiles?.name && (
                            <p className="text-[10px] font-semibold text-primary-600 mb-0.5">
                              {msg.profiles.name}
                            </p>
                          )}
                          <p className="leading-relaxed break-words">{msg.content}</p>
                          <p className={cn('text-[10px] mt-1', isMe ? 'text-primary-200' : 'text-gray-400')}>
                            {formatRelativeTime(msg.created_at)}
                          </p>
                        </div>
                      </div>
                    )
                  })
                )}
                <div ref={messagesEndRef} />
              </div>

              {/* Eingabe */}
              <form onSubmit={sendMessage} className="px-5 py-4 border-t border-warm-100">
                <div className="flex gap-3">
                  <input
                    type="text"
                    value={newMessage}
                    onChange={e => setNewMessage(e.target.value)}
                    placeholder="Nachricht schreiben…"
                    className="input flex-1"
                    autoFocus
                  />
                  <button
                    type="submit"
                    disabled={sending || !newMessage.trim()}
                    className="p-3 bg-primary-600 hover:bg-primary-700 disabled:opacity-40 text-white rounded-xl transition-colors"
                  >
                    <Send className="w-4 h-4" />
                  </button>
                </div>
              </form>
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center text-center">
              <div>
                <MessageCircle className="w-16 h-16 text-gray-200 mx-auto mb-4" />
                <h3 className="font-semibold text-gray-700 mb-2">Wähle ein Gespräch</h3>
                <p className="text-sm text-gray-400">Oder starte eine neue Unterhaltung</p>
                <button
                  onClick={() => setShowNewChat(true)}
                  className="mt-4 btn-primary"
                >
                  <Plus className="w-4 h-4" /> Neue Nachricht
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* ── Neues Gespräch Modal ── */}
      {showNewChat && (
        <NewChatModal
          userId={userId}
          onClose={() => setShowNewChat(false)}
          onCreated={(conv) => {
            setConversations(prev => [conv, ...prev.filter(c => c.id !== conv.id)])
            setActiveConv(conv)
            setMobileShowChat(true)
            setShowNewChat(false)
          }}
        />
      )}
    </div>
  )
}

// ─── ConversationItem ─────────────────────────────────────────────────────────
function ConversationItem({
  conv, active, title, initials, onClick, userId
}: {
  conv: Conversation
  active: boolean
  title: string
  initials: string
  onClick: () => void
  userId: string
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'w-full flex items-center gap-3 px-3 py-3 rounded-xl text-left transition-all duration-150',
        active
          ? 'bg-primary-100 border border-primary-200 shadow-sm'
          : 'hover:bg-warm-50 border border-transparent'
      )}
    >
      <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0">
        {conv.type === 'group' ? <Users className="w-5 h-5" /> : initials}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-gray-900 truncate">{title}</p>
        <p className="text-xs text-gray-500 truncate mt-0.5">
          {conv.last_message
            ? (conv.last_message.sender_id === userId ? 'Du: ' : '') + conv.last_message.content
            : 'Noch keine Nachrichten'}
        </p>
      </div>
      {conv.last_message && (
        <span className="text-[10px] text-gray-400 flex-shrink-0">
          {formatRelativeTime(conv.last_message.created_at)}
        </span>
      )}
    </button>
  )
}

// ─── NewChatModal ─────────────────────────────────────────────────────────────
function NewChatModal({
  userId, onClose, onCreated
}: {
  userId: string
  onClose: () => void
  onCreated: (conv: Conversation) => void
}) {
  const supabase = createClient()
  const [query, setQuery]       = useState('')
  const [results, setResults]   = useState<Profile[]>([])
  const [selected, setSelected] = useState<Profile[]>([])
  const [groupTitle, setGroupTitle] = useState('')
  const [searching, setSearching]   = useState(false)
  const [creating, setCreating]     = useState(false)

  const searchUsers = useCallback(async (q: string) => {
    if (q.trim().length < 2) { setResults([]); return }
    setSearching(true)
    const { data } = await supabase
      .from('profiles')
      .select('id, name, email, avatar_url, nickname')
      .neq('id', userId)
      .or(`name.ilike.%${q}%,nickname.ilike.%${q}%,email.ilike.%${q}%`)
      .limit(8)
    setResults((data as Profile[]) || [])
    setSearching(false)
  }, [supabase, userId])

  useEffect(() => {
    const t = setTimeout(() => searchUsers(query), 300)
    return () => clearTimeout(t)
  }, [query, searchUsers])

  const toggleSelect = (p: Profile) => {
    setSelected(prev =>
      prev.find(s => s.id === p.id)
        ? prev.filter(s => s.id !== p.id)
        : [...prev, p]
    )
  }

  const startConversation = async () => {
    if (selected.length === 0) return
    setCreating(true)

    const isGroup = selected.length > 1
    const type: 'direct' | 'group' = isGroup ? 'group' : 'direct'

    // Prüfen ob Direktgespräch bereits existiert
    if (!isGroup) {
      const { data: existing } = await supabase
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', userId)

      if (existing && existing.length > 0) {
        const convIds = existing.map((e: any) => e.conversation_id)
        const { data: shared } = await supabase
          .from('conversation_members')
          .select('conversation_id, conversations(id, type, title, created_at, conversation_members(user_id, profiles(id, name, email, avatar_url, nickname)))')
          .eq('user_id', selected[0].id)
          .in('conversation_id', convIds)

        if (shared && shared.length > 0) {
          const directConv = (shared as any[]).find(
            s => s.conversations?.type === 'direct'
          )
          if (directConv) {
            onCreated({ ...directConv.conversations, last_message: null })
            return
          }
        }
      }
    }

    // Neue Konversation erstellen
    const { data: conv, error } = await supabase
      .from('conversations')
      .insert({
        type,
        title: isGroup ? (groupTitle || selected.map(s => s.name || s.email).join(', ')) : null,
      })
      .select()
      .single()

    if (error || !conv) { setCreating(false); return }

    // Mitglieder hinzufügen (eigene ID + ausgewählte)
    const members = [userId, ...selected.map(s => s.id)].map(uid => ({
      conversation_id: conv.id,
      user_id: uid,
    }))
    await supabase.from('conversation_members').insert(members)

    onCreated({
      ...conv,
      conversation_members: members.map(m => ({
        user_id: m.user_id,
        profiles: selected.find(s => s.id === m.user_id) || null,
      })),
      last_message: null,
    })
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md animate-slide-up">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-warm-100">
          <h3 className="font-bold text-gray-900 text-lg">Neue Unterhaltung</h3>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-warm-100 text-gray-500">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {/* Ausgewählte */}
          {selected.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {selected.map(p => (
                <span key={p.id} className="flex items-center gap-1.5 px-3 py-1.5 bg-primary-100 text-primary-700 rounded-full text-sm font-medium">
                  {p.name || p.email?.split('@')[0]}
                  <button onClick={() => toggleSelect(p)} className="hover:text-primary-900">
                    <X className="w-3.5 h-3.5" />
                  </button>
                </span>
              ))}
            </div>
          )}

          {/* Gruppen-Titel (wenn >1 Person) */}
          {selected.length > 1 && (
            <input
              value={groupTitle}
              onChange={e => setGroupTitle(e.target.value)}
              placeholder="Gruppenname (optional)"
              className="input"
            />
          )}

          {/* Suche */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              value={query}
              onChange={e => setQuery(e.target.value)}
              placeholder="Name, Nutzername oder E-Mail suchen…"
              className="input pl-9"
              autoFocus
            />
          </div>

          {/* Suchergebnisse */}
          <div className="space-y-1 max-h-60 overflow-y-auto no-scrollbar">
            {searching && (
              <div className="text-center py-4">
                <div className="w-5 h-5 border-2 border-primary-300 border-t-primary-600 rounded-full animate-spin mx-auto" />
              </div>
            )}
            {!searching && query.length >= 2 && results.length === 0 && (
              <p className="text-sm text-gray-400 text-center py-4">Keine Nutzer gefunden</p>
            )}
            {results.map(p => {
              const isSelected = selected.some(s => s.id === p.id)
              return (
                <button
                  key={p.id}
                  onClick={() => toggleSelect(p)}
                  className={cn(
                    'w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all text-left',
                    isSelected
                      ? 'bg-primary-50 border border-primary-200'
                      : 'hover:bg-warm-50 border border-transparent'
                  )}
                >
                  <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-sm font-bold flex-shrink-0">
                    {p.avatar_url
                      ? <img src={p.avatar_url} alt="" className="w-full h-full rounded-full object-cover" />
                      : (p.name || p.email || '?')[0].toUpperCase()
                    }
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-900 truncate">
                      {p.name || p.email?.split('@')[0] || 'Unbekannt'}
                    </p>
                    <p className="text-xs text-gray-500 truncate">
                      {p.nickname ? '@' + p.nickname : p.email}
                    </p>
                  </div>
                  {isSelected && (
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

        {/* Footer */}
        <div className="p-5 border-t border-warm-100 flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1 justify-center">
            Abbrechen
          </button>
          <button
            onClick={startConversation}
            disabled={selected.length === 0 || creating}
            className="btn-primary flex-1 justify-center"
          >
            {creating
              ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              : selected.length > 1 ? `Gruppe erstellen (${selected.length})` : 'Gespräch starten'
            }
          </button>
        </div>
      </div>
    </div>
  )
}
