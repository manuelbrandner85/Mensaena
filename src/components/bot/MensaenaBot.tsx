'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import Image from 'next/image'
import { X, Send, Loader2, RotateCcw, ChevronDown, Sparkles, MessageCircle } from 'lucide-react'
import { cn } from '@/lib/utils'

interface BotMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  ts: number
}

const QUICK_PROMPTS = [
  '🆘 Wie inseriere ich Hilfe?',
  '💬 Wie funktioniert der Chat?',
  '🗺️ Was zeigt die Karte?',
  '🐾 Tierhilfe finden?',
  '🚨 Was ist das Krisensystem?',
  '🌿 Was ist Mensaena?',
  '💰 Ist Mensaena kostenlos?',
  '🌾 Wo finde ich Bauernhöfe?',
]

const GREETING: BotMessage = {
  id: 'greeting',
  role: 'assistant',
  content: 'Hallo! 👋 Ich bin der **Mensaena-Bot** – dein KI-Assistent für die Plattform.\n\nIch beantworte Fragen zu Mensaena und zu Themen rund um **Mensch, Tier und Natur**.\n\nWas kann ich für dich tun?',
  ts: 0, // 0 = no timestamp display for greeting
}

function escapeHtml(str: string): string {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

function formatContent(text: string): string {
  return escapeHtml(text)
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    .replace(/\n\n/g, '<br/><br/>')
    .replace(/\n/g, '<br/>')
    .replace(/`(.*?)`/g, '<code class="bg-gray-100 px-1 rounded text-xs font-mono">$1</code>')
}

let msgCounter = 0
function genId() {
  return `msg-${Date.now()}-${++msgCounter}`
}

export default function MensaenaBot() {
  const [open, setOpen] = useState(false)
  const [messages, setMessages] = useState<BotMessage[]>([GREETING])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [hasNew, setHasNew] = useState(false)
  const [minimized, setMinimized] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const abortRef = useRef<AbortController | null>(null)

  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [])

  useEffect(() => {
    if (open) {
      scrollToBottom()
      setHasNew(false)
      setTimeout(() => inputRef.current?.focus(), 150)
    }
  }, [open, messages, scrollToBottom])

  // Show notification dot after 4s on first load
  useEffect(() => {
    const t = setTimeout(() => setHasNew(true), 4000)
    return () => clearTimeout(t)
  }, [])

  const sendMessage = useCallback(async (content: string) => {
    if (!content.trim() || loading) return
    setInput('')
    setLoading(true)

    // Cancel any previous in-flight request
    abortRef.current?.abort()
    abortRef.current = new AbortController()

    const userMsg: BotMessage = { id: genId(), role: 'user', content, ts: Date.now() }

    setMessages(prev => [...prev, userMsg])

    try {
      // Build history: exclude the static greeting, include the new user message
      const history = messages
        .filter(m => m.id !== 'greeting')
        .concat(userMsg)
        .slice(-14)

      const res = await fetch('/api/bot', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: history.map(m => ({ role: m.role, content: m.content })),
        }),
        signal: abortRef.current.signal,
      })

      if (!res.ok) throw new Error(`HTTP ${res.status}`)

      const data = await res.json()
      const reply = data.reply?.trim() || 'Entschuldigung, ich konnte keine Antwort generieren.'

      setMessages(prev => [...prev, { id: genId(), role: 'assistant', content: reply, ts: Date.now() }])
    } catch (err: any) {
      if (err?.name === 'AbortError') return
      setMessages(prev => [...prev, {
        id: genId(),
        role: 'assistant',
        content: 'Entschuldigung, ein Fehler ist aufgetreten. Bitte versuche es nochmal! 🙏',
        ts: Date.now(),
      }])
    } finally {
      setLoading(false)
    }
  }, [loading, messages])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    sendMessage(input)
  }

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage(input)
    }
  }

  const reset = () => {
    abortRef.current?.abort()
    setMessages([GREETING])
    setInput('')
    setLoading(false)
    setTimeout(() => inputRef.current?.focus(), 100)
  }

  const toggleOpen = () => {
    setOpen(o => !o)
    setHasNew(false)
  }

  return (
    <>
      {/* Floating Button – bottom-right, clear of bottom nav on mobile */}
      <button
        onClick={toggleOpen}
        className={cn(
          'fixed bottom-20 right-4 lg:bottom-6 lg:right-6 z-30 flex items-center justify-center rounded-full shadow-xl transition-all duration-300',
          open
            ? 'w-10 h-10 bg-gray-700 hover:bg-gray-800 scale-100'
            : 'w-12 h-12 bg-white border-2 border-primary-200 hover:border-primary-400 hover:scale-110'
        )}
        aria-label={open ? 'Mensaena-Bot schließen' : 'Mensaena-Bot öffnen'}
      >
        {open ? (
          <X className="w-5 h-5 text-white" />
        ) : (
          <>
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena-Bot"
              width={44}
              height={44}
              className="w-11 h-11 object-contain"
            />
            {hasNew && (
              <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-primary-500 rounded-full border-2 border-white animate-pulse" />
            )}
          </>
        )}
      </button>

      {/* Chat Window */}
      {open && (
        <div
          className={cn(
            'fixed bottom-[5.5rem] right-4 lg:bottom-20 lg:right-6 z-30 w-[360px] max-w-[calc(100vw-1.5rem)] bg-white rounded-2xl shadow-2xl border border-warm-200 flex flex-col overflow-hidden transition-all duration-300',
            minimized ? 'h-14' : 'h-[480px] max-h-[calc(100vh-8rem)]'
          )}
        >
          {/* Header */}
          <div className="flex items-center gap-3 px-4 py-3 bg-gradient-to-r from-primary-600 to-primary-700 flex-shrink-0 cursor-pointer"
            onClick={() => minimized && setMinimized(false)}>
            <div className="w-9 h-9 rounded-full bg-white/15 flex items-center justify-center flex-shrink-0 overflow-hidden border border-white/20">
              <Image src="/mensaena-logo.png" alt="Bot" width={32} height={32} className="w-7 h-7 object-contain" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold text-white flex items-center gap-1.5">
                Mensaena-Bot
                <Sparkles className="w-3.5 h-3.5 text-yellow-300 flex-shrink-0" />
              </p>
              <p className="text-[10px] text-primary-200 flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse inline-block flex-shrink-0" />
                KI-Assistent · Mensch, Tier &amp; Natur
              </p>
            </div>
            <div className="flex items-center gap-0.5" onClick={e => e.stopPropagation()}>
              <button
                onClick={reset}
                title="Gespräch neu starten"
                className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all"
              >
                <RotateCcw className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => setMinimized(m => !m)}
                title={minimized ? 'Maximieren' : 'Minimieren'}
                className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all"
              >
                <ChevronDown className={cn('w-3.5 h-3.5 transition-transform duration-200', minimized && 'rotate-180')} />
              </button>
              <button
                onClick={() => setOpen(false)}
                title="Schließen"
                className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          {!minimized && (
            <>
              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-4 space-y-3 scroll-smooth">
                {messages.map((msg) => (
                  <div
                    key={msg.id}
                    className={cn('flex gap-2 items-end', msg.role === 'user' ? 'justify-end' : 'justify-start')}
                  >
                    {msg.role === 'assistant' && (
                      <div className="w-6 h-6 rounded-full bg-primary-100 flex items-center justify-center flex-shrink-0 overflow-hidden mb-0.5">
                        <Image src="/mensaena-logo.png" alt="" width={20} height={20} className="w-5 h-5 object-contain" />
                      </div>
                    )}
                    <div
                      className={cn(
                        'max-w-[83%] px-3.5 py-2.5 rounded-2xl text-sm leading-relaxed',
                        msg.role === 'user'
                          ? 'bg-primary-600 text-white rounded-br-sm'
                          : 'bg-warm-100 text-gray-800 rounded-bl-sm'
                      )}
                    >
                      <div
                        className="break-words"
                        dangerouslySetInnerHTML={{ __html: formatContent(msg.content) }}
                      />
                      {msg.ts > 0 && (
                        <p className={cn('text-[10px] mt-1.5 select-none', msg.role === 'user' ? 'text-primary-200 text-right' : 'text-gray-400')}>
                          {new Date(msg.ts).toLocaleTimeString('de-AT', { hour: '2-digit', minute: '2-digit' })}
                        </p>
                      )}
                    </div>
                  </div>
                ))}

                {/* Typing indicator */}
                {loading && (
                  <div className="flex gap-2 items-end justify-start">
                    <div className="w-6 h-6 rounded-full bg-primary-100 flex items-center justify-center flex-shrink-0 overflow-hidden mb-0.5">
                      <Image src="/mensaena-logo.png" alt="" width={20} height={20} className="w-5 h-5 object-contain" />
                    </div>
                    <div className="bg-warm-100 rounded-2xl rounded-bl-sm px-4 py-3 flex items-center gap-1.5">
                      {[0, 160, 320].map((d, i) => (
                        <span
                          key={i}
                          className="w-2 h-2 bg-primary-400 rounded-full animate-bounce"
                          style={{ animationDelay: `${d}ms` }}
                        />
                      ))}
                    </div>
                  </div>
                )}
                <div ref={messagesEndRef} />
              </div>

              {/* Quick Prompts – show when only greeting message visible */}
              {messages.length <= 1 && !loading && (
                <div className="px-3 pb-2 flex flex-wrap gap-1.5">
                  {QUICK_PROMPTS.map(p => (
                    <button
                      key={p}
                      onClick={() => sendMessage(p)}
                      className="text-[11px] px-2.5 py-1 bg-primary-50 text-primary-700 border border-primary-200 rounded-full hover:bg-primary-100 hover:border-primary-300 transition-all font-medium"
                    >
                      {p}
                    </button>
                  ))}
                </div>
              )}

              {/* Input */}
              <form
                onSubmit={handleSubmit}
                className="flex gap-2 items-center px-3 py-3 border-t border-warm-100 bg-white flex-shrink-0"
              >
                <input
                  ref={inputRef}
                  value={input}
                  onChange={e => setInput(e.target.value)}
                  onKeyDown={handleKeyDown}
                  placeholder="Frage stellen…"
                  disabled={loading}
                  maxLength={1000}
                  className="flex-1 text-sm px-3 py-2.5 border border-warm-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300 bg-warm-50 disabled:opacity-50 transition-shadow"
                  autoComplete="off"
                />
                <button
                  type="submit"
                  disabled={loading || !input.trim()}
                  className="w-10 h-10 flex items-center justify-center bg-primary-600 hover:bg-primary-700 disabled:opacity-40 disabled:cursor-not-allowed text-white rounded-xl transition-all flex-shrink-0 shadow-sm"
                  aria-label="Senden"
                >
                  {loading ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <Send className="w-4 h-4" />
                  )}
                </button>
              </form>
            </>
          )}
        </div>
      )}
    </>
  )
}
