'use client'

import dynamic from 'next/dynamic'

// Dynamic import to avoid SSR issues with zustand persist
const AppShell = dynamic(() => import('./AppShell'), { ssr: false })

export default function AppShellWrapper({ children }: { children: React.ReactNode }) {
  return <AppShell>{children}</AppShell>
}
