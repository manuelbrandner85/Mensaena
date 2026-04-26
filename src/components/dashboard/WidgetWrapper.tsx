'use client'

// ── WidgetWrapper ─────────────────────────────────────────────────────────────
// Generischer Wrapper für Dashboard-Widgets mit Card-Header, Collapse-Toggle
// und Error-Boundary. Wird in der nächsten Phase mit dem WidgetGrid verdrahtet.

import { Component, useState, type ReactNode } from 'react'
import {
  ChevronDown, ChevronUp, AlertTriangle, RotateCcw, GripVertical,
} from 'lucide-react'

const COLLAPSE_PREFIX = 'mensaena_widget_collapsed_'

function isCollapsed(id: string): boolean {
  if (typeof window === 'undefined') return false
  try { return window.localStorage.getItem(COLLAPSE_PREFIX + id) === '1' } catch { return false }
}
function setCollapsed(id: string, value: boolean): void {
  if (typeof window === 'undefined') return
  try {
    if (value) window.localStorage.setItem(COLLAPSE_PREFIX + id, '1')
    else window.localStorage.removeItem(COLLAPSE_PREFIX + id)
  } catch { /* ignore */ }
}

// ── Error-Boundary ───────────────────────────────────────────────────────────

interface ErrorBoundaryProps {
  fallback: (retry: () => void) => ReactNode
  children: ReactNode
}

interface ErrorBoundaryState { hasError: boolean }

class WidgetErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true }
  }

  componentDidCatch(): void {
    // Logging optional. Sentry o. ä. könnte hier andocken.
  }

  retry = (): void => this.setState({ hasError: false })

  render(): ReactNode {
    if (this.state.hasError) return this.props.fallback(this.retry)
    return this.props.children
  }
}

// ── Wrapper ──────────────────────────────────────────────────────────────────

export interface WidgetWrapperProps {
  id: string
  title: string
  children: ReactNode
  /** Drag-Handle anzeigen (nur im Settings-/Edit-Modus) */
  draggable?: boolean
  /** Initial collapsed (überschreibt localStorage nicht) */
  defaultCollapsed?: boolean
  className?: string
}

export function WidgetWrapper({
  id,
  title,
  children,
  draggable = false,
  defaultCollapsed = false,
  className = '',
}: WidgetWrapperProps) {
  const [collapsed, setLocalCollapsed] = useState<boolean>(
    () => isCollapsed(id) || defaultCollapsed,
  )

  function toggle() {
    setLocalCollapsed(prev => {
      const next = !prev
      setCollapsed(id, next)
      return next
    })
  }

  return (
    <section
      aria-label={title}
      className={`overflow-hidden rounded-xl border border-stone-200 bg-white shadow-sm dark:border-gray-700 dark:bg-ink-800 ${className}`}
    >
      <header className="flex items-center justify-between border-b border-stone-100 px-3 py-2 dark:border-gray-700">
        <div className="flex items-center gap-2">
          {draggable && (
            <button
              type="button"
              aria-label="Widget verschieben"
              className="cursor-grab rounded p-1 text-ink-400 hover:bg-stone-100 active:cursor-grabbing dark:hover:bg-ink-700"
            >
              <GripVertical aria-hidden className="h-4 w-4" />
            </button>
          )}
          <h2 className="text-sm font-semibold text-ink-900 dark:text-gray-100">
            {title}
          </h2>
        </div>
        <button
          type="button"
          onClick={toggle}
          aria-expanded={!collapsed}
          aria-controls={`widget-${id}-content`}
          aria-label={collapsed ? 'Widget ausklappen' : 'Widget einklappen'}
          className="rounded p-1 text-ink-500 hover:bg-stone-100 dark:text-stone-400 dark:hover:bg-ink-700"
        >
          {collapsed ? <ChevronDown aria-hidden className="h-4 w-4" /> : <ChevronUp aria-hidden className="h-4 w-4" />}
        </button>
      </header>

      {!collapsed && (
        <div id={`widget-${id}-content`} className="p-3">
          <WidgetErrorBoundary
            fallback={(retry) => (
              <div role="alert" className="flex items-center justify-between gap-3 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-100">
                <span className="flex items-center gap-2">
                  <AlertTriangle aria-hidden className="h-4 w-4" />
                  Widget konnte nicht geladen werden.
                </span>
                <button
                  type="button"
                  onClick={retry}
                  className="inline-flex items-center gap-1 rounded-md border border-amber-300 px-2 py-1 text-xs font-medium hover:bg-amber-100 dark:border-amber-700 dark:hover:bg-amber-900/40"
                >
                  <RotateCcw aria-hidden className="h-3 w-3" />
                  Neu laden
                </button>
              </div>
            )}
          >
            {children}
          </WidgetErrorBoundary>
        </div>
      )}
    </section>
  )
}

export default WidgetWrapper
