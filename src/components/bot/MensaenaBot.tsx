'use client'

import { useState, useRef, useEffect, useCallback, useMemo } from 'react'
import Image from 'next/image'
import { usePathname } from 'next/navigation'
import {
  X, Send, Loader2, RotateCcw, ChevronDown, Sparkles,
  Mic, MicOff, Volume2, VolumeX, ThumbsUp, ThumbsDown,
  MapPin,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useNavigationStore } from '@/store/useNavigationStore'

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

// ─── i18n: Locale-Typ & Helpers ──────────────────────────────────────────────
// Hauptsprachen: Deutsch & Englisch (Auto-Erkennung).
// Italienisch ist als manuelle Auswahl im Bot-Header verfügbar.
type Locale = 'de' | 'en' | 'it'
const SUPPORTED_LOCALES: Locale[] = ['de', 'en', 'it']
const LOCALE_LABELS: Record<Locale, string> = {
  de: 'Deutsch',
  en: 'English',
  it: 'Italiano',
}
const LOCALE_FLAGS: Record<Locale, string> = {
  de: '🇩🇪',
  en: '🇬🇧',
  it: '🇮🇹',
}
const LOCALE_STORAGE_KEY = 'mensaena-bot-locale'

function detectLocale(): Locale {
  if (typeof navigator === 'undefined') return 'de'
  const raw = (navigator.language || 'de').split('-')[0].toLowerCase()
  // Nur de/en werden automatisch erkannt. Italienisch ist opt-in.
  if (raw === 'en') return 'en'
  return 'de'
}

// FIX-B1/B2: Locale → BCP-47 für SpeechRecognition + SpeechSynthesis
// Vorher hardcoded 'de-DE' für englische/italienische User.
function localeToBcp47(locale: Locale): string {
  return locale === 'en' ? 'en-US' : locale === 'it' ? 'it-IT' : 'de-DE'
}

// ─── T: Personalisierte Begrüßung ────────────────────────────────────────────
function buildGreeting(userName: string | null, locale: Locale): BotMessage {
  const name = userName?.trim() || ''
  const has = name.length > 0

  const content =
    locale === 'en'
      ? has
        ? `Hi ${name}! 👋 I'm the **Mensaena Bot** – your AI assistant for the platform.\n\nI answer questions about Mensaena and topics around **humans, animals and nature**. *Freedom begins in consciousness.*\n\nWhat can I do for you?`
        : `Hi there! 👋 I'm the **Mensaena Bot** – your AI assistant for the platform.\n\nI answer questions about Mensaena and topics around **humans, animals and nature**. *Freedom begins in consciousness.*\n\nWhat can I do for you?`
      : locale === 'it'
      ? has
        ? `Ciao ${name}! 👋 Sono il **Mensaena Bot** – il tuo assistente IA per la piattaforma.\n\nRispondo a domande su Mensaena e su temi legati a **persone, animali e natura**. *La libertà inizia nella consapevolezza.*\n\nCosa posso fare per te?`
        : `Ciao! 👋 Sono il **Mensaena Bot** – il tuo assistente IA per la piattaforma.\n\nRispondo a domande su Mensaena e su temi legati a **persone, animali e natura**. *La libertà inizia nella consapevolezza.*\n\nCosa posso fare per te?`
      : has
      ? `Hallo ${name}! 👋 Ich bin der **Mensaena-Bot** – dein KI-Assistent für die Plattform.\n\nIch beantworte Fragen zu Mensaena und zu Themen rund um **Mensch, Tier und Natur**. *Freiheit beginnt im Bewusstsein.*\n\nWas kann ich für dich tun?`
      : `Hallo! 👋 Ich bin der **Mensaena-Bot** – dein KI-Assistent für die Plattform.\n\nIch beantworte Fragen zu Mensaena und zu Themen rund um **Mensch, Tier und Natur**. *Freiheit beginnt im Bewusstsein.*\n\nWas kann ich für dich tun?`

  return { id: 'greeting', role: 'assistant', content, ts: 0 }
}

// ─── U: Route-aware Quick Prompts ────────────────────────────────────────────
function getQuickPrompts(pathname: string | null, locale: Locale): string[] {
  const p = pathname ?? ''
  const key = p.startsWith('/dashboard/marketplace') ? 'marketplace'
    : p.startsWith('/dashboard/map') ? 'map'
    : p.startsWith('/dashboard/chat') ? 'chat'
    : p.startsWith('/dashboard/crisis') ? 'crisis'
    : p.startsWith('/dashboard/animals') ? 'animals'
    : 'default'

  const byLocale: Record<string, Record<Locale, string[]>> = {
    marketplace: {
      de: ['Wie inseriere ich Hilfe?', 'Wie kontaktiere ich einen Anbieter?', 'Kann ich Bilder hochladen?', 'Was kostet ein Inserat?'],
      en: ['How do I post an ad?', 'How do I contact a provider?', 'Can I upload pictures?', 'Is posting free?'],
      it: ['Come pubblico un annuncio?', 'Come contatto chi offre aiuto?', 'Posso caricare foto?', 'Pubblicare è gratis?'],
    },
    map: {
      de: ['Wie ändere ich den Radius?', 'Was bedeuten die Marker-Farben?', 'Funktioniert die Karte live?', 'Wie zentriere ich auf mich?'],
      en: ['How do I change the radius?', 'What do the marker colors mean?', 'Is the map realtime?', 'How do I recenter on me?'],
      it: ['Come cambio il raggio?', 'Cosa significano i colori dei marker?', 'La mappa è in tempo reale?', 'Come mi ricentro?'],
    },
    chat: {
      de: ['Kann ich Sprachnachrichten senden?', 'Was sind Kanäle?', 'Wie starte ich einen DM?', 'Gibt es Ende-zu-Ende?'],
      en: ['Can I send voice messages?', 'What are channels?', 'How do I start a DM?', 'Is chat end-to-end?'],
      it: ['Posso inviare messaggi vocali?', 'Cosa sono i canali?', 'Come avvio un DM?', 'La chat è end-to-end?'],
    },
    crisis: {
      de: ['Ich brauche jetzt Hilfe', 'Wie erreiche ich die Telefonseelsorge?', 'Was ist das Retter-System?', 'Ist das anonym?'],
      en: ['I need help right now', 'How do I reach a crisis hotline?', 'What is the rescuer system?', 'Is this anonymous?'],
      it: ['Ho bisogno di aiuto subito', 'Come raggiungo una linea di crisi?', 'Cos’è il sistema dei soccorritori?', 'È anonimo?'],
    },
    animals: {
      de: ['Wie vermittle ich ein Tier?', 'Was ist eine Pflegestelle?', 'Ich habe ein verletztes Tier gefunden', 'Tierrettung in meiner Nähe?'],
      en: ['How do I rehome an animal?', 'What is a foster home?', 'I found an injured animal', 'Animal rescue near me?'],
      it: ['Come do in adozione un animale?', 'Cos’è uno stallo?', 'Ho trovato un animale ferito', 'Soccorso animali vicino a me?'],
    },
    default: {
      de: ['Wie inseriere ich Hilfe?', 'Wie funktioniert der Chat?', 'Was zeigt die Karte?', 'Tierhilfe finden?', 'Was ist das Krisensystem?', 'Was ist Mensaena?', 'Ist Mensaena kostenlos?', 'Wo finde ich Bauernhöfe?'],
      en: ['How do I post for help?', 'How does chat work?', 'What does the map show?', 'Find animal help?', 'What is the crisis system?', 'What is Mensaena?', 'Is Mensaena free?', 'Where do I find farms?'],
      it: ['Come chiedo aiuto?', 'Come funziona la chat?', 'Cosa mostra la mappa?', 'Trovare aiuto per animali?', 'Cos’è il sistema di crisi?', 'Cos’è Mensaena?', 'Mensaena è gratis?', 'Dove trovo le fattorie?'],
    },
  }

  return byLocale[key][locale] ?? byLocale[key].de
}

// ─── V: Proactive Tips (ein Tipp pro Modul, einmalig) ────────────────────────
type TipDef = { title: Record<Locale, string>; body: Record<Locale, string> }
const TIPS: Record<string, TipDef> = {
  '/dashboard/marketplace': {
    title: {
      de: 'Tipp: Inserate mit Bild',
      en: 'Tip: Ads with photos',
      it: 'Suggerimento: annunci con foto',
    },
    body: {
      de: 'Inserate mit Foto bekommen deutlich mehr Antworten. Frag mich, wie das geht!',
      en: 'Ads with a photo get far more replies. Ask me how to add one!',
      it: 'Gli annunci con foto ricevono molte più risposte. Chiedimi come aggiungerne una!',
    },
  },
  '/dashboard/map': {
    title: {
      de: 'Tipp: Radius anpassen',
      en: 'Tip: Adjust the radius',
      it: 'Suggerimento: regola il raggio',
    },
    body: {
      de: 'Stell den Such-Radius auf deine Nachbarschaft ein – so findest du Hilfe ganz in deiner Nähe.',
      en: 'Set the search radius to your neighborhood to find help nearby.',
      it: 'Imposta il raggio di ricerca sul tuo quartiere per trovare aiuto vicino a te.',
    },
  },
  '/dashboard/chat': {
    title: {
      de: 'Tipp: Sprachnachrichten',
      en: 'Tip: Voice messages',
      it: 'Suggerimento: messaggi vocali',
    },
    body: {
      de: 'Du kannst im Chat auch Sprachnachrichten verschicken – ideal wenn’s schnell gehen muss.',
      en: 'You can also send voice messages in chat – perfect when you’re in a hurry.',
      it: 'Puoi anche inviare messaggi vocali in chat – perfetto quando hai fretta.',
    },
  },
  '/dashboard/crisis': {
    title: {
      de: 'Du bist nicht allein',
      en: 'You are not alone',
      it: 'Non sei solo',
    },
    body: {
      de: 'In akuten Notlagen wähle 112. Die Telefonseelsorge ist rund um die Uhr unter 0800 111 0 111 erreichbar.',
      en: 'In acute emergencies, dial 112. Crisis hotlines are available 24/7.',
      it: 'In caso di emergenza acuta, chiama il 112. Le linee di crisi sono attive 24 ore su 24.',
    },
  },
  '/dashboard/animals': {
    title: {
      de: 'Tipp: Verletztes Tier?',
      en: 'Tip: Injured animal?',
      it: 'Suggerimento: animale ferito?',
    },
    body: {
      de: 'Fotografiere das Tier aus sicherer Distanz und poste im Tier-Modul – Retter in der Nähe werden benachrichtigt.',
      en: 'Photograph the animal from a safe distance and post it – nearby rescuers get notified.',
      it: 'Fotografa l’animale da distanza sicura e pubblica nel modulo animali – i soccorritori vicini verranno avvisati.',
    },
  },
}

function matchTipKey(pathname: string | null): string | null {
  if (!pathname) return null
  const keys = Object.keys(TIPS)
  return keys.find(k => pathname.startsWith(k)) ?? null
}

const TIP_STORAGE_PREFIX = 'mensaena-bot-tip-seen-'

// ─── Intelligente Positionierung: Bot überlagert keine Route-spezifischen UI ─────
// Primär: dynamische Messung von [data-bot-avoid] Elementen (siehe useObservedClearance).
// Fallback: route-spezifischer Mindest-Abstand falls data-bot-avoid Marker fehlt.
function getRouteFloorPx(pathname: string | null): number {
  const p = pathname ?? ''
  if (p.startsWith('/dashboard/chat') || p.startsWith('/dashboard/messages')) return 144 // 9rem über BottomNav für Composer
  if (p.startsWith('/dashboard/map')) return 144 // über gestackten FABs
  return 80 // bottom-20 default (über BottomNav)
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
  html = html.replace(/`([^`\n]+)`/g, '<code class="bg-stone-100 px-1 rounded text-[11px] font-mono">$1</code>')

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

// FIX-V6: Storage-Key für Drag-Position
const CUSTOM_POS_KEY = 'mensaena-bot-custom-pos'

// FIX-B6/V5: Misst alle [data-bot-avoid] Elemente im DOM und gibt die Höhe
// (in px vom unteren Viewport-Rand) des am höchsten reichenden zurück.
// Reagiert auf Größenänderungen, Mount/Unmount und Viewport-Resize.
function useObservedClearance(): number {
  const [clearance, setClearance] = useState(0)

  useEffect(() => {
    if (typeof window === 'undefined') return

    let frame = 0
    const measure = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        // Auf Desktop hat der Bot seinen eigenen Eck-Platz — keine Messung nötig
        if (window.innerWidth >= 1024) {
          setClearance(0)
          return
        }
        const elements = document.querySelectorAll('[data-bot-avoid]')
        let maxFromBottom = 0
        elements.forEach((el) => {
          const rect = (el as HTMLElement).getBoundingClientRect()
          if (rect.height === 0 || rect.width === 0) return
          // Nur Elemente nahe dem Viewport-Bottom (innerhalb 80px)
          // → ignoriert Composer im Desktop-Panel oder gescrollte Inputs
          if (window.innerHeight - rect.bottom > 80) return
          const fromBottom = window.innerHeight - rect.top
          if (fromBottom > maxFromBottom) maxFromBottom = fromBottom
        })
        setClearance(maxFromBottom)
      })
    }

    measure()

    const resizeObserver = new ResizeObserver(measure)
    const observed = new Set<Element>()
    const attach = () => {
      document.querySelectorAll('[data-bot-avoid]').forEach((el) => {
        if (!observed.has(el)) {
          resizeObserver.observe(el)
          observed.add(el)
        }
      })
    }
    attach()

    // MutationObserver erkennt neu hinzugefügte/entfernte data-bot-avoid Elemente
    const mutationObserver = new MutationObserver(() => { attach(); measure() })
    mutationObserver.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-bot-avoid'] })

    window.addEventListener('resize', measure)

    return () => {
      cancelAnimationFrame(frame)
      resizeObserver.disconnect()
      mutationObserver.disconnect()
      window.removeEventListener('resize', measure)
    }
  }, [])

  return clearance
}

// ─── Component ────────────────────────────────────────────────────────────────
export default function MensaenaBot() {
  const pathname = usePathname()
  // FIX-V4: Bot bei aktivem Anruf komplett ausblenden
  const isInCall = useNavigationStore((s) => s.isInCall)

  // ── UI State
  const [open, setOpen] = useState(false)
  const [minimized, setMinimized] = useState(false)
  const [hasNew, setHasNew] = useState(false)
  const [showOnboarding, setShowOnboarding] = useState(false)

  // ── T+X: User-Name + Locale
  const [userName, setUserName] = useState<string | null>(null)
  const [locale, setLocale] = useState<Locale>('de')

  // ── V: Proactive Tip
  const [activeTipKey, setActiveTipKey] = useState<string | null>(null)

  // ── Language Picker
  const [showLangMenu, setShowLangMenu] = useState(false)
  const changeLocale = useCallback((next: Locale) => {
    setLocale(next)
    setShowLangMenu(false)
    try {
      if (typeof window !== 'undefined') {
        localStorage.setItem(LOCALE_STORAGE_KEY, next)
      }
    } catch {
      /* ignore */
    }
  }, [])

  const greeting = useMemo(() => buildGreeting(userName, locale), [userName, locale])
  const quickPrompts = useMemo(() => getQuickPrompts(pathname, locale), [pathname, locale])

  // FIX-B6/V5: Dynamisch gemessene Clearance + Route-Floor als Fallback
  const observedClearance = useObservedClearance()
  const routeFloorPx = useMemo(() => getRouteFloorPx(pathname), [pathname])

  // FIX-V2: Custom Drag-Position (überschreibt Auto-Positionierung)
  const [customPos, setCustomPos] = useState<{ x: number; y: number } | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const dragStartRef = useRef<{ pointerX: number; pointerY: number; btnX: number; btnY: number } | null>(null)
  const longPressTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const wasDraggedRef = useRef(false)

  // ── Chat State
  const [messages, setMessages] = useState<BotMessage[]>([greeting])
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

  // ── Mount: lade Verlauf aus localStorage + Onboarding-Status + Locale
  useEffect(() => {
    if (typeof window === 'undefined') return
    // X: Gespeicherte Locale-Auswahl bevorzugen, sonst Browser-Erkennung (nur de/en).
    // Italienisch ist nur via manueller Auswahl verfügbar.
    try {
      const stored = localStorage.getItem(LOCALE_STORAGE_KEY) as Locale | null
      if (stored && SUPPORTED_LOCALES.includes(stored)) {
        setLocale(stored)
      } else {
        setLocale(detectLocale())
      }
    } catch {
      setLocale(detectLocale())
    }
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

  // ── T: Profil aus Supabase laden (Vorname/Nickname)
  useEffect(() => {
    let cancelled = false
    const run = async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user || cancelled) return
        const { data: profile } = await supabase
          .from('profiles')
          .select('name, nickname')
          .eq('id', user.id)
          .maybeSingle()
        if (cancelled) return
        const first = (profile?.nickname || profile?.name || '').toString().trim().split(/\s+/)[0] ?? ''
        if (first) setUserName(first)
      } catch (err) {
        console.warn('[bot] profile lookup failed:', err)
      }
    }
    run()
    return () => { cancelled = true }
  }, [])

  // ── Begrüßung aktualisieren, solange der User noch nichts geschrieben hat
  useEffect(() => {
    setMessages(prev => {
      if (prev.length === 1 && prev[0]?.id === 'greeting') return [greeting]
      return prev
    })
  }, [greeting])

  // ── V: Proactive Tip bei Modulwechsel (einmalig, wenn kein Onboarding läuft)
  useEffect(() => {
    if (typeof window === 'undefined') return
    if (showOnboarding || open) return
    const key = matchTipKey(pathname)
    if (!key) { setActiveTipKey(null); return }
    const seenKey = `${TIP_STORAGE_PREFIX}${key}`
    if (localStorage.getItem(seenKey)) { setActiveTipKey(null); return }
    const show = setTimeout(() => setActiveTipKey(key), 3000)
    const hide = setTimeout(() => {
      setActiveTipKey(curr => {
        if (curr === key) {
          try { localStorage.setItem(seenKey, '1') } catch {}
          return null
        }
        return curr
      })
    }, 15000)
    return () => { clearTimeout(show); clearTimeout(hide) }
  }, [pathname, showOnboarding, open])

  const dismissTip = useCallback(() => {
    setActiveTipKey(curr => {
      if (curr && typeof window !== 'undefined') {
        try { localStorage.setItem(`${TIP_STORAGE_PREFIX}${curr}`, '1') } catch {}
      }
      return null
    })
  }, [])

  // ── Persistiere Verlauf
  // FIX-B5: Bei Erreichen des 50-Nachrichten-Limits wird der ältere Teil
  // nicht still gelöscht, sondern in den State zurückgespiegelt — damit der
  // User den effektiven Verlauf sieht und keine ungespeicherten "Geister"
  // im UI verbleiben.
  useEffect(() => {
    if (typeof window === 'undefined') return
    if (messages.length <= 1 && messages[0]?.id === 'greeting') return
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(messages.slice(-50)))
      if (messages.length > 50) {
        // Effektiven Verlauf auch im State kürzen, damit UI = Persistenz.
        setMessages(prev => prev.length > 50 ? prev.slice(-50) : prev)
      }
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

  // FIX-V2: Custom-Position aus localStorage wiederherstellen
  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      const raw = localStorage.getItem(CUSTOM_POS_KEY)
      if (!raw) return
      const parsed = JSON.parse(raw) as { x: number; y: number }
      if (typeof parsed?.x === 'number' && typeof parsed?.y === 'number') {
        // Position auf Viewport clampen für Fall, dass Viewport schrumpfte
        const x = Math.max(8, Math.min(window.innerWidth - 64, parsed.x))
        const y = Math.max(8, Math.min(window.innerHeight - 64, parsed.y))
        setCustomPos({ x, y })
      }
    } catch {}
  }, [])

  // FIX-V3: Auto-minimize wenn der User einen Chat-Input fokussiert
  useEffect(() => {
    if (typeof document === 'undefined') return
    const onFocusIn = (e: FocusEvent) => {
      if (!open || minimized) return
      const target = e.target as HTMLElement | null
      if (!target) return
      const isEditable = target.matches('input, textarea, [contenteditable="true"]')
      if (!isEditable) return
      // Nicht minimieren bei Inputs INNERHALB des Bot-Panels selbst
      if (target.closest('[data-bot-panel]')) return
      // Nur bei Inputs in der Chat-Composer minimieren
      if (target.closest('[data-bot-avoid]')) {
        setMinimized(true)
      }
    }
    document.addEventListener('focusin', onFocusIn)
    return () => document.removeEventListener('focusin', onFocusIn)
  }, [open, minimized])

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
          userName,
          locale,
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
  }, [loading, messages, pathname, ttsEnabled, userName, locale])

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
    setMessages([greeting])
    setInput('')
    setLoading(false)
    if (typeof window !== 'undefined') {
      localStorage.removeItem(STORAGE_KEY)
      if ('speechSynthesis' in window) window.speechSynthesis.cancel()
    }
    setSpeakingMsgId(null)
    setTimeout(() => inputRef.current?.focus(), 100)
  }, [greeting])

  const toggleOpen = () => {
    // FIX-V2: Wenn der Button gedraggt wurde, Click NICHT als Toggle interpretieren
    if (wasDraggedRef.current) {
      wasDraggedRef.current = false
      return
    }
    setOpen(o => !o)
    setHasNew(false)
  }

  // FIX-V2: Drag-to-reposition (Long-Press 500ms aktiviert Drag-Modus)
  const handlePointerDown = useCallback((e: React.PointerEvent<HTMLButtonElement>) => {
    if (open) return
    const button = e.currentTarget
    longPressTimerRef.current = setTimeout(() => {
      const rect = button.getBoundingClientRect()
      dragStartRef.current = {
        pointerX: e.clientX,
        pointerY: e.clientY,
        btnX: rect.left,
        btnY: rect.top,
      }
      setIsDragging(true)
      try { button.setPointerCapture(e.pointerId) } catch {}
      if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
        try { navigator.vibrate?.(40) } catch {}
      }
    }, 500)
  }, [open])

  const handlePointerMove = useCallback((e: React.PointerEvent<HTMLButtonElement>) => {
    if (!isDragging || !dragStartRef.current) return
    e.preventDefault()
    wasDraggedRef.current = true
    const dx = e.clientX - dragStartRef.current.pointerX
    const dy = e.clientY - dragStartRef.current.pointerY
    const newX = Math.max(8, Math.min(window.innerWidth - 64, dragStartRef.current.btnX + dx))
    const newY = Math.max(8, Math.min(window.innerHeight - 64, dragStartRef.current.btnY + dy))
    setCustomPos({ x: newX, y: newY })
  }, [isDragging])

  const handlePointerUp = useCallback((e: React.PointerEvent<HTMLButtonElement>) => {
    if (longPressTimerRef.current) {
      clearTimeout(longPressTimerRef.current)
      longPressTimerRef.current = null
    }
    if (isDragging) {
      try { e.currentTarget.releasePointerCapture(e.pointerId) } catch {}
      setIsDragging(false)
      // Persistieren
      if (customPos) {
        try { localStorage.setItem(CUSTOM_POS_KEY, JSON.stringify(customPos)) } catch {}
      }
    }
    dragStartRef.current = null
  }, [isDragging, customPos])

  const resetPosition = useCallback(() => {
    setCustomPos(null)
    try { localStorage.removeItem(CUSTOM_POS_KEY) } catch {}
  }, [])

  // FIX-V6: Lokale Antwort auf "Ist die App aktuell?" — kein API-Call nötig
  const handleVersionCheck = useCallback(async () => {
    const userMsg: BotMessage = {
      id: genId(),
      role: 'user',
      content: locale === 'en' ? 'Is the app up to date?'
             : locale === 'it' ? 'L\'app è aggiornata?'
             : 'Ist die App aktuell?',
      ts: Date.now(),
    }
    setMessages(prev => [...prev, userMsg])
    try {
      const res = await fetch(`/version.json?t=${Date.now()}`)
      if (!res.ok) throw new Error('not ok')
      const data = await res.json() as { webVersion: string; apkVersion: string; releasedAt?: string }
      const stored = typeof window !== 'undefined' ? localStorage.getItem('mensaena_web_version') : null
      const isCurrent = !stored || stored === data.webVersion
      const date = data.releasedAt ? new Date(data.releasedAt).toLocaleDateString(localeToBcp47(locale)) : ''
      const content =
        locale === 'en'
          ? `${isCurrent ? '✅' : '🆕'} **Web v${data.webVersion}**${date ? ` (released ${date})` : ''}\n\nAndroid app: **v${data.apkVersion}**\n\n${isCurrent ? 'You\'re on the latest version!' : 'A newer version is available — reload to update.'}`
          : locale === 'it'
          ? `${isCurrent ? '✅' : '🆕'} **Web v${data.webVersion}**${date ? ` (rilasciata ${date})` : ''}\n\nApp Android: **v${data.apkVersion}**\n\n${isCurrent ? 'Sei sull\'ultima versione!' : 'È disponibile una versione più recente — ricarica per aggiornare.'}`
          : `${isCurrent ? '✅' : '🆕'} **Web v${data.webVersion}**${date ? ` (veröffentlicht am ${date})` : ''}\n\nAndroid-App: **v${data.apkVersion}**\n\n${isCurrent ? 'Du bist auf der neuesten Version!' : 'Eine neuere Version ist verfügbar — lade die Seite neu, um zu aktualisieren.'}`
      setMessages(prev => [...prev, { id: genId(), role: 'assistant', content, ts: Date.now() }])
    } catch {
      setMessages(prev => [...prev, {
        id: genId(),
        role: 'assistant',
        content: locale === 'en' ? 'Couldn\'t fetch version info. 🙏' : locale === 'it' ? 'Impossibile recuperare la versione. 🙏' : 'Konnte Versionsinfo nicht laden. 🙏',
        ts: Date.now(),
      }])
    }
  }, [locale])

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
    // FIX-B1: Locale-aware Spracherkennung statt hardcoded de-DE
    rec.lang = localeToBcp47(locale)
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
    // FIX-B3: Unicode-aware Emoji-Strip statt unvollständiger Character-Class.
    // Erfasst alle Emoji inkl. neuer (📞📦📥…) und Skin-Tone-Modifier.
    const plain = text
      .replace(/\*\*/g, '')
      .replace(/\*/g, '')
      .replace(/`/g, '')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/\p{Extended_Pictographic}\p{Emoji_Modifier}?(?:‍\p{Extended_Pictographic}\p{Emoji_Modifier}?)*/gu, '')
    window.speechSynthesis.cancel()
    const utter = new SpeechSynthesisUtterance(plain)
    // FIX-B2: Locale-aware TTS statt hardcoded de-DE
    utter.lang = localeToBcp47(locale)
    utter.rate = 1.0
    utter.pitch = 1.0
    utter.onstart = () => setSpeakingMsgId(msgId)
    utter.onend = () => setSpeakingMsgId(null)
    utter.onerror = () => setSpeakingMsgId(null)
    window.speechSynthesis.speak(utter)
  }, [locale])

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

  // FIX-B4: Index der letzten echten Bot-Antwort (für Feedback-Buttons).
  const lastAssistantIdx = useMemo(() => {
    for (let i = messages.length - 1; i >= 0; i--) {
      const m = messages[i]
      if (m.role === 'assistant' && m.id !== 'greeting' && m.content.length > 0) {
        return i
      }
    }
    return -1
  }, [messages])

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

  // FIX-V4: Bot bei aktivem Anruf komplett ausblenden
  if (isInCall) return null

  // FIX-B6/V5/V2: Position berechnen — Custom-Drag > max(Observed-Clearance, Route-Floor)
  const computedBottomPx = customPos
    ? null
    : Math.max(routeFloorPx, observedClearance + 16 /* gap */)

  const buttonStyle: React.CSSProperties = customPos
    ? {
        position: 'fixed',
        left: customPos.x,
        top: customPos.y,
        right: 'auto',
        bottom: 'auto',
      }
    : computedBottomPx !== null
      ? { bottom: `${computedBottomPx}px` }
      : {}

  return (
    <>
      {/* ─── Floating Button (Position passt sich Route + UI dynamisch an) ─── */}
      <button
        onClick={toggleOpen}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        style={buttonStyle}
        className={cn(
          'fixed z-30 flex items-center justify-center rounded-full shadow-xl transition-all duration-300 touch-none',
          // Right + Desktop-Bottom kommen aus Klassen, Mobile-Bottom aus inline style.
          // lg:!bottom-6 mit !important überschreibt inline style auf Desktop,
          // damit der Bot dort in der Ecke bleibt (mobile observedClearance gilt nicht für Desktop).
          customPos ? '' : 'right-4 lg:right-6 lg:!bottom-6',
          isDragging && 'ring-4 ring-primary-300 cursor-grabbing scale-95',
          open
            ? 'w-10 h-10 bg-ink-700 hover:bg-ink-800 scale-100'
            : 'w-14 h-14 hover:scale-110',
        )}
        aria-label={open ? 'Mensaena-Bot schließen' : 'Mensaena-Bot öffnen (lange drücken zum Verschieben)'}
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

      {/* ─── V: Proaktiver Tipp pro Modul (einmalig) ──────────────── */}
      {!open && !showOnboarding && activeTipKey && TIPS[activeTipKey] && !customPos && (
        <div
          onClick={dismissTip}
          style={
            computedBottomPx !== null
              ? { bottom: `${computedBottomPx + 80}px` }
              : undefined
          }
          className={cn(
            'fixed z-20 max-w-[260px] bg-white rounded-2xl shadow-card border border-primary-200 p-3 animate-slide-up cursor-pointer',
            'right-4 lg:right-24 lg:!bottom-24',
          )}
        >
          <button
            onClick={(e) => { e.stopPropagation(); dismissTip() }}
            className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-white border border-stone-200 text-ink-400 hover:text-ink-600 flex items-center justify-center shadow-sm"
            aria-label="Tipp schließen"
          >
            <X className="w-3 h-3" />
          </button>
          <p className="text-xs font-semibold text-ink-800 flex items-center gap-1.5">
            <Sparkles className="w-3.5 h-3.5 text-primary-600" />
            {TIPS[activeTipKey].title[locale] ?? TIPS[activeTipKey].title.de}
          </p>
          <p className="text-[11px] text-ink-500 mt-1 leading-relaxed">
            {TIPS[activeTipKey].body[locale] ?? TIPS[activeTipKey].body.de}
          </p>
          <div className="absolute -bottom-1.5 right-6 w-3 h-3 bg-white border-r border-b border-primary-200 rotate-45" />
        </div>
      )}

      {/* ─── Onboarding-Tooltip (einmalig beim ersten Besuch) ─────── */}
      {showOnboarding && !open && !customPos && (
        <div
          style={
            computedBottomPx !== null
              ? { bottom: `${computedBottomPx + 80}px` }
              : undefined
          }
          className={cn(
            'fixed z-30 max-w-[240px] bg-white rounded-2xl shadow-card border border-primary-200 p-3 animate-slide-up',
            'right-4 lg:right-24 lg:!bottom-24',
          )}
        >
          <button
            onClick={() => {
              setShowOnboarding(false)
              if (typeof window !== 'undefined') localStorage.setItem(ONBOARDING_KEY, '1')
            }}
            className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-white border border-stone-200 text-ink-400 hover:text-ink-600 flex items-center justify-center shadow-sm"
            aria-label="Tooltip schließen"
          >
            <X className="w-3 h-3" />
          </button>
          <p className="text-xs font-semibold text-ink-800 flex items-center gap-1.5">
            <Sparkles className="w-3.5 h-3.5 text-primary-600" />
            Frag mich alles zu Mensaena
          </p>
          <p className="text-[11px] text-ink-500 mt-1 leading-relaxed">
            Der KI-Assistent hilft bei Fragen rund um die Plattform, Natur & Gemeinschaft.
          </p>
          {/* Speech-Bubble tail */}
          <div className="absolute -bottom-1.5 right-6 w-3 h-3 bg-white border-r border-b border-primary-200 rotate-45" />
        </div>
      )}

      {/* ─── Chat-Fenster (Position passt sich Route + Clearance dynamisch an) ──── */}
      {open && (
        <div
          data-bot-panel="true"
          style={
            !minimized && computedBottomPx !== null
              ? { bottom: `calc(${computedBottomPx + 16}px + env(safe-area-inset-bottom, 0px))` }
              : minimized && computedBottomPx !== null
                ? { bottom: `${computedBottomPx}px` }
                : undefined
          }
          className={cn(
            'fixed z-30 bg-white shadow-2xl border border-warm-200 flex flex-col overflow-hidden transition-all duration-300 rounded-2xl',
            // Mobile: Bottom-Sheet, max 75dvh + Cap bei 600px (Querformat)
            !minimized && 'left-2 right-2 top-auto h-[75dvh] max-h-[600px]',
            // Tablet (sm+): schmaler + rechtsbündig statt stretched
            !minimized && 'sm:left-auto sm:right-4 sm:w-[92vw] sm:max-w-[440px]',
            // Desktop: feste Panel-Dimension
            !minimized && 'lg:inset-auto lg:!bottom-20 lg:right-6 lg:w-[420px] lg:h-[580px] lg:max-h-none',
            // Minimized: nur Header-Leiste, rechtsbündig
            minimized && 'h-14 top-auto left-auto w-auto right-4 lg:right-6 lg:!bottom-6',
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
              <p className="text-xs text-primary-100 flex items-center gap-1.5">
                <span className={cn(
                  'w-1.5 h-1.5 rounded-full inline-block flex-shrink-0',
                  loading ? 'bg-amber-300 animate-pulse' : 'bg-green-400 animate-pulse',
                )} />
                {loading ? 'denkt nach…' : 'KI-Assistent · Mensch, Tier & Natur'}
              </p>
            </div>
            <div className="relative flex items-center gap-0.5" onClick={e => e.stopPropagation()}>
              {/* Language Picker */}
              <div className="relative">
                <button
                  onClick={() => setShowLangMenu(v => !v)}
                  title={`Sprache: ${LOCALE_LABELS[locale]}`}
                  aria-label="Sprache wählen"
                  aria-expanded={showLangMenu}
                  className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all text-base leading-none"
                >
                  <span aria-hidden="true">{LOCALE_FLAGS[locale]}</span>
                </button>
                {showLangMenu && (
                  <div className="absolute right-0 top-full mt-1.5 z-50 min-w-[140px] bg-white rounded-xl shadow-xl border border-stone-100 overflow-hidden">
                    {SUPPORTED_LOCALES.map(code => (
                      <button
                        key={code}
                        onClick={() => changeLocale(code)}
                        className={cn(
                          'w-full flex items-center gap-2.5 px-3 py-2 text-xs font-medium text-left transition-colors',
                          locale === code
                            ? 'bg-primary-50 text-primary-800'
                            : 'text-ink-700 hover:bg-stone-50',
                        )}
                      >
                        <span className="text-base leading-none">{LOCALE_FLAGS[code]}</span>
                        <span>{LOCALE_LABELS[code]}</span>
                        {locale === code && (
                          <span className="ml-auto w-1.5 h-1.5 rounded-full bg-primary-500" />
                        )}
                      </button>
                    ))}
                  </div>
                )}
              </div>
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
              {/* FIX-V2: Reset-Position-Button erscheint nur wenn der User den Bot verschoben hat */}
              {customPos && (
                <button
                  onClick={resetPosition}
                  title="Position zurücksetzen"
                  aria-label="Bot-Position zurücksetzen"
                  className="p-1.5 rounded-lg text-white/70 hover:text-white hover:bg-white/10 transition-all"
                >
                  <MapPin className="w-3.5 h-3.5" />
                </button>
              )}
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
                  // FIX-B4: Feedback-Buttons nur unter der LETZTEN Bot-Antwort,
                  // nicht unter allen vergangenen (vorher waren sie überall sichtbar).
                  const isLastAssistant = msg.role === 'assistant'
                    && msg.id !== 'greeting'
                    && msg.content.length > 0
                    && i === lastAssistantIdx
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
                              : 'bg-warm-100 text-ink-800 rounded-bl-sm',
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
                            <p className={cn('text-xs mt-1.5 select-none', msg.role === 'user' ? 'text-primary-200 text-right' : 'text-ink-400')}>
                              {new Date(msg.ts).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}
                            </p>
                          )}
                        </div>
                        {/* Feedback + TTS unter jeder Bot-Antwort */}
                        {isLastAssistant && (
                          <div className="flex items-center gap-1 mt-1 ml-1 text-ink-400">
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
                  {quickPrompts.map(p => (
                    <button
                      key={p}
                      onClick={() => sendMessage(p)}
                      className="text-[11px] px-2.5 py-1 bg-primary-50 text-primary-700 border border-primary-200 rounded-full hover:bg-primary-100 hover:border-primary-300 transition-all font-medium"
                    >
                      {p}
                    </button>
                  ))}
                  {/* FIX-V6: Spezial-Quick-Prompt für App-Versions-Check (lokal, kein API-Call) */}
                  <button
                    onClick={handleVersionCheck}
                    className="text-[11px] px-2.5 py-1 bg-warm-50 text-ink-700 border border-warm-200 rounded-full hover:bg-warm-100 transition-all font-medium"
                  >
                    {locale === 'en' ? '🔄 Is the app up to date?' : locale === 'it' ? '🔄 L’app è aggiornata?' : '🔄 Ist die App aktuell?'}
                  </button>
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
                      : 'bg-warm-50 text-ink-500 border-warm-200 hover:bg-warm-100 hover:text-primary-600',
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
