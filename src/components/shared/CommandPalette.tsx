'use client'

/* ═══════════════════════════════════════════════════════════════════════
   MENSAENA – Command Palette (⌘K / Ctrl+K)
   Fast navigation + quick actions with fuzzy match.
   ═══════════════════════════════════════════════════════════════════════ */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  Search,
  Home,
  Map,
  Users,
  MessageCircle,
  Bell,
  User,
  Settings,
  PlusCircle,
  Calendar,
  Sparkles,
  HeartPulse,
  BookOpen,
  Briefcase,
  HandHeart,
  ShieldAlert,
  CornerDownLeft,
  ArrowUp,
  ArrowDown,
  type LucideIcon,
} from 'lucide-react'

interface Command {
  id: string
  label: string
  hint?: string
  icon: LucideIcon
  href?: string
  action?: () => void
  group: 'Navigation' | 'Erstellen' | 'Aktionen'
  keywords?: string
}

const OPEN_EVENT = 'mensaena:open-command-palette'

/** Open the command palette from anywhere in the app. */
export function openCommandPalette() {
  if (typeof window === 'undefined') return
  window.dispatchEvent(new CustomEvent(OPEN_EVENT))
}

function score(command: Command, q: string): number {
  if (!q) return 1
  const haystack = `${command.label} ${command.hint ?? ''} ${command.keywords ?? ''}`.toLowerCase()
  const needle = q.toLowerCase().trim()
  if (!needle) return 1
  if (haystack.includes(needle)) {
    // Prefix boost
    return command.label.toLowerCase().startsWith(needle) ? 100 : 50
  }
  // Fuzzy: every character of needle appears in order
  let hi = 0
  for (const ch of needle) {
    const idx = haystack.indexOf(ch, hi)
    if (idx === -1) return 0
    hi = idx + 1
  }
  return 10
}

export default function CommandPalette() {
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [activeIndex, setActiveIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)

  const commands: Command[] = useMemo(
    () => [
      // Navigation
      { id: 'dashboard', label: 'Dashboard', hint: 'Übersicht', icon: Home, href: '/dashboard', group: 'Navigation', keywords: 'start home home' },
      { id: 'map', label: 'Karte', hint: 'Hilfe in deiner Umgebung', icon: Map, href: '/dashboard/map', group: 'Navigation', keywords: 'map umgebung geo' },
      { id: 'chat', label: 'Nachrichten', hint: 'Direkte Gespräche', icon: MessageCircle, href: '/dashboard/chat', group: 'Navigation', keywords: 'messages dm' },
      { id: 'community', label: 'Community', hint: 'Gemeinschaft & Gruppen', icon: Users, href: '/dashboard/community', group: 'Navigation', keywords: 'gruppen forum' },
      { id: 'notifications', label: 'Benachrichtigungen', hint: 'Aktivitäten & Updates', icon: Bell, href: '/dashboard/notifications', group: 'Navigation' },
      { id: 'calendar', label: 'Kalender', hint: 'Deine Termine', icon: Calendar, href: '/dashboard/calendar', group: 'Navigation' },
      { id: 'events', label: 'Veranstaltungen', hint: 'Nachbarschafts-Events', icon: Sparkles, href: '/dashboard/events', group: 'Navigation' },
      { id: 'knowledge', label: 'Wissen', hint: 'Tipps & Anleitungen', icon: BookOpen, href: '/dashboard/knowledge', group: 'Navigation' },
      { id: 'mental-support', label: 'Mentale Unterstützung', hint: 'Hilfe in schweren Zeiten', icon: HeartPulse, href: '/dashboard/mental-support', group: 'Navigation', keywords: 'psyche krise' },
      { id: 'marketplace', label: 'Marktplatz', hint: 'Tauschen & Verschenken', icon: Briefcase, href: '/dashboard/marketplace', group: 'Navigation' },
      { id: 'timebank', label: 'Zeitbank', hint: 'Zeit gegen Zeit', icon: HandHeart, href: '/dashboard/timebank', group: 'Navigation' },
      { id: 'crisis', label: 'Krisenhilfe', hint: 'Schnelle Hilfe im Notfall', icon: ShieldAlert, href: '/dashboard/crisis', group: 'Navigation' },

      // Erstellen
      { id: 'create-post', label: 'Beitrag erstellen', hint: 'Angebot oder Anfrage', icon: PlusCircle, href: '/dashboard/create', group: 'Erstellen', keywords: 'new neu post' },
      { id: 'create-event', label: 'Event erstellen', hint: 'Nachbarschafts-Veranstaltung', icon: Calendar, href: '/dashboard/events/create', group: 'Erstellen' },
      { id: 'create-crisis', label: 'Krise melden', hint: 'Ich brauche sofort Hilfe', icon: ShieldAlert, href: '/dashboard/crisis/create', group: 'Erstellen', keywords: 'sos notfall' },

      // Aktionen
      { id: 'profile', label: 'Mein Profil', hint: 'Profil ansehen & bearbeiten', icon: User, href: '/dashboard/profile', group: 'Aktionen' },
      { id: 'settings', label: 'Einstellungen', hint: 'Account & Präferenzen', icon: Settings, href: '/dashboard/settings', group: 'Aktionen' },
    ],
    [],
  )

  const filtered = useMemo(() => {
    const scored = commands
      .map((c) => ({ c, s: score(c, query) }))
      .filter(({ s }) => s > 0)
      .sort((a, b) => b.s - a.s)
    return scored.map(({ c }) => c)
  }, [commands, query])

  // Reset active index when query changes
  useEffect(() => {
    setActiveIndex(0)
  }, [query])

  // Open shortcut: Cmd/Ctrl+K
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const isMac = navigator.platform.toLowerCase().includes('mac')
      const cmdOrCtrl = isMac ? e.metaKey : e.ctrlKey
      if (cmdOrCtrl && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setOpen((o) => !o)
      } else if (e.key === 'Escape' && open) {
        e.preventDefault()
        setOpen(false)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  // Open via custom event
  useEffect(() => {
    const handler = () => {
      setQuery('')
      setOpen(true)
    }
    window.addEventListener(OPEN_EVENT, handler)
    return () => window.removeEventListener(OPEN_EVENT, handler)
  }, [])

  // Focus input when opened
  useEffect(() => {
    if (open) {
      const t = setTimeout(() => inputRef.current?.focus(), 40)
      return () => clearTimeout(t)
    }
  }, [open])

  // Body scroll lock
  useEffect(() => {
    if (!open) return
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = prev
    }
  }, [open])

  const runCommand = useCallback(
    (cmd: Command) => {
      setOpen(false)
      setQuery('')
      if (cmd.href) router.push(cmd.href)
      else if (cmd.action) cmd.action()
    },
    [router],
  )

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setActiveIndex((i) => Math.min(i + 1, Math.max(0, filtered.length - 1)))
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setActiveIndex((i) => Math.max(i - 1, 0))
    } else if (e.key === 'Enter') {
      e.preventDefault()
      const cmd = filtered[activeIndex]
      if (cmd) runCommand(cmd)
    }
  }

  if (!open) return null

  // Group filtered commands by group in the order Navigation → Erstellen → Aktionen
  const groups: Command['group'][] = ['Navigation', 'Erstellen', 'Aktionen']

  // Compute running flat index so we can highlight by activeIndex
  let runningIndex = -1

  return (
    <div
      className="fixed inset-0 z-[110] flex items-start justify-center pt-[12vh] p-4 animate-fade-in"
      role="dialog"
      aria-modal="true"
      aria-label="Befehlspalette"
    >
      {/* Backdrop */}
      <button
        type="button"
        aria-label="Schließen"
        onClick={() => setOpen(false)}
        className="absolute inset-0 bg-ink-950/60 backdrop-blur-md"
      />

      {/* Panel */}
      <div className="relative w-full max-w-xl overflow-hidden rounded-2xl border border-white/40 bg-paper shadow-2xl animate-slide-up">
        {/* Search row */}
        <div className="flex items-center gap-3 px-4 py-3 border-b border-stone-200">
          <Search className="w-4 h-4 text-ink-400 flex-shrink-0" aria-hidden="true" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Wohin möchtest du? (z. B. Karte, Einstellungen…)"
            className="flex-1 bg-transparent text-sm text-ink-900 placeholder:text-ink-400 focus:outline-none"
            aria-label="Befehl oder Seite suchen"
          />
          <kbd className="hidden sm:inline-flex items-center gap-1 text-[10px] font-medium text-ink-500 bg-stone-100 border border-stone-200 rounded px-1.5 py-0.5">
            Esc
          </kbd>
        </div>

        {/* Results */}
        <div className="max-h-[55vh] overflow-y-auto py-2">
          {filtered.length === 0 ? (
            <div className="py-8 text-center text-sm text-ink-500">
              Keine Treffer für „{query}"
            </div>
          ) : (
            groups.map((groupName) => {
              const inGroup = filtered.filter((c) => c.group === groupName)
              if (inGroup.length === 0) return null
              return (
                <div key={groupName} className="mb-1">
                  <div className="px-4 pt-2 pb-1 text-[10px] uppercase tracking-[0.14em] font-semibold text-ink-400">
                    {groupName}
                  </div>
                  {inGroup.map((cmd) => {
                    runningIndex += 1
                    const active = runningIndex === activeIndex
                    const Icon = cmd.icon
                    return (
                      <button
                        key={cmd.id}
                        type="button"
                        onClick={() => runCommand(cmd)}
                        onMouseEnter={() => setActiveIndex(runningIndex)}
                        className={`w-full flex items-center gap-3 px-4 py-2.5 text-left transition-colors ${
                          active ? 'bg-primary-50' : 'hover:bg-stone-50'
                        }`}
                      >
                        <span
                          className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${
                            active ? 'bg-primary-100 text-primary-700' : 'bg-stone-100 text-ink-600'
                          }`}
                        >
                          <Icon className="w-4 h-4" />
                        </span>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-ink-900 truncate">{cmd.label}</p>
                          {cmd.hint && <p className="text-xs text-ink-500 truncate">{cmd.hint}</p>}
                        </div>
                        {active && (
                          <CornerDownLeft className="w-3.5 h-3.5 text-ink-400 flex-shrink-0" aria-hidden="true" />
                        )}
                      </button>
                    )
                  })}
                </div>
              )
            })
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-4 py-2 border-t border-stone-200 bg-stone-50 text-[11px] text-ink-500">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1">
              <ArrowUp className="w-3 h-3" />
              <ArrowDown className="w-3 h-3" />
              Navigieren
            </span>
            <span className="flex items-center gap-1">
              <CornerDownLeft className="w-3 h-3" />
              Öffnen
            </span>
          </div>
          <span className="hidden sm:flex items-center gap-1">
            <kbd className="bg-white border border-stone-200 rounded px-1.5 py-0.5 font-medium">⌘K</kbd>
            umschalten
          </span>
        </div>
      </div>
    </div>
  )
}
