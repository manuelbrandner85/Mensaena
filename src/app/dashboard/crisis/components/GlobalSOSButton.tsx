'use client'

import { useState } from 'react'
import SOSButton from './SOSButton'
import SOSModal from './SOSModal'

/**
 * Global SOS button – red, pulsating, visible on all logged-in pages.
 * Rendered by AppShell.
 */
export default function GlobalSOSButton() {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <>
      {/* Floating SOS button – no bottom nav, so consistent bottom-6 */}
      <div className="fixed bottom-6 right-4 z-40" aria-label="SOS Notruf-Button">
        <SOSButton onClick={() => setIsOpen(true)} size="md" />
      </div>

      {/* SOS Modal */}
      <SOSModal isOpen={isOpen} onClose={() => setIsOpen(false)} />
    </>
  )
}
