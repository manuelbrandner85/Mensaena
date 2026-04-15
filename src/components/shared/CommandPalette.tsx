'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  Search, X, Home, BookOpen, Wrench, HeartHandshake, Users, Dog, Apple,
  Bike, Brain, Package, ShoppingBag, Gift, Map, AlertTriangle, Calendar,
  Settings, User, Bell, MessageCircle, Plus, Moon, Sun, Compass, PlayCircle,
} from 'lucide-react'
import { useT } from '@/lib/i18n'
import { useThemeStore } from '@/store/useThemeStore'

type PaletteItem = {
  id: string
  label: string
  section: 'modules' | 'actions' | 'recent' | 'settings'
  icon: React.ComponentType<{ className?: string }>
  action: () => void
  keywords?: string
}

export default function CommandPalette() {
  const router = useRouter()
  const { t } = useT()
  const toggleTheme = useThemeStore((s) => s.toggle)

  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [selectedIdx, setSelectedIdx] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)

  // ── Global hotkey: Cmd/Ctrl+K or "/" (when not in an input) ──
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const isMeta = e.metaKey || e.ctrlKey
      const inField = (() => {
        const el = document.activeElement as HTMLElement | null
        if (!el) return false
        const tag = el.tagName
        return (
          tag === 'INPUT' ||
          tag === 'TEXTAREA' ||
          tag === 'SELECT' ||
          el.isContentEditable
        )
      })()
      if (isMeta && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setOpen((v) => !v)
      } else if (e.key === '/' && !inField && !open) {
        e.preventDefault()
        setOpen(true)
      } else if (e.key === 'Escape' && open) {
        setOpen(false)
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open])

  // Expose a global opener so the Topbar search button can trigger it
  useEffect(() => {
    const opener = () => setOpen(true)
    window.addEventListener('mensaena:open-command-palette', opener)
    return () => window.removeEventListener('mensaena:open-command-palette', opener)
  }, [])

  // Focus input on open + reset state
  useEffect(() => {
    if (open) {
      setQuery('')
      setSelectedIdx(0)
      // next tick
      setTimeout(() => inputRef.current?.focus(), 20)
    }
  }, [open])

  const go = (path: string) => {
    setOpen(false)
    router.push(path)
  }

  const items: PaletteItem[] = useMemo(() => [
    // ── Modules ─────────────────────────────────────────────────
    { id: 'm-dashboard',   section: 'modules', icon: Home,          label: t('nav.dashboard'),     action: () => go('/dashboard'),             keywords: 'start home' },
    { id: 'm-posts',       section: 'modules', icon: Compass,       label: t('nav.posts'),         action: () => go('/dashboard/posts'),       keywords: 'feed' },
    { id: 'm-housing',     section: 'modules', icon: Home,          label: t('nav.housing'),       action: () => go('/dashboard/housing'),     keywords: 'wohnen casa' },
    { id: 'm-animals',     section: 'modules', icon: Dog,           label: t('nav.animals'),       action: () => go('/dashboard/animals'),     keywords: 'pets tiere animali' },
    { id: 'm-harvest',     section: 'modules', icon: Apple,         label: t('nav.harvest'),       action: () => go('/dashboard/harvest'),     keywords: 'food essen cibo' },
    { id: 'm-knowledge',   section: 'modules', icon: BookOpen,      label: t('nav.knowledge'),     action: () => go('/dashboard/knowledge'),   keywords: 'wissen learning' },
    { id: 'm-skills',      section: 'modules', icon: Wrench,        label: t('nav.skills'),        action: () => go('/dashboard/skills'),      keywords: 'skills competenze' },
    { id: 'm-sharing',     section: 'modules', icon: Gift,          label: t('nav.sharing'),       action: () => go('/dashboard/sharing'),     keywords: 'teilen share prestare' },
    { id: 'm-mobility',    section: 'modules', icon: Bike,          label: t('nav.mobility'),      action: () => go('/dashboard/mobility'),    keywords: 'fahrt mobility mobilita' },
    { id: 'm-rescuer',     section: 'modules', icon: HeartHandshake,label: t('nav.rescuer'),       action: () => go('/dashboard/rescuer'),     keywords: 'help rettung soccorso' },
    { id: 'm-mental',      section: 'modules', icon: Brain,         label: t('nav.mentalSupport'), action: () => go('/dashboard/mental-support'), keywords: 'mental support' },
    { id: 'm-community',   section: 'modules', icon: Users,         label: t('nav.community'),     action: () => go('/dashboard/community'),   keywords: 'gemeinschaft' },
    { id: 'm-calendar',    section: 'modules', icon: Calendar,      label: t('nav.calendar'),      action: () => go('/dashboard/calendar'),    keywords: 'events' },
    { id: 'm-events',      section: 'modules', icon: Calendar,      label: t('nav.events'),        action: () => go('/dashboard/events'),      keywords: 'calendar' },
    { id: 'm-supply',      section: 'modules', icon: Package,       label: t('nav.supply'),        action: () => go('/dashboard/supply'),      keywords: 'farm hof' },
    { id: 'm-marketplace', section: 'modules', icon: ShoppingBag,   label: t('nav.marketplace'),   action: () => go('/dashboard/marketplace'), keywords: 'market shop' },
    { id: 'm-map',         section: 'modules', icon: Map,           label: t('nav.map'),           action: () => go('/dashboard/map'),         keywords: 'karte mappa' },
    { id: 'm-crisis',      section: 'modules', icon: AlertTriangle, label: t('nav.crisis'),        action: () => go('/dashboard/crisis'),      keywords: 'sos emergency notfall' },
    { id: 'm-groups',      section: 'modules', icon: Users,         label: t('nav.groups'),        action: () => go('/dashboard/groups'),      keywords: 'gruppen' },
    { id: 'm-wiki',        section: 'modules', icon: BookOpen,      label: t('nav.wiki'),          action: () => go('/dashboard/wiki'),        keywords: 'docs' },

    // ── Actions ─────────────────────────────────────────────────
    { id: 'a-create',   section: 'actions', icon: Plus,        label: t('palette.actions.createPost'),    action: () => go('/dashboard/create'),        keywords: 'new beitrag post' },
    { id: 'a-theme',    section: 'actions', icon: Moon,        label: t('palette.actions.toggleTheme'),   action: () => { toggleTheme(); setOpen(false) }, keywords: 'dark light mode theme' },
    { id: 'a-sos',      section: 'actions', icon: AlertTriangle, label: t('palette.actions.sos'),         action: () => go('/dashboard/crisis'),        keywords: 'emergency notfall' },
    { id: 'a-profile',  section: 'actions', icon: User,        label: t('palette.actions.openProfile'),   action: () => go('/dashboard/profile'),       keywords: 'me' },
    { id: 'a-settings', section: 'actions', icon: Settings,    label: t('palette.actions.openSettings'),  action: () => go('/dashboard/settings'),      keywords: 'sprache language theme' },
    { id: 'a-tour',     section: 'actions', icon: PlayCircle,  label: t('palette.actions.replayTour'),    action: () => { localStorage.setItem('mensaena-onboarding-replay', String(Date.now())); window.dispatchEvent(new Event('mensaena:replay-onboarding')); setOpen(false) }, keywords: 'onboarding intro tour' },
    { id: 'a-notif',    section: 'actions', icon: Bell,        label: t('nav.notifications'),             action: () => go('/dashboard/notifications'),  keywords: 'bell' },
    { id: 'a-chat',     section: 'actions', icon: MessageCircle, label: t('nav.chat'),                    action: () => go('/dashboard/chat'),          keywords: 'messages nachrichten' },
  ], [t, toggleTheme]) // eslint-disable-line react-hooks/exhaustive-deps

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return items
    return items.filter((i) =>
      i.label.toLowerCase().includes(q) ||
      (i.keywords?.toLowerCase().includes(q) ?? false)
    )
  }, [items, query])

  // Keep selectedIdx in bounds when filter changes
  useEffect(() => {
    if (selectedIdx >= filtered.length) setSelectedIdx(0)
  }, [filtered, selectedIdx])

  // ── Keyboard nav inside the open palette ──
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'ArrowDown') {
        e.preventDefault()
        setSelectedIdx((i) => Math.min(i + 1, filtered.length - 1))
      } else if (e.key === 'ArrowUp') {
        e.preventDefault()
        setSelectedIdx((i) => Math.max(i - 1, 0))
      } else if (e.key === 'Enter') {
        e.preventDefault()
        const item = filtered[selectedIdx]
        if (item) item.action()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open, filtered, selectedIdx])

  if (!open) return null

  // Group filtered items by section preserving order
  const grouped: Record<PaletteItem['section'], PaletteItem[]> = {
    modules: [],
    actions: [],
    recent: [],
    settings: [],
  }
  filtered.forEach((i) => grouped[i.section].push(i))

  const sectionLabels: Record<PaletteItem['section'], string> = {
    modules: t('palette.sections.modules'),
    actions: t('palette.sections.actions'),
    recent: t('palette.sections.recent'),
    settings: t('palette.sections.settings'),
  }

  // Flat index of items in display order, for selection highlighting
  const flatList: PaletteItem[] = []
  ;(['actions', 'modules', 'recent', 'settings'] as const).forEach((s) => {
    flatList.push(...grouped[s])
  })

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={t('a11y.searchOpen')}
      className="fixed inset-0 z-[1000] flex items-start justify-center pt-[10vh] px-4"
      onClick={(e) => { if (e.target === e.currentTarget) setOpen(false) }}
    >
      {/* Backdrop */}
      <div className="absolute inset-0 bg-ink-900/40 dark:bg-black/60 backdrop-blur-sm animate-fade-in" />

      {/* Panel */}
      <div className="relative w-full max-w-xl bg-paper dark:bg-ink-800 rounded-2xl shadow-hover border border-stone-200 dark:border-ink-600 overflow-hidden animate-scale-in">
        {/* Input */}
        <div className="flex items-center gap-3 px-4 py-3 border-b border-stone-200 dark:border-ink-600">
          <Search className="w-4 h-4 text-ink-400 dark:text-stone-400 flex-shrink-0" />
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t('palette.placeholder')}
            className="flex-1 bg-transparent outline-none text-sm text-ink-800 dark:text-stone-100 placeholder:text-ink-400 dark:placeholder:text-stone-500"
            aria-label={t('common.search')}
          />
          <button
            onClick={() => setOpen(false)}
            className="p-1 rounded-lg hover:bg-stone-100 dark:hover:bg-ink-700 text-ink-500 dark:text-stone-400"
            aria-label={t('a11y.closeDialog')}
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Results */}
        <div className="max-h-[55vh] overflow-y-auto py-2">
          {flatList.length === 0 && (
            <div className="text-center py-10 text-sm text-ink-400 dark:text-stone-500">
              {t('palette.empty')}
            </div>
          )}

          {(['actions', 'modules'] as const).map((section) => {
            const list = grouped[section]
            if (list.length === 0) return null
            return (
              <div key={section} className="px-2 py-1">
                <div className="px-3 py-1.5 text-[10px] font-bold uppercase tracking-[0.14em] text-ink-400 dark:text-stone-500">
                  {sectionLabels[section]}
                </div>
                {list.map((item) => {
                  const idx = flatList.indexOf(item)
                  const active = idx === selectedIdx
                  return (
                    <button
                      key={item.id}
                      onClick={item.action}
                      onMouseEnter={() => setSelectedIdx(idx)}
                      className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-left text-sm transition-colors ${
                        active
                          ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-200'
                          : 'text-ink-700 dark:text-stone-200 hover:bg-stone-100 dark:hover:bg-ink-700'
                      }`}
                    >
                      <item.icon className={`w-4 h-4 flex-shrink-0 ${active ? 'text-primary-500' : 'text-ink-400 dark:text-stone-500'}`} />
                      <span className="flex-1 truncate">{item.label}</span>
                      {active && <span className="text-[10px] text-ink-400 dark:text-stone-500 font-mono">↵</span>}
                    </button>
                  )
                })}
              </div>
            )
          })}
        </div>

        {/* Footer hint */}
        <div className="flex items-center justify-between px-4 py-2 border-t border-stone-200 dark:border-ink-600 bg-stone-50 dark:bg-ink-900 text-[10px] text-ink-400 dark:text-stone-500 font-medium">
          <span className="flex items-center gap-1">
            <kbd className="px-1.5 py-0.5 rounded bg-white dark:bg-ink-700 border border-stone-200 dark:border-ink-600 font-mono">↑↓</kbd>
            <span>·</span>
            <kbd className="px-1.5 py-0.5 rounded bg-white dark:bg-ink-700 border border-stone-200 dark:border-ink-600 font-mono">↵</kbd>
            <span>·</span>
            <kbd className="px-1.5 py-0.5 rounded bg-white dark:bg-ink-700 border border-stone-200 dark:border-ink-600 font-mono">esc</kbd>
          </span>
          <span>{t('palette.hint')}</span>
        </div>
      </div>
    </div>
  )
}
