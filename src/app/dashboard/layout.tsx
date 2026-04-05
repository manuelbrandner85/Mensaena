'use client'

import MensaenaBot from '@/components/bot/MensaenaBot'
import OfflineIndicator from '@/components/ui/OfflineIndicator'

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      {children}
      {/* Bot only in logged-in area */}
      <MensaenaBot />
      {/* Offline Indicator */}
      <OfflineIndicator />
    </>
  )
}
