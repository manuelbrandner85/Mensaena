'use client'

import { useEffect } from 'react'
import dynamic from 'next/dynamic'
import ThemeProvider from '@/components/ThemeProvider'
import { HtmlLangSync } from '@/lib/i18n'

// Dynamic imports to avoid SSR issues with zustand persist and to keep
// the shell bundle lean.
const AppShell = dynamic(() => import('./AppShell'), { ssr: false })
const CommandPalette = dynamic(() => import('@/components/shared/CommandPalette'), { ssr: false })
const OnboardingTour = dynamic(() => import('@/components/shared/OnboardingTour'), { ssr: false })

export default function AppShellWrapper({ children }: { children: React.ReactNode }) {
  // ── Register Service Worker on first load ──────────────────────
  useEffect(() => {
    if (typeof window === 'undefined') return
    // Dynamic import to keep the main bundle small
    import('@/lib/pwa/register-sw').then(({ registerServiceWorker }) => {
      registerServiceWorker()
    })
  }, [])

  return (
    <ThemeProvider>
      <HtmlLangSync />
      <AppShell>{children}</AppShell>
      <CommandPalette />
      <OnboardingTour />
    </ThemeProvider>
  )
}
