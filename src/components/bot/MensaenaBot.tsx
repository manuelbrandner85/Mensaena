'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import Image from 'next/image'
import { X, Send, Loader2, RotateCcw, ChevronDown, Sparkles } from 'lucide-react'
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
]

const GREETING: BotMessage = {
  id: 'greeting',
  role: 'assistant',
  content: 'Hallo! 👋 Ich bin der **Mensaena-Bot**. Ich helfe dir bei Fragen zur Plattform und zu Themen rund um Mensch, Tier und Natur.\n\nWas kann ich für dich tun?',
  ts: Date.now(),
}

function formatContent(text: string): string {
  return text
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    .replace(/\n/g, '<br/>')
    .replace(/`(.*?)`/g, '<code class="bg-gray-100 px-1 rounded text-xs font-mono">$1</code>')
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

  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [])

  useEffect(() => {
    if (open) {
      scrollToBottom()
      setHasNew(false)
      setTimeout(() => inputRef.current?.focus(), 100)
    }
  }, [open, messages, scrollToBottom])

  // Show notification dot after 3s on first load
  useEffect(() => {
    const t = setTimeout(() => setHasNew(true), 3000)
    return () => clearTimeout(t)
  }, [])

  const sendMessage = async (content: string) => {
    if (!content.trim() || loading) return
    setInput('')
    setLoading(true)

    const userMsg: BotMessage = { id: crypto.randomUUID(), role: 'user', content, ts: Date.now() }
    setMessages(prev => [...prev, userMsg])

    try {
      const history = messages.filter(m => m.id !== 'greeting').concat(userMsg).slice(-12)
      const res = await fetch('/api/bot', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: history.map(m => ({ role: m.role, content: m.content })) }),
      })
      const data = await res.json()
      const reply = data.reply ?? 'Entschuldigung, ich konnte keine Antwort generieren.'
      setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'assistant', content: reply, ts: Date.now() }])
    } catch {
      setMessages(prev => [...prev, {
        id: crypto.randomUUID(), role: 'assistant',
        content: 'Entschuldigung, ein Fehler ist aufgetreten. Bitte versuche es nochmal! 🙏',
        ts: Date.now()
      }])
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    sendMessage(input)
  }

  const reset = () => {
    setMessages([GREETING])
    setInput('')
  }

  return (
    <>
      {/* Floating Button */}
      <button
        onClick={() => { setOpen(o => !o); setHasNew(false) }}
        className={cn(
          'fixed bottom-6 right-6 z-50 flex items-center justify-center rounded-full shadow-2xl transition-all duration-300',
          open ? 'w-12 h-12 bg-gray-700 hover:bg-gray-800' : 'w-16 h-16 bg-white border-2 border-primary-200 hover:border-primary-400 hover:scale-110'
        )}
        aria-label="Mensaena-Bot öffnen"
      >
        {open ? (
          <X className="w-5 h-5 text-white" />
        ) : (
          <>
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena-Bot"
              width={48}
              height={48}
              className="w-11 h-11 object-contain rounded-full"
            />
            {hasNew && (
              <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-primary-500 rounded-full border-2 border-white animate-pulse" />
            )}
          </>
        )}
      </button>

      {/* Chat Window */}
      {open && (
        <div className={cn(
          'fixed bottom-24 right-6 z-50 w-[360px] max-w-[calc(100vw-2rem)] bg-white rounded-2xl shadow-2xl border border-warm-200 flex flex-col overflow-hidden transition-all duration-300',
          minimized ? 'h-14' : 'h-[520px] max-h-[calc(100vh-8rem)]'
        )}>
          {/* Header */}
          <div className="flex items-center gap-3 px-4 py-3 bg-gradient-to-r from-primary-600 to-primary-700 flex-shrink-0">
            <div className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center flex-shrink-0 overflow-hidden">
              <Image src="/mensaena-logo.png" alt="Bot" width={36} height={36} className="w-8 h-8 object-contain" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold text-white flex items-center gap-1.5">
                Mensaena-Bot <Sparkles className="w-3.5 h-3.5 text-yellow-300" />
              </p>
              <p className="text-[10px] text-primary-200 flex items-center gap-1">
                <span className="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse inline-block" />
                KI-Assistent · Mensch, Tier & Natur
              </p>
            </div>
            <div className="flex items-center gap-1">
              <button onClick={reset} title="Neu starten"
                className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all">
                <RotateCcw className="w-3.5 h-3.5" />
              </button>
              <button onClick={() => setMinimized(m => !m)} title={minimized ? 'Maximieren' : 'Minimieren'}
                className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all">
                <ChevronDown className={cn('w-3.5 h-3.5 transition-transform', minimized && 'rotate-180')} />
              </button>
              <button onClick={() => setOpen(false)}
                className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all">
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          {!minimized && (
            <>
              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-4 space-y-3 no-scrollbar">
                {messages.map((msg) => (
                  <div key={msg.id} className={cn('flex gap-2', msg.role === 'user' ? 'justify-end' : 'justify-start')}>
                    {msg.role === 'assistant' && (
                      <div className="w-6 h-6 rounded-full bg-primary-100 flex items-center justify-center flex-shrink-0 mt-0.5 overflow-hidden">
                        <Image src="/mensaena-logo.png" alt="" width={24} height={24} className="w-5 h-5 object-contain" />
                      </div>
                    )}
                    <div className={cn(
                      'max-w-[82%] px-3 py-2.5 rounded-2xl text-sm leading-relaxed',
                      msg.role === 'user'
                        ? 'bg-primary-600 text-white rounded-br-sm'
                        : 'bg-warm-100 text-gray-800 rounded-bl-sm'
                    )}>
                      <p
                        className="break-words"
                        dangerouslySetInnerHTML={{ __html: formatContent(msg.content) }}
                      />
                      <p className={cn('text-[10px] mt-1', msg.role === 'user' ? 'text-primary-200 text-right' : 'text-gray-400')}>
                        {new Date(msg.ts).toLocaleTimeString('de-AT', { hour: '2-digit', minute: '2-digit' })}
                      </p>
                    </div>
                  </div>
                ))}

                {loading && (
                  <div className="flex gap-2 justify-start">
                    <div className="w-6 h-6 rounded-full bg-primary-100 flex items-center justify-center flex-shrink-0 mt-0.5 overflow-hidden">
                      <Image src="/mensaena-logo.png" alt="" width={24} height={24} className="w-5 h-5 object-contain" />
                    </div>
                    <div className="bg-warm-100 rounded-2xl rounded-bl-sm px-4 py-3 flex items-center gap-1.5">
                      {[0, 150, 300].map((d, i) => (
                        <span key={i} className="w-1.5 h-1.5 bg-primary-400 rounded-full animate-bounce" style={{ animationDelay: `${d}ms` }} />
                      ))}
                    </div>
                  </div>
                )}
                <div ref={messagesEndRef} />
              </div>

              {/* Quick Prompts */}
              {messages.length <= 2 && !loading && (
                <div className="px-3 pb-2 flex flex-wrap gap-1.5">
                  {QUICK_PROMPTS.map(p => (
                    <button key={p} onClick={() => sendMessage(p)}
                      className="text-[11px] px-2.5 py-1 bg-primary-50 text-primary-700 border border-primary-200 rounded-full hover:bg-primary-100 transition-all font-medium">
                      {p}
                    </button>
                  ))}
                </div>
              )}

              {/* Input */}
              <form onSubmit={handleSubmit} className="flex gap-2 items-center px-3 py-3 border-t border-warm-100 bg-white flex-shrink-0">
                <input
                  ref={inputRef}
                  value={input}
                  onChange={e => setInput(e.target.value)}
                  placeholder="Frage stellen…"
                  disabled={loading}
                  className="flex-1 text-sm px-3 py-2 border border-warm-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300 bg-warm-50 disabled:opacity-50"
                />
                <button
                  type="submit"
                  disabled={loading || !input.trim()}
                  className="w-9 h-9 flex items-center justify-center bg-primary-600 hover:bg-primary-700 disabled:opacity-40 text-white rounded-xl transition-all flex-shrink-0"
                >
                  {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                </button>
              </form>
            </>
          )}
        </div>
      )}
    </>
  )
}
