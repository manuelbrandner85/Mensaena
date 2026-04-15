'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import Image from 'next/image'
import { usePathname } from 'next/navigation'
import {
  X, Send, Loader2, RotateCcw, ChevronDown, Sparkles,
  Mic, MicOff, Volume2, VolumeX, ThumbsUp, ThumbsDown,
} from 'lucide-react'
import { cn } from '@/lib/utils'

// ─── Types ────────────────────────────────────────────────────────────────────
interface BotMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  ts: number
  rating?: 'up' | 'down'
}

// ─── Konstanten ───────────────────────────────────────────────────────────────
const STORAGE_KEY = 'mensaena-bot-history-v2'
const ONBOARDING_KEY = 'mensaena-bot-onboarded'
const BOT_AVATAR = '/mensaena-bot.png'

const QUICK_PROMPTS = [
  'Wie inseriere ich Hilfe?',
  'Wie funktioniert der Chat?',
  'Was zeigt die Karte?',
  'Tierhilfe finden?',
  'Was ist das Krisensystem?',
  'Was ist Mensaena?',
  'Ist Mensaena kostenlos?',
  'Wo finde ich Bauernhöfe?',
]

const GREETING: BotMessage = {
  id: 'greeting',
  role: 'assistant',
  content: 'Hallo! 👋 Ich bin der **Mensaena-Bot** – dein KI-Assistent für die Plattform.\n\nIch beantworte Fragen zu Mensaena und zu Themen rund um **Mensch, Tier und Natur**. *Freiheit beginnt im Bewusstsein.*\n\nWas kann ich für dich tun?',
  ts: 0,
}

// ─── Mini-Markdown-Renderer ───────────────────────────────────────────────────
// Unterstützt **fett**, *kursiv*, `code`, [link](url), - Listen und Zeilenumbrüche.
// Linkt interne Mensaena-Pfade (/dashboard/...) automatisch als Next-Client-Links
// via <a> (der Browser handled Intra-App-Navigation über den Layout-Router).
function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function renderMarkdown(text: string): string {
  // Zuerst HTML escapen
  let html = escapeHtml(text)

  // Code-Spans (vor allem anderen, damit * in Code nicht als kursiv interpretiert wird)
  html = html.replace(/`([^`\n]+)`/g, '<code class="bg-gray-100 px-1 rounded text-[11px] font-mono">$1</code>')

  // Links [label](url) — interne Pfade bekommen eine eigene class für Styling
  html = html.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_m, label: string, url: string) => {
    const isInternal = url.startsWith('/')
    const safe = url.replace(/"/g, '%22')
    const cls = isInternal
      ? 'text-primary-700 font-medium underline underline-offset-2 hover:text-primary-900 decoration-primary-300'
      : 'text-primary-700 underline underline-offset-2 hover:text-primary-900'
    const target = isInternal ? '' : ' target="_blank" rel="noopener noreferrer"'
    return `<a href="${safe}" class="${cls}"${target}>${label}</a>`
  })

  // Fett & kursiv
  html = html.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>')
  html = html.replace(/(^|[^*])\*([^*\n]+)\*/g, '$1<em>$2</em>')

  // Listen (Zeilen, die mit "- " oder "• " beginnen)
  html = html.replace(/(^|\n)(?:- |• )(.+)/g, '$1<li class="ml-4 list-disc">$2</li>')
  html = html.replace(/(<li[^>]*>.*?<\/li>)(?:\n(?!<li))/g, '$1')

  // Zeilenumbrüche
  html = html.replace(/\n\n/g, '<br/><br/>')
  html = html.replace(/\n/g, '<br/>')

  return html
}

let msgCounter = 0
function genId() {
  return `msg-${Date.now()}-${++msgCounter}`
}

// ─── Web Speech API Types ─────────────────────────────────────────────────────
// SpeechRecognition ist nicht in den Standard-DOM-Types, daher lokal definiert.
/* eslint-disable @typescript-eslint/no-explicit-any */
type SpeechRecognitionLike = {
  lang: string
  interimResults: boolean
  continuous: boolean
  onresult: ((e: any) => void) | null
  onerror: ((e: any) => void) | null
  onend: (() => void) | null
  start: () => void
  stop: () => void
}

function getSpeechRecognition(): SpeechRecognitionLike | null {
  if (typeof window === 'undefined') return null
  const SR = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
  if (!SR) return null
  try {
    return new SR() as SpeechRecognitionLike
  } catch {
    return null
  }
}
/* eslint-enable @typescript-eslint/no-explicit-any */

// ─── Component ────────────────────────────────────────────────────────────────
export default function MensaenaBot() {
  const pathname = usePathname()

  // ── UI State
  const [open, setOpen] = useState(false)
  const [minimized, setMinimized] = useState(false)
  const [hasNew, setHasNew] = useState(false)
  const [showOnboarding, setShowOnboarding] = useState(false)

  // ── Chat State
  const [messages, setMessages] = useState<BotMessage[]>([GREETING])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)

  // ── Voice I/O
  const [listening, setListening] = useState(false)
  const [ttsEnabled, setTtsEnabled] = useState(false)
  const [speakingMsgId, setSpeakingMsgId] = useState<string | null>(null)
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null)

  // ── Refs
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const abortRef = useRef<AbortController | null>(null)

  // ── Scrollen ans Ende
  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [])

  // ── Mount: lade Verlauf aus localStorage + Onboarding-Status
  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (raw) {
        const parsed = JSON.parse(raw) as BotMessage[]
        if (Array.isArray(parsed) && parsed.length > 0) {
          setMessages(parsed)
        }
      }
    } catch (err) {
      console.warn('[bot] restore history failed:', err)
    }
    const onboarded = localStorage.getItem(ONBOARDING_KEY)
    if (!onboarded) {
      // Nach 2.5s den Onboarding-Tooltip einmalig zeigen
      const t = setTimeout(() => setShowOnboarding(true), 2500)
      return () => clearTimeout(t)
    }
  }, [])

  // ── Persistiere Verlauf
  useEffect(() => {
    if (typeof window === 'undefined') return
    // Greeting alleine muss nicht gespeichert werden
    if (messages.length <= 1 && messages[0]?.id === 'greeting') return
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(messages.slice(-50)))
    } catch (err) {
      console.warn('[bot] persist failed:', err)
    }
  }, [messages])

  // ── Open-Effekt: fokus + scroll + notification dismiss
  useEffect(() => {
    if (open) {
      scrollToBottom()
      setHasNew(false)
      setShowOnboarding(false)
      if (typeof window !== 'undefined') localStorage.setItem(ONBOARDING_KEY, '1')
      setTimeout(() => inputRef.current?.focus(), 150)
    }
  }, [open, messages, scrollToBottom])

  // ── Initial: notification dot nach 4s
  useEffect(() => {
    const t = setTimeout(() => {
      setHasNew(prev => (open ? prev : true))
    }, 4000)
    return () => clearTimeout(t)
  }, [open])

  // ── Cleanup TTS beim Unmount
  useEffect(() => () => {
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel()
    }
  }, [])

  // ── Streaming-Aufruf an /api/bot
  const sendMessage = useCallback(async (content: string) => {
    const trimmed = content.trim()
    if (!trimmed || loading) return
    setInput('')
    setLoading(true)

    abortRef.current?.abort()
    abortRef.current = new AbortController()

    const userMsg: BotMessage = { id: genId(), role: 'user', content: trimmed, ts: Date.now() }
    setMessages(prev => [...prev, userMsg])

    // Placeholder-Message für Streaming
    const assistantId = genId()
    setMessages(prev => [...prev, { id: assistantId, role: 'assistant', content: '', ts: Date.now() }])

    try {
      const history = messages
        .filter(m => m.id !== 'greeting')
        .concat(userMsg)
        .slice(-14)

      const res = await fetch('/api/bot', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: history.map(m => ({ role: m.role, content: m.content })),
          route: pathname,
        }),
        signal: abortRef.current.signal,
      })

      if (!res.ok || !res.body) throw new Error(`HTTP ${res.status}`)

      const reader = res.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ''
      let accumulated = ''

      // SSE-Frames parsen
      // Format (vom /api/bot Endpoint): "data: {\"token\":\"...\"}\n\n" und "data: [DONE]\n\n"
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        buffer += decoder.decode(value, { stream: true })
        let idx: number
        while ((idx = buffer.indexOf('\n\n')) !== -1) {
          const frame = buffer.slice(0, idx).trim()
          buffer = buffer.slice(idx + 2)
          if (!frame.startsWith('data:')) continue
          const payload = frame.slice(5).trim()
          if (payload === '[DONE]') continue
          try {
            const obj = JSON.parse(payload) as { token?: string }
            if (obj.token) {
              accumulated += obj.token
              setMessages(prev => prev.map(m =>
                m.id === assistantId ? { ...m, content: accumulated } : m,
              ))
            }
          } catch {
            // Nicht-JSON ignorieren
          }
        }
      }

      if (!accumulated) {
        setMessages(prev => prev.map(m =>
          m.id === assistantId
            ? { ...m, content: 'Entschuldigung, ich konnte keine Antwort generieren. 🙏' }
            : m,
        ))
      }

      // TTS für die neue Antwort (falls aktiviert)
      if (ttsEnabled && accumulated && typeof window !== 'undefined' && 'speechSynthesis' in window) {
        speakText(accumulated, assistantId)
      }
    } catch (err) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      if ((err as any)?.name === 'AbortError') return
      console.warn('[bot] send failed:', err)
      setMessages(prev => prev.map(m =>
        m.id === assistantId
          ? { ...m, content: 'Entschuldigung, ein Fehler ist aufgetreten. Bitte versuche es gleich nochmal. 🙏' }
          : m,
      ))
    } finally {
      setLoading(false)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, messages, pathname, ttsEnabled])

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

  // ── Reset / Cleanup
  const reset = useCallback(() => {
    abortRef.current?.abort()
    setMessages([GREETING])
    setInput('')
    setLoading(false)
    if (typeof window !== 'undefined') {
      localStorage.removeItem(STORAGE_KEY)
      if ('speechSynthesis' in window) window.speechSynthesis.cancel()
    }
    setSpeakingMsgId(null)
    setTimeout(() => inputRef.current?.focus(), 100)
  }, [])

  const toggleOpen = () => {
    setOpen(o => !o)
    setHasNew(false)
  }

  // ── Voice Input (Mikrofon)
  const toggleListening = useCallback(() => {
    if (listening) {
      recognitionRef.current?.stop()
      setListening(false)
      return
    }
    const rec = getSpeechRecognition()
    if (!rec) {
      console.warn('[bot] speech recognition not supported')
      return
    }
    rec.lang = 'de-DE'
    rec.interimResults = false
    rec.continuous = false
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    rec.onresult = (e: any) => {
      const transcript: string = e?.results?.[0]?.[0]?.transcript ?? ''
      if (transcript) {
        setInput(transcript)
        // Automatisch senden, wenn Spracheingabe klar
        setTimeout(() => sendMessage(transcript), 150)
      }
    }
    rec.onerror = () => setListening(false)
    rec.onend = () => setListening(false)
    try {
      rec.start()
      recognitionRef.current = rec
      setListening(true)
    } catch (err) {
      console.warn('[bot] start recognition failed:', err)
      setListening(false)
    }
  }, [listening, sendMessage])

  // ── Text-to-Speech
  const speakText = useCallback((text: string, msgId: string) => {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return
    // Markdown entfernen für TTS
    const plain = text
      .replace(/\*\*/g, '')
      .replace(/\*/g, '')
      .replace(/`/g, '')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/[🆘💬🗺️🐾🚨🌿💰🌾👋🤝🏡🔧🚗🔄🌍✨🔑🔒⚡📎💙🌱✅]/g, '')
    window.speechSynthesis.cancel()
    const utter = new SpeechSynthesisUtterance(plain)
    utter.lang = 'de-DE'
    utter.rate = 1.0
    utter.pitch = 1.0
    utter.onstart = () => setSpeakingMsgId(msgId)
    utter.onend = () => setSpeakingMsgId(null)
    utter.onerror = () => setSpeakingMsgId(null)
    window.speechSynthesis.speak(utter)
  }, [])

  const stopSpeaking = useCallback(() => {
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel()
    }
    setSpeakingMsgId(null)
  }, [])

  const toggleMsgSpeech = useCallback((msg: BotMessage) => {
    if (speakingMsgId === msg.id) {
      stopSpeaking()
    } else {
      speakText(msg.content, msg.id)
    }
  }, [speakingMsgId, speakText, stopSpeaking])

  // ── Feedback 👍 / 👎
  const sendFeedback = useCallback(async (msg: BotMessage, rating: 'up' | 'down') => {
    setMessages(prev => prev.map(m => m.id === msg.id ? { ...m, rating } : m))
    try {
      // Frage = vorherige User-Message
      const idx = messages.findIndex(m => m.id === msg.id)
      const question = idx > 0 ? messages[idx - 1]?.content ?? '' : ''
      await fetch('/api/bot/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messageId: msg.id,
          rating,
          question,
          answer: msg.content,
          route: pathname,
        }),
      })
    } catch (err) {
      console.warn('[bot] feedback failed:', err)
    }
  }, [messages, pathname])

  return (
    <>
      {/* ─── Floating Button ─────────────────────────────────────── */}
      <button
        onClick={toggleOpen}
        className={cn(
          'fixed bottom-20 right-4 lg:bottom-6 lg:right-6 z-30 flex items-center justify-center rounded-full shadow-xl transition-all duration-300',
          open
            ? 'w-10 h-10 bg-gray-700 hover:bg-gray-800 scale-100'
            : 'w-14 h-14 hover:scale-110',
        )}
        aria-label={open ? 'Mensaena-Bot schließen' : 'Mensaena-Bot öffnen'}
      >
        {open ? (
          <X className="w-5 h-5 text-white" />
        ) : (
          <>
            <Image
              src={BOT_AVATAR}
              alt="Mensaena-Bot"
              width={56}
              height={56}
              className={cn(
                'w-14 h-14 object-contain rounded-full',
                loading && 'animate-pulse',
              )}
              priority
            />
            {hasNew && (
              <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-primary-500 rounded-full border-2 border-white animate-pulse" />
            )}
          </>
        )}
      </button>

      {/* ─── Onboarding-Tooltip (einmalig beim ersten Besuch) ─────── */}
      {showOnboarding && !open && (
        <div className="fixed bottom-36 right-4 lg:bottom-24 lg:right-24 z-30 max-w-[240px] bg-white rounded-2xl shadow-card border border-primary-200 p-3 animate-slide-up">
          <button
            onClick={() => {
              setShowOnboarding(false)
              if (typeof window !== 'undefined') localStorage.setItem(ONBOARDING_KEY, '1')
            }}
            className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-white border border-gray-200 text-gray-400 hover:text-gray-600 flex items-center justify-center shadow-sm"
            aria-label="Tooltip schließen"
          >
            <X className="w-3 h-3" />
          </button>
          <p className="text-xs font-semibold text-gray-800 flex items-center gap-1.5">
            <Sparkles className="w-3.5 h-3.5 text-primary-600" />
            Frag mich alles zu Mensaena
          </p>
          <p className="text-[11px] text-gray-500 mt-1 leading-relaxed">
            Der KI-Assistent hilft bei Fragen rund um die Plattform, Natur & Gemeinschaft.
          </p>
          {/* Speech-Bubble tail */}
          <div className="absolute -bottom-1.5 right-6 w-3 h-3 bg-white border-r border-b border-primary-200 rotate-45" />
        </div>
      )}

      {/* ─── Chat-Fenster ────────────────────────────────────────── */}
      {open && (
        <div
          className={cn(
            'fixed z-30 bg-white shadow-2xl border border-warm-200 flex flex-col overflow-hidden transition-all duration-300',
            // Mobile: fast-fullscreen. Desktop: größeres Panel.
            'inset-x-2 bottom-[4.75rem] top-[3.5rem] rounded-2xl',
            'lg:inset-auto lg:bottom-20 lg:right-6 lg:top-auto lg:w-[420px] lg:h-[580px] lg:rounded-2xl',
            minimized && 'lg:h-14 h-14 top-auto inset-x-auto right-4 bottom-20',
          )}
        >
          {/* Header */}
          <div
            className="flex items-center gap-3 px-4 py-3 bg-gradient-to-r from-primary-600 via-primary-600 to-primary-700 flex-shrink-0 cursor-pointer relative overflow-hidden"
            onClick={() => minimized && setMinimized(false)}
          >
            {/* Subtle noise for depth */}
            <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />
            <div className="relative w-9 h-9 rounded-full bg-white/10 flex items-center justify-center flex-shrink-0 overflow-hidden border border-white/30">
              <Image
                src={BOT_AVATAR}
                alt="Bot"
                width={36}
                height={36}
                className={cn('w-9 h-9 object-contain', loading && 'animate-pulse')}
              />
            </div>
            <div className="relative flex-1 min-w-0">
              <p className="text-sm font-bold text-white flex items-center gap-1.5">
                Mensaena-Bot
                <Sparkles className="w-3.5 h-3.5 text-yellow-300 flex-shrink-0" />
              </p>
              <p className="text-[10px] text-primary-100 flex items-center gap-1.5">
                <span className={cn(
                  'w-1.5 h-1.5 rounded-full inline-block flex-shrink-0',
                  loading ? 'bg-amber-300 animate-pulse' : 'bg-green-400 animate-pulse',
                )} />
                {loading ? 'denkt nach…' : 'KI-Assistent · Mensch, Tier & Natur'}
              </p>
            </div>
            <div className="relative flex items-center gap-0.5" onClick={e => e.stopPropagation()}>
              <button
                onClick={() => setTtsEnabled(v => !v)}
                title={ttsEnabled ? 'Antworten vorlesen: an' : 'Antworten vorlesen: aus'}
                className={cn(
                  'p-1.5 rounded-lg transition-all',
                  ttsEnabled ? 'text-yellow-200 bg-white/15' : 'text-white/70 hover:text-white hover:bg-white/10',
                )}
              >
                {ttsEnabled ? <Volume2 className="w-3.5 h-3.5" /> : <VolumeX className="w-3.5 h-3.5" />}
              </button>
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
              <div className="flex-1 overflow-y-auto p-4 space-y-3 scroll-smooth bg-gradient-to-b from-warm-50/40 to-white">
                {messages.map((msg, i) => {
                  const isLastAssistant = msg.role === 'assistant'
                    && msg.id !== 'greeting'
                    && msg.content.length > 0
                  const isSpeaking = speakingMsgId === msg.id
                  return (
                    <div
                      key={msg.id}
                      className={cn('flex gap-2 items-end', msg.role === 'user' ? 'justify-end' : 'justify-start')}
                    >
                      {msg.role === 'assistant' && (
                        <div className="w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 overflow-hidden mb-0.5">
                          <Image
                            src={BOT_AVATAR}
                            alt=""
                            width={28}
                            height={28}
                            className={cn(
                              'w-7 h-7 object-contain',
                              // Aktuell streamendes letztes Bot-Msg pulst
                              loading && i === messages.length - 1 && 'animate-pulse',
                            )}
                          />
                        </div>
                      )}
                      <div className="flex flex-col max-w-[82%]">
                        <div
                          className={cn(
                            'px-3.5 py-2.5 rounded-2xl text-sm leading-relaxed',
                            msg.role === 'user'
                              ? 'bg-primary-600 text-white rounded-br-sm'
                              : 'bg-warm-100 text-gray-800 rounded-bl-sm',
                          )}
                        >
                          {msg.content.length === 0 && msg.role === 'assistant' ? (
                            <span className="inline-flex gap-1 py-0.5">
                              {[0, 160, 320].map(d => (
                                <span key={d} className="w-1.5 h-1.5 bg-primary-400 rounded-full animate-bounce" style={{ animationDelay: `${d}ms` }} />
                              ))}
                            </span>
                          ) : (
                            <div
                              className="break-words"
                              dangerouslySetInnerHTML={{ __html: renderMarkdown(msg.content) }}
                            />
                          )}
                          {msg.ts > 0 && msg.content.length > 0 && (
                            <p className={cn('text-[10px] mt-1.5 select-none', msg.role === 'user' ? 'text-primary-200 text-right' : 'text-gray-400')}>
                              {new Date(msg.ts).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}
                            </p>
                          )}
                        </div>
                        {/* Feedback + TTS unter jeder Bot-Antwort */}
                        {isLastAssistant && (
                          <div className="flex items-center gap-1 mt-1 ml-1 text-gray-400">
                            <button
                              onClick={() => sendFeedback(msg, 'up')}
                              disabled={!!msg.rating}
                              title="Hilfreich"
                              className={cn(
                                'p-1 rounded transition-colors disabled:cursor-default',
                                msg.rating === 'up' ? 'text-primary-600' : 'hover:text-primary-600',
                              )}
                            >
                              <ThumbsUp className="w-3 h-3" />
                            </button>
                            <button
                              onClick={() => sendFeedback(msg, 'down')}
                              disabled={!!msg.rating}
                              title="Nicht hilfreich"
                              className={cn(
                                'p-1 rounded transition-colors disabled:cursor-default',
                                msg.rating === 'down' ? 'text-red-500' : 'hover:text-red-500',
                              )}
                            >
                              <ThumbsDown className="w-3 h-3" />
                            </button>
                            <button
                              onClick={() => toggleMsgSpeech(msg)}
                              title={isSpeaking ? 'Wiedergabe stoppen' : 'Antwort vorlesen'}
                              className={cn(
                                'p-1 rounded transition-colors',
                                isSpeaking ? 'text-primary-600' : 'hover:text-primary-600',
                              )}
                            >
                              {isSpeaking ? <VolumeX className="w-3 h-3" /> : <Volume2 className="w-3 h-3" />}
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  )
                })}
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
                <button
                  type="button"
                  onClick={toggleListening}
                  disabled={loading}
                  title={listening ? 'Aufnahme stoppen' : 'Per Stimme fragen'}
                  className={cn(
                    'w-10 h-10 flex items-center justify-center rounded-xl transition-all flex-shrink-0 border',
                    listening
                      ? 'bg-red-500 text-white border-red-500 animate-pulse'
                      : 'bg-warm-50 text-gray-500 border-warm-200 hover:bg-warm-100 hover:text-primary-600',
                  )}
                  aria-label="Spracheingabe"
                >
                  {listening ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
                </button>
                <input
                  ref={inputRef}
                  value={input}
                  onChange={e => setInput(e.target.value)}
                  onKeyDown={handleKeyDown}
                  placeholder={listening ? 'Ich höre zu…' : 'Frage stellen…'}
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
