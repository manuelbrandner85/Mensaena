'use client'

import { useEffect } from 'react'
import { useThemeStore, resolveTheme } from '@/store/useThemeStore'

/**
 * Applies the current theme to <html> as the `dark` class and keeps the
 * viewport theme-color meta in sync so the PWA status bar matches.
 * System-mode changes are watched via matchMedia.
 */
export default function ThemeProvider({ children }: { children: React.ReactNode }) {
  const mode = useThemeStore((s) => s.mode)

  useEffect(() => {
    if (typeof document === 'undefined') return

    const apply = () => {
      const resolved = resolveTheme(mode)
      const root = document.documentElement
      if (resolved === 'dark') {
        root.classList.add('dark')
      } else {
        root.classList.remove('dark')
      }
      // Update native theme-color so PWA status bar / iOS matches
      const meta = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
      if (meta) {
        meta.content = resolved === 'dark' ? '#0B1514' : '#0a1420'
      }
    }

    apply()

    if (mode === 'system' && typeof window !== 'undefined' && window.matchMedia) {
      const mql = window.matchMedia('(prefers-color-scheme: dark)')
      const handler = () => apply()
      mql.addEventListener('change', handler)
      return () => mql.removeEventListener('change', handler)
    }
  }, [mode])

  return <>{children}</>
}
