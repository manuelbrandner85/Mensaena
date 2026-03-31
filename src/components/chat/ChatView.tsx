'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { Send, Phone, MessageCircle, Users, Plus, Search, X, UserSearch, CheckCircle } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { formatRelativeTime } from '@/lib/utils'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'

type AnyRecord = Record<string, any>

export default function ChatView({ userId }: { userId: string }) {
  const [conversations, setConversations] = useState<AnyRecord[]>([])
  const [activeConv, setActiveConv] = useState<AnyRecord | null>(null)
  const [messages, setMessages] = useState<AnyRecord[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(false)
  const [showNewChat, setShowNewChat] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState<AnyRecord[]>([])
  const [searching, setSearching] = useState(false)
  const [convSearch, setConvSearch] = useState('')
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const channelRef = useRef<ReturnType<ReturnType<typeof createClient>['channel']> | null>(null)
  const supabase = createClient()

  // Gespräche laden
  const loadConversations = useCallback(async () => {
    const { data, error } = await supabase
      .from('conversation_members')
      .select(`
        conversation_id,
        conversations(
          id, type, title, created_at,
          messages(id, content, created_at, sender_id)
        )
      `)
      .eq('user_id', userId)

    if (!error && data) {
      const convs = data
        .map((d: AnyRecord) => d.conversations)
        .filter(Boolean)
        .sort((a: AnyRecord, b: AnyRecord) => {
          const aLast = a.messages?.at(-1)?.created_at || a.created_at
          const bLast = b.messages?.at(-1)?.created_at || b.created_at
          return new Date(bLast).getTime() - new Date(aLast).getTime()
        })
      setConversations(convs)
    }
  }, [userId, supabase])

  // Nachrichten laden
  const loadMessages = useCallback(async (convId: string) => {
    const { data } = await supabase
      .from('messages')
      .select('*, profiles(name, avatar_url, nickname)')
      .eq('conversation_id', convId)
      .order('created_at', { ascending: true })
      .limit(100)
    setMessages(data || [])
  }, [supabase])

  // Realtime Subscription
  const subscribeToMessages = useCallback((convId: string) => {
    if (channelRef.current) supabase.removeChannel(channelRef.current)

    channelRef.current = supabase
      .channel(`conv:${convId}:${Date.now()}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${convId}` },
        (payload) => {
          setMessages((prev) => {
            // Doppelte verhindern
            if (prev.find(m => m.id === payload.new.id)) return prev
            return [...prev, payload.new]
          })
        }
      )
      .subscribe()
  }, [supabase])

  useEffect(() => { loadConversations() }, [loadConversations])

  useEffect(() => {
    if (activeConv) {
      loadMessages(activeConv.id)
      subscribeToMessages(activeConv.id)
    }
    return () => {
      if (channelRef.current) supabase.removeChannel(channelRef.current)
    }
  }, [activeConv, loadMessages, subscribeToMessages])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  // Nutzer suchen
  const searchUsers = async (query: string) => {
    if (query.length < 2) { setSearchResults([]); return }
    setSearching(true)
    const { data } = await supabase
      .from('profiles')
      .select('id, name, nickname, avatar_url')
      .or(`name.ilike.%${query}%,nickname.ilike.%${query}%`)
      .neq('id', userId)
      .limit(8)
    setSearchResults(data || [])
    setSearching(false)
  }

  // Neue Direktnachricht starten
  const startDirectChat = async (targetUserId: string, targetName: string) => {
    // Existierende DM prüfen
    const { data: existing } = await supabase
      .from('conversation_members')
      .select('conversation_id, conversations(id, type)')
      .eq('user_id', userId)

    // Prüfe ob schon eine direkte Konversation mit dieser Person existiert
    for (const item of (existing || [])) {
      const conv = item.conversations as AnyRecord
      if (conv?.type === 'direct') {
        const { data: members } = await supabase
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conv.id)
        const memberIds = members?.map((m: AnyRecord) => m.user_id) || []
        if (memberIds.includes(targetUserId) && memberIds.length === 2) {
          // Bestehende Konversation öffnen
          setActiveConv(conv)
          setShowNewChat(false)
          return
        }
      }
    }

    // Neue Konversation erstellen
    const { data: newConv, error } = await supabase
      .from('conversations')
      .insert({ type: 'direct', title: targetName })
      .select()
      .single()

    if (error || !newConv) { toast.error('Fehler beim Erstellen des Chats'); return }

    // Beide Mitglieder hinzufügen
    await supabase.from('conversation_members').insert([
      { conversation_id: newConv.id, user_id: userId },
      { conversation_id: newConv.id, user_id: targetUserId },
    ])

    toast.success(`Chat mit ${targetName} gestartet`)
    setActiveConv(newConv)
    setShowNewChat(false)
    await loadConversations()
  }

  // Nachricht senden
  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || !activeConv) return
    setLoading(true)
    const content = newMessage.trim()
    setNewMessage('')

    const { error } = await supabase.from('messages').insert({
      conversation_id: activeConv.id,
      sender_id: userId,
      content,
    })

    if (error) {
      toast.error('Nachricht konnte nicht gesendet werden')
      setNewMessage(content) // Wiederherstellen
    }
    setLoading(false)
  }

  const filteredConvs = conversations.filter(c =>
    !convSearch || (c.title || '').toLowerCase().includes(convSearch.toLowerCase())
  )

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Nachrichten</h1>
          <p className="text-sm text-gray-600 mt-0.5">Direkte Kommunikation mit der Community</p>
        </div>
      </div>

      <div className="flex-1 flex gap-4 min-h-0">
        {/* Conversations List */}
        <div className="w-72 flex-shrink-0 flex flex-col gap-3">
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Gespräche suchen…"
                value={convSearch}
                onChange={e => setConvSearch(e.target.value)}
                className="input pl-9 text-sm py-2"
              />
            </div>
            <button
              onClick={() => setShowNewChat(true)}
              className="p-2.5 bg-primary-600 text-white rounded-xl hover:bg-primary-700 transition-colors"
              title="Neues Gespräch"
            >
              <Plus className="w-4 h-4" />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto space-y-1 no-scrollbar">
            {filteredConvs.length === 0 ? (
              <div className="text-center py-12">
                <MessageCircle className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p className="text-sm text-gray-500">Noch keine Gespräche</p>
                <button
                  onClick={() => setShowNewChat(true)}
                  className="mt-3 text-xs text-primary-600 font-medium hover:underline"
                >
                  + Neues Gespräch starten
                </button>
              </div>
            ) : (
              filteredConvs.map((conv) => (
                <ConversationItem
                  key={conv.id}
                  conv={conv}
                  active={activeConv?.id === conv.id}
                  onClick={() => setActiveConv(conv)}
                  userId={userId}
                />
              ))
            )}
          </div>
        </div>

        {/* Chat Area */}
        <div className="flex-1 card flex flex-col min-h-0 relative">
          {showNewChat ? (
            /* Neue Konversation Panel */
            <div className="flex flex-col h-full p-5">
              <div className="flex items-center justify-between mb-5">
                <h3 className="font-semibold text-gray-900 flex items-center gap-2">
                  <UserSearch className="w-5 h-5 text-primary-600" />
                  Neues Gespräch
                </h3>
                <button onClick={() => setShowNewChat(false)} className="text-gray-400 hover:text-gray-600">
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="relative mb-4">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="text"
                  placeholder="Name oder @nickname suchen…"
                  value={searchQuery}
                  onChange={e => { setSearchQuery(e.target.value); searchUsers(e.target.value) }}
                  className="input pl-9"
                  autoFocus
                />
              </div>

              <div className="flex-1 overflow-y-auto space-y-2">
                {searching && (
                  <div className="text-center py-8 text-sm text-gray-500">
                    <div className="w-5 h-5 border-2 border-primary-400 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                    Suche läuft…
                  </div>
                )}
                {!searching && searchQuery.length >= 2 && searchResults.length === 0 && (
                  <div className="text-center py-8 text-sm text-gray-500">
                    Keine Nutzer gefunden für „{searchQuery}"
                  </div>
                )}
                {searchResults.map(user => (
                  <button
                    key={user.id}
                    onClick={() => startDirectChat(user.id, user.name || user.nickname || 'Nutzer')}
                    className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-primary-50 transition-colors text-left"
                  >
                    <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center text-white text-sm font-bold flex-shrink-0 overflow-hidden">
                      {user.avatar_url
                        ? <img src={user.avatar_url} alt="" className="w-full h-full object-cover" />
                        : (user.name?.[0] || user.nickname?.[0] || '?').toUpperCase()
                      }
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-gray-900 text-sm truncate">{user.name || 'Unbekannt'}</p>
                      {user.nickname && <p className="text-xs text-gray-500">@{user.nickname}</p>}
                    </div>
                    <CheckCircle className="w-4 h-4 text-primary-400 flex-shrink-0" />
                  </button>
                ))}
                {!searchQuery && (
                  <div className="text-center py-8 text-gray-400">
                    <UserSearch className="w-12 h-12 mx-auto mb-3 opacity-40" />
                    <p className="text-sm">Tippe einen Namen oder @nickname</p>
                  </div>
                )}
              </div>
            </div>
          ) : activeConv ? (
            <>
              {/* Chat Header */}
              <div className="flex items-center justify-between px-5 py-4 border-b border-warm-100">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center">
                    {activeConv.type === 'group'
                      ? <Users className="w-4 h-4 text-primary-600" />
                      : <MessageCircle className="w-4 h-4 text-primary-600" />
                    }
                  </div>
                  <div>
                    <p className="font-semibold text-gray-900 text-sm">
                      {activeConv.title || 'Direktnachricht'}
                    </p>
                    <p className="text-xs text-gray-500 flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-green-400 inline-block" />
                      {activeConv.type === 'group' ? 'Gruppe' : 'Online'}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button className="p-2 rounded-lg hover:bg-warm-100 text-gray-500 transition-colors" title="Anrufen">
                    <Phone className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-5 space-y-3 no-scrollbar">
                {messages.length === 0 && (
                  <div className="text-center py-12 text-gray-400">
                    <MessageCircle className="w-10 h-10 mx-auto mb-2 opacity-40" />
                    <p className="text-sm">Noch keine Nachrichten</p>
                    <p className="text-xs mt-1">Schreibe die erste Nachricht!</p>
                  </div>
                )}
                {messages.map((msg) => {
                  const isMe = msg.sender_id === userId
                  const senderName = msg.profiles?.name || msg.profiles?.nickname || '?'
                  return (
                    <div key={msg.id} className={cn('flex gap-2', isMe ? 'justify-end' : 'justify-start')}>
                      {!isMe && (
                        <div className="w-7 h-7 rounded-full bg-primary-100 flex items-center justify-center text-xs font-bold text-primary-700 flex-shrink-0 mt-1 overflow-hidden">
                          {msg.profiles?.avatar_url
                            ? <img src={msg.profiles.avatar_url} alt="" className="w-full h-full object-cover" />
                            : senderName[0]?.toUpperCase()
                          }
                        </div>
                      )}
                      <div className={cn('max-w-[70%]', isMe ? 'items-end' : 'items-start', 'flex flex-col gap-1')}>
                        {!isMe && (
                          <span className="text-xs text-gray-500 px-1">{senderName}</span>
                        )}
                        <div
                          className={cn(
                            'px-4 py-2.5 rounded-2xl text-sm',
                            isMe
                              ? 'bg-primary-600 text-white rounded-br-sm'
                              : 'bg-warm-100 text-gray-800 rounded-bl-sm'
                          )}
                        >
                          <p className="leading-relaxed whitespace-pre-wrap break-words">{msg.content}</p>
                          <p className={cn('text-[10px] mt-1', isMe ? 'text-primary-200 text-right' : 'text-gray-400')}>
                            {formatRelativeTime(msg.created_at)}
                          </p>
                        </div>
                      </div>
                    </div>
                  )
                })}
                <div ref={messagesEndRef} />
              </div>

              {/* Message Input */}
              <form onSubmit={sendMessage} className="px-5 py-4 border-t border-warm-100">
                <div className="flex gap-3">
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="Nachricht schreiben…"
                    className="input flex-1"
                    onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) sendMessage(e) }}
                  />
                  <button
                    type="submit"
                    disabled={loading || !newMessage.trim()}
                    className="p-3 bg-primary-600 hover:bg-primary-700 disabled:opacity-50 text-white rounded-xl transition-colors"
                  >
                    <Send className="w-4 h-4" />
                  </button>
                </div>
              </form>
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center text-center p-8">
              <div>
                <div className="w-20 h-20 bg-primary-50 rounded-full flex items-center justify-center mx-auto mb-4">
                  <MessageCircle className="w-10 h-10 text-primary-300" />
                </div>
                <h3 className="font-semibold text-gray-700 mb-2">Wähle ein Gespräch</h3>
                <p className="text-sm text-gray-500 mb-4">Oder starte ein neues mit der Community</p>
                <button
                  onClick={() => setShowNewChat(true)}
                  className="btn-primary gap-2"
                >
                  <Plus className="w-4 h-4" />
                  Neue Nachricht
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function ConversationItem({
  conv, active, onClick, userId
}: {
  conv: AnyRecord
  active: boolean
  onClick: () => void
  userId: string
}) {
  const lastMsg = conv.messages?.at(-1)
  return (
    <button
      onClick={onClick}
      className={cn(
        'w-full flex items-center gap-3 px-3 py-3 rounded-xl text-left transition-all duration-150',
        active ? 'bg-primary-100 border border-primary-200' : 'hover:bg-warm-50 border border-transparent'
      )}
    >
      <div className="w-9 h-9 rounded-full bg-primary-100 flex items-center justify-center flex-shrink-0">
        {conv.type === 'group'
          ? <Users className="w-4 h-4 text-primary-600" />
          : <MessageCircle className="w-4 h-4 text-primary-600" />
        }
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900 truncate">
          {conv.title || 'Direktnachricht'}
        </p>
        <p className="text-xs text-gray-500 truncate">
          {lastMsg?.sender_id === userId ? '✓ Du: ' : ''}{lastMsg?.content || 'Noch keine Nachrichten'}
        </p>
      </div>
      {lastMsg && (
        <span className="text-[10px] text-gray-400 flex-shrink-0">
          {formatRelativeTime(lastMsg.created_at)}
        </span>
      )}
    </button>
  )
}
