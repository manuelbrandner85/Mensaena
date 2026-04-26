'use client'

/* ═══════════════════════════════════════════════════════════════════════
   MENSAENA – Keyboard Shortcuts Modal
   Press "?" to open. Shows all global shortcuts with Mac/Win kbds.
   Also handles "G + X" navigation sequences (GoTo shortcuts).
   ═══════════════════════════════════════════════════════════════════════ */

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Keyboard, X } from 'lucide-react'
import { openCommandPalette } from './CommandPalette'
import { replayOnboarding } from './OnboardingTour'

const OPEN_EVENT = 'mensaena:open-shortcuts'

/** Open the shortcuts modal programmatically. */
export function openShortcutsModal() {
  if (typeof window === 'undefined') return
  window.dispatchEvent(new CustomEvent(OPEN_EVENT))
}

interface Shortcut {
  keys: string[]
  label: string
}

interface ShortcutGroup {
  title: string
  items: Shortcut[]
}

// Goto sequences: press G, then one of these within 1.2s
const GOTO_MAP: Record<string, string> = {
  d: '/dashboard',
  m: '/dashboard/map',
  c: '/dashboard/chat',
  n: '/dashboard/notifications',
  p: '/dashboard/profile',
  s: '/dashboard/settings',
  e: '/dashboard/events',
  k: '/dashboard/calendar',
  '+': '/dashboard/create',
}

function isEditable(target: EventTarget | null): boolean {
  if (!target || !(target instanceof HTMLElement)) return false
  const tag = target.tagName
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return true
  if (target.isContentEditable) return true
  return false
}

export default function KeyboardShortcutsModal() {
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const [gotoArmed, setGotoArmed] = useState(false)

  const groups: ShortcutGroup[] = useMemo(
    () => [
      {
        title: 'Allgemein',
        items: [
          { keys: ['?'], label: 'Tastaturkürzel anzeigen' },
          { keys: ['⌘', 'K'], label: 'Befehlspalette öffnen' },
          { keys: ['Esc'], label: 'Modals / Dialog schließen' },
        ],
      },
      {
        title: 'Navigation (G + Taste)',
        items: [
          { keys: ['G', 'D'], label: 'Dashboard' },
          { keys: ['G', 'M'], label: 'Karte' },
          { keys: ['G', 'C'], label: 'Nachrichten' },
          { keys: ['G', 'N'], label: 'Benachrichtigungen' },
          { keys: ['G', 'P'], label: 'Profil' },
          { keys: ['G', 'S'], label: 'Einstellungen' },
          { keys: ['G', 'E'], label: 'Veranstaltungen' },
          { keys: ['G', 'K'], label: 'Kalender' },
          { keys: ['G', '+'], label: 'Beitrag erstellen' },
        ],
      },
      {
        title: 'Onboarding',
        items: [
          { keys: ['Shift', '?'], label: 'Onboarding-Tour wiederholen' },
        ],
      },
    ],
    [],
  )

  // ── Listen for open event ──
  useEffect(() => {
    const handler = () => setOpen(true)
    window.addEventListener(OPEN_EVENT, handler)
    return () => window.removeEventListener(OPEN_EVENT, handler)
  }, [])

  // ── Global key handler ──
  useEffect(() => {
    let gotoTimer: number | null = null

    const disarm = () => {
      setGotoArmed(false)
      if (gotoTimer) {
        window.clearTimeout(gotoTimer)
        gotoTimer = null
      }
    }

    const onKey = (e: KeyboardEvent) => {
      if (isEditable(e.target)) return

      // Close modal with Escape
      if (e.key === 'Escape') {
        if (open) {
          e.preventDefault()
          setOpen(false)
        }
        disarm()
        return
      }

      // Shift + ? → replay onboarding
      if (e.shiftKey && e.key === '?') {
        e.preventDefault()
        replayOnboarding()
        return
      }

      // "?" → toggle shortcuts modal
      if (e.key === '?' && !e.metaKey && !e.ctrlKey) {
        e.preventDefault()
        setOpen((o) => !o)
        return
      }

      // Don't process G-sequences while modal is open
      if (open) return

      // "G" arms the goto sequence
      if (!gotoArmed && e.key.toLowerCase() === 'g' && !e.metaKey && !e.ctrlKey && !e.altKey) {
        e.preventDefault()
        setGotoArmed(true)
        gotoTimer = window.setTimeout(() => {
          setGotoArmed(false)
        }, 1200)
        return
      }

      // Armed: next key is the destination
      if (gotoArmed) {
        const key = e.key.toLowerCase()
        const target = GOTO_MAP[key]
        disarm()
        if (target) {
          e.preventDefault()
          if (key === '+' || target === '/dashboard/create') {
            // Special: ? already opens shortcuts, keep + for create
          }
          router.push(target)
        }
      }
    }

    window.addEventListener('keydown', onKey)
    return () => {
      window.removeEventListener('keydown', onKey)
      if (gotoTimer) window.clearTimeout(gotoTimer)
    }
  }, [open, gotoArmed, router])

  // ── Body scroll lock ──
  useEffect(() => {
    if (!open) return
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = prev
    }
  }, [open])

  return (
    <>
      {/* Goto-armed indicator */}
      {gotoArmed && !open && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-[95] pointer-events-none animate-fade-in">
          <div className="px-4 py-2 rounded-full bg-ink-900/90 text-paper text-xs font-medium backdrop-blur-md shadow-lg flex items-center gap-2">
            <kbd className="inline-flex items-center bg-white/15 rounded px-1.5 py-0.5 text-[10px] font-semibold">
              G
            </kbd>
            <span>Wohin? (D · M · C · N · P · S · E · K)</span>
          </div>
        </div>
      )}

      {open && (
        <div
          className="fixed inset-0 z-[105] flex items-center justify-center p-4 animate-fade-in"
          role="dialog"
          aria-modal="true"
          aria-labelledby="shortcuts-title"
        >
          {/* Backdrop */}
          <button
            type="button"
            aria-label="Schließen"
            onClick={() => setOpen(false)}
            className="absolute inset-0 bg-ink-900/60 backdrop-blur-md"
          />

          {/* Panel */}
          <div className="relative w-full max-w-xl overflow-hidden rounded-2xl border border-white/40 bg-paper shadow-2xl animate-slide-up">
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4 border-b border-stone-200">
              <div className="flex items-center gap-3">
                <span className="w-9 h-9 rounded-xl bg-primary-100 text-primary-700 flex items-center justify-center">
                  <Keyboard className="w-4 h-4" />
                </span>
                <div>
                  <h2 id="shortcuts-title" className="font-display text-lg font-medium text-ink-900 tracking-tight">
                    Tastaturkürzel
                  </h2>
                  <p className="text-[11px] text-ink-500">Schnell durch Mensaena navigieren</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="p-1.5 rounded-full text-ink-500 hover:bg-stone-100 hover:text-ink-800 transition-colors"
                aria-label="Schließen"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Groups */}
            <div className="max-h-[65vh] overflow-y-auto p-5 space-y-5">
              {groups.map((group) => (
                <section key={group.title}>
                  <h3 className="text-[10px] uppercase tracking-[0.14em] font-semibold text-ink-400 mb-2">
                    {group.title}
                  </h3>
                  <ul className="divide-y divide-stone-100">
                    {group.items.map((item, i) => (
                      <li key={i} className="flex items-center justify-between py-2">
                        <span className="text-sm text-ink-700">{item.label}</span>
                        <span className="flex items-center gap-1">
                          {item.keys.map((k, idx) => (
                            <span key={idx} className="flex items-center gap-1">
                              {idx > 0 && <span className="text-ink-300 text-[10px]">+</span>}
                              <kbd className="inline-flex items-center bg-white border border-stone-200 rounded px-2 py-0.5 text-[11px] font-semibold text-ink-700 shadow-sm">
                                {k}
                              </kbd>
                            </span>
                          ))}
                        </span>
                      </li>
                    ))}
                  </ul>
                </section>
              ))}
            </div>

            {/* Footer */}
            <div className="px-5 py-3 border-t border-stone-200 bg-stone-50 flex items-center justify-between">
              <p className="text-[11px] text-ink-500">
                Befehlspalette für noch mehr Aktionen:{' '}
                <button
                  type="button"
                  onClick={() => {
                    setOpen(false)
                    setTimeout(openCommandPalette, 80)
                  }}
                  className="font-semibold text-primary-700 hover:underline"
                >
                  ⌘K öffnen
                </button>
              </p>
              <kbd className="inline-flex items-center bg-white border border-stone-200 rounded px-2 py-0.5 text-[10px] font-semibold text-ink-500">
                Esc
              </kbd>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
