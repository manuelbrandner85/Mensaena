'use client'

import { useEffect } from 'react'
import dynamic from 'next/dynamic'

// Dynamic import to avoid SSR issues with zustand persist
const AppShell = dynamic(() => import('./AppShell'), { ssr: false })

export default function AppShellWrapper({ children }: { children: React.ReactNode }) {
  // ── Register Service Worker on first load ──────────────────────
  useEffect(() => {
    if (typeof window === 'undefined') return
    // Dynamic import to keep the main bundle small
    import('@/lib/pwa/register-sw').then(({ registerServiceWorker }) => {
      registerServiceWorker()
    })
  }, [])

  return <AppShell>{children}</AppShell>
}
