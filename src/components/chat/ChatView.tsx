'use client'

import { useState, useEffect, useRef } from 'react'
import { Send, Phone, MessageCircle, Users, Plus, Search } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { formatRelativeTime } from '@/lib/utils'
import { cn } from '@/lib/utils'
import type { Conversation, Message } from '@/types'

export default function ChatView({ userId }: { userId: string }) {
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [activeConv, setActiveConv] = useState<Conversation | null>(null)
  const [messages, setMessages] = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const supabase = createClient()

  useEffect(() => {
    loadConversations()
  }, [])

  useEffect(() => {
    if (activeConv) {
      loadMessages(activeConv.id)
      subscribeToMessages(activeConv.id)
    }
  }, [activeConv])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const loadConversations = async () => {
    const { data } = await supabase
      .from('conversations')
      .select(`
        *,
        conversation_members!inner(user_id),
        messages(id, content, created_at, sender_id)
      `)
      .eq('conversation_members.user_id', userId)
      .order('created_at', { ascending: false })

    setConversations((data as Conversation[]) || [])
  }

  const loadMessages = async (convId: string) => {
    const { data } = await supabase
      .from('messages')
      .select('*, profiles(name, avatar_url)')
      .eq('conversation_id', convId)
      .order('created_at', { ascending: true })
      .limit(50)
    setMessages((data as Message[]) || [])
  }

  const subscribeToMessages = (convId: string) => {
    const channel = supabase
      .channel(`conv:${convId}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${convId}` },
        (payload) => {
          setMessages((prev) => [...prev, payload.new as Message])
        }
      )
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || !activeConv) return

    setLoading(true)
    const { error } = await supabase.from('messages').insert({
      conversation_id: activeConv.id,
      sender_id: userId,
      content: newMessage.trim(),
    })

    if (!error) setNewMessage('')
    setLoading(false)
  }

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col">
      <div className="mb-4">
        <h1 className="text-2xl font-bold text-gray-900">Nachrichten</h1>
        <p className="text-sm text-gray-600 mt-0.5">Direkte Kommunikation mit der Community</p>
      </div>

      <div className="flex-1 flex gap-4 min-h-0">
        {/* Conversations List */}
        <div className="w-72 flex-shrink-0 flex flex-col gap-3">
          {/* Search + New */}
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Suchen…"
                className="input pl-9 text-sm py-2"
              />
            </div>
            <button className="p-2.5 bg-primary-600 text-white rounded-xl hover:bg-primary-700 transition-colors">
              <Plus className="w-4 h-4" />
            </button>
          </div>

          {/* Conversation Items */}
          <div className="flex-1 overflow-y-auto space-y-1 no-scrollbar">
            {conversations.length === 0 ? (
              <div className="text-center py-12">
                <MessageCircle className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p className="text-sm text-gray-500">Noch keine Gespräche</p>
                <p className="text-xs text-gray-400 mt-1">Starte eine neue Unterhaltung</p>
              </div>
            ) : (
              conversations.map((conv) => (
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
        <div className="flex-1 card flex flex-col min-h-0">
          {activeConv ? (
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
                    <p className="text-xs text-gray-500">
                      {activeConv.type === 'group' ? 'Gruppe' : 'Direktnachricht'}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button className="p-2 rounded-lg hover:bg-warm-100 text-gray-500 transition-colors">
                    <Phone className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-5 space-y-3 no-scrollbar">
                {messages.map((msg) => {
                  const isMe = msg.sender_id === userId
                  return (
                    <div key={msg.id} className={cn('flex', isMe ? 'justify-end' : 'justify-start')}>
                      <div
                        className={cn(
                          'max-w-[70%] px-4 py-2.5 rounded-2xl text-sm',
                          isMe
                            ? 'bg-primary-600 text-white rounded-br-sm'
                            : 'bg-warm-100 text-gray-800 rounded-bl-sm'
                        )}
                      >
                        <p className="leading-relaxed">{msg.content}</p>
                        <p className={cn('text-[10px] mt-1', isMe ? 'text-primary-200' : 'text-gray-400')}>
                          {formatRelativeTime(msg.created_at)}
                        </p>
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
            <div className="flex-1 flex items-center justify-center text-center">
              <div>
                <MessageCircle className="w-16 h-16 text-gray-200 mx-auto mb-4" />
                <h3 className="font-semibold text-gray-700 mb-2">Wähle ein Gespräch</h3>
                <p className="text-sm text-gray-500">Oder starte ein neues Gespräch</p>
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
  conv: Conversation
  active: boolean
  onClick: () => void
  userId: string
}) {
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
          {conv.last_message?.content || 'Keine Nachrichten'}
        </p>
      </div>
    </button>
  )
}
