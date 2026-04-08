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
      {/* Floating SOS button */}
      <div className="fixed bottom-24 lg:bottom-6 right-4 z-50" aria-label="SOS Notruf-Button">
        <SOSButton onClick={() => setIsOpen(true)} size="md" />
      </div>

      {/* SOS Modal */}
      <SOSModal isOpen={isOpen} onClose={() => setIsOpen(false)} />
    </>
  )
}
